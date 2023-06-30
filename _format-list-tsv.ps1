Get-Content -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'list.json') -Raw -Encoding 'UTF8NoBOM' |
	ConvertFrom-Json -Depth 100 |
	Select-Object -ExpandProperty 'content' |
	ForEach-Object -Process {
		[PSCustomObject]$Result = $_
		ForEach ($Property In $_.PSObject.Properties) {
			If ($Property.Value.GetType().BaseType.Name -ieq 'Array') {
				$Result.($Property.Name) = $Property.Value |
					Join-String -Separator ';;'
			}
		}
		$Result |
			Write-Output
	} |
	Sort-Object -Property 'Name' |
	Export-Csv -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'list.tsv') -Encoding 'UTF8NoBOM' -Delimiter "`t" -UseQuotes 'AsNeeded'
