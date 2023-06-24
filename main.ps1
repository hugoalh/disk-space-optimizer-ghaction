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
Function Show-DiskSpace {
	[CmdletBinding()]
	[OutputType([Void])]
	Param ()
	If ($OsLinux -or $OsMac) {
		df -h |
			Write-Host
	}
	ElseIf ($OsWindows) {
		Get-Volume |
			Out-String -Width 120 |
			Write-Host
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
Write-Host -Object 'Before: '
Show-DiskSpace
$Script:ErrorActionPreference = 'Continue'
<# APT. #>
If ($OsLinux) {
	ForEach ($_APT In (
		Import-Csv -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'apt.tsv') -Delimiter "`t" -Encoding 'UTF8NoBOM' -ErrorAction 'Continue' |
			Where-Object -FilterScript { Test-StringMatchRegEx -Item $_.Name -Matcher $RemoveGeneral }
	)) {
		Write-Host -Object "Remove $($_APT.Description)."
		Invoke-Expression -Command "sudo apt-get --assume-yes remove '$($_APT.Package)'"
	}
	If (Test-StringMatchRegEx -Item 'AptCache' -Matcher $RemoveGeneral) {
		Write-Host -Object 'Remove APT cache.'
		sudo apt-get --assume-yes autoremove
		sudo apt-get --assume-yes clean
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
	If ($Null -ine $_Dir.Env) {
		[String]$DirEnv = Get-Content -LiteralPath "Env:\$($_Dir.Env)" -ErrorAction 'SilentlyContinue'
		If ($Null -ine $DirEnv -and (Test-Path -LiteralPath $DirEnv)) {
			Get-ChildItem -LiteralPath $DirEnv -Force -ErrorAction 'Continue' |
				ForEach-Object -Process {
					Remove-Item -LiteralPath $_.FullName -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
				}
		}
	}
	If ($OsLinux -and $Null -ine $_Dir.PathLinux -and (Test-Path -LiteralPath $_Dir.PathLinux)) {
		Get-ChildItem -LiteralPath $_Dir.PathLinux -Force -ErrorAction 'Continue' |
			ForEach-Object -Process {
				Remove-Item -LiteralPath $_.FullName -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
			}
	}
	If ($OsMac -and $Null -ine $_Dir.PathMacOS -and (Test-Path -LiteralPath $_Dir.PathMacOS)) {
		Get-ChildItem -LiteralPath $_Dir.PathMacOS -Force -ErrorAction 'Continue' |
			ForEach-Object -Process {
				Remove-Item -LiteralPath $_.FullName -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
			}
	}
	If ($OsWindows -and $Null -ine $_Dir.PathWindows -and (Test-Path -LiteralPath $_Dir.PathWindows)) {
		Get-ChildItem -LiteralPath $_Dir.PathWindows -Force -ErrorAction 'Continue' |
			ForEach-Object -Process {
				Remove-Item -LiteralPath $_.FullName -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
			}
	}
}
If ($OsLinux -and $RemoveLinuxSwap) {
	Write-Host -Object 'Remove Linux swap space.'
	sudo swapoff -a
	sudo rm -f /mnt/swapfile
}
$Script:ErrorActionPreference = 'Stop'
Write-Host -Object 'After: '
Show-DiskSpace
$LASTEXITCODE = 0
