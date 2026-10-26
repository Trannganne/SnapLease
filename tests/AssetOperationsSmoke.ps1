param([string]$BaseUrl = "http://localhost:5000")

$ErrorActionPreference = "Stop"
$suffix = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
$username = "asset_smoke_$suffix"
$password = "SmokeTest@2026"
$phone = "08" + $suffix.Substring($suffix.Length - 8)
$accountId = $null
$customerId = $null
$branch1 = $null
$modelId = $null
$deviceId = $null
$maintenanceId = $null
$damageId = $null

function Invoke-Api {
    param([string]$Method, [string]$Path, $Body = $null, [string]$Token = "")
    $headers = @{}
    if ($Token) { $headers.Authorization = "Bearer $Token" }
    $args = @{
        Method = $Method
        Uri = "$BaseUrl$Path"
        Headers = $headers
        UseBasicParsing = $true
    }
    if ($null -ne $Body) {
        $args.ContentType = "application/json; charset=utf-8"
        $json = $Body | ConvertTo-Json -Depth 8 -Compress
        $args.Body = [Text.Encoding]::UTF8.GetBytes($json)
    }
    try {
        Invoke-RestMethod @args
    }
    catch {
        $detail = $_.ErrorDetails.Message
        if (-not $detail -and $_.Exception.Response) {
            $reader = [IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            try { $detail = $reader.ReadToEnd() } finally { $reader.Dispose() }
        }
        if (-not $detail) { $detail = $_.Exception.Message }
        throw "$Method $Path failed: $detail"
    }
}

function Invoke-ContainerSql([string]$Query) {
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Query))
    docker exec -e "SQL_QUERY_B64=$encoded" rentalcamera-sql /bin/bash -c `
        'printf "%s" "$SQL_QUERY_B64" | base64 -d | /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -I -b -V 16 -d RentalCameraDb20 -i /dev/stdin' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "SQL command failed." }
}

function Check([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAILED: $Name" }
    Write-Host "PASS $Name"
}

try {
    $registered = Invoke-Api POST "/api/auth/register" @{
        tenDangNhap = $username
        matKhau = $password
        soDienThoai = $phone
        email = "$username@example.test"
    }
    $accountId = $registered.maTaiKhoan
    $customerId = $registered.maKhachThue
    Invoke-ContainerSql "UPDATE dbo.TaiKhoan SET VaiTro='ADMIN' WHERE MaTaiKhoan='$accountId';"

    $login = Invoke-Api POST "/api/auth/login" @{ tenDangNhap = $username; matKhau = $password }
    $token = $login.accessToken
    Check ($login.vaiTro -eq "ADMIN") "synthetic account promoted to admin"

    $category = (Invoke-Api GET "/api/danh-muc")[0]
    $brand = (Invoke-Api GET "/api/thuong-hieu")[0]
    Check ($null -ne $category -and $null -ne $brand) "catalog fixture available"

    $branch1Result = Invoke-Api POST "/api/cua-hang" @{
        tenCuaHang = "Smoke Branch A $suffix"
        diaChi = "1 Test Street"
        soDienThoai = "09" + $suffix.Substring($suffix.Length - 8)
        email = "branch-a-$suffix@example.test"
        moTa = "Synthetic smoke-test branch"
    } $token
    $branch1 = $branch1Result.maCuaHang
    Check ($null -ne $branch1) "create branch"

    $model = Invoke-Api POST "/api/dong-may" @{
        maDanhMuc = $category.maDanhMuc
        maThuongHieu = $brand.maThuongHieu
        tenDongMay = "Smoke Model $suffix"
        moTa = "Synthetic smoke-test model"
        giaThueNgay = 100000
        tienCoc = 500000
        phanTramGiamGia = 0
    } $token
    $modelId = $model.maDongMay
    $stopped = Invoke-Api PUT "/api/dong-may/$modelId/trang-thai" @{ trangThai = "NGUNG_KINH_DOANH" } $token
    Check ($stopped.trangThai -eq "NGUNG_KINH_DOANH") "stop a model without deleting history"
    $active = Invoke-Api PUT "/api/dong-may/$modelId/trang-thai" @{ trangThai = "HOAT_DONG" } $token
    Check ($active.trangThai -eq "HOAT_DONG") "reactivate a model"

    $device = Invoke-Api POST "/api/thiet-bi" @{
        maDongMay = $modelId
        maCuaHang = $branch1
        soSerial = "SMOKE-$suffix"
        tinhTrang = "Mới"
        trangThai = "SAN_SANG"
        ngayNhap = $null
    } $token
    $deviceId = $device.maThietBi
    Check ($device.trangThai -eq "SAN_SANG") "create physical device"

    $maintenance = Invoke-Api POST "/api/bao-tri" @{
        maThietBi = $deviceId
        moTaLoi = "Smoke-test maintenance"
        chiPhiDuKien = 150000
        ghiChu = "Synthetic record"
    } $token
    $maintenanceId = $maintenance.maPhieuBaoTri
    Check ($maintenance.trangThai -eq "MOI_TAO") "create maintenance ticket"
    $maintenance = Invoke-Api PUT "/api/bao-tri/$maintenanceId" @{
        moTaLoi = "Smoke-test maintenance in progress"
        trangThai = "DANG_XU_LY"
        chiPhiDuKien = 175000
        ghiChu = "Started"
    } $token
    Check ($maintenance.trangThai -eq "DANG_XU_LY") "start maintenance"

    $damage = Invoke-Api POST "/api/thiet-bi/$deviceId/hu-hong" @{
        moTa = "Synthetic damaged shutter"
        mucDo = "TRUNG_BINH"
        chiPhiSuaChua = 175000
        maPhieuBaoTri = $maintenanceId
    } $token
    $damageId = $damage.maHuHong
    $damage = Invoke-Api PUT "/api/hu-hong/$damageId" @{
        trangThai = "DA_SUA"
        chiPhiSuaChua = 180000
        tinhTrangSauSuaChua = "Hoạt động ổn định"
        ghiChu = "Smoke-test completed"
    } $token
    Check ($damage.trangThai -eq "DA_SUA" -and $damage.chiPhiSuaChua -eq 180000) "update damage cost and status"

    $completed = Invoke-Api PUT "/api/bao-tri/$maintenanceId/hoan-tat" @{
        chiPhiThucTe = 180000
        trangThaiThietBi = "SAN_SANG"
        tinhTrangThietBi = "Tốt"
        ghiChu = "Smoke-test completed"
    } $token
    Check ($completed.phieu.trangThai -eq "HOAN_TAT" -and $completed.trangThai -eq "SAN_SANG") "complete maintenance"

    $damageHistory = Invoke-Api GET "/api/thiet-bi/$deviceId/hu-hong" $null $token
    Check ($damageHistory[0].lichSu.Count -eq 1) "persist damage update history"
}
finally {
    if ($accountId) {
        $ids = @($damageId, $maintenanceId, $deviceId, $modelId, $branch1, $customerId, $accountId) |
            ForEach-Object { if ($_ -and $_ -notmatch "^[A-Za-z0-9]+$") { throw "Unsafe cleanup id." }; $_ }
        $cleanup = @"
DELETE FROM dbo.NhatKyHeThong WHERE MaTaiKhoan='$accountId';
DELETE FROM dbo.LichSuCapNhatHuHong WHERE MaHuHong='$damageId';
DELETE FROM dbo.HuHongThietBi WHERE MaHuHong='$damageId';
DELETE FROM dbo.PhieuBaoTri WHERE MaPhieuBaoTri='$maintenanceId';
DELETE FROM dbo.ThietBi WHERE MaThietBi='$deviceId';
DELETE FROM dbo.DongMay WHERE MaDongMay='$modelId';
DELETE FROM dbo.CuaHang WHERE MaCuaHang='$branch1';
DELETE FROM dbo.KhachThue WHERE MaKhachThue='$customerId';
DELETE FROM dbo.TaiKhoan WHERE MaTaiKhoan='$accountId';
"@
        Invoke-ContainerSql ($cleanup -replace "`r?`n", " ")
    }
}
