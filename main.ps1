#Requires -PSEdition Core -Version 7.2
$Script:ErrorActionPreference = 'Stop'
Get-Alias -Scope 'Local' -ErrorAction 'SilentlyContinue' |
	Remove-Alias -Scope 'Local' -Force -ErrorAction 'SilentlyContinue'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Test-GitHubActionsEnvironment -Mandatory
Write-Host -Object 'Initialize.'
[Boolean]$OsLinux = $Env:RUNNER_OS -ieq 'Linux'
[Boolean]$OsMac = $Env:RUNNER_OS -ieq 'MacOS'
[Boolean]$OsWindows = $Env:RUNNER_OS -ieq 'Windows'
[String]$OsPathType = "Path$($Env:RUNNER_OS)"
[Boolean]$APTProgram = $Null -ine (Get-Command -Name 'apt-get' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
[String[]]$APTRemoveQueue = @()
[Boolean]$ChocolateyProgram = $Null -ine (Get-Command -Name 'choco' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
[String[]]$ChocolateyRemoveQueue = @()
[Boolean]$DockerProgram = $Null -ine (Get-Command -Name 'docker' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
[String[]]$DockerList = @()
[String[]]$DockerRemoveQueue = @()
[String[]]$FileEnvRemoveQueue = @()
[String[]]$FilePathRemoveQueue = @()
[Boolean]$HomebrewProgram = $Null -ine (Get-Command -Name 'brew' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
[String[]]$HomebrewRemoveQueue = @()
[Boolean]$NPMProgram = $Null -ine (Get-Command -Name 'npm' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
[String[]]$NPMRemoveQueue = @()
[Boolean]$PipxProgram = $Null -ine (Get-Command -Name 'pipx' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
[String[]]$PipxRemoveQueue = @()
[String[]]$RemoveQueueName = @()
[String]$JobIdPrefix = (
	New-Guid |
		Select-Object -ExpandProperty 'Guid'
).ToUpper() -ireplace '-', ''
Function Get-DiskSpace {
	[CmdletBinding()]
	[OutputType([String])]
	Param ()
	If ($OsWindows) {
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
	Runner_Session = $JobIdPrefix
	Program_APT = $APTProgram
	Program_Chocolatey = $ChocolateyProgram
	Program_Docker = $DockerProgram
	Program_Homebrew = $HomebrewProgram
	Program_NPM = $NPMProgram
	Program_Pipx = $PipxProgram
} |
	Format-List |
	Out-String -Width 120 |
	Write-GitHubActionsDebug
Write-Host -Object 'Import input.'
[RegEx]$InputListDelimiter = Get-GitHubActionsInput -Name 'input_listdelimiter' -Mandatory -EmptyStringAsNull
[Boolean]$OperationAsync = [Boolean]::Parse((Get-GitHubActionsInput -Name 'operate_async' -Mandatory -EmptyStringAsNull))
[AllowEmptyCollection()][RegEx[]]$RemoveGeneralInclude = ((
	((Get-GitHubActionsInput -Name 'general_include' -EmptyStringAsNull) ?? '') -isplit $InputListDelimiter |
		Where-Object -FilterScript { $_.Length -gt 0 }
) + (
	((Get-GitHubActionsInput -Name 'general' -EmptyStringAsNull) ?? '') -isplit $InputListDelimiter |
		Where-Object -FilterScript { $_.Length -gt 0 }
)) ?? @()
[AllowEmptyCollection()][RegEx[]]$RemoveGeneralExclude = (
	((Get-GitHubActionsInput -Name 'general_exclude' -EmptyStringAsNull) ?? '') -isplit $InputListDelimiter |
		Where-Object -FilterScript { $_.Length -gt 0 }
) ?? @()
[Boolean]$RemoveAptCache = [Boolean]::Parse((Get-GitHubActionsInput -Name 'aptcache' -Mandatory -EmptyStringAsNull))
[AllowEmptyCollection()][RegEx[]]$RemoveDockerImageInclude = ((
	((Get-GitHubActionsInput -Name 'dockerimage_include' -EmptyStringAsNull) ?? '') -isplit $InputListDelimiter |
		Where-Object -FilterScript { $_.Length -gt 0 }
) + (
	((Get-GitHubActionsInput -Name 'dockerimage' -EmptyStringAsNull) ?? '') -isplit $InputListDelimiter |
		Where-Object -FilterScript { $_.Length -gt 0 }
)) ?? @()
[AllowEmptyCollection()][RegEx[]]$RemoveDockerImageExclude = (
	((Get-GitHubActionsInput -Name 'dockerimage_exclude' -EmptyStringAsNull) ?? '') -isplit $InputListDelimiter |
		Where-Object -FilterScript { $_.Length -gt 0 }
) ?? @()
[Boolean]$RemoveHomebrewCache = [Boolean]::Parse((Get-GitHubActionsInput -Name 'homebrewcache' -Mandatory -EmptyStringAsNull))
[Boolean]$RemoveNpmCache = [Boolean]::Parse((Get-GitHubActionsInput -Name 'npmcache' -Mandatory -EmptyStringAsNull))
[Boolean]$RemoveLinuxSwap = [Boolean]::Parse((Get-GitHubActionsInput -Name 'swap' -Mandatory -EmptyStringAsNull))
If ($DockerProgram -and $RemoveDockerImageInclude.Count -gt 0) {
	If ($OperationAsync) {
		$Null = Start-Job -Name "$JobIdPrefix/Docker/List" -ScriptBlock {
			docker image ls --all --format '{{json .}}' |
				Join-String -Separator ',' -OutputPrefix '[' -OutputSuffix ']' |
				ConvertFrom-Json -Depth 100 |
				ForEach-Object -Process { "$($_.Repository)$(($_.Tag.Length -gt 0) ? ":$($_.Tag)" : '')" } |
				Write-Output
		}
	}
	Else {
		$DockerList += docker image ls --all --format '{{json .}}' |
			Join-String -Separator ',' -OutputPrefix '[' -OutputSuffix ']' |
			ConvertFrom-Json -Depth 100 |
			ForEach-Object -Process { "$($_.Repository)$(($_.Tag.Length -gt 0) ? ":$($_.Tag)" : '')" }
		$DockerRemoveQueue += $DockerList |
			Where-Object -FilterScript { (Test-StringMatchRegEx -Item $_ -Matcher $RemoveDockerImageInclude) -and !(Test-StringMatchRegEx -Item $_ -Matcher $RemoveDockerImageExclude) }
	}
}
If ($RemoveGeneralInclude.Count -gt 0) {
	ForEach ($Item In (
		Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'list.json') -Raw -Encoding 'UTF8NoBOM' -ErrorAction 'Continue' |
			ConvertFrom-Json -Depth 100 |
			Select-Object -ExpandProperty 'content' |
			Where-Object -FilterScript {
				($APTProgram -and $_.APT.Count -gt 0) -or
				($ChocolateyProgram -and $_.Chocolatey.Count -gt 0) -or
				($HomebrewProgram -and $_.Homebrew.Count -gt 0) -or
				($NPMProgram -and $_.NPM.Count -gt 0) -or
				($PipxProgram -and $_.Pipx.Count -gt 0) -or
				$_.Env.Count -gt 0 -or
				$_.($OsPathType).Count -gt 0
			} |
			Where-Object -FilterScript { (Test-StringMatchRegEx -Item $_.Name -Matcher $RemoveGeneralInclude) -and !(Test-StringMatchRegEx -Item $_.Name -Matcher $RemoveGeneralExclude) } |
			Sort-Object -Property 'Name' |
			Sort-Object -Property 'Priority' -Descending
	)) {
		$RemoveQueueName += $Item.Name
		$APTRemoveQueue += $Item.APT
		$ChocolateyRemoveQueue += $Item.Chocolatey
		$FileEnvRemoveQueue += $Item.Env
		$FilePathRemoveQueue += $Item.($OsPathType)
		$HomebrewRemoveQueue += $Item.Homebrew
		$NPMRemoveQueue += $Item.NPM
		$PipxRemoveQueue += $Item.Pipx
	}
}
If ($DockerProgram -and $RemoveDockerImageInclude.Count -gt 0 -and $OperationAsync) {
	$DockerList += Receive-Job -Name "$JobIdPrefix/Docker/List" -Wait -AutoRemoveJob
	$DockerRemoveQueue += $DockerList |
		Where-Object -FilterScript { (Test-StringMatchRegEx -Item $_ -Matcher $RemoveDockerImageInclude) -and !(Test-StringMatchRegEx -Item $_ -Matcher $RemoveDockerImageExclude) }
}
[String[]]$FileEnvRemoveQueueResolve = $FileEnvRemoveQueue |
	ForEach-Object -Process { Get-Content -LiteralPath "Env:\$_" -ErrorAction 'SilentlyContinue' } |
	Where-Object -FilterScript { $_.Length -gt 0 } |
	Select-Object -Unique
[String[]]$FilePathRemoveQueueResolve = $FilePathRemoveQueue |
	ForEach-Object -Process { ($_ -imatch '\$Env:') ? (Invoke-Expression -Command "`"$_`"") : $_ } |
	Where-Object -FilterScript { $_.Length -gt 0 } |
	Select-Object -Unique
If ($RemoveQueueName.Count -gt 0) {
	Write-Host -Object "Remove item [$($RemoveQueueName.Count)]: $(
		$RemoveQueueName |
			Sort-Object |
			Join-String -Separator ', '
	)"
}
If ($DockerRemoveQueue.Count -gt 0) {
	Write-Host -Object "Remove Docker image [$($DockerRemoveQueue.Count)]: $(
		$DockerRemoveQueue |
			Join-String -Separator ', '
	)"
}
Write-GitHubActionsDebug -Message "Remove file (Env) [$($FileEnvRemoveQueueResolve.Count)]: $(
	$FileEnvRemoveQueueResolve |
		Join-String -Separator ', '
)"
Write-GitHubActionsDebug -Message "Remove file (Path) [$($FilePathRemoveQueueResolve.Count)]: $(
	$FilePathRemoveQueueResolve |
		Join-String -Separator ', '
)"
$Script:ErrorActionPreference = 'Continue'
If ($DockerProgram) {
	If ($OperationAsync) {
		Write-Host -Object '[ASYNC] Remove Docker image and cache.'
		$Null = Start-Job -Name "$JobIdPrefix/Docker/Optimize" -ScriptBlock {
			ForEach ($_DI In $Using:DockerRemoveQueue) {
				docker image rm $_DI *>&1
			}
			docker image prune --force *>&1
		}
	}
	Else {
		If ($DockerRemoveQueue.Count -gt 0) {
			Write-Host -Object 'Remove Docker image.'
			ForEach ($_DI In $DockerRemoveQueue) {
				docker image rm $_DI *>&1 |
					Write-GitHubActionsDebug
			}
		}
		Write-Host -Object 'Remove Docker cache.'
		docker image prune --force *>&1 |
			Write-GitHubActionsDebug
	}
}
If ($APTProgram) {
	If ($OperationAsync) {
		Write-Host -Object '[ASYNC] Remove APT package and cache.'
		$Null = Start-Job -Name "$JobIdPrefix/APT/Optimize" -ScriptBlock {
			ForEach ($APT In $Using:APTRemoveQueue) {
				apt-get --assume-yes remove $APT *>&1
			}
			If ($Using:RemoveAptCache) {
				apt-get --assume-yes autoremove *>&1
				apt-get --assume-yes clean *>&1
			}
		}
	}
	Else {
		If ($APTRemoveQueue.Count -gt 0) {
			Write-Host -Object 'Remove APT package.'
			ForEach ($APT In $APTRemoveQueue) {
				apt-get --assume-yes remove $APT *>&1 |
					Write-GitHubActionsDebug
			}
		}
		If ($RemoveAptCache) {
			Write-Host -Object 'Remove APT cache.'
			apt-get --assume-yes autoremove *>&1 |
				Write-GitHubActionsDebug
			apt-get --assume-yes clean *>&1 |
				Write-GitHubActionsDebug
		}
	}
}
If ($ChocolateyProgram) {
	If ($OperationAsync) {
		Write-Host -Object '[ASYNC] Remove Chocolatey package.'
		$Null = Start-Job -Name "$JobIdPrefix/Chocolatey/Optimize" -ScriptBlock {
			ForEach ($Chocolatey In $Using:ChocolateyRemoveQueue) {
				choco uninstall $Chocolatey --ignore-detected-reboot --yes *>&1
			}
		}
	}
	Else {
		If ($ChocolateyRemoveQueue.Count -gt 0) {
			Write-Host -Object 'Remove Chocolatey package.'
			ForEach ($Chocolatey In $ChocolateyRemoveQueue) {
				choco uninstall $Chocolatey --ignore-detected-reboot --yes *>&1 |
					Write-GitHubActionsDebug
			}
		}
	}
}
If ($HomebrewProgram) {
	If ($OperationAsync) {
		Write-Host -Object '[ASYNC] Remove Homebrew package and cache.'
		$Null = Start-Job -Name "$JobIdPrefix/Homebrew/Optimize" -ScriptBlock {
			ForEach ($Homebrew In $Using:HomebrewRemoveQueue) {
				brew uninstall $Homebrew *>&1
			}
			If ($Using:RemoveHomebrewCache) {
				brew autoremove *>&1
			}
		}
	}
	Else {
		If ($HomebrewRemoveQueue.Count -gt 0) {
			Write-Host -Object 'Remove Homebrew package.'
			ForEach ($Homebrew In $HomebrewRemoveQueue) {
				brew uninstall $Homebrew *>&1 |
					Write-GitHubActionsDebug
			}
		}
		If ($RemoveHomebrewCache) {
			Write-Host -Object 'Remove Homebrew cache.'
			brew autoremove *>&1 |
				Write-GitHubActionsDebug
		}
	}
}
If ($NPMProgram) {
	If ($OperationAsync) {
		Write-Host -Object '[ASYNC] Remove NPM package and cache.'
		$Null = Start-Job -Name "$JobIdPrefix/NPM/Optimize" -ScriptBlock {
			ForEach ($NPM In $Using:NPMRemoveQueue) {
				npm --global uninstall $NPM *>&1
			}
			If ($Using:RemoveNpmCache) {
				npm cache clean --force *>&1
			}
		}
	}
	Else {
		If ($NPMRemoveQueue.Count -gt 0) {
			Write-Host -Object 'Remove NPM package.'
			ForEach ($NPM In $NPMRemoveQueue) {
				npm --global uninstall $NPM *>&1 |
					Write-GitHubActionsDebug
			}
		}
		If ($RemoveNpmCache) {
			Write-Host -Object 'Remove NPM cache.'
			npm cache clean --force *>&1 |
				Write-GitHubActionsDebug
		}
	}
}
If ($PipxProgram) {
	If ($OperationAsync) {
		Write-Host -Object '[ASYNC] Remove Pipx package.'
		$Null = Start-Job -Name "$JobIdPrefix/Pipx/Optimize" -ScriptBlock {
			ForEach ($Pipx In $Using:PipxRemoveQueue) {
				pipx uninstall $Pipx *>&1
			}
		}
	}
	Else {
		If ($PipxRemoveQueue.Count -gt 0) {
			Write-Host -Object 'Remove Pipx package.'
			ForEach ($Pipx In $PipxRemoveQueue) {
				pipx uninstall $Pipx *>&1 |
					Write-GitHubActionsDebug
			}
		}
	}
}
If ($OperationAsync) {
	$Null = Wait-Job -Name "$JobIdPrefix/*" -ErrorAction 'SilentlyContinue'
	Get-Job -Name "$JobIdPrefix/*" |
		Format-Table -Property @('Name', 'State') -AutoSize -Wrap |
		Out-String -Width 120 |
		Write-GitHubActionsDebug
	If (Get-GitHubActionsDebugStatus) {
		Get-Job -Name "$JobIdPrefix/*" |
			ForEach-Object -Process {
				Enter-GitHubActionsLogGroup -Title $_.Name
				Receive-Job -Name $_.Name -Wait -AutoRemoveJob
				Exit-GitHubActionsLogGroup
			}
	}
}
If (($FileEnvRemoveQueueResolve.Count + $FilePathRemoveQueueResolve.Count) -gt 0) {
	Write-Host -Object 'Remove file.'
	ForEach ($File In (
		$FileEnvRemoveQueueResolve + $FilePathRemoveQueueResolve |
			Select-Object -Unique
	)) {
		If (Test-Path -LiteralPath $File) {
			Get-ChildItem -LiteralPath $File -Force -ErrorAction 'Continue' |
				Remove-Item -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
		}
	}
}
If ($OsLinux -and $RemoveLinuxSwap) {
	Write-Host -Object 'Remove Linux swap space.'
	swapoff -a *>&1 |
		Write-GitHubActionsDebug
	Remove-Item -LiteralPath '/mnt/swapfile' -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
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
