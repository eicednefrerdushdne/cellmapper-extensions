start-transcript -Path "$psscriptroot\log.txt" -Append -Force

Add-Type -AssemblyName 'System.Device'
# enter this URL to reach PowerShell’s web server
$url = 'http://localhost:8080/'
$customDBPath = "$PSScriptRoot\Cellmapper.dbe"
. $PSScriptRoot/httphelpers.ps1
. $PSScriptRoot/CustomDB.ps1
. $PSScriptRoot/scriptblockcallback.ps1
if (-not (Test-Path $customDBPath)) {
  New-CustomDB -Path $customDBPath
}

# HTML content for some URLs entered by the user
$GLOBAL:htmlcontents = @{
  '^OPTIONS .*$'                           = {
    return ''
  }
  '^GET /$'                                = '<html><building>Here is PowerShell</building></html>'
  '^PUT /smallcells/(\d+-\d+)/(\d+)/?$'    = {
    param (
      [System.Net.HttpListenerRequest]
      $request
    )
    $m = $request.Url.LocalPath -match '^/smallcells/(?<mccmnc>\d+-\d+)/(?<enb>\d+)/?$'


    $existingQuery = @{
      Database      = $customDBPath
      Query         = 'select * from SmallCells where enb = @enb and mccmnc = @mccmnc'
      SqlParameters = @{
        enb    = $matches.enb
        mccmnc = $matches.mccmnc
      }
    }
    $existing = Invoke-SqliteQuery @existingQuery

    if (-not $existing) {
      $insertQuery = @{
        Database      = $customDBPath
        Query         = 'insert into SmallCells (eNB, MCCMNC) values (@eNB, @mccmnc)'
        SqlParameters = @{
          enb    = $matches.enb
          mccmnc = $matches.mccmnc
        }
      }
      $insert = Invoke-SqliteQuery @insertQuery
    }
    
    return 'true'
  }
  '^DELETE /smallcells/(\d+-\d+)/(\d+)/?$' = {
    param (
      [System.Net.HttpListenerRequest]
      $request
    )
    $m = $request.Url.LocalPath -match '^/smallcells/(?<mccmnc>\d+-\d+)/(?<enb>\d+)/?$'


    $deleteQuery = @{
      Database      = $customDBPath
      Query         = 'delete from SmallCells where enb = @enb and mccmnc = @mccmnc'
      SqlParameters = @{
        enb    = $matches.enb
        mccmnc = $matches.mccmnc
      }
    }
    $delete = Invoke-SqliteQuery @deleteQuery
    
    return 'true'
  }
  '^GET /smallcells/\d+-\d+/?$'            = {
    param (
      [System.Net.HttpListenerRequest]
      $request
    )
    $m = $request.Url.LocalPath -match '^/smallcells/(?<mccmnc>\d+-\d+)/?$'
    $query = @{
      Database      = $customDBPath
      Query         = 'select * from SmallCells where mccmnc = @mccmnc'
      SqlParameters = @{
        mccmnc = $matches.mccmnc
      }
    }
    $enbs = Invoke-SqliteQuery @query

    $enbs = @($enbs | ForEach-Object { $_.eNB.ToString() })

    return ConvertTo-Json $enbs

  }
  '^GET /enb/\d+/\d+/\d+(-\d+)?$'                 = {
    param (
      [System.Net.HttpListenerRequest]
      $request
    )
    $m = $request.Url.LocalPath -match '^/enb/(?<mcc>\d+)/(?<mnc>\d+)/(?<enb>\d+)(-(?<cid>\d+))?$'

    if($matches.cid){
      Write-Host "Retrieving points for $($matches.mcc)-$($matches.mnc) eNB $($matches.enb) cid $($matches.cid)"
    } else {
      Write-Host "Retrieving points for $($matches.mcc)-$($matches.mnc) eNB $($matches.enb)"
    }
    $points = @(Get-eNBPoints -Path $customDBPath -enb $matches.enb -mcc $matches.mcc -mnc $matches.mnc)
    if($matches.mcc -eq 310 -and $matches.mnc -eq 120) {
      $points += @(Get-eNBPoints -Path $customDBPath -enb $matches.enb -mcc 312 -mnc 250)
    }

    if($matches.cid){
      $cid = [int]$matches.cid
      $points = [System.Collections.ArrayList]@($points | where-object {($_.CellID -band 255) -eq $cid})
    }

    $alwaysKeepPoints = [System.Collections.ArrayList]@($points | Where-Object { $_.TAMeters -le 150 })
    $filterPoints = [System.Collections.ArrayList]@($points | Where-Object { $_.TAMeters -gt 150 })
    
    while ($filterPoints.Count -gt 100) {
      $i = 0
      if ($filterPoints.Count -gt 1) {
        $i = Get-Random -Maximum ($filterPoints.Count - 1)
      }
      $filterPoints.RemoveAt($i)
    }
    $combined = $alwaysKeepPoints + $filterPoints

    Write-Host "  Returning $($combined.Count) points of $($points.Count)"
    return  ConvertTo-Json $combined
  }
  '^POST /openGoogleEarth$'                = {
    param (
      [System.Net.HttpListenerRequest]
      $request
    )
    #$m = $request.Url.LocalPath -match '^/openGoogleEarth/(?<enb>\d+)$'
    $requestJson = $null
    try {
      $strReader = [System.IO.StreamReader]::new($request.InputStream)
      $requestJson = $strReader.ReadToEnd();
      $requestJson = $requestJson | ConvertFrom-Json

      if ($requestJson.mcc -isnot [int]) {
        throw 'mcc was not an int'
      }
      if ($requestJson.mnc -isnot [int]) {
        throw 'mnc was not an int'
      }
      if ($requestJson.enb -isnot [string]) {
        throw 'eNB was not a string'
      }
      if ($requestJson.latitude -isnot [decimal]) {
        throw 'latitude was not a decimal'
      }
      if ($requestJson.longitude -isnot [decimal]) {
        throw 'longitude was not a decimal'
      }
      if ($requestJson.verified -isnot [bool]) {
        throw 'verified was not a bool'
      }
    }
    finally {
      if ($strReader) {
        $strReader.Dispose();
      }
    }
    
    Write-Host "Opening Google Earth for eNB $($requestJson.enb)"
    mkdir "$PSScriptRoot\kmls" -force
    $filename = "$PSScriptRoot\kmls\tower$($requestJson.mcc)-$($requestJson.mnc)-$($requestJson.enb).kml"
    Write-Host "Running & .\Create-CellmapperKML.ps1 -mcc $($requestJson.mcc) -mnc $($requestJson.mnc) -eNB '$($requestJson.enb)' -filename '$filename' -noLines"
    . .\Create-CellmapperKML.ps1 -mcc $requestJson.mcc -mnc $requestJson.mnc -eNB $requestJson.enb -latitude $requestJson.Latitude -longitude $requestJson.Longitude -verified $requestJson.verified -filename $filename -noLines
    Start-Process $filename

    return 'hello'
  }
}
# start web server
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)
$listener.Start()

