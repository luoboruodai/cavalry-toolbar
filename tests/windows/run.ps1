$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$helper = Join-Path $root 'native/windows/CavalryWheel.ps1'
$winFormsReferences = @('System.Windows.Forms', 'System.Drawing', 'System.Web.Extensions')
$temp = Join-Path ([IO.Path]::GetTempPath()) ('CavalryWheelTests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
$script:checks = 0
function Check([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:checks++
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class WheelNativeInput {
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
}
'@
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
function Invoke-Wheel([uint32[]]$Keys) {
    $sourceText = [IO.File]::ReadAllText($helper, [Text.Encoding]::UTF8)
    $match = [regex]::Match($sourceText, "-TypeDefinition @'\r?\n(?<code>[\s\S]*?)\r?\n'@")
    Check ($match.Success) 'production WinForms source is extracted without duplication'
    if (-not ('CavalryWheelForm' -as [type])) {
        Add-Type -ReferencedAssemblies $winFormsReferences -TypeDefinition $match.Groups['code'].Value
    }
    $json = [IO.File]::ReadAllText($request, [Text.Encoding]::UTF8)
    $form = New-Object CavalryWheelForm($json)
    try {
        $form.GetType().GetField('selected', [Reflection.BindingFlags]'NonPublic,Instance').SetValue($form, -1)
        $handle = $form.Handle
        Check ($handle -ne [IntPtr]::Zero) 'production form creates a real native window handle'
        $onKeyDown = $form.GetType().GetMethod('OnKeyDown', [Reflection.BindingFlags]'NonPublic,Instance')
        foreach ($key in $Keys) {
            $eventArgs = New-Object System.Windows.Forms.KeyEventArgs(([System.Windows.Forms.Keys]$key))
            $onKeyDown.Invoke($form, @($eventArgs)) | Out-Null
        }
        Write-Host "WHEEL_RESPONSE=$($form.Response)"
        return $form.Response | ConvertFrom-Json
    } finally {
        $form.Dispose()
    }
}
function Invoke-WaitReader([string]$Path, [int]$Seconds) {
    $stdout = Join-Path $temp ([Guid]::NewGuid().ToString('N') + '.txt')
    $args = @('-NoProfile', '-File', "`"$helper`"", '-WaitResponsePath', "`"$Path`"", '-WaitSeconds', $Seconds)
    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $args -RedirectStandardOutput $stdout -WindowStyle Hidden -Wait -PassThru
    Check ($process.ExitCode -eq 0) "wait reader exits successfully"
    return [IO.File]::ReadAllText($stdout, [Text.Encoding]::UTF8).Trim()
}

try {
    $waitFile = Join-Path $temp 'wait.json'
    [IO.File]::WriteAllText($waitFile, '{"version":1,"action":"run","slot":6}', (New-Object Text.UTF8Encoding($false)))
    $waitResult = Invoke-WaitReader $waitFile 1
    Check ($waitResult -match '"action"\s*:\s*"run"' -and $waitResult -match '"slot"\s*:\s*6') 'wait reader returns the completed response'
    $pending = Invoke-WaitReader (Join-Path $temp 'missing.json') 1
    Check ($pending -match '"pending"\s*:\s*true') 'wait reader is bounded and reports pending'

    $run = Invoke-Wheel @(0x26, 0x26, 0x0D)
    Check ($run.action -eq 'run' -and $run.profile -eq 0 -and $run.slot -eq 6) 'two Down key events then Enter select the second stable slot'
    $switched = Invoke-Wheel @(0xC0, 0x26, 0x0D)
    Check ($switched.action -eq 'run' -and $switched.profile -eq 1 -and $switched.slot -eq 10) 'grave accent switches profile before selection'
    $cancel = Invoke-Wheel @(0x1B)
    Check ($cancel.action -eq 'cancel') 'Escape cancels without running a slot'
    Write-Output "PASS: $script:checks native Windows WinForms assertions on $env:COMPUTERNAME"
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
