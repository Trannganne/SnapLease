$url = "http://localhost:5000"

# 1. Test quantity <= 0 (expect bad request)
Write-Host "Test 1: soLuong = 0"
try {
  Invoke-RestMethod "$url/api/tam-tinh?maCuaHang=CH001&maDongMay=DM001&soLuong=0&ngayBatDau=2024-05-01&ngayKetThuc=2024-05-05" -Method Get
} catch {
  Write-Host $_.Exception.Message
}

# 2. Test branch/device not exist (expect not found)
Write-Host "Test 2: device DM999"
try {
  Invoke-RestMethod "$url/api/tam-tinh?maCuaHang=CH001&maDongMay=DM999&soLuong=1&ngayBatDau=2024-05-01&ngayKetThuc=2024-05-05" -Method Get
} catch {
  Write-Host $_.Exception.Message
}

# 3. Test invalid date range (> 90 days)
Write-Host "Test 3: > 90 days"
try {
  Invoke-RestMethod "$url/api/tam-tinh?maCuaHang=CH001&maDongMay=DM001&soLuong=1&ngayBatDau=2024-05-01&ngayKetThuc=2024-09-01" -Method Get
} catch {
  Write-Host $_.Exception.Message
}

# 4. Test normal quote
Write-Host "Test 4: Normal Quote"
Invoke-RestMethod "$url/api/tam-tinh?maCuaHang=CH001&maDongMay=DM001&soLuong=2&ngayBatDau=2024-05-01T10:00:00&ngayKetThuc=2024-05-03T10:00:00" -Method Get | ConvertTo-Json

# 5. Test availability
Write-Host "Test 5: Availability"
Invoke-RestMethod "$url/api/lich-trong?maCuaHang=CH001&maDongMay=DM001&ngayBatDau=2024-05-01T10:00:00&ngayKetThuc=2024-05-03T10:00:00" -Method Get | ConvertTo-Json
