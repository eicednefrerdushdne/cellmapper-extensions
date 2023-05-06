function ImportInstall-Module ($moduleName) {
  if (-not (Get-Module $moduleName)) {
    if (-not (Get-Module -ListAvailable $moduleName)) {
      Install-Module $moduleName -Scope CurrentUser -Force
    }
    Import-Module $moduleName
  }
}

function rad2deg ($angle) {
  return $angle * (180 / [Math]::PI);
}
function deg2rad ($angle) {
  return $angle * ([Math]::PI / 180);
}

function Get-CircleCoordinates($lat, $long, $meter) {
  # convert coordinates to radians
  $lat1 = $lat * ([Math]::PI / 180);
  $long1 = $long * ([Math]::PI / 180);
  $d_rad = $meter / 6378137;
 
  $coordinatesList = @();
  # loop through the array and write path linestrings
  for ($i = 0; $i -le 360; $i += 9) {
    $radial = $i * ([Math]::PI / 180);
    $lat_rad = [math]::asin([math]::sin($lat1) * [math]::cos($d_rad) + [math]::cos($lat1) * [math]::sin($d_rad) * [math]::cos($radial));
    $dlon_rad = [math]::atan2([math]::sin($radial) * [math]::sin($d_rad) * [math]::cos($lat1), [math]::cos($d_rad) - [math]::sin($lat1) * [math]::sin($lat_rad));
    $lon_rad = (($long1 + $dlon_rad + [math]::PI) % (2 * [math]::PI)) - [math]::PI;
    $coordinatesList += "$($lon_rad * (180 / [Math]::PI)),$($lat_rad * (180 / [Math]::PI)),0"
  }
  return [string]::join(' ', $coordinatesList)
}

$lastDigitRegex = [regex]'\d(?= - )'

