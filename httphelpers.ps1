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
<#
function Get-eNBPoints([int]$enb) {
  $data = [System.Collections.ArrayList]::new()
  
  $filter = "(CID >> 8) in ($enb)"
  <#
  if (($filterMCCMNC -is [string]) -and ($filterMCCMNC.Contains('-'))) {
    $filterMCCParts = $filterMCCMNC.Split('-')
    $filter = "MCC = $($filterMCCParts[0]) and MNC = $($filterMCCParts[1]) and $filter"
  }# >
  
  $dbData = Get-DBResults -Query "select
  (MCC || '-' || MNC) as MCCMNC,
  -1                  as TimingAdvance,
  -1                  as Band,
  Date,
  CID,
  Latitude,
  Longitude,
  Signal,
  extraData from data
  where $filter
  group by Latitude,Longitude,Altitude,CID
  having min(rowid)" -ErrorAction Stop
  if ($dbData -isnot [array]) {
    $dbData = @($dbData)
  }
  $data.AddRange($dbData)


  foreach ($point in $data) {

    if ($point.extraData -match $bandRegex) {
      $point.Band = [int]$matches.Band
    }
  
    if ($point.extraData -match $taRegex) {
      $point.TimingAdvance = [int]$matches.TA

      if (($point.TimingAdvance % 78) -eq 0) {
        $point.TimingAdvance = $point.TimingAdvance / 78
      }
      elseif (($point.TimingAdvance % 144) -eq 0) {
        $point.TimingAdvance = $point.TimingAdvance / 144
      }
      elseif (($point.TimingAdvance % 150) -eq 0) {
        $point.TimingAdvance = $point.TimingAdvance / 150
      }
    
      $carrierTA = $timingAdvances[$point.MCCMNC]
      if (-not $carrierTA) {
        $carrierTA = $timingAdvances['']
      }
      if ($carrierTA) {
        if (-not $carrierTA[$point.Band]) {
          $point.TimingAdvance = $point.TimingAdvance * $carrierTA[0]
        }
        elseif ( $carrierTA[$point.Band] -is [scriptblock]) {
          $point.TimingAdvance = $carrierTA[$point.Band].InvokeReturnAsIs($point.TimingAdvance)
        }
        else {
          $point.TimingAdvance = $point.TimingAdvance * $carrierTA[$point.Band]
        }
      }
    }

    $point.psobject.Properties.remove('extraData')
    $point.psobject.Properties.remove('MCCMNC')
    $point.psobject.Properties.remove('eNB')
    $point.psobject.Properties.remove('date')
    $point.psobject.Properties.remove('Band')
  }

  return $data
}#>
