#Requires -PSEdition Core -Version 7.2
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Test-GitHubActionsEnvironment -Mandatory
Write-Host -Object 'Import inputs.'
[Boolean]$OsLinux = $Env:RUNNER_OS -ieq 'Linux'
[Boolean]$OsMac = $Env:RUNNER_OS -ieq 'MacOS'
[Boolean]$OsWindows = $Env:RUNNER_OS -ieq 'Windows'
[RegEx]$InputListDelimiter = Get-GitHubActionsInput -Name 'input_listdelimiter' -Mandatory -EmptyStringAsNull
[AllowEmptyCollection()][RegEx[]]$RemoveGeneral = (
	((Get-GitHubActionsInput -Name 'general' -EmptyStringAsNull) ?? '') -isplit $InputListDelimiter |
		Where-Object -FilterScript { $_.Length -gt 0 }
) ?? @()
[AllowEmptyCollection()][RegEx[]]$RemoveDockerImage = (
	((Get-GitHubActionsInput -Name 'dockerimage' -EmptyStringAsNull) ?? '') -isplit $InputListDelimiter |
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
<# APT. #>
If ($OsLinux) {
	ForEach ($_APT In (
		Import-Csv -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'apt.tsv') -Delimiter "`t" -Encoding 'UTF8NoBOM' -ErrorAction 'Continue' |
			Where-Object -FilterScript { Test-StringMatchRegEx -Item $_.Name -Matcher $RemoveGeneral }
	)) {
		Write-Host -Object "Remove $($_APT.Description)."
		ForEach ($Package In (
			$_APT.Packages -isplit ';;' |
				Where-Object -FilterScript { $_.Length -gt 0 }
		)) {
			Invoke-Expression -Command "sudo apt-get --assume-yes remove '$($Package)'" |
				Write-Host
		}
	}
	If (Test-StringMatchRegEx -Item 'AptCache' -Matcher $RemoveGeneral) {
		Write-Host -Object 'Remove APT cache.'
		sudo apt-get --assume-yes autoremove |
			Write-Host
		sudo apt-get --assume-yes clean |
			Write-Host
	}
}
<# Docker Image. #><# TODO #>
<#
If () {
	Write-Host -Object 'Remove Docker images.'
	If ($OsLinux) {
		sudo docker image prune --all --force
	}
	Else {
		docker image prune --all --force
	}
}
#>
<# Direct. #>
ForEach ($_Dir In (
	Import-Csv -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'direct.tsv') -Delimiter "`t" -Encoding 'UTF8NoBOM' -ErrorAction 'Continue' |
		Where-Object -FilterScript { Test-StringMatchRegEx -Item $_.Name -Matcher $RemoveGeneral }
)) {
	Write-Host -Object "Remove $($_Dir.Description)."
	If ($_Dir.Envs.Length -gt 0) {
		ForEach ($DirEnv In (
			$_Dir.Envs -isplit ';;' |
				Where-Object -FilterScript { $_.Length -gt 0 }
		)) {
			[String]$DirEnvValue = Get-Content -LiteralPath "Env:\$DirEnv" -ErrorAction 'SilentlyContinue'
			If ($DirEnvValue.Length -gt 0 -and (Test-Path -LiteralPath $DirEnvValue)) {
				Get-ChildItem -LiteralPath $DirEnvValue -Force -ErrorAction 'Continue' |
					ForEach-Object -Process {
						Remove-Item -LiteralPath $_.FullName -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
					}
			}
		}
	}
	ForEach ($OsType In @(
		@{ Is = $OsLinux; Name = 'Linux' },
		@{ Is = $OsMac; Name = 'MacOS' },
		@{ Is = $OsWindows; Name = 'Windows' }
	)) {
		If (!$OsType.Is) {
			Continue
		}
		If ($_Dir.("Paths$($OsType.Name)").Length -gt 0) {
			ForEach ($DirPath In (
				$_Dir.("Paths$($OsType.Name)") -isplit ';;' |
					Where-Object -FilterScript { $_.Length -gt 0 }
			)) {
				If (Test-Path -LiteralPath $DirPath) {
					Get-ChildItem -LiteralPath $DirPath -Force -ErrorAction 'Continue' |
						ForEach-Object -Process {
							Remove-Item -LiteralPath $_.FullName -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
						}
				}
			}
		}
	}
}
If ($OsLinux -and $RemoveLinuxSwap) {
	Write-Host -Object 'Remove Linux swap space.'
	sudo swapoff -a
	sudo rm -f /mnt/swapfile
}
$Script:ErrorActionPreference = 'Stop'
[String]$DiskSpaceAfter = Get-DiskSpace
Write-Host -Object @"
===== BEFORE =====
$DiskSpaceBefore

===== AFTER =====
$DiskSpaceAfter
"@
$LASTEXITCODE = 0
