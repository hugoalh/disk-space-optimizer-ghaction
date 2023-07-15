#Requires -PSEdition Core -Version 7.2
$Script:ErrorActionPreference = 'Stop'
Get-Alias -Scope 'Local' -ErrorAction 'SilentlyContinue' |
	Remove-Alias -Scope 'Local' -Force -ErrorAction 'SilentlyContinue'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Test-GitHubActionsEnvironment -Mandatory
Write-Host -Object 'Initialize.'
[Boolean]$OsIsLinux = $Env:RUNNER_OS -ieq 'Linux'
[Boolean]$OsIsMac = $Env:RUNNER_OS -ieq 'MacOS'
[Boolean]$OsIsWindows = $Env:RUNNER_OS -ieq 'Windows'
If ($True -inotin @($OsIsLinux, $OsIsMac, $OsIsWindows)) {
	Write-GitHubActionsWarning -Message "``$Env:RUNNER_OS`` is not an supported runner OS!"
	Exit 0
}
[String]$OsPathPropertyName = "Path$($Env:RUNNER_OS)"
[Boolean]$APTProgramIsExist = $Null -ine (Get-Command -Name 'apt-get' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
[ScriptBlock]$APTCommandListPackage = {
	apt list --installed *>&1 |
		Write-Output
}
[ScriptBlock]$APTCommandUninstallPackage = {
	Param ([String[]]$InputObject = @())
	ForEach ($_ In $InputObject) {
		apt-get --assume-yes remove $_ *>&1 |
			Write-Output
	}
}
[Boolean]$ChocolateyProgramIsExist = $Null -ine (Get-Command -Name 'choco' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
[ScriptBlock]$ChocolateyCommandListPackage = {
	choco list --include-programs --no-progress --prerelease *>&1 |
		Write-Output
}
[ScriptBlock]$ChocolateyCommandUninstallPackage = {
	Param ([String[]]$InputObject = @())
	ForEach ($_ In $InputObject) {
		choco uninstall $_ --ignore-detected-reboot --yes *>&1 |
			Write-Output
	}
}
[Boolean]$DockerProgramIsExist = $Null -ine (Get-Command -Name 'docker' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
[ScriptBlock]$DockerCommandListImage = {
	docker image ls --all --format '{{json .}}' *>&1 |
		Write-Output
}
[ScriptBlock]$DockerCommandPruneImage = {
	docker image prune --force *>&1 |
		Write-Output
}
[ScriptBlock]$DockerCommandRemoveImage = {
	Param ([String[]]$InputObject = @())
	ForEach ($_ In $InputObject) {
		docker image rm $_ *>&1 |
			Write-Output
	}
}
[Boolean]$HomebrewProgramIsExist = $Null -ine (Get-Command -Name 'brew' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
[ScriptBlock]$HomebrewCommandListPackage = {
	brew list -1 --versions *>&1 |
		Write-Output
}
[ScriptBlock]$HomebrewCommandUninstallPackage = {
	Param ([String[]]$InputObject = @())
	ForEach ($_ In $InputObject) {
		brew uninstall $_ *>&1 |
			Write-Output
	}
}
[Boolean]$NPMProgramIsExist = $Null -ine (Get-Command -Name 'npm' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
[ScriptBlock]$NPMCommandListPackage = {
	npm --global list *>&1 |
		Write-Output
}
[ScriptBlock]$NPMCommandUninstallPackage = {
	Param ([String[]]$InputObject = @())
	ForEach ($_ In $InputObject) {
		npm --global uninstall $_ *>&1 |
			Write-Output
	}
}
[Boolean]$PipxProgramIsExist = $Null -ine (Get-Command -Name 'pipx' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
[ScriptBlock]$PipxCommandListPackage = {
	pipx list --json *>&1 |
		Write-Output
}
[ScriptBlock]$PipxCommandUninstallPackage = {
	Param ([String[]]$InputObject = @())
	ForEach ($_ In $InputObject) {
		pipx uninstall $_ *>&1 |
			Write-Output
	}
}
[String]$SessionId = (
	New-Guid |
		Select-Object -ExpandProperty 'Guid'
).ToUpper() -ireplace '-', ''
Function Get-DiskSpace {
	[CmdletBinding()]
	[OutputType([String])]
	Param ()
	If ($OsIsWindows) {
		Get-Volume |
			Out-String -Width 120 |
			Write-Output
	}
	Else {
		df -h |
			Join-String -Separator "`n" |
			Write-Output
	}
}
Function Show-TreeDetail {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Stage
	)
	Enter-GitHubActionsLogGroup -Title "Path ($Stage): "
	[String[]]$PathTree = @()
	If ($OsIsLinux) {
		$PathTree += @(
			$Env:AGENT_TOOLSDIRECTORY,
			$Env:HOME,
			'/opt',
			'/usr/bin',
			'/usr/lib',
			'/usr/local',
			'/usr/sbin',
			'/usr/share'
		)
	}
	If ($OsIsMac) {
		$PathTree += @(
			$Env:AGENT_TOOLSDIRECTORY,
			$Env:HOME,
			'/Applications',
			'/opt',
			'/Users/runner',
			'/usr/bin',
			'/usr/lib',
			'/usr/local',
			'/usr/sbin',
			'/usr/share'
		)
	}
	If ($OsIsWindows) {
		$PathTree += @(
			$Env:APPDATA,
			$Env:LOCALAPPDATA,
			'C:\',
			'C:\Program Files (x86)',
			'C:\Program Files',
			'C:\ProgramData',
			'C:\Users',
			'D:\'
		)
	}
	$PathTree |
		ForEach-Object -Process {
			Get-ChildItem -LiteralPath $_ -Recurse -Depth 2 -Force -ErrorAction 'Continue'
		} |
		Select-Object -ExpandProperty 'FullName' |
		Sort-Object -Unique |
		Write-Host
	Exit-GitHubActionsLogGroup
	If ($APTProgramIsExist) {
		Enter-GitHubActionsLogGroup -Title "APT ($Stage): "
		Invoke-Command -ScriptBlock $APTCommandListPackage |
			Write-Host
		Exit-GitHubActionsLogGroup
	}
	If ($ChocolateyProgramIsExist) {
		Enter-GitHubActionsLogGroup -Title "Chocolatey ($Stage): "
		Invoke-Command -ScriptBlock $ChocolateyCommandListPackage |
			Write-Host
		Exit-GitHubActionsLogGroup
	}
	If ($DockerProgramIsExist) {
		Enter-GitHubActionsLogGroup -Title "Docker ($Stage): "
		Invoke-Command -ScriptBlock $DockerCommandListImage |
			Write-Host
		Exit-GitHubActionsLogGroup
	}
	If ($HomebrewProgramIsExist) {
		Enter-GitHubActionsLogGroup -Title "Homebrew ($Stage): "
		Invoke-Command -ScriptBlock $HomebrewCommandListPackage |
			Write-Host
		Exit-GitHubActionsLogGroup
	}
	If ($NPMProgramIsExist) {
		Enter-GitHubActionsLogGroup -Title "NPM ($Stage): "
		Invoke-Command -ScriptBlock $NPMCommandListPackage |
			Write-Host
		Exit-GitHubActionsLogGroup
	}
	If ($PipxProgramIsExist) {
		Enter-GitHubActionsLogGroup -Title "Pipx ($Stage): "
		Invoke-Command -ScriptBlock $PipxCommandListPackage |
			Write-Host
		Exit-GitHubActionsLogGroup
	}
}
Function Test-StringMatchRegEx {
	[CmdletBinding()]
	[OutputType([Boolean])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][String]$Item,
		[Parameter(Mandatory = $True, Position = 1)][AllowEmptyCollection()][Alias('Matchers')][RegEx[]]$Matcher
	)
	ForEach ($_M In $Matcher) {
		If ($Item -imatch $_M) {
			Write-Output -InputObject $True
			Return
		}
	}
	Write-Output -InputObject $False
}
[String]$DiskSpaceBefore = Get-DiskSpace
[PSCustomObject]@{
	Runner_OS = $Env:RUNNER_OS
	Env_ToolDirectory = $Env:AGENT_TOOLSDIRECTORY
	Program_APT = $APTProgramIsExist
	Program_Chocolatey = $ChocolateyProgramIsExist
	Program_Docker = $DockerProgramIsExist
	Program_Homebrew = $HomebrewProgramIsExist
	Program_NPM = $NPMProgramIsExist
	Program_Pipx = $PipxProgramIsExist
} |
	Format-List |
	Out-String -Width 120 |
	Write-GitHubActionsDebug
If (Get-GitHubActionsDebugStatus) {
	Show-TreeDetail -Stage 'Before'
}
Write-Host -Object 'Import input.'
[RegEx]$InputListDelimiter = Get-GitHubActionsInput -Name 'input_listdelimiter' -Mandatory -EmptyStringAsNull
[Boolean]$OperationAsync = [Boolean]::Parse((Get-GitHubActionsInput -Name 'operate_async' -Mandatory -EmptyStringAsNull))
[AllowEmptyCollection()][RegEx[]]$RemoveGeneralInclude = (
	((Get-GitHubActionsInput -Name 'general_include' -EmptyStringAsNull) ?? '') -isplit $InputListDelimiter |
		Where-Object -FilterScript { $_.Length -gt 0 }
) ?? @()
[AllowEmptyCollection()][RegEx[]]$RemoveGeneralExclude = (
	((Get-GitHubActionsInput -Name 'general_exclude' -EmptyStringAsNull) ?? '') -isplit $InputListDelimiter |
		Where-Object -FilterScript { $_.Length -gt 0 }
) ?? @()
[AllowEmptyCollection()][RegEx[]]$RemoveDockerImageInclude = (
	((Get-GitHubActionsInput -Name 'dockerimage_include' -EmptyStringAsNull) ?? '') -isplit $InputListDelimiter |
		Where-Object -FilterScript { $_.Length -gt 0 }
) ?? @()
[AllowEmptyCollection()][RegEx[]]$RemoveDockerImageExclude = (
	((Get-GitHubActionsInput -Name 'dockerimage_exclude' -EmptyStringAsNull) ?? '') -isplit $InputListDelimiter |
		Where-Object -FilterScript { $_.Length -gt 0 }
) ?? @()
[Boolean]$RemoveAptCache = [Boolean]::Parse((Get-GitHubActionsInput -Name 'cache_apt' -Mandatory -EmptyStringAsNull))
[Boolean]$RemoveDockerCache = [Boolean]::Parse((Get-GitHubActionsInput -Name 'cache_docker' -Mandatory -EmptyStringAsNull))
[Boolean]$RemoveHomebrewCache = [Boolean]::Parse((Get-GitHubActionsInput -Name 'cache_homebrew' -Mandatory -EmptyStringAsNull))
[Boolean]$RemoveNpmCache = [Boolean]::Parse((Get-GitHubActionsInput -Name 'cache_npm' -Mandatory -EmptyStringAsNull))
[Boolean]$RemoveLinuxSwap = [Boolean]::Parse((Get-GitHubActionsInput -Name 'swap' -Mandatory -EmptyStringAsNull))
Write-Host -Object 'Resolve operation.'
[String[]]$DockerImageListRaw = @()
[String[]]$DockerImageRemoveQueue = @()
[PSCustomObject[]]$GeneralRemoveQueue = @()
If ($DockerProgramIsExist -and $RemoveDockerImageInclude.Count -gt 0) {
	If ($OperationAsync) {
		$Null = Start-Job -Name "$SessionId/Docker/List" -ScriptBlock $DockerCommandListImage
	}
	Else {
		$DockerImageListRaw += Invoke-Command -ScriptBlock $DockerCommandListImage
	}
}
If ($RemoveGeneralInclude.Count -gt 0) {
	$GeneralRemoveQueue += Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'list.json') -Raw -Encoding 'UTF8NoBOM' -ErrorAction 'Continue' |
		ConvertFrom-Json -Depth 100 |
		Select-Object -ExpandProperty 'content' |
		Where-Object -FilterScript {
			($APTProgramIsExist -and $_.APT.Count -gt 0) -or
			($ChocolateyProgramIsExist -and $_.Chocolatey.Count -gt 0) -or
			($HomebrewProgramIsExist -and $_.Homebrew.Count -gt 0) -or
			($NPMProgramIsExist -and $_.NPM.Count -gt 0) -or
			($PipxProgramIsExist -and $_.Pipx.Count -gt 0) -or
			$_.Env.Count -gt 0 -or
			$_.($OsPathPropertyName).Count -gt 0
		} |
		Where-Object -FilterScript { (Test-StringMatchRegEx -Item $_.Name -Matcher $RemoveGeneralInclude) -and !(Test-StringMatchRegEx -Item $_.Name -Matcher $RemoveGeneralExclude) } |
		Sort-Object -Property 'Name'
}
If ($DockerProgramIsExist -and $RemoveDockerImageInclude.Count -gt 0 -and $OperationAsync) {
	$DockerImageListRaw += Receive-Job -Name "$SessionId/Docker/List" -Wait -AutoRemoveJob -ErrorAction 'Continue'
}
$DockerImageRemoveQueue += $DockerImageListRaw |
	Join-String -Separator ',' -OutputPrefix '[' -OutputSuffix ']' |
	ConvertFrom-Json -Depth 100 |
	ForEach-Object -Process { "$($_.Repository)$(($_.Tag.Length -gt 0) ? ":$($_.Tag)" : '')" } |
	Where-Object -FilterScript { (Test-StringMatchRegEx -Item $_ -Matcher $RemoveDockerImageInclude) -and !(Test-StringMatchRegEx -Item $_ -Matcher $RemoveDockerImageExclude) } |
	Sort-Object
If ($GeneralRemoveQueue.Count -gt 0) {
	Write-Host -Object "Removable item [$($GeneralRemoveQueue.Count)]: $(
		$GeneralRemoveQueue |
			Select-Object -ExpandProperty 'Name' |
			Join-String -Separator ', '
	)"
}
If ($DockerImageRemoveQueue.Count -gt 0) {
	Write-Host -Object "Removable Docker image [$($DockerImageRemoveQueue.Count)]: $(
		$DockerImageRemoveQueue |
			Join-String -Separator ', '
	)"
}
$Script:ErrorActionPreference = 'Continue'
If ($DockerProgramIsExist) {
	If ($OperationAsync) {
		Write-Host -Object '[ASYNC] Remove Docker image.'
		$Null = Start-Job -Name "$SessionId/Docker/Remove" -ScriptBlock $DockerCommandRemoveImage -ArgumentList (, $DockerImageRemoveQueue) {
			If ($Using:RemoveDockerCache) {
				docker image prune --force *>&1
			}
		}
	}
	Else {
		If ($DockerImageRemoveQueue.Count -gt 0) {
			ForEach ($_DI In $DockerImageRemoveQueue) {
				Write-Host -Object "Remove Docker image ``$_DI``."
				Invoke-Command -ScriptBlock $DockerCommandRemoveImage -ArgumentList (, $_DI) |
					Write-GitHubActionsDebug
			}
		}
		If ($RemoveDockerCache) {
			Write-Host -Object 'Remove Docker cache.'
			Invoke-Command -ScriptBlock $DockerCommandPruneImage |
				Write-GitHubActionsDebug
		}
	}
}
Function Invoke-GeneralOptimizeOperation {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][PSCustomObject[]]$Queue,
		[Parameter(Mandatory = $True, Position = 1)][UInt64]$Index
	)
	If ($OperationAsync) {
		[String[]]$QueueAPT = $Queue |
			ForEach-Object -Process {
				$_.APT |
					Write-Output
			}
		[String[]]$QueueChocolatey = $Queue |
			ForEach-Object -Process {
				$_.Chocolatey |
					Write-Output
			}
		[String[]]$QueueHomebrew = $Queue |
			ForEach-Object -Process {
				$_.Homebrew |
					Write-Output
			}
		[String[]]$QueueNPM = $Queue |
			ForEach-Object -Process {
				$_.NPM |
					Write-Output
			}
		[String[]]$QueuePipx = $Queue |
			ForEach-Object -Process {
				$_.Pipx |
					Write-Output
			}
		[PSCustomObject[]]$QueueFSPlain = $Queue |
			Where-Object -FilterScript {
				$_.APT.Count -eq 0 -and $_.Chocolatey.Count -eq 0 -and $_.Homebrew.Count -eq 0 -and $_.NPM.Count -eq 0 -and $_.Pipx.Count -eq 0 -and (
					$_.Env.Count -gt 0 -or
					$_.($OsPathPropertyName).Count -gt 0
				)
			}
		[PSCustomObject[]]$QueueFSRest = $Queue |
			Where-Object -FilterScript {
				($_.APT.Count -gt 0 -or $_.Chocolatey.Count -gt 0 -or $_.Homebrew.Count -gt 0 -or $_.NPM.Count -gt 0 -or $_.Pipx.Count -gt 0) -and (
					$_.Env.Count -gt 0 -or
					$_.($OsPathPropertyName).Count -gt 0
				)
			}
		If ($APTProgramIsExist -and $QueueAPT.Count -gt 0) {
			Write-Host -Object "[ASYNC] Remove APT package with postpone #$Index."
			$Null = Start-Job -Name "$SessionId/$Index/PM/APT" -ScriptBlock {
				ForEach ($APT In $Using:QueueAPT) {
					apt-get --assume-yes remove $APT *>&1
				}
			}
		}
		If ($ChocolateyProgramIsExist -and $QueueChocolatey.Count -gt 0) {
			Write-Host -Object "[ASYNC] Remove Chocolatey package with postpone #$Index."
			$Null = Start-Job -Name "$SessionId/$Index/PM/Chocolatey" -ScriptBlock {
				ForEach ($Chocolatey In $Using:QueueChocolatey) {
					choco uninstall $Chocolatey --ignore-detected-reboot --yes *>&1
				}
			}
		}
		If ($HomebrewProgramIsExist -and $QueueHomebrew.Count -gt 0) {
			Write-Host -Object "[ASYNC] Remove Homebrew package with postpone #$Index."
			$Null = Start-Job -Name "$SessionId/$Index/PM/Homebrew" -ScriptBlock {
				ForEach ($Homebrew In $Using:QueueHomebrew) {
					brew uninstall $Homebrew *>&1
				}
			}
		}
		If ($NPMProgramIsExist -and $QueueNPM.Count -gt 0) {
			Write-Host -Object "[ASYNC] Remove NPM package with postpone #$Index."
			$Null = Start-Job -Name "$SessionId/$Index/PM/NPM" -ScriptBlock {
				ForEach ($NPM In $Using:QueueNPM) {
					npm --global uninstall $NPM *>&1
				}
			}
		}
		If ($PipxProgramIsExist -and $QueuePipx.Count -gt 0) {
			Write-Host -Object "[ASYNC] Remove Pipx package with postpone #$Index."
			$Null = Start-Job -Name "$SessionId/$Index/PM/Pipx" -ScriptBlock {
				ForEach ($Pipx In $Using:QueuePipx) {
					pipx uninstall $Pipx *>&1
				}
			}
		}
		If ($QueueFSPlain.Count -gt 0) {
			ForEach ($FSPlain In $QueueFSPlain) {
				Write-Host -Object "[ASYNC] Remove $($FSPlain.Description) file with postpone #$Index."
				$Null = Start-Job -Name "$SessionId/$Index/FSPlain/$($FSPlain.Name)" -ScriptBlock {
					ForEach ($EnvName In ($Using:FSPlain).Env) {
						[String]$EnvValue = Get-Content -LiteralPath "Env:\$EnvName" -ErrorAction 'SilentlyContinue'
						If ($EnvValue.Length -gt 0 -and (Test-Path -LiteralPath $EnvValue)) {
							Get-ChildItem -LiteralPath $EnvValue -Force -ErrorAction 'Continue' |
								Remove-Item -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
						}
					}
					ForEach ($Path In ($Using:FSPlain).($Using:OsPathPropertyName)) {
						[String]$PathResolve = ($Path -imatch '\$Env:') ? (Invoke-Expression -Command "`"$Path`"") : $Path
						If ($PathResolve.Length -gt 0 -and (Test-Path -LiteralPath $PathResolve)) {
							Get-ChildItem -LiteralPath $PathResolve -Force -ErrorAction 'Continue' |
								Remove-Item -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
						}
					}
				}
			}
		}
		If ($QueueFSRest.Count -gt 0) {
			$Null = Wait-Job -Name "$SessionId/$Index/PM/*" -ErrorAction 'SilentlyContinue'
			ForEach ($FSRest In $QueueFSRest) {
				Write-Host -Object "[ASYNC] Remove $($FSRest.Description) file with postpone #$Index."
				$Null = Start-Job -Name "$SessionId/$Index/FSRest/$($FSRest.Name)" -ScriptBlock {
					ForEach ($EnvName In ($Using:FSRest).Env) {
						[String]$EnvValue = Get-Content -LiteralPath "Env:\$EnvName" -ErrorAction 'SilentlyContinue'
						If ($EnvValue.Length -gt 0 -and (Test-Path -LiteralPath $EnvValue)) {
							Get-ChildItem -LiteralPath $EnvValue -Force -ErrorAction 'Continue' |
								Remove-Item -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
						}
					}
					ForEach ($Path In ($Using:FSRest).($Using:OsPathPropertyName)) {
						[String]$PathResolve = ($Path -imatch '\$Env:') ? (Invoke-Expression -Command "`"$Path`"") : $Path
						If ($PathResolve.Length -gt 0 -and (Test-Path -LiteralPath $PathResolve)) {
							Get-ChildItem -LiteralPath $PathResolve -Force -ErrorAction 'Continue' |
								Remove-Item -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
						}
					}
				}
			}
		}
		$Null = Wait-Job -Name "$SessionId/$Index/*" -ErrorAction 'SilentlyContinue'
	}
	Else {
		ForEach ($Item In $Queue) {
			If ($APTProgramIsExist -and $Item.APT.Count -gt 0) {
				Write-Host -Object "Remove $($Item.Description) via APT."
				ForEach ($APT In $Item.APT) {
					apt-get --assume-yes remove $APT *>&1 |
						Write-GitHubActionsDebug
				}
			}
			If ($ChocolateyProgramIsExist -and $Item.Chocolatey.Count -gt 0) {
				Write-Host -Object "Remove $($Item.Description) via Chocolatey."
				ForEach ($Chocolatey In $Item.Chocolatey) {
					choco uninstall $Chocolatey --ignore-detected-reboot --yes *>&1 |
						Write-GitHubActionsDebug
				}
			}
			If ($HomebrewProgramIsExist -and $Item.Homebrew.Count -gt 0) {
				Write-Host -Object "Remove $($Item.Description) via Homebrew."
				ForEach ($Homebrew In $Item.Homebrew) {
					brew uninstall $Homebrew *>&1 |
						Write-GitHubActionsDebug
				}
			}
			If ($NPMProgramIsExist -and $Item.NPM.Count -gt 0) {
				Write-Host -Object "Remove $($Item.Description) via NPM."
				ForEach ($NPM In $Item.NPM) {
					npm --global uninstall $NPM *>&1 |
						Write-GitHubActionsDebug
				}
			}
			If ($PipxProgramIsExist -and $Item.Pipx.Count -gt 0) {
				Write-Host -Object "Remove $($Item.Description) via Pipx."
				ForEach ($Pipx In $Item.Pipx) {
					pipx uninstall $Pipx *>&1 |
						Write-GitHubActionsDebug
				}
			}
			If ($Item.Env.Count -gt 0 -or $Item.($OsPathPropertyName).Count -gt 0) {
				Write-Host -Object "Remove $($Item.Description) files."
				ForEach ($EnvName In $Item.Env) {
					[String]$EnvValue = Get-Content -LiteralPath "Env:\$EnvName" -ErrorAction 'SilentlyContinue'
					If ($EnvValue.Length -gt 0 -and (Test-Path -LiteralPath $EnvValue)) {
						Get-ChildItem -LiteralPath $EnvValue -Force -ErrorAction 'Continue' |
							Remove-Item -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
					}
				}
				ForEach ($Path In $Item.($OsPathPropertyName)) {
					[String]$PathResolve = ($Path -imatch '\$Env:') ? (Invoke-Expression -Command "`"$Path`"") : $Path
					If ($PathResolve.Length -gt 0 -and (Test-Path -LiteralPath $PathResolve)) {
						Get-ChildItem -LiteralPath $PathResolve -Force -ErrorAction 'Continue' |
							Remove-Item -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
					}
				}
			}
		}
	}
}
ForEach ($Index In (
	$GeneralRemoveQueue |
		Select-Object -ExpandProperty 'Postpone' |
		Sort-Object -Unique
)) {
	Invoke-GeneralOptimizeOperation -Queue (
		$GeneralRemoveQueue |
			Where-Object -FilterScript { $_.Postpone -eq $Index }
	) -Index $Index
}
If ($APTProgramIsExist -and $RemoveAptCache) {
	Write-Host -Object 'Remove APT cache.'
	apt-get --assume-yes autoremove *>&1 |
		Write-GitHubActionsDebug
	apt-get --assume-yes clean *>&1 |
		Write-GitHubActionsDebug
}
If ($HomebrewProgramIsExist -and $RemoveHomebrewCache) {
	Write-Host -Object 'Remove Homebrew cache.'
	brew autoremove *>&1 |
		Write-GitHubActionsDebug
}
If ($NPMProgramIsExist -and $RemoveNpmCache) {
	Write-Host -Object 'Remove NPM cache.'
	npm cache clean --force *>&1 |
		Write-GitHubActionsDebug
}
If ($OperationAsync) {
	$Null = Wait-Job -Name "$SessionId/*" -ErrorAction 'SilentlyContinue'
	If (Get-GitHubActionsDebugStatus) {
		Get-Job -Name "$SessionId/*" |
			ForEach-Object -Process {
				Enter-GitHubActionsLogGroup -Title "$($_.Name -ireplace "^$($SessionId)\/", '') ($($_.State))"
				Receive-Job -Name $_.Name -Wait -AutoRemoveJob
				Exit-GitHubActionsLogGroup
			}
	}
}
If ($OsIsLinux -and $RemoveLinuxSwap) {
	Write-Host -Object 'Remove Linux swap space.'
	swapoff -a *>&1 |
		Write-GitHubActionsDebug
	Remove-Item -LiteralPath '/mnt/swapfile' -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
}
If (Get-GitHubActionsDebugStatus) {
	Enter-GitHubActionsLogGroup -Title 'Program Tree (After): '
	Get-ProgramTree
	Exit-GitHubActionsLogGroup
	If ($APTProgramIsExist) {
		Enter-GitHubActionsLogGroup -Title 'APT (After): '
		Invoke-Command -ScriptBlock $APTCommandListPackage |
			Write-Host
		Exit-GitHubActionsLogGroup
	}
	If ($ChocolateyProgramIsExist) {
		Enter-GitHubActionsLogGroup -Title 'Chocolatey (After): '
		Invoke-Command -ScriptBlock $ChocolateyCommandListPackage |
			Write-Host
		Exit-GitHubActionsLogGroup
	}
	If ($DockerProgramIsExist) {
		Enter-GitHubActionsLogGroup -Title 'Docker (After): '
		Invoke-Command -ScriptBlock $DockerCommandListImage |
			Write-Host
		Exit-GitHubActionsLogGroup
	}
	If ($HomebrewProgramIsExist) {
		Enter-GitHubActionsLogGroup -Title 'Homebrew (After): '
		Invoke-Command -ScriptBlock $HomebrewCommandListPackage |
			Write-Host
		Exit-GitHubActionsLogGroup
	}
	If ($NPMProgramIsExist) {
		Enter-GitHubActionsLogGroup -Title 'NPM (After): '
		Invoke-Command -ScriptBlock $NPMCommandListPackage |
			Write-Host
		Exit-GitHubActionsLogGroup
	}
	If ($PipxProgramIsExist) {
		Enter-GitHubActionsLogGroup -Title 'Pipx (After): '
		Invoke-Command -ScriptBlock $PipxCommandListPackage |
			Write-Host
		Exit-GitHubActionsLogGroup
	}
}
$Script:ErrorActionPreference = 'Stop'
[String]$DiskSpaceAfter = Get-DiskSpace
Write-Host -Object @"
===== DISK SPACE BEFORE =====
$DiskSpaceBefore

===== DISK SPACE AFTER =====
$DiskSpaceAfter
"@
$LASTEXITCODE = 0
