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
[Boolean]$ChocolateyProgram = $Null -ine (Get-Command -Name 'choco' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
[Boolean]$DockerProgram = $Null -ine (Get-Command -Name 'docker' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
[Boolean]$HomebrewProgram = $Null -ine (Get-Command -Name 'brew' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
[Boolean]$NPMProgram = $Null -ine (Get-Command -Name 'npm' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
[Boolean]$PipxProgram = $Null -ine (Get-Command -Name 'pipx' -CommandType 'Application' -ErrorAction 'SilentlyContinue')
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
[String[]]$DockerImageList = @()
[String[]]$DockerImageRemoveQueue = @()
[PSCustomObject[]]$GeneralRemoveQueue = @()
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
		$DockerImageList += docker image ls --all --format '{{json .}}' |
			Join-String -Separator ',' -OutputPrefix '[' -OutputSuffix ']' |
			ConvertFrom-Json -Depth 100 |
			ForEach-Object -Process { "$($_.Repository)$(($_.Tag.Length -gt 0) ? ":$($_.Tag)" : '')" }
	}
}
If ($RemoveGeneralInclude.Count -gt 0) {
	$GeneralRemoveQueue += Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'list.json') -Raw -Encoding 'UTF8NoBOM' -ErrorAction 'Continue' |
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
		Sort-Object -Property 'Name'
}
If ($DockerProgram -and $RemoveDockerImageInclude.Count -gt 0 -and $OperationAsync) {
	$DockerImageList += Receive-Job -Name "$JobIdPrefix/Docker/List" -Wait -AutoRemoveJob -ErrorAction 'Continue'
}
$DockerImageRemoveQueue += $DockerImageList |
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
If ($DockerProgram) {
	If ($OperationAsync) {
		Write-Host -Object '[ASYNC] Remove Docker image and cache.'
		$Null = Start-Job -Name "$JobIdPrefix/Docker/Optimize" -ScriptBlock {
			ForEach ($_DI In $Using:DockerImageRemoveQueue) {
				docker image rm $_DI *>&1
			}
			If ($Using:RemoveDockerCache) {
				docker image prune --force *>&1
			}
		}
	}
	Else {
		If ($DockerImageRemoveQueue.Count -gt 0) {
			ForEach ($_DI In $DockerImageRemoveQueue) {
				Write-Host -Object "Remove Docker image ``$_DI``."
				docker image rm $_DI *>&1 |
					Write-GitHubActionsDebug
			}
		}
		If ($RemoveDockerCache) {
			Write-Host -Object 'Remove Docker cache.'
			docker image prune --force *>&1 |
				Write-GitHubActionsDebug
		}
	}
}
Function Invoke-OptimizeOperation {
	[CmdletBinding()]
	[OutputType([Void])]
	Param (
		[Parameter(Mandatory = $True, Position = 0)][PSCustomObject[]]$Queue
	)
	ForEach ($Item In $Queue) {
		Write-Host -Object "Remove $($Item.Name)."
		If ($APTProgram) {
			ForEach ($APT In $Item.APT) {
				apt-get --assume-yes remove $APT *>&1 |
					Write-GitHubActionsDebug
			}
		}
		If ($ChocolateyProgram) {
			ForEach ($Chocolatey In $Item.Chocolatey) {
				choco uninstall $Chocolatey --ignore-detected-reboot --yes *>&1 |
					Write-GitHubActionsDebug
			}
		}
		If ($HomebrewProgram) {
			ForEach ($Homebrew In $Item.Homebrew) {
				brew uninstall $Homebrew *>&1 |
					Write-GitHubActionsDebug
			}
		}
		If ($NPMProgram) {
			ForEach ($NPM In $Item.NPM) {
				npm --global uninstall $NPM *>&1 |
					Write-GitHubActionsDebug
			}
		}
		If ($PipxProgram) {
			ForEach ($Pipx In $Item.Pipx) {
				pipx uninstall $Pipx *>&1 |
					Write-GitHubActionsDebug
			}
		}
		ForEach ($EnvName In $Item.Env) {
			[String]$EnvValue = Get-Content -LiteralPath "Env:\$EnvName" -ErrorAction 'SilentlyContinue'
			If ($EnvValue.Length -gt 0 -and (Test-Path -LiteralPath $EnvValue)) {
				Get-ChildItem -LiteralPath $EnvValue -Force -ErrorAction 'Continue' |
					Remove-Item -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
			}
		}
		ForEach ($Path In $Item.($OsPathType)) {
			[String]$PathResolve = ($Path -imatch '\$Env:') ? (Invoke-Expression -Command "`"$Path`"") : $Path
			If ($PathResolve.Length -gt 0 -and (Test-Path -LiteralPath $PathResolve)) {
				Get-ChildItem -LiteralPath $PathResolve -Force -ErrorAction 'Continue' |
					Remove-Item -Recurse -Force -Confirm:$False -ErrorAction 'Continue'
			}
		}
	}
}
Invoke-OptimizeOperation -Queue (
	$GeneralRemoveQueue |
		Where-Object -FilterScript { $_.Postpone -ieq $False }
)
Invoke-OptimizeOperation -Queue (
	$GeneralRemoveQueue |
		Where-Object -FilterScript { $_.Postpone -ine $False -and $_.Postpone -ine $True }
)
Invoke-OptimizeOperation -Queue (
	$GeneralRemoveQueue |
		Where-Object -FilterScript { $_.Postpone -ieq $True }
)
If ($APTProgram -and $RemoveAptCache) {
	Write-Host -Object 'Remove APT cache.'
	apt-get --assume-yes autoremove *>&1 |
		Write-GitHubActionsDebug
	apt-get --assume-yes clean *>&1 |
		Write-GitHubActionsDebug
}
If ($HomebrewProgram -and $RemoveHomebrewCache) {
	Write-Host -Object 'Remove Homebrew cache.'
	brew autoremove *>&1 |
		Write-GitHubActionsDebug
}
If ($NPMProgram -and $RemoveNpmCache) {
	Write-Host -Object 'Remove NPM cache.'
	npm cache clean --force *>&1 |
		Write-GitHubActionsDebug
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