function Get-eNBFolder($points, $tower, [int]$mcc, [int]$mnc, [switch]$noCircles, [switch]$noLines, [switch]$noPoints, [switch]$noTowers, [switch]$noToMove, [switch]$colorPointsBySector = $false) {
  $towerStatus = $null
  if ($tower.Verified) {
    $towerStatus = 'Verified'
    $desc = "$($tower.eNB) - Verified"
  }
  else {
    $towerStatus = 'Calculated'
    $desc = "$($tower.eNB) - Calculated"
  }

  $taCount = @(($points | Where-Object { $_.TAMeters -ne -1 })).Count
  
  $parts = @(
    "
		<Folder>
			<name>$desc ($taCount)</name>
			<open>0</open>
    "
  )
  if (-not $noTowers) {
    $parts += "
  <Placemark>
    <name>$($tower.eNB) - $towerStatus</name>
    <visibility>1</visibility>
    <styleUrl>#m_ylw-pushpin</styleUrl>
    <description>
https://www.cellmapper.net/map?MCC=$($tower.MCC)&amp;MNC=$($tower.MNC)&amp;type=LTE&amp;latitude=$($tower.latitude)&amp;longitude=$($tower.longitude)&amp;zoom=15&amp;clusterEnabled=false&amp;showOrphans=true</description>
    <Point>
      <gx:drawOrder>1</gx:drawOrder>
      <coordinates>$($tower.longitude),$($tower.latitude),0</coordinates>
    </Point>
  </Placemark>"
    if (-not $noToMove) {
      $parts += "
  <Placemark>
    <name>Move This - $($group.Name)</name>
    <visibility>1</visibility>
    <styleUrl>#m_ylw-pushpin</styleUrl>
    <Point>
      <gx:drawOrder>1</gx:drawOrder>
      <coordinates>$($tower.longitude),$($tower.latitude + 0.0005),0</coordinates>
    </Point>
  </Placemark>"
    }
  }

  $circles = @()
  $lineFolders = @{}
  $pointFolders = @{}
  $circleFolders = @{}
  $signals = $points | ForEach-Object { $_.Signal } | Sort-Object -Descending
  if ($signals) {
    $ratios = @(
    (($signals[0] * 3 + $signals[$signals.count - 1]) / 4),
    (($signals[0] + $signals[$signals.count - 1]) / 2),
    (($signals[0] + $signals[$signals.count - 1] * 3) / 4))
  }
  else {
    $ratios = @(-85, -95, -105)
  }
  
  if (-not $noCircles) {
    $taPoints = [System.Collections.ArrayList](@($points | Where-Object { $_.TAMeters -ne -1 }))

    foreach ($point in $taPoints) {
      $folderName = Get-PointFolderName $point
      if (-not $circleFolders[$folderName]) {
        $circleFolders[$folderName] = @()
      }
      $circleFolders[$folderName] += Get-CirclePlacemark $point
    }
  }
  
  foreach ($point in $points) {
    $folderName = Get-PointFolderName $point

    if (-not $noPoints) {
      if (-not $pointFolders[$folderName]) {
        $pointFolders[$folderName] = @()
      }
      # Create points
      $pointFolders[$folderName] += Get-PointPlacemark -point $point -signalRatios $ratios -colorPointsBySector:$colorPointsBySector
    }

    if (-not $noLines -and $tower) {
      # Create lines
      if (-not $lineFolders[$folderName]) {
        $lineFolders[$folderName] = @()
      }
      $lineFolders[$folderName] += Get-Line -point $point -targetPoint $tower
    }
  }

  
  if (-not $noPoints) {
    #### Points
    $parts += "
  <Folder>
    <name>Points</name>
    <open>0</open>  
  "
    $sortedPointFolders = $pointFolders.Keys | Sort-object { $_[$_.IndexOf(' ') - 1] }, { $_ }
    foreach ($pf in $sortedPointFolders) {
      $parts += "
    <Folder>
      <name>$pf</name>
      <open>0</open>  
    "
      $parts += $pointFolders[$pf]
      $parts += "</Folder>"
    }
    $parts += "</Folder>"
  }
  
  #### Circles
  if (-not $noCircles) {
    if ($circleFolders.Count) {
      $sortedCircleFolders = $circleFolders.Keys | Sort-object { $_[$_.IndexOf(' ') - 1] }, { $_ }
      
      $parts += "
  <Folder>
    <name>Circles</name>
    <open>0</open>  
  "

      foreach ($cf in $sortedCircleFolders) {
        $parts += "
      <Folder>
        <name>$cf</name>
        <open>0</open>  
      "
        $parts += $circleFolders[$cf]
        $parts += "</Folder>"
      }


      $parts += "</Folder>"
      #### End Circles
    }
  }
  if (-not $noLines) {
    #### Lines to Tower
    if ($tower) {
      $parts += "
  <Folder>
    <name>Lines</name>
    <open>0</open>  
  "
      $sortedLineFolders = $lineFolders.Keys | Sort-object { $_[$_.IndexOf(' ') - 1] }, { $_ }

      foreach ($pf in $sortedLineFolders) {
        $parts += "
    <Folder>
      <name>$pf</name>
      <open>0</open>  
    "
        $parts += $lineFolders[$pf]
        $parts += "</Folder>"
      }
      $parts += "</Folder>"
    }
  }

  
  $parts += "</Folder>"
  
  [pscustomobject]@{
    XML    = [string]::Join("`r`n", $parts)
    Status = $towerStatus
  }
}



