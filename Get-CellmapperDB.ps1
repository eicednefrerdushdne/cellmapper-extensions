[CmdletBinding()]
param (
  [Parameter()]
  [string]
  $Path
)

$tempDir = Join-Path $env:TEMP ([System.IO.Path]::GetRandomFileName())
$tempFile = Join-Path $tempDir cellmapper.ab
$abuexe = [io.path]::Combine($psscriptroot, 'abu.exe')
$abuExtractDir = [io.path]::Combine($tempdir, 'extracted')
mkdir -force $abuExtractDir

Write-Host "Please connect your device and allow USB debugging."
adb wait-for-device

if (-not $Path) {
  $deviceName = & adb shell settings get global device_name
  $datetimestring = [datetime]::now.ToString('yyyy.MM.dd_hh.mm.ss')
  $Path = [io.path]::Combine($psscriptroot, 'ToImport', ($deviceName + "_$datetimestring.db"))
  $lastDownloadedPath = [io.path]::Combine($psscriptroot, 'ToImport', ($deviceName + "_lastDownloaded.txt"))
}

$thisDownloaded = [datetime]::now
Write-Host "Please approve the backup."
adb backup -f "$tempFile" -noapk cellmapper.net.cellmapper

$result = & $abuexe "$tempFile" --unpack "$abuExtractDir" 2>&1

if($result -is [System.Management.Automation.ErrorRecord]){
  if($result.Exception.Message -eq 'The backup is encrypted but no password was provided') {
    $result = & $abuexe --password password "$tempFile" --unpack "$abuExtractDir" 2>&1
    if($result -is [System.Management.Automation.ErrorRecord] -and $result.Exception.Message -eq 'Wrong password'){
      throw "Please run adb backup either with no password or with the password set to `password` (excluding quotes)."
    }
  }
}

Move-Item (Join-Path $abuExtractDir apps/cellmapper.net.cellmapper/db/cellmapperdata.db) $Path -Force

Remove-Item $tempDir -Recurse -force

if ((get-command sqlite3).CommandType -ne 'Application') {
  Write-Warning "Install the sqlite executable on the path, and the script will attempt to repair any potential errors in the database."
  exit
}
else {
  # Repair database errors which are common
  Write-Output "Checking for database errors..."
  $output = sqlite3 $path "pragma integrity_check" 2>&1
  if ($output | where-object { $_ -is [System.Management.Automation.ErrorRecord] }) {
    Write-Output "Repairing database errors"
    sqlite3 $path ".recover" | sqlite3 recovered.db
    Move-Item Recovered.db $path -Force
  }

  # Remove data that was previously downloaded
  if (Test-Path $lastDownloadedPath) {
    $lastDownloadedContent = Get-Content -Raw $lastDownloadedPath
    [datetime]$lastDownloaded = [datetime]::MinValue
    if ([datetime]::TryParse($lastDownloadedContent, [ref]$lastDownloaded)) {
      if ($lastDownloaded -is [datetime]) {
        sqlite3 $path "delete from data where date < '$($lastDownloaded.ToUniversalTime().ToString('o').Replace("T"," "))'"
      }
    }
  }

  # Remove non-LTE points
  sqlite3 $path "delete from data where system <> 'LTE'"

  # Compact the database
  sqlite3 $path "vacuum main"

  # If we've reached this point, it was likely successful, so save the downloaded date to use next time
  $thisDownloaded.ToUniversalTime().ToString('o') | Set-Content $lastDownloadedPath
}
