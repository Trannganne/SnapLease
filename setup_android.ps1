$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Khong tim thay flutter. Hay them Flutter SDK vao PATH truoc.'
}
$spec = Get-Content pubspec.yaml -Raw
$lint = Get-Content analysis_options.yaml -Raw
try {
  & flutter create --platforms=android --project-name=rentcam --org=vn.rentcam --no-pub .
  if ($LASTEXITCODE -ne 0) { throw 'flutter create that bai.' }
} finally {
  [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'pubspec.yaml'), $spec, [Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'analysis_options.yaml'), $lint, [Text.UTF8Encoding]::new($false))
}
$manifest = Join-Path $PSScriptRoot 'android/app/src/main/AndroidManifest.xml'
$content = (Get-Content $manifest -Raw) -replace 'android:label="rentcam"', 'android:label="RentCam"'
[IO.File]::WriteAllText($manifest, $content, [Text.UTF8Encoding]::new($false))
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get that bai.' }
Write-Host 'Da tao Android project. Chay: flutter analyze; flutter test; flutter run'
Write-Host 'Anh Figma: xem assets/images/README.txt va tool/download_assets.ps1'
