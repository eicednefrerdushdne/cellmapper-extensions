function ImportInstall-Module ($moduleName) {
  if (-not (Get-Module $moduleName)) {
    if (-not (Get-Module -ListAvailable $moduleName)) {
      Install-Module $moduleName -Scope CurrentUser -Force
    }
    Import-Module $moduleName
  }
}

ImportInstall-Module PSSqlite
Add-Type -AssemblyName 'system.drawing'

$timingAdvances = @{
  "310-260" = @{
    0  = 150
    41 = { param($ta) ($ta - 20) * 150 }
  }
  "310-120" = @{
    0  = 150
    41 = { param($ta) ($ta - 20) * 150 }
  }
  ""        = @{
    0 = 150
  }
}

$taRegex = [regex]'&LTE_TA=(?<TA>[0-9]+)&'
$bandRegex = [regex]'&INFO_BAND_NUMBER=(?<Band>[0-9]+)&'
$arfcnRegex = [regex]'&ARFCN=(?<ARFCN>[0-9]+)&'

function Get-DBResults([string]$Query) {
  $dbNames = Get-ChildItem -Path $PSScriptRoot -Filter '*.db' | foreach-object { $_.FullName }
  $results = @()
  foreach ($db in $dbNames) {
    try {
      $enbs = Invoke-SqliteQuery -Database $db -Query $Query -ErrorAction Stop
      
      $results += $enbs
    }
    catch [System.Management.Automation.MethodInvocationException] {
      Write-Host "Error processing $db`r`n" + $_.Exception.ToString()
    }
  }
  return $results
}
