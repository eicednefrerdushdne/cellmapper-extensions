. "$PSScriptRoot\CustomDB.ps1"
$customDBPath = "$PSScriptRoot\Cellmapper.dbe"

$importFolders = @(
    "$PSScriptRoot\ToImport"
    "G:\My Drive\Cellmapper"
)

foreach ($item in $importFolders) {
    $destinationFolder = Join-Path $item 'Imported'
    $null = mkdir $destinationFolder -Force
    $dbNames = Get-ChildItem -Path $item -Filter '*.db' | foreach-object { $_.FullName }
    write-host "Found $($dbNames.Count) databases in $item"
    foreach ($db in $dbNames) {
        Write-Host "  Importing $db"
        $importedCount = Import-CellMapperDB -cmDBPath $db -customDBPath $customDBPath
        Move-Item $db -Destination $destinationFolder
    }
}
