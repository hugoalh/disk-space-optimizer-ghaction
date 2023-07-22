#Requires -PSEdition Core -Version 7.2
[Boolean]$OsIsLinux = $Env:RUNNER_OS -ieq 'Linux'
[Boolean]$OsIsMac = $Env:RUNNER_OS -ieq 'MacOS'
[Boolean]$OsIsWindows = $Env:RUNNER_OS -ieq 'Windows'
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
[Boolean]$WMICProgramIsExist = $Null -ine (Get-Command -Name 'wmic' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
[ScriptBlock]$WMICCommandListPackage = {
	wmic product get name *>&1 |
		Write-Output
}
[ScriptBlock]$WMICCommandUninstallPackage = {
	Param ([String[]]$InputObject = @())
	ForEach ($_ In $InputObject) {
		wmic product where name="$_" call uninstall *>&1 |
			Write-Output
	}
}
Export-ModuleMember -Variable @(
	'APTCommandListPackage',
	'APTCommandUninstallPackage',
	'APTProgramIsExist',
	'ChocolateyCommandListPackage',
	'ChocolateyCommandUninstallPackage',
	'ChocolateyProgramIsExist',
	'DockerCommandListImage',
	'DockerCommandRemoveImage',
	'DockerProgramIsExist',
	'HomebrewCommandListPackage',
	'HomebrewCommandUninstallPackage',
	'HomebrewProgramIsExist',
	'NPMCommandListPackage',
	'NPMCommandUninstallPackage',
	'NPMProgramIsExist',
	'OsIsLinux',
	'OsIsMac',
	'OsIsWindows',
	'PipxCommandListPackage',
	'PipxCommandUninstallPackage',
	'PipxProgramIsExist',
	'WMICCommandListPackage',
	'WMICCommandUninstallPackage',
	'WMICProgramIsExist'
)
