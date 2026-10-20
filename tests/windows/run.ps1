$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$helper = Join-Path $root 'native/windows/CavalryWheel.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('CavalryWheelTests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
$script:checks = 0
function Check([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:checks++
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic
$requestObject = @{
    version = 1; active = 0; reducedMotion = $true; timeoutSeconds = 30
    accent = '#078430'; accentText = '#2fcd71'
    profiles = @(
        @{ name = 'QA-A'; items = @(
            @{ slot = 1; name = '普通脚本'; mode = 'script'; available = $true },
            @{ slot = 6; name = '面板脚本'; mode = 'ui'; available = $true }
        ) },
        @{ name = 'QA-B'; items = @(
            @{ slot = 10; name = 'Long-name-with 中文'; mode = 'script'; available = $true }
        ) }
    )
}
$request = Join-Path $temp 'request.json'
[IO.File]::WriteAllText($request, ($requestObject | ConvertTo-Json -Depth 8 -Compress), (New-Object Text.UTF8Encoding($false)))
function Invoke-Wheel([string]$Keys) {
    $response = Join-Path $temp ([Guid]::NewGuid().ToString('N') + '.json')
    $args = @('-NoProfile', '-STA', '-File', "`"$helper`"", '-RequestPath', "`"$request`"", '-ResponsePath', "`"$response`"")
    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $args -PassThru
    try {
        Start-Sleep -Milliseconds 900
        [Microsoft.VisualBasic.Interaction]::AppActivate($process.Id)
        Start-Sleep -Milliseconds 250
        [System.Windows.Forms.SendKeys]::SendWait($Keys)
        $process | Wait-Process -Timeout 20 -ErrorAction SilentlyContinue
        Check ($process.HasExited) "wheel did not exit after input: $Keys"
        Check ([IO.File]::Exists($response)) "wheel wrote no response: $Keys"
        return [IO.File]::ReadAllText($response, [Text.Encoding]::UTF8) | ConvertFrom-Json
    } finally {
        if (-not $process.HasExited) { $process.Kill() }
    }
}
try {
    $waitFile = Join-Path $temp 'wait.json'
    [IO.File]::WriteAllText($waitFile, '{"version":1,"action":"run","slot":6}', (New-Object Text.UTF8Encoding($false)))
    $waitResult = (& $helper -WaitResponsePath $waitFile -WaitSeconds 1 | Out-String).Trim()
    Write-Output "WAIT_RESULT_TYPE=$($waitResult.GetType().FullName) VALUE=[$waitResult]"
    Check ($waitResult -match '"action"\s*:\s*"run"' -and $waitResult -match '"slot"\s*:\s*6') 'wait reader returns the completed response'
    $pending = (& $helper -WaitResponsePath (Join-Path $temp 'missing.json') -WaitSeconds 1 | Out-String).Trim()
    Check ($pending -match '"pending"\s*:\s*true') 'wait reader is bounded and reports pending'

    $run = Invoke-Wheel '{DOWN}{DOWN}{ENTER}'
    Check ($run.action -eq 'run' -and $run.profile -eq 0 -and $run.slot -eq 6) 'two Down keys then Enter select the second stable slot'
    $profileKeys = '`{DOWN}{ENTER}'
    $switched = Invoke-Wheel $profileKeys
    Check ($switched.action -eq 'run' -and $switched.profile -eq 1 -and $switched.slot -eq 10) 'grave accent switches profile before selection'
    $cancel = Invoke-Wheel '{ESC}'
    Check ($cancel.action -eq 'cancel') 'Escape cancels without running a slot'
    Write-Output "PASS: $script:checks native Windows WinForms assertions on $env:COMPUTERNAME"
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
