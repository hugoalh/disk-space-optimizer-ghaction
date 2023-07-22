#Requires -PSEdition Core -Version 7.2
$Script:ErrorActionPreference = 'Continue'
Get-Alias -Scope 'Local' -ErrorAction 'SilentlyContinue' |
	Remove-Alias -Scope 'Local' -Force -ErrorAction 'SilentlyContinue'
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'common.psm1') -Scope 'Local'
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
	If ($WMICProgramIsExist) {
		Enter-GitHubActionsLogGroup -Title "WMIC ($Stage): "
		Invoke-Command -ScriptBlock $WMICCommandListPackage |
			Write-Host
		Exit-GitHubActionsLogGroup
	}
}
