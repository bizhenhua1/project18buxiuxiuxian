param([switch]$World)
$ErrorActionPreference = 'Stop'
$webPreviewUrl = 'http://127.0.0.1:8000/'
$webPreviewRunning = $false
try {
    $webPreviewCheck = Invoke-WebRequest ($webPreviewUrl + 'world-demo.html') -TimeoutSec 2
    $webPreviewRunning = $webPreviewCheck.Content.Contains('world-fog.js')
    if (-not $webPreviewRunning) { throw 'Port 8000 belongs to another application.' }
} catch {
    if (Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue) {
        throw 'Port 8000 is occupied by a different application; it was left untouched.'
    }
}
if (-not $webPreviewRunning) {
    $webPreviewPython = Get-Command python.exe -ErrorAction SilentlyContinue
    if (-not $webPreviewPython) { throw 'Python is required to run the original web demo.' }
    Start-Process -FilePath $webPreviewPython.Source -ArgumentList @('-m','http.server','8000','--bind','127.0.0.1','--directory',('"'+$PSScriptRoot+'"')) -WindowStyle Hidden
    for ($attempt=0; $attempt -lt 30; $attempt++) {
        try { $null = Invoke-WebRequest ($webPreviewUrl+'world-demo.html') -TimeoutSec 1; break }
        catch { Start-Sleep -Milliseconds 100 }
    }
}
Start-Process ($webPreviewUrl + $(if ($World) { 'world-demo.html' } else { 'index.html' }))
