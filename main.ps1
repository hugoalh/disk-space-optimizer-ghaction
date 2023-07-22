#Requires -PSEdition Core -Version 7.2
$Script:ErrorActionPreference = 'Stop'
Get-Alias -Scope 'Local' -ErrorAction 'SilentlyContinue' |
	Remove-Alias -Scope 'Local' -Force -ErrorAction 'SilentlyContinue'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'common.psm1') -Scope 'Local'
Test-GitHubActionsEnvironment -Mandatory
Write-Host -Object 'Initialize.'
If ($True -inotin @($OsIsLinux, $OsIsMac, $OsIsWindows)) {
	Write-GitHubActionsWarning -Message "``$Env:RUNNER_OS`` is not an supported runner OS!"
	Exit 0
}
[String]$OsPathPropertyName = "Path$($Env:RUNNER_OS)"
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
	Program_WMIC = $WMICProgramIsExist
} |
	Format-List |
	Out-String -Width 120 |
	Write-GitHubActionsDebug
Write-Host -Object 'Import input.'
[RegEx]$InputListDelimiter = Get-GitHubActionsInput -Name 'input_listdelimiter' -Mandatory -EmptyStringAsNull
[Boolean]$OperationAsync = [Boolean]::Parse((Get-GitHubActionsInput -Name 'operate_async' -Mandatory -EmptyStringAsNull))
[AllowEmptyCollection()][RegEx[]]$InputGeneralInclude = (
	((Get-GitHubActionsInput -Name 'general_include' -EmptyStringAsNull) ?? '') -isplit $InputListDelimiter |
		Where-Object -FilterScript { $_.Length -gt 0 }
) ?? @()
[AllowEmptyCollection()][RegEx[]]$InputGeneralExclude = (
	((Get-GitHubActionsInput -Name 'general_exclude' -EmptyStringAsNull) ?? '') -isplit $InputListDelimiter |
		Where-Object -FilterScript { $_.Length -gt 0 }
) ?? @()
[AllowEmptyCollection()][RegEx[]]$InputDockerInclude = (
	((Get-GitHubActionsInput -Name 'docker_include' -EmptyStringAsNull) ?? '') -isplit $InputListDelimiter |
		Where-Object -FilterScript { $_.Length -gt 0 }
) ?? @()
[AllowEmptyCollection()][RegEx[]]$InputDockerExclude = (
	((Get-GitHubActionsInput -Name 'docker_exclude' -EmptyStringAsNull) ?? '') -isplit $InputListDelimiter |
		Where-Object -FilterScript { $_.Length -gt 0 }
) ?? @()
[Boolean]$InputDockerPrune = [Boolean]::Parse((Get-GitHubActionsInput -Name 'docker_prune' -Mandatory -EmptyStringAsNull))
[Boolean]$InputDockerClean = [Boolean]::Parse((Get-GitHubActionsInput -Name 'docker_clean' -Mandatory -EmptyStringAsNull))
[Boolean]$InputAptPrune = [Boolean]::Parse((Get-GitHubActionsInput -Name 'apt_prune' -Mandatory -EmptyStringAsNull))
[Boolean]$InputAptClean = [Boolean]::Parse((Get-GitHubActionsInput -Name 'apt_clean' -Mandatory -EmptyStringAsNull))
[Boolean]$InputHomebrewPrune = [Boolean]::Parse((Get-GitHubActionsInput -Name 'homebrew_prune' -Mandatory -EmptyStringAsNull))
[Boolean]$InputHomebrewClean = [Boolean]::Parse((Get-GitHubActionsInput -Name 'homebrew_clean' -Mandatory -EmptyStringAsNull))
[Boolean]$InputNpmPrune = [Boolean]::Parse((Get-GitHubActionsInput -Name 'npm_prune' -Mandatory -EmptyStringAsNull))
[Boolean]$InputNpmClean = [Boolean]::Parse((Get-GitHubActionsInput -Name 'npm_clean' -Mandatory -EmptyStringAsNull))
[Boolean]$InputOsSwap = [Boolean]::Parse((Get-GitHubActionsInput -Name 'os_swap' -Mandatory -EmptyStringAsNull))
Write-Host -Object 'Resolve operation.'
[String[]]$DockerImageListRaw = @()
[String[]]$DockerImageRemove = @()
[PSCustomObject[]]$GeneralRemove = @()
If ($DockerProgramIsExist -and $InputDockerInclude.Count -gt 0) {
	If ($OperationAsync) {
		$Null = Start-Job -Name "$SessionId/Docker/List" -ScriptBlock $DockerCommandListImage
	}
	Else {
		$DockerImageListRaw += Invoke-Command -ScriptBlock $DockerCommandListImage
	}
}
If ($InputGeneralInclude.Count -gt 0) {
	$GeneralRemove += Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'list.json') -Raw -Encoding 'UTF8NoBOM' -ErrorAction 'Continue' |
		ConvertFrom-Json -Depth 100 |
		Select-Object -ExpandProperty 'content' |
		Where-Object -FilterScript {
			($APTProgramIsExist -and $_.APT.Count -gt 0) -or
			($ChocolateyProgramIsExist -and $_.Chocolatey.Count -gt 0) -or
			($HomebrewProgramIsExist -and $_.Homebrew.Count -gt 0) -or
			($NPMProgramIsExist -and $_.NPM.Count -gt 0) -or
			($PipxProgramIsExist -and $_.Pipx.Count -gt 0) -or
			($WMICProgramIsExist -and $_.WMIC.Count -gt 0) -or
			$_.Env.Count -gt 0 -or
			$_.($OsPathPropertyName).Count -gt 0
		} |
		Where-Object -FilterScript { (Test-StringMatchRegEx -Item $_.Name -Matcher $InputGeneralInclude) -and !(Test-StringMatchRegEx -Item $_.Name -Matcher $InputGeneralExclude) } |
		Sort-Object -Property 'Name'
}
If ($DockerProgramIsExist -and $InputDockerInclude.Count -gt 0 -and $OperationAsync) {
	$DockerImageListRaw += Receive-Job -Name "$SessionId/Docker/List" -Wait -AutoRemoveJob -ErrorAction 'Continue'
}
$DockerImageRemove += $DockerImageListRaw |
	Join-String -Separator ',' -OutputPrefix '[' -OutputSuffix ']' |
	ConvertFrom-Json -Depth 100 -ErrorAction 'Continue' |
	ForEach-Object -Process { "$($_.Repository)$(($_.Tag.Length -gt 0) ? ":$($_.Tag)" : '')" } |
	Where-Object -FilterScript { (Test-StringMatchRegEx -Item $_ -Matcher $InputDockerInclude) -and !(Test-StringMatchRegEx -Item $_ -Matcher $InputDockerExclude) } |
	Sort-Object
