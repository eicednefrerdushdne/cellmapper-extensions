[CmdletBinding()]
param (
  [string]$towerID = '',
  $filename = '.kml',
  [int]$mcc = 310,
  [int]$mnc = 260,
  [decimal]$latitude,
  [decimal]$longitude,
  [string]$rat,
  [bool]$verified,
  [switch]$noCircles,
  [switch]$noLines = $true,
  [switch]$noPoints,
  [switch]$noTowers,
  [switch]$noToMove,
  [int]$minPoints = -1,
  [int]$maxCircleDistance = -1,
  [switch]$colorPointsBySector = $true
)

#.\Get-CellmapperDB.ps1
. .\helpers.ps1
. .\CustomDB.ps1

$customDBPath = "$PSScriptRoot\Cellmapper.dbe"

ImportInstall-Module PSSqlite
Add-Type -AssemblyName 'system.drawing'


Write-Host "Reading DB"
$towerIDString = $towerID
if ($towerIDString -match '^(?<towerID>\d+)(-(?<cid>\d+))?$') {
  # DAS cell logic
  $towerID = [int]$matches.towerID
  if ($matches.cid) {
    $cellID = [int]$matches.cid
  }
}
else {
  throw "`$towerID parameter must match \d+ or \d+-\d+. ``$towerID`` does not match."
}


if ($rat -eq 'LTE') {

  $data = @((Get-eNBPoints -Path $customDBPath -mcc $mcc -mnc $mnc -eNB $towerID))
  if ($mcc -eq 310 -and $mnc -eq 120) {
    $data += @((Get-eNBPoints -Path $customDBPath -mcc 312 -mnc 250 -eNB $towerID))
  }
}
elseif ($rat -eq 'NR') {
  $data = @((Get-gNBPoints -Path $customDBPath -mcc $mcc -mnc $mnc -gnb $towerID))
}

if ($cellID -is [int]) {
  $data = @(($data | where-object { ($_.CellID -band 255) -eq $cellID }))
}


if ($maxCircleDistance -ne -1) {
  $data = @(($data | Where-Object TAMeters -LE $maxCircleDistance))
}

Write-Host "Using $($data.Count) points"

try {
  $results = @($kmlHeader.Replace('My Places.kml', "$towerIDString - $($data.count)"))
  $results += Get-LineStyles
  $tower = [pscustomobject]@{
    MCC       = $mcc
    MNC       = $mnc
    eNB       = $towerIDString
    Latitude  = $latitude
    Longitude = $longitude
    Verified  = $verified
  }
  $towerIDFolder = Get-eNBFolder -tower $tower -points $data -noCircles:$noCircles -noLines:$noLines -noPoints:$noPoints -noTowers:$noTowers -noToMove:$noToMove -colorPointsBySector:$colorPointsBySector
  $results += $towerIDFolder.XML
  
  $results += $kmlFooter

  $results = [string]::Join("`r`n", $results)
  $results | Out-File $filename
  Write-Host "Created $filename"
  
}
finally {
}