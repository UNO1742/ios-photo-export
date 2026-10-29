#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Start,
    [string]$End,
    [string]$Destination,
    [string]$Config,
    [string]$TimeZone = 'China Standard Time',
    [switch]$Preview,
    [switch]$AllFolders,
    [ValidateRange(10,3600)][int]$TimeoutSeconds = 180,
    [ValidateSet('All','Photos','Videos')][string]$Media = 'All'
)
$ErrorActionPreference = 'Stop'
try {
    if ($Config) {
        $settings = Get-Content -LiteralPath $Config -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($key in @('Start','End','Destination','TimeZone','TimeoutSeconds','Media')) {
            if (!$PSBoundParameters.ContainsKey($key) -and $null -ne $settings.$key) { Set-Variable -Name $key -Value $settings.$key }
        }
        if (!$PSBoundParameters.ContainsKey('AllFolders') -and $settings.AllFolders) { $AllFolders = $true }
    }
    $zone = [TimeZoneInfo]::FindSystemTimeZoneById($TimeZone)
    $now = [TimeZoneInfo]::ConvertTimeFromUtc([datetime]::UtcNow,$zone)
    if (!$Start) { throw 'Provide -Start "yyyy-MM-dd HH:mm:ss" or set Start in config.json.' }
    function Read-Date([string]$Text) {
        $value = [datetime]::ParseExact($Text,[string[]]@('yyyy-MM-dd HH:mm:ss','yyyy-MM-dd HH:mm'),[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None)
        return [datetime]::SpecifyKind($value,[DateTimeKind]::Unspecified)
    }
    $from = Read-Date $Start
    $until = if ($End) { Read-Date $End } else { $now }
    if ($until -lt $from) { throw 'End must be on or after Start.' }
    if ($Media -notin @('All','Photos','Videos')) { throw 'Media must be All, Photos or Videos.' }
    if ($TimeoutSeconds -lt 10 -or $TimeoutSeconds -gt 3600) { throw 'TimeoutSeconds must be between 10 and 3600.' }
    if (!$Destination) { $Destination = Join-Path $PSScriptRoot ('exports\iPhone_'+$from.ToString('yyyy-MM-dd_HHmmss')+'_'+$until.ToString('yyyy-MM-dd_HHmmss')) }
    $Destination = [IO.Path]::GetFullPath($Destination)
    $shell = New-Object -ComObject Shell.Application
    $device = @($shell.Namespace(17).Items() | Where-Object {$_.Name -match 'iPhone'})
    if ($device.Count -ne 1) { throw ('Expected one connected iPhone; found '+$device.Count+'. Unlock it and allow access, or disconnect other iPhones.') }
    $storage = @($device[0].GetFolder.Items() | Where-Object {$_.IsFolder})
    $dcim = $null
    foreach ($s in $storage) { $dcim = $s.GetFolder.Items() | Where-Object {$_.Name -eq 'DCIM'}; if ($dcim) { break } }
    if (!$dcim) { throw 'DCIM is unavailable. Unlock iPhone, reconnect USB and trust this computer.' }
    $months = @(); $cursor = [datetime]::new($from.Year,$from.Month,1)
    while ($cursor -le $until) { $months += $cursor.ToString('yyyyMM'); $cursor = $cursor.AddMonths(1) }
    $folders = @($dcim.GetFolder.Items() | Where-Object { $AllFolders -or ($_.Name.Length -ge 6 -and $_.Name.Substring(0,6) -in $months) })
    $selected = @()
    foreach ($folder in $folders) {
        Write-Host ('Scanning '+$folder.Name)
        foreach ($item in $folder.GetFolder.Items()) {
            $ext = [IO.Path]::GetExtension($item.Name).ToLowerInvariant()
            $kind = if ($ext -in @('.mov','.mp4','.m4v','.avi')) {'Video'} elseif ($ext -in @('.heic','.heif','.jpg','.jpeg','.png','.gif','.tif','.tiff','.dng')) {'Photo'} else {continue}
            if (($Media -eq 'Photos' -and $kind -ne 'Photo') -or ($Media -eq 'Videos' -and $kind -ne 'Video')) {continue}
            # WPD returns this COM timestamp in UTC without a reliable Kind flag.
            # Convert explicitly; do not compare its raw clock value with local time.
            $raw = $item.ExtendedProperty('System.DateCreated')
            if (!$raw) { throw ('Missing device creation timestamp: '+$item.Name) }
            $local = [TimeZoneInfo]::ConvertTimeFromUtc([datetime]::SpecifyKind([datetime]$raw,[DateTimeKind]::Utc),$zone)
            if ($local -lt $from -or $local -gt $until) {continue}
            $bytes = [long]$item.ExtendedProperty('System.Size')
            if ($bytes -le 0) { throw ('Invalid source size: '+$item.Name) }
            $relative = Join-Path $folder.Name $item.Name
            $selected += [pscustomobject]@{Folder=$folder.Name;Name=$item.Name;DeviceTime=$local.ToString('yyyy-MM-dd HH:mm:ss');Type=$kind;Bytes=$bytes;RelativePath=$relative;ShellPath=$item.Path;Status='Pending'}
        }
    }
    $selected = @($selected | Sort-Object DeviceTime,RelativePath)
    $selected | Select-Object Name,DeviceTime,Type,Bytes | Format-Table -AutoSize | Out-Host
    Write-Host ('Selected: '+$selected.Count+'; destination: '+$Destination)
    if ($Preview) { exit 0 }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    $manifest = Join-Path $Destination ('export-manifest-'+[datetime]::Now.ToString('yyyyMMdd-HHmmss-fff')+'.json')
    $run = [ordered]@{Start=$from.ToString('s');End=$until.ToString('s');TimeZone=$TimeZone;TimestampBasis='iPhone WPD DateCreated converted from UTC; album edits may differ';Destination=$Destination;Files=$selected}
    function Save-Manifest { $run | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifest -Encoding UTF8 }
    Save-Manifest
    foreach ($entry in $selected) {
        $target = Join-Path $Destination $entry.RelativePath
        if (Test-Path -LiteralPath $target) {
            if ((Get-Item -LiteralPath $target).Length -eq $entry.Bytes) { $entry.Status='AlreadyPresent'; Save-Manifest; continue }
            $entry.Status='Conflict'; Save-Manifest; throw ('Existing file has a different size; preserve or rename it before retrying: '+$target)
        }
        $parent = Split-Path -Parent $target
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        $jobFile = Join-Path ([IO.Path]::GetTempPath()) ('iphone-export-'+[guid]::NewGuid().ToString('N')+'.json')
        @{Folder=$entry.Folder;Name=$entry.Name;Bytes=$entry.Bytes;Destination=$parent;TimeoutSeconds=$TimeoutSeconds} | ConvertTo-Json | Set-Content -LiteralPath $jobFile -Encoding UTF8
        try {
            $exe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
            $worker = Join-Path $PSScriptRoot 'Copy-iPhoneItem.ps1'
            $arguments = '-NoProfile -STA -ExecutionPolicy Bypass -File "'+$worker+'" -JobFile "'+$jobFile+'"'
            Write-Host ('Copying '+$entry.Name)
            $process = Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru
            $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
            $complete = $false
            do {
                Start-Sleep -Milliseconds 750
                if ($process.HasExited -and $process.ExitCode -ne 0) { break }
                if ((Test-Path -LiteralPath $target) -and (Get-Item -LiteralPath $target).Length -eq $entry.Bytes -and $process.HasExited) { $complete=$true; break }
            } while ([datetime]::UtcNow -lt $deadline)
            if (!$complete -or $process.ExitCode -ne 0) {
                if (!$process.HasExited) { $process.Kill() }
                $entry.Status='Failed'; Save-Manifest
                throw ('Transfer failed or timed out: '+$entry.Name+'. Reconnect and retry. A partial file, if present, must be renamed before retry.')
            }
            $entry.Status='Copied'; Save-Manifest
        } finally { Remove-Item -LiteralPath $jobFile -Force -ErrorAction SilentlyContinue }
    }
    $total = ($selected | Measure-Object Bytes -Sum).Sum
    Write-Host ('SUCCESS: '+$selected.Count+' files; '+$total+' bytes. Manifest: '+$manifest)
    exit 0
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }
