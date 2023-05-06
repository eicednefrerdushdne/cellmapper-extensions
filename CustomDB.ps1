# Import httphelpers.ps1 to have access to the timing advance conversions.
. $PSScriptRoot\httphelpers.ps1
Add-Type -AssemblyName 'System.Device'


function New-CustomDB([string]$Path, [switch]$Force) {
  if (-not (Test-Path -Path "$PSScriptRoot\CellMapper.dbe.sql")) {
    throw "Can't find CellMapper.dbe.sql to use as a database template."
  }

  $dbScript = Get-Content -Raw -Path "$PSScriptRoot\CellMapper.dbe.sql"

  if (Test-Path -Type Leaf -Path $Path) {
    if ($Force) {
      Remove-Item -Force -Path $Path
    }
    else {
      throw "Database already exists. Use -Force parameter to delete and recreate."
    }
  }

  Invoke-SqliteQuery -DataSource $Path -Query $dbScript
}


function Get-PointsForCustomDB([string]$cmDB) {
  $data = Invoke-SqliteQuery -DataSource $cmDB -Query "select
      Latitude as Latitude,
      Longitude as Longitude,
      MCC,
      MNC,
      -1 as TAMeters,
      CID as CellID,
      System as System,
      -1 as Band,
      -1 as ARFCN,
      Signal as Signal,
      extraData from data
      where System in ('LTE', 'NR') and subSystem not in ('NSA')
      group by Latitude,Longitude,Altitude,CID
      having min(rowid)"
  
    
  foreach ($point in $data) {
  
    if ($point.extraData -match $bandRegex) {
      $point.Band = [int]$matches.Band
    }
    if ($point.extraData -match $arfcnRegex) {
      $point.ARFCN = [int]$matches.ARFCN
    }
  
    if ($point.extraData -match $bandRegex) {
      $point.Band = [int]$matches.Band
    }
    
    if ($point.extraData -match $taRegex) {
      $point.TAMeters = [int]$matches.TA
  
      if (($point.TAMeters % 78) -eq 0) {
        $point.TAMeters = $point.TAMeters / 78
      }
      elseif (($point.TAMeters % 144) -eq 0) {
        $point.TAMeters = $point.TAMeters / 144
      }
      elseif (($point.TAMeters % 150) -eq 0) {
        $point.TAMeters = $point.TAMeters / 150
      }
      
      $carrierTA = $timingAdvances["$($point.MCC)-$($point.MNC)"]
      if (-not $carrierTA) {
        $carrierTA = $timingAdvances['']
      }
      if ($carrierTA) {
        if (-not $carrierTA[$point.Band]) {
          $point.TAMeters = $point.TAMeters * $carrierTA[0]
        }
        elseif ( $carrierTA[$point.Band] -is [scriptblock]) {
          $point.TAMeters = $carrierTA[$point.Band].InvokeReturnAsIs($point.TAMeters)
        }
        else {
          $point.TAMeters = $point.TAMeters * $carrierTA[$point.Band]
        }
      }
    }
  
    $point.psobject.Properties.remove('extraData')
    $point.psobject.Properties.remove('eNB')
  }
  
  return $data
}

function Get-CellIDPoints([string]$Path, [long]$CellID) {
  return Invoke-SqliteQuery -DataSource $Path -Query "Select * from Points where CellID = $CellID"
}

function Get-eNBPoints([string]$Path, [int]$mcc, [int]$mnc, [long]$eNB) {
  return Invoke-SqliteQuery -DataSource $Path -Query "Select * from Points where MCC = $mcc and MNC = $mnc and (CellID >> 8) = $eNB and System = 'LTE'"
}

function Get-gNBPoints([string]$Path, [int]$mcc, [int]$mnc, [long]$gNB) {
  return Invoke-SqliteQuery -DataSource $Path -Query "Select * from Points where MCC = $mcc and MNC = $mnc and (CellID >> 12) = $gNB and System = 'NR'"
}

function Add-PointsToCustomDB([string]$customDBPath, $points) {
  $dataTable = $points | Out-DataTable
  Invoke-SQLiteBulkCopy -DataSource $customDBPath -DataTable $dataTable -Table 'Points' -Force
}

# Returns points that don't have near duplicates in the target database.
function Remove-Duplicates([string]$targetDatabasePath, $points) {
  $cells = @{}
  $taDuplicateLimits = @{
    -1  = 40
    0   = 2
    150 = 10
    300 = 20
  }
  $defaultDuplicateLimit = 40
  [collections.arraylist]$results = @()

  foreach ($point in $points) {
    [collections.generic.list[PSCustomObject]]$existingPoints = $cells[$point.CellID]
    # Find existing points for this cell
    if (-not $existingPoints) {

      $existingPoints = Get-CellIDPoints -Path $targetDatabasePath -CellID $point.CellID
      if (-not $existingPoints) {
        $existingPoints = [collections.generic.list[PSCustomObject]]::new()
      }
      else {
        $existingPoints = [collections.generic.list[PSCustomObject]]::new($existingPoints)
      }

      $cells[$point.CellID] = $existingPoints
    } 

    $minDistance = $taDuplicateLimits[[int32]$point.TAMeters]
    if (-not $minDistance) {
      $minDistance = $defaultDuplicateLimit
    }

    $thisPoint = [System.Device.Location.GeoCoordinate]::new($point.Latitude, $point.Longitude)
 
        
    [bool] $isDup = [System.Linq.Enumerable]::Any($existingPoints, [func[pscustomobject, bool]] {
        param($p)
        return ($p.TAMeters -eq $point.TAMeters) -and
            ($thisPoint.GetDistanceTo([System.Device.Location.GeoCoordinate]::new($p.Latitude, $p.Longitude)) -lt $minDistance) })
        
    if (-not $isDup) {
      $null = $existingPoints.add($point)
      $null = $results.Add($point)
    }

  }

  return $results
}

function Import-CellMapperDB([string]$cmDBPath, [string]$customDBPath) {
  $points = Get-PointsForCustomDB $cmDBPath
  Write-Host "    Processing $($points.count) points"
  $toAdd = Remove-Duplicates -targetDatabasePath $customDBPath -points $points
  if ($toAdd) {
    Add-PointsToCustomDB -customDBPath $customDBPath -points $toAdd
  }
  Write-Host "    Imported $($toAdd.Count) points"
}

function Remove-CellMapperDBPoints([string]$cmDBPath, [string]$customDBPath) {
  $points = Get-PointsForCustomDB $cmDBPath
  Write-Host "    Processing $($points.count) points"
  $query = "Delete from Points where MCC = @mcc and MNC = @mnc and CellID = @cellid and Latitude = @latitude and Longitude = @longitude"
  $totalDeleted = 0
  foreach ($point in $points) {
    $parameters = @{
      mcc       = $point.MCC
      mnc       = $point.MNC
      cellid    = $point.CellID
      latitude  = $point.Latitude
      longitude = $point.Longitude
    }
    $deleted = Invoke-SqliteQuery -DataSource $customDBPath -Query $query -SqlParameters $parameters
    if ($deleted -is [int]) {
      $totalDeleted += $deleted
    }
  }
  
  Write-Host "    Removed $totalDeleted points"
}
