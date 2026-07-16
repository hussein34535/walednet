$tempDir = "D:\sing_box_temp_build"
if (!(Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}

# Use system Go (1.25+) and isolate GOPATH/GOMODCACHE
$env:GOPATH = "$tempDir\gopath"
$env:GOMODCACHE = "$tempDir\pkg-mod"

Write-Host "Current Go version in build session:" -ForegroundColor Green
go version

$singBoxDir = "$tempDir\sing-box"
if (Test-Path $singBoxDir) {
    Remove-Item -Recurse -Force $singBoxDir
}

Write-Host "Cloning Hiddify sing-box fork (with dnstt outbound support)..." -ForegroundColor Green
git clone --depth 1 -b extended https://github.com/hiddify/hiddify-sing-box.git $singBoxDir 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "Git clone failed!" -ForegroundColor Red
    Exit 1
}

Write-Host "Initializing submodules (replace/ overrides)..." -ForegroundColor Green
Set-Location -LiteralPath $singBoxDir
git submodule update --init --recursive --depth 1 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "Git submodule update failed!" -ForegroundColor Red
    Exit 1
}

Write-Host "Configuring Go and Git environment variables..." -ForegroundColor Green
$env:GOPROXY = "https://proxy.golang.org,direct"
$env:GIT_TERMINAL_PROMPT = "0"

# Set Android NDK Home
$env:ANDROID_NDK_HOME = "C:\Users\husso\AppData\Local\Android\Sdk\ndk\29.0.13113456"
$env:GOTOOLCHAIN = "local"

# Hiddify fork uses go 1.25.6+

Write-Host "Installing gomobile tools..." -ForegroundColor Green
# Use latest gomobile; Go auto-resolves to compatible version
go install golang.org/x/mobile/cmd/gomobile@latest 2>&1
go install golang.org/x/mobile/cmd/gobind@latest 2>&1

# Add Go bin to PATH
$goBin = "$env:GOPATH\bin"
$env:PATH = "$env:PATH;$goBin"

Write-Host "Initializing gomobile..." -ForegroundColor Green
gomobile init 2>&1

Write-Host "Adding mobile tool dependency to module..." -ForegroundColor Green
Set-Location -LiteralPath $singBoxDir
go get -tool golang.org/x/mobile/cmd/gobind 2>&1

Write-Host "Compiling libbox.aar with dnstt (SlowDNS) support..." -ForegroundColor Green
gomobile bind -v -androidapi 21 -tags "with_gvisor,with_dhcp,with_wireguard,with_utls,with_clash_api,with_quic,with_dnstt" -target=android -ldflags="-checklinkname=0" -o "$tempDir\libbox.aar" ./experimental/libbox

if ($LASTEXITCODE -ne 0) {
    Write-Host "gomobile bind failed! Check compiler logs..." -ForegroundColor Red
    Exit 1
}

Write-Host "Successfully compiled libbox.aar!" -ForegroundColor Green
Write-Host "Copying new libbox.aar to project libs directory..." -ForegroundColor Green
Copy-Item -Path "$tempDir\libbox.aar" -Destination "D:\WALEDNET\android\app\libs\libbox.aar" -Force

Write-Host "Done! Compiled successfully on Go $(go version)!" -ForegroundColor Green
