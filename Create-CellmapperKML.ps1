[CmdletBinding()]
param (
  [int]$eNB = 894009,
  $filename = '894009.kml',
  [int]$mcc,
  [int]$mnc,
  [decimal]$latitude,
  [decimal]$longitude,
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

$data = @((Get-eNBPoints -Path $customDBPath -mcc $mcc -mnc $mnc -eNB $enb))


if ($maxCircleDistance -ne -1) {
  $data = @(($data | Where-Object TAMeters -LE $maxCircleDistance))
}

Write-Host "Using $($data.Count) points"

try {
  $results = @($kmlHeader.Replace('My Places.kml', "$enb"))
  $results += Get-LineStyles
  $tower = [pscustomobject]@{
    MCC       = $mcc
    MNC       = $mnc
    eNB       = $enb
    Latitude  = $latitude
    Longitude = $longitude
    Verified  = $verified
  }
  $enbFolder = Get-eNBFolder -tower $tower -points $data -noCircles:$noCircles -noLines:$noLines -noPoints:$noPoints -noTowers:$noTowers -noToMove:$noToMove -colorPointsBySector:$colorPointsBySector
  $results += $enbFolder.XML
  
  $results += $kmlFooter

  $results = [string]::Join("`r`n", $results)
  $results | Out-File $filename
  Write-Host "Created $filename"
  
}
finally {
}