. "$PSScriptRoot\CustomDB.ps1"
$customDBPath = "$PSScriptRoot\Cellmapper.dbe"

$importFolders = @(
    "$PSScriptRoot\ToDelete"
)

foreach ($item in $importFolders) {
    $destinationFolder = Join-Path $item 'Deleted'
    $null = mkdir $destinationFolder -Force
    $dbNames = Get-ChildItem -Path $item -Filter '*.db' | foreach-object { $_.FullName }
    write-host "Found $($dbNames.Count) databases in $item"
    foreach ($db in $dbNames) {
        Write-Host "  Removing points found in $db"
        $removedCount = Remove-CellMapperDBPoints -cmDBPath $db -customDBPath $customDBPath
        Move-Item $db -Destination $destinationFolder
    }
}
