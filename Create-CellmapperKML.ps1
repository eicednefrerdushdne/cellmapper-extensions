[CmdletBinding()]
param (
  [string]$eNB = '',
  $filename = '.kml',
  [int]$mcc = 310,
  [int]$mnc = 260,
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
$enbString = $enb
if ($enb -match '^(?<enb>\d+)(-(?<cid>\d+))?$') {
  # DAS cell logic
  $enb = [int]$matches.enb
  if ($matches.cid) {
    $cellID = [int]$matches.cid
  }
}
else {
  throw "`$enb parameter must match \d+ or \d+-\d+. ``$enb`` does not match."
}



$data = @((Get-eNBPoints -Path $customDBPath -mcc $mcc -mnc $mnc -eNB $enb))
if ($mcc -eq 310 -and $mnc -eq 120) {
  $data += @((Get-eNBPoints -Path $customDBPath -mcc 312 -mnc 250 -eNB $enb))
}

if($cellID -is [int]){
  $data = @(($data | where-object {($_.CellID -band 255) -eq $cellID}))
}


if ($maxCircleDistance -ne -1) {
  $data = @(($data | Where-Object TAMeters -LE $maxCircleDistance))
}

Write-Host "Using $($data.Count) points"

try {
  $results = @($kmlHeader.Replace('My Places.kml', "$enbString"))
  $results += Get-LineStyles
  $tower = [pscustomobject]@{
    MCC       = $mcc
    MNC       = $mnc
    eNB       = $enbString
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