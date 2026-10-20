$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$helper = Join-Path $root 'native/windows/CavalryWheel.ps1'
$winFormsReferences = @('System.Windows.Forms', 'System.Drawing', 'System.Web.Extensions', 'UIAutomationClient', 'UIAutomationTypes')
$temp = Join-Path ([IO.Path]::GetTempPath()) ('CavalryWheelTests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
$script:checks = 0
function Check([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:checks++
}
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
function New-WheelForm([bool]$ReducedMotion = $true) {
    $sourceText = [IO.File]::ReadAllText($helper, [Text.Encoding]::UTF8)
    $match = [regex]::Match($sourceText, "-TypeDefinition @'\r?\n(?<code>[\s\S]*?)\r?\n'@")
    Check ($match.Success) 'production WinForms source is extracted without duplication'
    if (-not ('CavalryWheelForm' -as [type])) {
        Add-Type -ReferencedAssemblies $winFormsReferences -TypeDefinition $match.Groups['code'].Value
    }
    $configuration = @{} + $requestObject
    $configuration.reducedMotion = $ReducedMotion
    $json = $configuration | ConvertTo-Json -Depth 8 -Compress
    $form = New-Object CavalryWheelForm($json)
    $form.ResponsePath = Join-Path $temp ([Guid]::NewGuid().ToString('N') + '.json')
    return $form
}
function Field($Form, $Name) {
    return $Form.GetType().GetField($Name, [Reflection.BindingFlags]'NonPublic,Instance').GetValue($Form)
}
function Set-Field($Form, $Name, $Value) {
    $field = $Form.GetType().GetField($Name, [Reflection.BindingFlags]'NonPublic,Instance')
    if ($field.FieldType -eq [int]) { $Value = [int]$Value }
    $field.SetValue($Form, $Value)
}
function Invoke-Private($Form, $Name, $Arguments = @()) {
    $method = $Form.GetType().GetMethod($Name, [Reflection.BindingFlags]'NonPublic,Instance')
    return $method.Invoke($Form, $Arguments)
}
function Invoke-Wheel([uint32[]]$Keys) {
    $form = New-WheelForm
    try {
        Set-Field $form 'selected' -1
        Check ($form.Handle -ne [IntPtr]::Zero) 'production form creates a real native window handle'
        $onKeyDown = $form.GetType().GetMethod('OnKeyDown', [Reflection.BindingFlags]'NonPublic,Instance')
        foreach ($key in $Keys) {
            $eventArgs = New-Object System.Windows.Forms.KeyEventArgs(([System.Windows.Forms.Keys]$key))
            $onKeyDown.Invoke($form, [object[]]@($eventArgs.PSObject.BaseObject)) | Out-Null
        }
        if ([IO.File]::Exists($form.ResponsePath)) { return [IO.File]::ReadAllText($form.ResponsePath) | ConvertFrom-Json }
        return $form.Response | ConvertFrom-Json
    } finally { $form.Dispose() }
}
function Invoke-WaitReader([string]$Path, [int]$Seconds) {
    $stdout = Join-Path $temp ([Guid]::NewGuid().ToString('N') + '.txt')
    $args = @('-NoProfile', '-File', "`"$helper`"", '-WaitResponsePath', "`"$Path`"", '-WaitSeconds', $Seconds)
    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $args -RedirectStandardOutput $stdout -WindowStyle Hidden -Wait -PassThru
    Check ($process.ExitCode -eq 0) 'wait reader exits successfully'
    return [IO.File]::ReadAllText($stdout, [Text.Encoding]::UTF8).Trim()
}
function Invoke-Dispatch([int]$HostPID, [string]$Target) {
    $request = Join-Path $temp ([Guid]::NewGuid().ToString('N') + '-ui.json')
    $response = Join-Path $temp ([Guid]::NewGuid().ToString('N') + '-ui-response.json')
    [IO.File]::WriteAllText($request, (@{ version = 1; hostPID = $HostPID; target = $Target } | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding($false)))
    $args = @('-NoProfile', '-STA', '-File', "`"$helper`"", '-DispatchUI', "`"$request`"", '-DispatchResponsePath', "`"$response`"", '-ScriptsRoot', "`"$scriptsRoot`"")
    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $args -PassThru
    $process | Wait-Process -Timeout 20 -ErrorAction SilentlyContinue
    Check ($process.HasExited) 'dispatch exits after invoking the isolated host'
    Check ([IO.File]::Exists($response)) 'dispatch writes a response file'
    return [IO.File]::ReadAllText($response, [Text.Encoding]::UTF8) | ConvertFrom-Json
}
try {
    $waitFile = Join-Path $temp 'wait.json'
    [IO.File]::WriteAllText($waitFile, '{"version":1,"action":"run","slot":6}', (New-Object Text.UTF8Encoding($false)))
    $waitResult = Invoke-WaitReader $waitFile 1
    Check ($waitResult -match '"action"\s*:\s*"run"' -and $waitResult -match '"slot"\s*:\s*6') 'wait reader returns the completed response'
    $pending = Invoke-WaitReader (Join-Path $temp 'missing.json') 1
    Check ($pending -match '"pending"\s*:\s*true') 'wait reader is bounded and reports pending'

    $run = Invoke-Wheel @(0x28, 0x28, 0x0D)
    Check ($run.action -eq 'run' -and $run.profile -eq 0 -and $run.slot -eq 6) 'two Down key events then Enter select the second stable slot'
    $switched = Invoke-Wheel @(0xC0, 0x28, 0x0D)
    Check ($switched.action -eq 'run' -and $switched.profile -eq 1 -and $switched.slot -eq 10) 'grave accent switches profile before selection'
    $cancel = Invoke-Wheel @(0x1B)
    Check ($cancel.action -eq 'cancel') 'Escape cancels without running a slot'

    $motion = New-WheelForm $false
    try {
        Invoke-Private $motion 'Pick' @(0)
        Check ((Field $motion 'motionTimer').Enabled) 'hover starts the shared motion timer'
        Set-Field $motion 'hoverStart' ([DateTime]::UtcNow.AddSeconds(-1))
        Invoke-Private $motion 'AdvanceMotion'
        Check ((Field $motion 'hover')[0] -eq 1 -and -not (Field $motion 'motionTimer').Enabled) 'hover reaches exact rest and stops'
        Invoke-Private $motion 'Press' @(0)
        Set-Field $motion 'pressStart' ([DateTime]::UtcNow.AddSeconds(-1))
        Invoke-Private $motion 'AdvanceMotion'
        Check ((Field $motion 'press')[0] -eq 1 -and -not (Field $motion 'motionTimer').Enabled) 'press reaches exact rest and stops'
        Invoke-Private $motion 'RunSelection' @($true)
        Check ($motion.ResponseWritten -and [IO.File]::Exists($motion.ResponsePath)) 'response is written before the close animation'
        Check ((Field $motion 'closeTimer').Enabled) 'pointer close starts the per-slice close timer'
        Set-Field $motion 'closeStart' ([DateTime]::UtcNow.AddSeconds(-1))
        Invoke-Private $motion 'AdvanceClose'
        Check (-not (Field $motion 'closeTimer').Enabled) 'close reaches completion and stops its timer'
        Check (((Field $motion 'closeValues') | Measure-Object -Sum).Sum -eq 0) 'all slices finish at exact zero opacity'
    } finally { $motion.Dispose() }
    $static = New-WheelForm $true
    try {
        Invoke-Private $static 'Pick' @(0)
        Check (-not (Field $static 'motionTimer').Enabled) 'reduced motion does not start hover animation'
        Invoke-Private $static 'RunSelection' @($true)
        Check (-not (Field $static 'closeTimer').Enabled) 'reduced motion closes without a close timer'
        Check ([IO.File]::Exists($static.ResponsePath)) 'reduced motion still writes the selection response'
    } finally { $static.Dispose() }

    $fakeSource = Join-Path $root 'tests/windows/FakeCavalry.cs'
    $fakeExe = Join-Path $temp 'Cavalry.exe'
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    & $compiler /nologo /target:winexe /out:$fakeExe $fakeSource | Out-Null
    Check ($LASTEXITCODE -eq 0) 'isolated Cavalry.exe host compiles'
    $scriptsRoot = Join-Path $temp 'Scripts'
    New-Item -ItemType Directory -Path $scriptsRoot | Out-Null
    [IO.File]::WriteAllText((Join-Path $scriptsRoot 'CavalryToolbar.js'), '// isolated no-op', (New-Object Text.UTF8Encoding($false)))
    $fake = Start-Process -FilePath $fakeExe -WorkingDirectory $scriptsRoot -PassThru
    try {
        Start-Sleep -Milliseconds 900
        $installed = Invoke-Dispatch $fake.Id (Join-Path $scriptsRoot 'CavalryToolbar.js')
        Check ($installed.action -eq 'ui-dispatch' -and $installed.status -eq 'menu-invoked') 'installed UI target invokes the exact isolated host menu'
        $receipt = Join-Path ([IO.Path]::GetTempPath()) 'CavalryWheel-qa-receipt.json'
        Check (([IO.File]::ReadAllText($receipt)) -eq 'CavalryToolbar') 'the isolated host clicked CavalryToolbar'
        $external = Join-Path $temp 'External Panel.js'
        [IO.File]::WriteAllText($external, '// external no-op', (New-Object Text.UTF8Encoding($false)))
        $externalResult = Invoke-Dispatch $fake.Id $external
        Check ($externalResult.status -eq 'evaluated') 'external JS relay reports evaluated after the isolated receipt'
        Check (([IO.File]::ReadAllText($receipt)).StartsWith('CavalryToolbar_UIDispatch_')) 'the isolated host clicked the generated external relay'
        Check ((Get-ChildItem -LiteralPath $scriptsRoot -Filter 'CavalryToolbar_UIDispatch_*.js').Count -eq 0) 'external relay is removed after dispatch'
        $unknown = Invoke-Dispatch 999999 $external
        Check ($unknown.status -eq 'error') 'unknown PID never dispatches to another host'
        $encrypted = Join-Path $temp 'Encrypted.jsc'
        [IO.File]::WriteAllText($encrypted, 'encrypted placeholder', (New-Object Text.UTF8Encoding($false)))
        $jsc = Invoke-Dispatch $fake.Id $encrypted
        Check ($jsc.status -eq 'unsupported-external-jsc') 'external encrypted JSC fails closed without source relay'
    } finally {
        if (-not $fake.HasExited) { $fake.Kill() }
    }
    Write-Output "PASS: $script:checks native Windows WinForms, motion, and UI Automation assertions on $env:COMPUTERNAME"
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path ([IO.Path]::GetTempPath()) 'CavalryWheel-qa-receipt.json') -Force -ErrorAction SilentlyContinue
}
