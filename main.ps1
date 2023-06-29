#Requires -PSEdition Core -Version 7.2
$Script:ErrorActionPreference = 'Stop'
Get-Alias -Scope 'Local' -ErrorAction 'SilentlyContinue' |
	Remove-Alias -Scope 'Local' -Force -ErrorAction 'SilentlyContinue'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Test-GitHubActionsEnvironment -Mandatory
Write-Host -Object 'Import inputs.'
[String]$SessionID = New-Guid |
	Select-Object -ExpandProperty 'Guid'
[Boolean]$OsLinux = $Env:RUNNER_OS -ieq 'Linux'
[Boolean]$OsMac = $Env:RUNNER_OS -ieq 'MacOS'
[Boolean]$OsWindows = $Env:RUNNER_OS -ieq 'Windows'
[String]$OsPathType = "Path$($Env:RUNNER_OS)"
[RegEx]$InputListDelimiter = Get-GitHubActionsInput -Name 'input_listdelimiter' -Mandatory -EmptyStringAsNull
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
[Boolean]$OperationAsync = [Boolean]::Parse((Get-GitHubActionsInput -Name 'op_async' -EmptyStringAsNull))
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
$Script:ErrorActionPreference = 'Continue'
<# Docker Image. #>
If ($OsLinux -or $OsWindows) {
	If ($OperationAsync) {
		Write-Host -Object 'Prune/Remove Docker images.'
		$Null = Start-Job -Name "$SessionID-Docker" -ScriptBlock {
			If ($Using:RemoveDockerImageInclude.Count -gt 0) {
				[PSCustomObject[]]$DockerImageList = (
					docker image ls --all --format '{{json .}}' |
						Join-String -Separator ',' -OutputPrefix '[' -OutputSuffix ']' |
						ConvertFrom-Json -Depth 100
				) ?? @()
				ForEach ($_DI In (
					$DockerImageList |
						ForEach-Object -Process { "$($_.Repository)$(($_.Tag.Length -gt 0) ? ":$($_.Tag)" : '')" } |
						Where-Object -FilterScript { (Test-StringMatchRegEx -Item $_ -Matcher $Using:RemoveDockerImageInclude) -and !(Test-StringMatchRegEx -Item $_ -Matcher $Using:RemoveDockerImageExclude) }
				)) {
					Write-Host -Object "Remove Docker image ``$_DI``."
					docker image rm $_DI |
						Write-GitHubActionsDebug
				}
			}
			Write-Host -Object 'Prune Docker images.'
			docker image prune --force |
				Write-GitHubActionsDebug
		}
	}
	Else {
		If ($RemoveDockerImageInclude.Count -gt 0) {
			[PSCustomObject[]]$DockerImageList = (
				docker image ls --all --format '{{json .}}' |
					Join-String -Separator ',' -OutputPrefix '[' -OutputSuffix ']' |
					ConvertFrom-Json -Depth 100
			) ?? @()
			ForEach ($_DI In (
				$DockerImageList |
					ForEach-Object -Process { "$($_.Repository)$(($_.Tag.Length -gt 0) ? ":$($_.Tag)" : '')" } |
					Where-Object -FilterScript { (Test-StringMatchRegEx -Item $_ -Matcher $RemoveDockerImageInclude) -and !(Test-StringMatchRegEx -Item $_ -Matcher $RemoveDockerImageExclude) }
			)) {
				Write-Host -Object "Remove Docker image ``$_DI``."
				docker image rm $_DI |
					Write-GitHubActionsDebug
			}
		}
		Write-Host -Object 'Prune Docker images.'
		docker image prune --force |
			Write-GitHubActionsDebug
	}
}
<# Super List. #>
If ($RemoveGeneralInclude.Count -gt 0) {
	ForEach ($Item In (
		Import-Csv -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'list.tsv') -Delimiter "`t" -Encoding 'UTF8NoBOM' -ErrorAction 'Continue' |
			Where-Object -FilterScript {
				($OsLinux -and $_.APT.Length -gt 0) -or
				($OsWindows -and $_.Chocolatey.Length -gt 0) -or
				($OsMac -and $_.Homebrew.Length -gt 0) -or
				$_.NPM.Length -gt 0 -or
				(($OsLinux -or $OsMac) -and $_.Pipx.Length -gt 0) -or
				$_.Env.Length -gt 0 -or
				$_.($OsPathType).Length -gt 0
			} |
			Where-Object -FilterScript { (Test-StringMatchRegEx -Item $_.Name -Matcher $RemoveGeneralInclude) -and !(Test-StringMatchRegEx -Item $_.Name -Matcher $RemoveGeneralExclude) } |
			Sort-Object -Property 'Name' |
			Sort-Object -Property 'Priority' -Descending
	)) {
		Write-Host -Object "Remove $($Item.Description)."
		If ($OsLinux -and $Item.APT.Length -gt 0) {
			If ($OperationAsync) {
				$Null = Get-Job -Name "$SessionID-APT-*" -ErrorAction 'SilentlyContinue' |
					Wait-Job
				$Null = Start-Job -Name "$SessionID-APT-$($Item.Name)" -ScriptBlock {
					ForEach ($APT In (
						$Using:Item.APT -isplit ';;' |
							Where-Object -FilterScript { $_.Length -gt 0 }
					)) {
						apt-get --assume-yes remove $APT |
							Write-GitHubActionsDebug
					}
				}
			}
			Else {
				ForEach ($APT In (
					$Item.APT -isplit ';;' |
						Where-Object -FilterScript { $_.Length -gt 0 }
				)) {
					apt-get --assume-yes remove $APT |
						Write-GitHubActionsDebug
				}
			}
		}
		If ($OsWindows -and $Item.Chocolatey.Length -gt 0) {
			If ($OperationAsync) {
				$Null = Get-Job -Name "$SessionID-Chocolatey-*" -ErrorAction 'SilentlyContinue' |
					Wait-Job
				$Null = Start-Job -Name "$SessionID-Chocolatey-$($Item.Name)" -ScriptBlock {
					ForEach ($Chocolatey In (
						$Using:Item.Chocolatey -isplit ';;' |
							Where-Object -FilterScript { $_.Length -gt 0 }
					)) {
						choco uninstall $Chocolatey --ignore-detected-reboot --yes |
							Write-GitHubActionsDebug
					}
				}
			}
			Else {
				ForEach ($Chocolatey In (
					$Item.Chocolatey -isplit ';;' |
						Where-Object -FilterScript { $_.Length -gt 0 }
				)) {
					choco uninstall $Chocolatey --ignore-detected-reboot --yes |
						Write-GitHubActionsDebug
				}
			}
		}
		If ($OsMac -and $Item.Homebrew.Length -gt 0) {
			If ($OperationAsync) {
				$Null = Get-Job -Name "$SessionID-Homebrew-*" -ErrorAction 'SilentlyContinue' |
					Wait-Job
				$Null = Start-Job -Name "$SessionID-Homebrew-$($Item.Name)" -ScriptBlock {
					ForEach ($Homebrew In (
						$Using:Item.Homebrew -isplit ';;' |
							Where-Object -FilterScript { $_.Length -gt 0 }
					)) {
						brew uninstall $Homebrew |
							Write-GitHubActionsDebug
					}
				}
			}
			Else {
				ForEach ($Homebrew In (
					$Item.Homebrew -isplit ';;' |
						Where-Object -FilterScript { $_.Length -gt 0 }
				)) {
					brew uninstall $Homebrew |
						Write-GitHubActionsDebug
				}
			}
		}
		If ($Item.NPM.Length -gt 0) {
			If ($OperationAsync) {
				$Null = Get-Job -Name "$SessionID-NPM-*" -ErrorAction 'SilentlyContinue' |
					Wait-Job
				$Null = Start-Job -Name "$SessionID-NPM-$($Item.Name)" -ScriptBlock {
					ForEach ($NPM In (
						$Using:Item.NPM -isplit ';;' |
							Where-Object -FilterScript { $_.Length -gt 0 }
					)) {
						npm --global uninstall $NPM |
							Write-GitHubActionsDebug
					}
				}
			}
			Else {
				ForEach ($NPM In (
					$Item.NPM -isplit ';;' |
						Where-Object -FilterScript { $_.Length -gt 0 }
				)) {
					npm --global uninstall $NPM |
						Write-GitHubActionsDebug
				}
			}
		}
		If (($OsLinux -or $OsMac) -and $Item.Pipx.Length -gt 0) {
			If ($OperationAsync) {
				$Null = Get-Job -Name "$SessionID-Pipx-*" -ErrorAction 'SilentlyContinue' |
					Wait-Job
				$Null = Start-Job -Name "$SessionID-Pipx-$($Item.Name)" -ScriptBlock {
					ForEach ($Pipx In (
						$Using:Item.Pipx -isplit ';;' |
							Where-Object -FilterScript { $_.Length -gt 0 }
					)) {
						pipx uninstall $Pipx |
							Write-GitHubActionsDebug
					}
				}
			}
			Else {
				ForEach ($Pipx In (
					$Item.Pipx -isplit ';;' |
						Where-Object -FilterScript { $_.Length -gt 0 }
				)) {
					pipx uninstall $Pipx |
						Write-GitHubActionsDebug
				}
			}
		}
		If ($Item.Env.Length -gt 0) {
			If ($OperationAsync) {
				$Null = Start-Job -Name "$SessionID-Env-$($Item.Name)" -ScriptBlock {
					ForEach ($ItemEnv In (
						$Using:Item.Env -isplit ';;' |
							Where-Object -FilterScript { $_.Length -gt 0 }
					)) {
						[String]$ItemEnvValue = Get-Content -LiteralPath "Env:\$ItemEnv" -ErrorAction 'SilentlyContinue'
						If ($ItemEnvValue.Length -gt 0 -and (Test-Path -LiteralPath $ItemEnvValue)) {
							Get-ChildItem -LiteralPath $ItemEnvValue -Force -ErrorAction 'Continue' |
								ForEach-Object -Process {
									Remove-Item -LiteralPath $_.FullName -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
								}
						}
					}
				}
			}
			Else {
				ForEach ($ItemEnv In (
					$Item.Env -isplit ';;' |
						Where-Object -FilterScript { $_.Length -gt 0 }
				)) {
					[String]$ItemEnvValue = Get-Content -LiteralPath "Env:\$ItemEnv" -ErrorAction 'SilentlyContinue'
					If ($ItemEnvValue.Length -gt 0 -and (Test-Path -LiteralPath $ItemEnvValue)) {
						Get-ChildItem -LiteralPath $ItemEnvValue -Force -ErrorAction 'Continue' |
							ForEach-Object -Process {
								Remove-Item -LiteralPath $_.FullName -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
							}
					}
				}
			}
		}
		If ($Item.($OsPathType).Length -gt 0) {
			If ($OperationAsync) {
				$Null = Get-Job -Name "$SessionID-Env-$($Item.Name)" -ErrorAction 'SilentlyContinue' |
					Wait-Job
				$Null = Start-Job -Name "$SessionID-Path-$($Item.Name)" -ScriptBlock {
					ForEach ($ItemPath In (
						($Using:Item).($Using:OsPathType) -isplit ';;' |
							Where-Object -FilterScript { $_.Length -gt 0 }
					)) {
						[String]$ItemPathResolve = ($ItemPath -imatch '\$Env:') ? (Invoke-Expression -Command "`"$ItemPath`"") : $ItemPath
						If (Test-Path -Path $ItemPathResolve) {
							Get-ChildItem -Path $ItemPathResolve -Force -ErrorAction 'Continue' |
								ForEach-Object -Process {
									Remove-Item -LiteralPath $_.FullName -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
								}
						}
					}
				}
			}
			Else {
				ForEach ($ItemPath In (
					$Item.($OsPathType) -isplit ';;' |
						Where-Object -FilterScript { $_.Length -gt 0 }
				)) {
					[String]$ItemPathResolve = ($ItemPath -imatch '\$Env:') ? (Invoke-Expression -Command "`"$ItemPath`"") : $ItemPath
					If (Test-Path -Path $ItemPathResolve) {
						Get-ChildItem -Path $ItemPathResolve -Force -ErrorAction 'Continue' |
							ForEach-Object -Process {
								Remove-Item -LiteralPath $_.FullName -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
							}
					}
				}
			}
		}
	}
}
$Null = Get-Job -Name "$SessionID-*" -ErrorAction 'SilentlyContinue' |
	Wait-Job
If ($OsLinux -and $RemoveAptCache) {
	Write-Host -Object 'Remove APT cache.'
	If ($OperationAsync) {
		$Null = Start-Job -Name "$SessionID-APTCache" -ScriptBlock {
			apt-get --assume-yes autoremove |
				Write-GitHubActionsDebug
			apt-get --assume-yes clean |
				Write-GitHubActionsDebug
		}
	}
	Else {
		apt-get --assume-yes autoremove |
			Write-GitHubActionsDebug
		apt-get --assume-yes clean |
			Write-GitHubActionsDebug
	}
}
If ($OsMac -and $RemoveHomebrewCache) {
	Write-Host -Object 'Remove Homebrew cache.'
	If ($OperationAsync) {
		$Null = Start-Job -Name "$SessionID-HomebrewCache" -ScriptBlock {
			brew autoremove |
				Write-GitHubActionsDebug
		}
	}
	Else {
		brew autoremove |
			Write-GitHubActionsDebug
	}
}
If ($RemoveNpmCache) {
	Write-Host -Object 'Remove NPM cache.'
	If ($OperationAsync) {
		$Null = Start-Job -Name "$SessionID-NPMCache" -ScriptBlock {
			npm cache clean --force |
				Write-GitHubActionsDebug
		}
	}
	Else {
		npm cache clean --force |
			Write-GitHubActionsDebug
	}
}
$Null = Get-Job -Name "$SessionID-*" -ErrorAction 'SilentlyContinue' |
	Wait-Job
If ($OsLinux -and $RemoveLinuxSwap) {
	Write-Host -Object 'Remove Linux swap space.'
	If ($OperationAsync) {
		$Null = Start-Job -Name "$SessionID-Swap" -ScriptBlock {
			swapoff -a |
				Write-GitHubActionsDebug
			Remove-Item -LiteralPath '/mnt/swapfile' -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
		}
	}
	Else {
		swapoff -a |
			Write-GitHubActionsDebug
		Remove-Item -LiteralPath '/mnt/swapfile' -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
	}
}
$Null = Get-Job -Name "$SessionID-*" -ErrorAction 'SilentlyContinue' |
	Wait-Job
If ($OperationAsync) {
	Get-Job -Name "$SessionID-*" |
		Format-Table -Property @('Name', 'State') -AutoSize -Wrap |
		Out-String -Width 120 |
		Write-Host
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