If ($GeneralRemove.Count -gt 0) {
	Write-Host -Object "Removable item [$($GeneralRemove.Count)]: $(
		$GeneralRemove |
			Select-Object -ExpandProperty 'Name' |
			Join-String -Separator ', '
	)"
}
If ($DockerImageRemove.Count -gt 0) {
	Write-Host -Object "Removable Docker image [$($DockerImageRemove.Count)]: $(
		$DockerImageRemove |
			Join-String -Separator ', '
	)"
}
$Script:ErrorActionPreference = 'Continue'
If ($DockerProgramIsExist) {
	If ($OperationAsync) {
		Write-Host -Object '[ASYNC] Remove Docker image.'
		$Null = Start-Job -Name "$SessionId/Docker/Remove" -ScriptBlock $DockerCommandRemoveImage -ArgumentList @(, $DockerImageRemove)
	}
	Else {
		ForEach ($_DI In $DockerImageRemove) {
			Write-Host -Object "Remove Docker image ``$_DI``."
			Invoke-Command -ScriptBlock $DockerCommandRemoveImage -ArgumentList @(, $_DI) |
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
		[String[]]$QueueWMIC = $Queue |
			ForEach-Object -Process {
				$_.WMIC |
					Write-Output
			}
		[PSCustomObject[]]$QueueFSPlain = $Queue |
			Where-Object -FilterScript {
				$_.APT.Count -eq 0 -and $_.Chocolatey.Count -eq 0 -and $_.Homebrew.Count -eq 0 -and $_.NPM.Count -eq 0 -and $_.Pipx.Count -eq 0 -and $_.WMIC.Count -eq 0 -and (
					$_.Env.Count -gt 0 -or
					$_.($OsPathPropertyName).Count -gt 0
				)
			}
		[PSCustomObject[]]$QueueFSRest = $Queue |
			Where-Object -FilterScript {
				($_.APT.Count -gt 0 -or $_.Chocolatey.Count -gt 0 -or $_.Homebrew.Count -gt 0 -or $_.NPM.Count -gt 0 -or $_.Pipx.Count -gt 0 -or $_.WMIC.Count -gt 0) -and (
					$_.Env.Count -gt 0 -or
					$_.($OsPathPropertyName).Count -gt 0
				)
			}
		If ($APTProgramIsExist -and $QueueAPT.Count -gt 0) {
			Write-Host -Object "[ASYNC] Remove APT package with postpone #$Index."
			$Null = Start-Job -Name "$SessionId/$Index/PM/APT" -ScriptBlock $APTCommandUninstallPackage -ArgumentList @(, $QueueAPT)
		}
		If ($ChocolateyProgramIsExist -and $QueueChocolatey.Count -gt 0) {
			Write-Host -Object "[ASYNC] Remove Chocolatey package with postpone #$Index."
			$Null = Start-Job -Name "$SessionId/$Index/PM/Chocolatey" -ScriptBlock $ChocolateyCommandUninstallPackage -ArgumentList @(, $QueueChocolatey)
		}
		If ($HomebrewProgramIsExist -and $QueueHomebrew.Count -gt 0) {
			Write-Host -Object "[ASYNC] Remove Homebrew package with postpone #$Index."
			$Null = Start-Job -Name "$SessionId/$Index/PM/Homebrew" -ScriptBlock $HomebrewCommandUninstallPackage -ArgumentList @(, $QueueHomebrew)
		}
		If ($NPMProgramIsExist -and $QueueNPM.Count -gt 0) {
			Write-Host -Object "[ASYNC] Remove NPM package with postpone #$Index."
			$Null = Start-Job -Name "$SessionId/$Index/PM/NPM" -ScriptBlock $NPMCommandUninstallPackage -ArgumentList @(, $QueueNPM)
		}
		If ($PipxProgramIsExist -and $QueuePipx.Count -gt 0) {
			Write-Host -Object "[ASYNC] Remove Pipx package with postpone #$Index."
			$Null = Start-Job -Name "$SessionId/$Index/PM/Pipx" -ScriptBlock $PipxCommandUninstallPackage -ArgumentList @(, $QueuePipx)
		}
		If ($WMICProgramIsExist -and $QueueWMIC.Count -gt 0) {
			Write-Host -Object "[ASYNC] Remove WMIC package with postpone #$Index."
			$Null = Start-Job -Name "$SessionId/$Index/PM/WMIC" -ScriptBlock $WMICCommandUninstallPackage -ArgumentList @(, $QueueWMIC)
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
				Invoke-Command -ScriptBlock $APTCommandUninstallPackage -ArgumentList @(, $Item.APT) |
					Write-GitHubActionsDebug
			}
			If ($ChocolateyProgramIsExist -and $Item.Chocolatey.Count -gt 0) {
				Write-Host -Object "Remove $($Item.Description) via Chocolatey."
				Invoke-Command -ScriptBlock $ChocolateyCommandUninstallPackage -ArgumentList @(, $Item.Chocolatey) |
					Write-GitHubActionsDebug
			}
			If ($HomebrewProgramIsExist -and $Item.Homebrew.Count -gt 0) {
				Write-Host -Object "Remove $($Item.Description) via Homebrew."
				Invoke-Command -ScriptBlock $HomebrewCommandUninstallPackage -ArgumentList @(, $Item.Homebrew) |
					Write-GitHubActionsDebug
			}
			If ($NPMProgramIsExist -and $Item.NPM.Count -gt 0) {
				Write-Host -Object "Remove $($Item.Description) via NPM."
				Invoke-Command -ScriptBlock $NPMCommandUninstallPackage -ArgumentList @(, $Item.NPM) |
					Write-GitHubActionsDebug
			}
			If ($PipxProgramIsExist -and $Item.Pipx.Count -gt 0) {
				Write-Host -Object "Remove $($Item.Description) via Pipx."
				Invoke-Command -ScriptBlock $PipxCommandUninstallPackage -ArgumentList @(, $Item.Pipx) |
					Write-GitHubActionsDebug
			}
			If ($WMICProgramIsExist -and $Item.WMIC.Count -gt 0) {
				Write-Host -Object "Remove $($Item.Description) via WMIC."
				Invoke-Command -ScriptBlock $WMICCommandUninstallPackage -ArgumentList @(, $Item.WMIC) |
					Write-GitHubActionsDebug
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
	$GeneralRemove |
		Select-Object -ExpandProperty 'Postpone' |
		Sort-Object -Unique
)) {
	Invoke-GeneralOptimizeOperation -Queue (
		$GeneralRemove |
			Where-Object -FilterScript { $_.Postpone -eq $Index }
	) -Index $Index
}
If ($OperationAsync) {
	$Null = Wait-Job -Name "$SessionId/*" -ErrorAction 'SilentlyContinue'
	If (Get-GitHubActionsDebugStatus) {
		Get-Job -Name "$SessionId/*" |
			ForEach-Object -Process {
				Enter-GitHubActionsLogGroup -Title "$($_.Name) ($($_.State))"
				Receive-Job -Name $_.Name -Wait -AutoRemoveJob
				Exit-GitHubActionsLogGroup
			}
	}
	Else {
		Get-Job -Name "$SessionId/*" |
			Remove-Job -Force -Confirm:$False
	}
}
If ($APTProgramIsExist) {
	If ($InputAptPrune) {
		Write-Host -Object 'Prune APT package.'
		apt-get --assume-yes autoremove *>&1 |
			Write-GitHubActionsDebug
	}
	If ($InputAptClean) {
		Write-Host -Object 'Remove APT cache.'
		apt-get --assume-yes clean *>&1 |
			Write-GitHubActionsDebug
	}
}
If ($DockerProgramIsExist) {
	If ($InputDockerPrune) {
		Write-Host -Object 'Prune Docker image.'
		docker image prune --force *>&1 |
			Write-GitHubActionsDebug
	}
	If ($InputDockerClean) {
		Write-Host -Object 'Clean Docker cache.'
		docker system prune --force *>&1 |
			Write-GitHubActionsDebug
	}
}
If ($HomebrewProgramIsExist) {
	If ($InputHomebrewPrune) {
		Write-Host -Object 'Prune Homebrew package.'
		brew autoremove *>&1 |
			Write-GitHubActionsDebug
	}
	If ($InputHomebrewClean) {
		Write-Host -Object 'Remove Homebrew cache.'
		brew cleanup --prune=all -s *>&1 |
			Write-GitHubActionsDebug
	}
}
If ($NPMProgramIsExist) {
	If ($InputNpmPrune) {
		Write-Host -Object 'Prune NPM package.'
		npm prune *>&1 |
			Write-GitHubActionsDebug
	}
	If ($InputNpmClean) {
		Write-Host -Object 'Remove NPM cache.'
		npm cache clean --force *>&1 |
			Write-GitHubActionsDebug
	}
}
If ($InputOsSwap) {
	If ($OsIsLinux) {
		Write-Host -Object 'Remove Linux page/swap file.'
		swapoff -a *>&1 |
			Write-GitHubActionsDebug
		Remove-Item -LiteralPath '/mnt/swapfile' -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
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