try {
  while ($listener.IsListening) {
    # process received request
    $callback = New-ScriptBlockCallback { param ($asyncResult)
      $context = $asyncResult.AsyncState.EndGetContext($asyncResult)

      $Request = $context.Request
      $Response = $context.Response
      $response.AddHeader('Access-Control-Allow-Origin', 'https://www.cellmapper.net')
      $response.AddHeader('Access-Control-Allow-Methods', 'DELETE, PUT, POST, GET, OPTIONS')
      $response.AddHeader('Access-Control-Allow-Headers', 'Access-Control-Allow-Headers, Origin,Accept, X-Requested-With, Content-Type, Access-Control-Request-Method, Access-Control-Request-Headers')
      $received = "$($request.httpmethod) $($Request.url.localpath)"

      Write-Host "`r`nReceived `"$received`""
      # is there HTML content for this URL?
      $key = $htmlcontents.Keys | Where-Object { $received -match $_ }

      if ($key) {
        Write-Host "Found handler: $key"
        $handler = $htmlcontents[$key]
        if ($handler -is [string]) {
          $html = $handler
        }
        elseif ($handler -is [scriptblock]) {
          $html = Invoke-Command -ScriptBlock $handler -ArgumentList @($Request)
        }
      }
      else {
        Write-Host "No handler available."
        $Response.statuscode = 404
        $html = 'Oops, the page is not available!'
      
      }
      if ($null -eq $html) {
        $html = ''
      }
      # return the HTML to the caller
      $buffer = [Text.Encoding]::UTF8.GetBytes($html)
      $Response.ContentLength64 = $buffer.length
      $Response.OutputStream.Write($buffer, 0, $buffer.length)
    
      $Response.Close()
    }
      
    $waitHandle = $listener.BeginGetContext($callback, $listener);
    if (-not $processing) {
      $processing = $true
      if (-not $waitHandle.AsyncWaitHandle.WaitOne(1000)) {
        $processing = $false
      }
      $processing = $false
    }
  }
}
finally {
  $listener.Stop()
}