function Get-PointPlacemark($point, $signalRatios = @(-84, -102, -111), [switch]$colorPointsBySector = $false) {
  $mccmnc = $point.MCC.ToString() + "-" + $point.MNC.ToString()
  if ($colorPointsBySector -and $sectorIDs[$mccmnc]) {
    $sectorConfig = $sectorIDs[$mccmnc] | where-object { $_.SectorIDs.Contains([int]($point.CID % 256)) }
    if ($sectorConfig) {
      $style = $sectorConfig.PointStyle
    }
  }

  if (-not $colorPointsBySector -or ($null -eq $sectorConfig)) {
    $style = "#m_grn-dot"
    
    if ($point.signal -le $signalRatios[2]) {
      $style = "#m_red-dot"
    }
    elseif ($point.signal -lt $signalRatios[1]) {
      $style = "#m_org-dot"
    }
    elseif ($point.signal -lt $signalRatios[0]) {
      $style = "#m_ylw-dot"
    }
  }
  $shift = Get-SystemRightShift -mcc $point.mcc -mnc $point.mnc -rat $point.system
  "
<Placemark>
  <name>$($point.Signal)</name>
  <visibility>1</visibility>
  <description>$($point.CellID -shr $shift.RightShift)-$($point.CellID -band $shift.CIDMask) ($($point.Signal))  $($point.TAMeters)m</description>
  <styleUrl>$style</styleUrl>
  <Point>
    <gx:drawOrder>1</gx:drawOrder>
    <coordinates>$($point.longitude),$($point.latitude),0</coordinates>
  </Point>
</Placemark>"
}

$lteMask = [pscustomobject]@{
  RightShift = 8
  CIDMask    = [int64]::maxvalue -shr (64 - 8)
}

$tmoNRMask = [pscustomobject]@{
  RightShift = 12
  CIDMask    = [int64]::maxvalue -shr (64 - 12)
}

function Get-SystemRightShift($mcc, $mnc, $rat) {
  if ($rat -eq 'LTE') {
    return $lteMask
  }
  elseif ($rat -eq 'NR') {
    if ($mcc -eq 310 -and $mnc -eq 260) {
      return $tmoNRMask
    }
  }
}

function Get-PointFolderName($point) {
  $shift = Get-SystemRightShift -mcc $point.mcc -mnc $point.mnc -rat $point.system

  $sectorNumber = $point.CellID -band $shift.CIDMask # Keep last byte
  
  "$sectorNumber - Band $($point.Band)"
}

function Get-CirclePlacemark($point) {
  $ta = $point.TAMeters
  if ($ta -eq 0) {
    $ta = 40
  }
  $shift = Get-SystemRightShift -mcc $point.mcc -mnc $point.mnc -rat $point.system
  "
  <Placemark>
    <name>$($point.CellID -shr $shift.RightShift)-$($point.CellID -band $shift.CIDMask) ($($point.Signal))  $($point.TAMeters)m</name>
    <visibility>1</visibility>
    <styleUrl>#inline0</styleUrl>
    <LineString>
      <tessellate>1</tessellate>
      <coordinates>
        $((Get-CircleCoordinates -lat $point.Latitude -long $point.Longitude -meter $ta))
      </coordinates>
    </LineString>
  </Placemark>"
}

$sectorIDs = @{
  '310-260' = @(
    @{
      SectorIDs   = @(1, 11, 21, 31, 41, 61, 101, 111, 131, 141)
      Description = "North"
      PointStyle  = "#m_grn-dot"
    }
    @{
      SectorIDs   = @(2, 12, 22, 32, 42, 62, 102, 112, 132, 142)
      Description = "SouthEast or East"
      PointStyle  = "#m_ylw-dot"
    }
    @{
      SectorIDs   = @(3, 13, 23, 33, 43, 63, 103, 113, 133, 143)
      Description = "SouthWest or South"
      PointStyle  = "#m_red-dot"
    }
    @{
      SectorIDs   = @(4, 14, 24, 34, 44, 64, 104, 114, 134, 144)
      Description = "West"
      PointStyle  = "#m_org-dot"
    }
    @{
      SectorIDs   = @(5)
      Description = "Blue"
      PointStyle  = "#m_blue-dot"
    }
    @{
      SectorIDs   = @(6)
      Description = "Pink"
      PointStyle  = "#m_pink-dot"
    }
    @{
      SectorIDs   = @(7)
      Description = "Light Blue"
      PointStyle  = "#m_lightblue-dot"
    }
  )
  '311-480' = @(
    @{
      SectorIDs   = @(1, 11, 12, 13, 14, 15, 16, 17, 18, 19)
      Description = "North"
      PointStyle  = "#m_grn-dot"
    }
    @{
      SectorIDs   = @(2, 21, 22, 23, 24, 25, 26, 27, 28, 29)
      Description = "SouthEast or East"
      PointStyle  = "#m_ylw-dot"
    }
    @{
      SectorIDs   = @(3, 31, 32, 33, 34, 35, 36, 37, 38, 39)
      Description = "SouthWest or South"
      PointStyle  = "#m_red-dot"
    }
  )
  '310-410' = @(
    @{
      SectorIDs   = @(1, 8, 15, 22, 43, 149, 208, 222, 215)
      Description = 'Northeast'
      PointStyle  = "#m_grn-dot"
    }
    @{
      SectorIDs   = @(2, 9, 16, 23, 44, 150, 209, 223, 216)
      Description = 'South'
      PointStyle  = "#m_ylw-dot"
    }
    @{
      SectorIDs   = @(3, 10, 17, 24, 45, 151, 210, 224, 217)
      Description = 'Northwest'
      PointStyle  = "#m_red-dot"
    }
  )
}

