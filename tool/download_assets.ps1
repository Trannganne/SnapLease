# These are original Figma asset URLs, retrieved 2026-09-18. They expire.
# If download fails, export the three nodes listed in assets/images/README.txt.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$assets = @{
  'camera.png' = 'https://www.figma.com/api/mcp/asset/3ebbdae5-9b9e-4edb-8ed3-ff8651bc18a2.png'
  'lens.png' = 'https://www.figma.com/api/mcp/asset/e4de8e38-c48e-4722-9f38-ac06de17335c.png'
  'banner.png' = 'https://www.figma.com/api/mcp/asset/fe5cd971-f24c-49a9-af02-ac3071689564.png'
}
foreach ($entry in $assets.GetEnumerator()) {
  $destination = Join-Path $root ('assets/images/' + $entry.Key)
  if (Test-Path $destination) { Write-Host ('Da co: ' + $entry.Key); continue }
  $temporary = $destination + '.part'
  try {
    Invoke-WebRequest -Uri $entry.Value -OutFile $temporary -TimeoutSec 30
    $bytes = [IO.File]::ReadAllBytes($temporary)
    if ($bytes.Length -lt 8 -or $bytes[0] -ne 137 -or $bytes[1] -ne 80 -or $bytes[2] -ne 78 -or $bytes[3] -ne 71) {
      throw 'Phan hoi khong phai anh PNG.'
    }
    Move-Item $temporary $destination
    Write-Host ('Da tai: ' + $entry.Key)
  } catch {
    if (Test-Path $temporary) { Remove-Item $temporary }
    Write-Warning ('Chua tai duoc ' + $entry.Key + '. Hay export tu Figma theo README.')
  }
}
