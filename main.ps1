#Requires -PSEdition Core -Version 7.2
Get-Alias -Scope 'Local' |
	Remove-Alias -Scope 'Local'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Test-GitHubActionsEnvironment -Mandatory
Write-Host -Object 'Import inputs.'
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
[Boolean]$RemoveLinuxSwap = [Boolean]::Parse((Get-GitHubActionsInput -Name 'swap' -Mandatory -EmptyStringAsNull))
Function Get-DiskSpace {
	[CmdletBinding()]
	[OutputType([String])]
	Param ()
	If ($OsLinux -or $OsMac) {
		df -h |
			Join-String -Separator "`n" |
			Write-Output
	}
	ElseIf ($OsWindows) {
		Get-Volume |
			Out-String -Width 120 |
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
Try {
	$CommandDocker = Get-Command -Name 'docker' -CommandType 'Application' -ErrorAction 'Stop'
}
Catch {}
If ($Null -ine $CommandDocker) {
	If ($RemoveDockerImageInclude.Count -gt 0) {
		[PSCustomObject[]]$DockerImageList = (
			docker image ls --all --format '{{json .Repository .Tag}}' |
				Join-String -Separator ',' -OutputPrefix '[' -OutputSuffix ']' |
				ConvertFrom-Json -Depth 100
		) ?? @()
		ForEach ($Item In (
			$DockerImageList |
				ForEach-Object -Process { "$($_.Repository)$(($_.Tag.Length -gt 0) ? ":$($_.Tag)" : '')" } |
				Where-Object -FilterScript { (Test-StringMatchRegEx -Item $_ -Matcher $RemoveDockerImageInclude) -and !(Test-StringMatchRegEx -Item $_ -Matcher $RemoveDockerImageExclude) }
		)) {
			Enter-GitHubActionsLogGroup -Title "Remove Docker image ``$Item``."
			docker image rm $Item
			Exit-GitHubActionsLogGroup
		}
	}
	Enter-GitHubActionsLogGroup -Title 'Prune Docker images.'
	docker image prune --force
	Exit-GitHubActionsLogGroup
}
<# Super List. #>
If ($RemoveGeneralInclude.Count -gt 0) {
	ForEach ($Item In (
		Import-Csv -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'list.tsv') -Delimiter "`t" -Encoding 'UTF8NoBOM' -ErrorAction 'Continue' |
			Where-Object -FilterScript {
				($OsLinux -and $_.APT.Length -gt 0) -or
				$_.NPM.Length -gt 0 -or
				$_.Env.Length -gt 0 -or
				$_.($OsPathType).Length -gt 0
			} |
			Where-Object -FilterScript { (Test-StringMatchRegEx -Item $_.Name -Matcher $RemoveGeneralInclude) -and !(Test-StringMatchRegEx -Item $_.Name -Matcher $RemoveGeneralExclude) }
	)) {
		Enter-GitHubActionsLogGroup -Title "Remove $($Item.Description)."
		If ($OsLinux -and $Item.APT.Length -gt 0) {
			ForEach ($APT In (
				$Item.APT -isplit ';;' |
					Where-Object -FilterScript { $_.Length -gt 0 }
			)) {
				Invoke-Expression -Command "sudo apt-get --assume-yes remove '$APT'"
			}
		}
		If ($Item.NPM.Length -gt 0) {
			ForEach ($NPM In (
				$Item.NPM -isplit ';;' |
					Where-Object -FilterScript { $_.Length -gt 0 }
			)) {
				If ($OsLinux) {
					Invoke-Expression -Command "sudo npm --global uninstall '$NPM'"
				}
				Else {
					Invoke-Expression -Command "npm --global uninstall '$NPM'"
				}
			}
		}
		If ($Item.Env.Length -gt 0) {
			ForEach ($ItemEnv In (
				$Item.Env -isplit ';;' |
					Where-Object -FilterScript { $_.Length -gt 0 }
			)) {
				[String]$ItemEnvValue = Get-Content -LiteralPath "Env:\$ItemEnv" -ErrorAction 'SilentlyContinue'
				If ($ItemEnvValue.Length -gt 0 -and (Test-Path -LiteralPath $ItemEnvValue)) {
					Get-ChildItem -LiteralPath $ItemEnvValue -Force -ErrorAction 'Continue' |
						ForEach-Object -Process {
							If ($OsLinux) {
								sudo rm --force --recursive $_.FullName
							}
							Else {
								Remove-Item -LiteralPath $_.FullName -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
							}
						}
				}
			}
		}
		If ($Item.($OsPathType).Length -gt 0) {
			ForEach ($ItemPath In (
				$Item.($OsPathType) -isplit ';;' |
					Where-Object -FilterScript { $_.Length -gt 0 }
			)) {
				[String]$ItemPathResolve = ($ItemPath -imatch '\$Env:') ? (Invoke-Expression -Command "`"$ItemPath`"") : $ItemPath
				If (Test-Path -Path $ItemPathResolve) {
					Get-ChildItem -Path $ItemPathResolve -Force -ErrorAction 'Continue' |
						ForEach-Object -Process {
							If ($OsLinux) {
								sudo rm --force --recursive $_.FullName
							}
							Else {
								Remove-Item -LiteralPath $_.FullName -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
							}
						}
				}
			}
		}
		Exit-GitHubActionsLogGroup
	}
}
If ($OsLinux -and $RemoveAptCache) {
	Enter-GitHubActionsLogGroup -Title 'Remove APT cache.'
	sudo apt-get --assume-yes autoremove
	sudo apt-get --assume-yes clean
	Exit-GitHubActionsLogGroup
}
If ($OsLinux -and $RemoveLinuxSwap) {
	Enter-GitHubActionsLogGroup -Title 'Remove Linux swap space.'
	sudo swapoff -a
	sudo rm -f /mnt/swapfile
	Exit-GitHubActionsLogGroup
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