function Get-LineStyles() {
  $list = [System.Collections.ArrayList]::new()
  
  for ($i = 0; $i -lt $sectorIDs.Count; $i++) {
    $id = $sectorIDs[$i]
    $color = ConvertFrom-Hsl -Hue ($i / $sectorIDs.Count * 360) -Lightness 50 -Saturation 100
    $n = $list.Add("
    <Style id=""sector$id"">
      <LineStyle>
        <color>ff$($color.B.ToString('X2'))$($color.G.ToString('X2'))$($color.R.ToString('X2'))</color>
        <width>1.5</width>
      </LineStyle>
    </Style>")
  }

  $n = $list.Add("
  <Style id=""sectorOther"">
    <LineStyle>
      <color>ff000000</color>
      <width>1.5</width>
    </LineStyle>
  </Style>")

  return $list.ToArray()
}

function Get-Line($point, $targetPoint) {
  $sectorNumber = $point.CID -band 0xFF
  $styleName = $sectorIDs.IndexOf([int]$sectorNumber)
  if ($styleName -eq -1) {
    $styleName = "sectorOther"
  }
  else {
    $styleName = "sector$sectorNumber"
  }
  "
  <Placemark>
    <name>$($point.Date.ToString('yyyy-MM-dd HH.mm.ss'))</name>
    <visibility>1</visibility>
    <styleUrl>#$styleName</styleUrl>
    <LineString>
      <tessellate>1</tessellate>
      <coordinates>
        $($point.Longitude),$($point.Latitude),0 $($targetPoint.Longitude),$($targetPoint.Latitude),0 
      </coordinates>
    </LineString>
  </Placemark>"
}

# https://gist.github.com/ConnorGriffin/ac21c25ecd7ef5e918cbd28e5cb6ed0d
function ConvertFrom-Hsl {
  param(
    $Hue,
    $Saturation,
    $Lightness
  )
  $Hue = [double]($Hue / 360)
  if ($Saturation -gt 1) {
    $Saturation = [double]($Saturation / 100)
  }
  if ($Lightness -gt 1) {
    $Lightness = [double]($Lightness / 100)
  }
  
  if ($Saturation -eq 0) {
    # No color
    $red = $green = $blue = $Lightness
  }
  else {
    function HueToRgb ($p, $q, $t) {
      if ($t -lt 0) {
        $t++
      }
      if ($t -gt 1) {
        $t--
      } 
      if ($t -lt 1 / 6) {
        return $p + ($q - $p) * 6 * $t
      } 
      if ($t -lt 1 / 2) {
        return $q
      }
      if ($t -lt 2 / 3) {
        return $p + ($q - $p) * (2 / 3 - $t) * 6
      }
      return $p
    }
    $q = if ($Lightness -lt .5) {
      $Lightness * (1 + $Saturation)
    }
    else {
      $Lightness + $Saturation - $Lightness * $Saturation
    }
    $p = 2 * $Lightness - $q
    $red = HueToRgb $p $q ($Hue + 1 / 3)
    $green = HueToRgb $p $q $Hue
    $blue = HueToRgb $p $q ($Hue - 1 / 3)
  }

  return [System.Drawing.Color]::FromArgb($red * 255, $green * 255, $blue * 255)
}

function Create-IconStyle(
  [string]$name, 
  [System.Nullable[System.Drawing.Color]]$color = $null, 
  [string]$url = "http://maps.google.com/mapfiles/kml/shapes/shaded_dot.png", 
  [System.Nullable[System.Drawing.Point]]$hotspot = $null,
  [float]$scaleNormal = 1.2,
  [float]$scaleHighlight = 1.4,
  [float]$labelScale = 1.0) {
  $hotspotText = ""
  $colorText = ""
  if ($null -ne $hotspot) {
    $hotspotText = "
    <hotSpot x=""$($hotspot.X)"" y=""$($hotspot.Y)"" xunits=""pixels"" yunits=""pixels""/>"
  }
  if ($null -ne $color) {
    $colorBGR = [string]::join("", $color.A.ToString('X2'), $color.B.ToString('X2'), $color.G.ToString('X2'), $color.R.ToString('X2'))
    $colorText = "
    <color>$colorBGR</color>"
  }
  $labelScaleText = ""
  if ($labelScale -ne 1.0) {
    $labelScaleText = "
    <LabelStyle>
      <scale>$labelScale</scale>
    </LabelStyle>"
  }
  "
  <Style id=""sn_$name"">
    <IconStyle>$colorText
      <scale>$scaleNormal</scale>
      <Icon>
        <href>$url</href>
      </Icon>$hotspotText
    </IconStyle>$labelScaleText
  </Style>
  <Style id=""sh_$name"">
    <IconStyle>$colorText
      <scale>$scaleHighlight</scale>
      <Icon>
        <href>$url</href>
      </Icon>$hotspotText
    </IconStyle>$labelScaleText
  </Style>
  <StyleMap id=""$name"">
    <Pair>
      <key>normal</key>
      <styleUrl>#sn_$name</styleUrl>
    </Pair>
    <Pair>
      <key>highlight</key>
      <styleUrl>#sh_$name</styleUrl>
    </Pair>
  </StyleMap>"
}

$kmlHeader = '<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
<Document>
	<name>My Places.kml</name>
	<Style id="inline0">
		<LineStyle>
			<color>ff0000ff</color>
			<width>2</width>
		</LineStyle>
	</Style>'

$kmlHeader += (Create-IconStyle `
    -name 's_ylw-pushpin' `
    -url 'http://maps.google.com/mapfiles/kml/pushpin/ylw-pushpin.png' `
    -hotspot ([system.drawing.point]::new(20, 2)) `
    -scaleNormal 1.1 `
    -scaleHighlight 1.3)

$kmlHeader += (Create-IconStyle -labelScale 0 -name 'm_grn-dot' -color ([system.drawing.color]::FromArgb(0x21, 0xFF, 0x00)))
$kmlHeader += (Create-IconStyle -labelScale 0 -name 'm_red-dot' -color ([system.drawing.color]::FromArgb(0x7F, 0x00, 0x00)))
$kmlHeader += (Create-IconStyle -labelScale 0 -name 'm_org-dot' -color ([system.drawing.color]::FromArgb(0xFF, 0xAA, 0x00)))
$kmlHeader += (Create-IconStyle -labelScale 0 -name 'm_ylw-dot' -color ([system.drawing.color]::FromArgb(0xFF, 0xFF, 0x00)))
$kmlHeader += (Create-IconStyle -labelScale 0 -name 'm_blue-dot' -color ([system.drawing.color]::Blue))
$kmlHeader += (Create-IconStyle -labelScale 0 -name 'm_pink-dot' -color ([system.drawing.color]::Pink))
$kmlHeader += (Create-IconStyle -labelScale 0 -name 'm_lightblue-dot' -color ([system.drawing.color]::LightBlue))
  
  
$kmlFooter = '
  </Document>
  </kml>
  '
