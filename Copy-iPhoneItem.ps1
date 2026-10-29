# Internal isolated COM worker; called by Export-iPhone.ps1.
param([Parameter(Mandatory=$true)][string]$JobFile)
$ErrorActionPreference='Stop'
try {
    $job=Get-Content -LiteralPath $JobFile -Raw | ConvertFrom-Json
    $shell=New-Object -ComObject Shell.Application
    $device=@($shell.Namespace(17).Items() | Where-Object {$_.Name -match 'iPhone'})
    if ($device.Count -ne 1) { throw 'iPhone is unavailable.' }
    $dcim=$null
    foreach($storage in $device[0].GetFolder.Items()) {
        if(!$storage.IsFolder){continue}
        $dcim=$storage.GetFolder.Items() | Where-Object {$_.Name -eq 'DCIM'}
        if($dcim){break}
    }
    if(!$dcim){throw 'DCIM is unavailable.'}
    $folder=$dcim.GetFolder.Items() | Where-Object {$_.Name -eq $job.Folder}
    $item=$folder.GetFolder.Items() | Where-Object {$_.Name -eq $job.Name}
    if (!$item) { throw 'Device item is unavailable.' }
    $destination=$shell.Namespace($job.Destination)
    if (!$destination) { throw 'Destination is unavailable.' }
    $destination.CopyHere($item,16)
    $target=Join-Path $job.Destination $job.Name
    $deadline=[datetime]::UtcNow.AddSeconds($job.TimeoutSeconds)
    $stable=0
    do {
        Start-Sleep -Milliseconds 750
        if((Test-Path -LiteralPath $target) -and (Get-Item -LiteralPath $target).Length -eq $job.Bytes){$stable++}else{$stable=0}
        if($stable -ge 3){exit 0}
    } while([datetime]::UtcNow -lt $deadline)
    throw 'Copy did not finish.'
    exit 0
} catch { exit 1 }
