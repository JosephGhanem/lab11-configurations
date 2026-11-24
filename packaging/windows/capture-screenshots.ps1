$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing, System.Windows.Forms, UIAutomationClient, UIAutomationTypes

$build = (Resolve-Path build).Path
$output = Join-Path $build 'windows-screenshots'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$package = Join-Path $build 'helloworld_Joseph_Ghanem.msi'
$ws = New-Object -ComObject WScript.Shell

function Save-Screen([string]$Name) {
    $bounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size)
        $bitmap.Save((Join-Path $output "$Name.png"), [Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function Find-UI([System.Windows.Automation.AutomationElement]$Parent, [string]$Name, [switch]$Children) {
    $condition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NameProperty, $Name)
    $scope = if ($Children) { 'Children' } else { 'Descendants' }
    $Parent.FindFirst($scope, $condition)
}

function Wait-For([scriptblock]$Probe, [string]$Description) {
    for ($attempt = 0; $attempt -lt 24; $attempt++) {
        $item = & $Probe
        if ($item) { return $item }
        Start-Sleep -Milliseconds 500
    }
    throw "Timed out waiting for $Description"
}

function Show-Console([string]$Title, [string]$Commands, [string]$ImageName) {
    $script = Join-Path $build "$ImageName.ps1"
    $done = Join-Path $build "$ImageName.done"
    @(
        '$ErrorActionPreference = "Stop"'
        '$host.UI.RawUI.WindowTitle = ' + "'$Title'"
        $Commands
        "New-Item -ItemType File -Force -Path '$done' | Out-Null"
    ) | Set-Content -Encoding UTF8 -Path $script
    $process = Start-Process powershell.exe -ArgumentList "-NoProfile -NoExit -ExecutionPolicy Bypass -File `"$script`"" -PassThru
    try {
        $null = Wait-For { Test-Path $done } "$Title to finish"
        $null = $ws.AppActivate($Title)
        Start-Sleep -Milliseconds 500
        Save-Screen $ImageName
    } finally {
        Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
    }
}

Write-Host "Windows session: $([Diagnostics.Process]::GetCurrentProcess().SessionId)"
Write-Host "Desktop: $([Windows.Forms.Screen]::PrimaryScreen.Bounds)"

$env:LAB_MSI = $package
Show-Console 'Lab 11 - Released MSI package properties' @'
Write-Host 'Windows Installer database properties'
Write-Host (Split-Path -Leaf $env:LAB_MSI)
$installer = New-Object -ComObject WindowsInstaller.Installer
$db = $installer.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $installer, @($env:LAB_MSI, 0))
$query = 'SELECT `Property`, `Value` FROM `Property`'
$view = $db.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $db, @($query))
$null = $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null)
while ($record = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)) {
    $name = $record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, @(1))
    if ($name -in @('ProductName','ProductVersion','Manufacturer','ProductCode','UpgradeCode','ProductLanguage','ALLUSERS')) {
        $value = $record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, @(2))
        Write-Host ('{0,-18} {1}' -f $name, $value)
    }
}
'@ 'windows-msi-properties'

$root = [System.Windows.Automation.AutomationElement]::RootElement
$product = 'Hello World - Joseph Ghanem'
$installer = Start-Process msiexec.exe -ArgumentList "/i `"$package`" /qb+ /norestart" -PassThru
try {
    $dialog = Wait-For {
        $candidate = Find-UI $root $product -Children
        if ($candidate -and (Find-UI $candidate 'OK')) { $candidate }
    } 'the Windows Installer completion dialog'
    $null = $ws.AppActivate($product)
    Save-Screen 'windows-msi-installation'
    $ws.SendKeys('{ENTER}')
    if (!$installer.WaitForExit(12000) -or $installer.ExitCode -ne 0) {
        throw 'Windows Installer did not exit successfully'
    }
} finally {
    if (!$installer.HasExited) { Stop-Process -Id $installer.Id }
}

Write-Host 'Windows Installer completed successfully.'
Start-Process control.exe -ArgumentList 'appwiz.cpl'
$panel = Wait-For { Find-UI $root 'Programs and Features' -Children } 'Programs and Features'
Write-Host 'Programs and Features opened.'
$entry = Wait-For { Find-UI $panel $product } 'the Hello World entry in Programs and Features'
$pattern = $null
if ($entry.TryGetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern, [ref]$pattern)) {
    $pattern.ScrollIntoView()
}
$pattern = $null
if ($entry.TryGetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern, [ref]$pattern)) {
    $pattern.Select()
}
$null = $ws.AppActivate('Programs and Features')
Start-Sleep -Milliseconds 500
Save-Screen 'windows-installed-apps'

Show-Console 'Lab 11 - Run the installed application' @'
Write-Host 'Running the executable installed by the MSI'
$exe = Join-Path $env:ProgramFiles 'HelloWorld\helloworld.exe'
Write-Host $exe
$greeting = & $exe
if ($LASTEXITCODE -ne 0 -or $greeting -cne 'Hello, World from Joseph_Ghanem!') { throw 'Unexpected output' }
Write-Host $greeting
'@ 'windows-application-run'

$zip = Join-Path $build 'wix.zip'
curl.exe --fail --location --silent --show-error --output $zip https://github.com/wixtoolset/wix3/releases/download/wix3141rtm/wix314-binaries.zip
if ($LASTEXITCODE -ne 0 -or (Get-FileHash $zip).Hash -ne '6ac824e1642d6f7277d0ed7ea09411a508f6116ba6fae0aa5f2c7daa2ff43d31') {
    throw 'WiX Toolset download failed verification'
}
$env:LAB_WIX = Join-Path $build 'wix'
Expand-Archive -Path $zip -DestinationPath $env:LAB_WIX -Force
Copy-Item (Join-Path $env:ProgramFiles 'HelloWorld\helloworld.exe') (Join-Path $build 'helloworld.exe')
Show-Console 'Lab 11 - WiX Toolset build on Windows' @'
Write-Host 'WiX Toolset rebuild using the same installer source and executable'
Write-Host '> candle.exe -arch x64 -out build\helloworld.wixobj helloworld.wxs'
& (Join-Path $env:LAB_WIX 'candle.exe') -arch x64 -out build\helloworld.wixobj helloworld.wxs
if ($LASTEXITCODE -ne 0) { throw 'WiX compilation failed' }
Write-Host '> light.exe -out build\wix-rebuild\helloworld_Joseph_Ghanem.msi build\helloworld.wixobj'
New-Item -ItemType Directory -Force build\wix-rebuild | Out-Null
& (Join-Path $env:LAB_WIX 'light.exe') -out build\wix-rebuild\helloworld_Joseph_Ghanem.msi build\helloworld.wixobj
if ($LASTEXITCODE -ne 0) { throw 'WiX linking failed' }
Get-Item build\wix-rebuild\helloworld_Joseph_Ghanem.msi | Format-Table Name, Length
'@ 'windows-wix-build'
