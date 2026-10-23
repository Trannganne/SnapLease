param([string]$BaseUrl = "http://localhost:5000")

$ErrorActionPreference = "Stop"
$suffix = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
$password = "SmokeTest@2026"
$customerUser = "customer_smoke_$suffix"
$adminUser = "customer_admin_$suffix"
$customerAccountId = $null
$adminAccountId = $null
$customerId = $null

function Invoke-Api {
    param([string]$Method, [string]$Path, $Body = $null, [string]$Token = "")
    $headers = @{}
    if ($Token) { $headers.Authorization = "Bearer $Token" }
    $args = @{ Method=$Method; Uri="$BaseUrl$Path"; Headers=$headers; UseBasicParsing=$true; TimeoutSec=30 }
    if ($null -ne $Body) {
        $args.ContentType = "application/json; charset=utf-8"
        $args.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 8 -Compress))
    }
    try { Invoke-RestMethod @args }
    catch {
        $detail = $_.ErrorDetails.Message
        if (-not $detail) { $detail = $_.Exception.Message }
        throw "$Method $Path failed: $detail"
    }
}

function Check([bool]$condition, [string]$name) {
    if (-not $condition) { throw "FAILED: $name" }
    Write-Host "PASS $name"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$passwordLine = Get-Content (Join-Path $repoRoot ".env") |
    Where-Object { $_ -match '^MSSQL_SA_PASSWORD=' } | Select-Object -First 1
$sqlPassword = $passwordLine.Substring($passwordLine.IndexOf('=') + 1).Trim().Trim('"').Trim("'")

function Invoke-Sql([string]$query) {
    $connection = [System.Data.SqlClient.SqlConnection]::new(
        "Server=localhost,14330;Database=RentalCameraDb20;User Id=sa;Password=$sqlPassword;Encrypt=True;TrustServerCertificate=True;Connect Timeout=10")
    try {
        $connection.Open(); $command = $connection.CreateCommand(); $command.CommandTimeout = 30
        $command.CommandText = $query; [void]$command.ExecuteNonQuery()
    } finally { $connection.Dispose() }
}

$cartReview = "GCR$suffix"; $holdReview = "GHR$suffix"; $contractReview = "HDR$suffix"
$detailReview = "CTR$suffix"; $deviceReview = "TBR$suffix"
$cartDue = "GCD$suffix"; $holdDue = "GHD$suffix"; $contractDue = "HDD$suffix"
$detailDue = "CTD$suffix"; $deviceDue = "TBD$suffix"
$cartPrep = "GCP$suffix"; $cartLinePrep = "CGP$suffix"; $holdPrep = "GHP$suffix"
$holdLinePrep = "CHP$suffix"; $contractPrep = "HDP$suffix"; $devicePrep = "TBP$suffix"
$reviewId = $null

try {
    Check ((Invoke-Api GET "/api/health").status -eq "ok") "API health"
    $customer = Invoke-Api POST "/api/auth/register" @{
        tenDangNhap=$customerUser; matKhau=$password; soDienThoai=("06" + $suffix.Substring($suffix.Length - 8)); email="$customerUser@example.test"
    }
    $admin = Invoke-Api POST "/api/auth/register" @{
        tenDangNhap=$adminUser; matKhau=$password; soDienThoai=("07" + $suffix.Substring($suffix.Length - 8)); email="$adminUser@example.test"
    }
    $customerAccountId = $customer.maTaiKhoan; $customerId = $customer.maKhachThue
    $adminAccountId = $admin.maTaiKhoan
    Invoke-Sql "UPDATE dbo.TaiKhoan SET VaiTro='ADMIN' WHERE MaTaiKhoan='$adminAccountId';"

    $fixture = @"
DECLARE @branch VARCHAR(20)=(SELECT TOP 1 MaCuaHang FROM dbo.CuaHang WHERE TrangThai='HOAT_DONG' ORDER BY MaCuaHang);
DECLARE @model VARCHAR(20)=(SELECT TOP 1 MaDongMay FROM dbo.DongMay WHERE TrangThai='HOAT_DONG' ORDER BY GiaThueNgay,MaDongMay);
DECLARE @price DECIMAL(18,2)=(SELECT GiaThueNgay FROM dbo.DongMay WHERE MaDongMay=@model);
DECLARE @deposit DECIMAL(18,2)=(SELECT TienCoc FROM dbo.DongMay WHERE MaDongMay=@model);
IF @branch IS NULL OR @model IS NULL THROW 50001, 'Missing branch or model fixture.', 1;
INSERT dbo.ThietBi(MaThietBi,MaDongMay,MaCuaHang,SoSerial,TinhTrang,TrangThai,NgayNhap) VALUES
('$deviceReview',@model,@branch,'SER-$deviceReview',N'Tốt','SAN_SANG',CAST(SYSDATETIME() AS date)),
('$deviceDue',@model,@branch,'SER-$deviceDue',N'Tốt','DANG_THUE',CAST(SYSDATETIME() AS date)),
('$devicePrep',@model,@branch,'SER-$devicePrep',N'Tốt','SAN_SANG',CAST(SYSDATETIME() AS date));
INSERT dbo.GioHang(MaGioHang,MaKhachThue,NgayTao,NgayCapNhat,TrangThai) VALUES
('$cartReview','$customerId',SYSDATETIME(),SYSDATETIME(),'DA_CHUYEN_HOP_DONG'),
('$cartDue','$customerId',SYSDATETIME(),SYSDATETIME(),'DA_CHUYEN_HOP_DONG'),
('$cartPrep','$customerId',SYSDATETIME(),SYSDATETIME(),'DA_CHUYEN_HOP_DONG');
INSERT dbo.ChiTietGioHang(MaChiTietGioHang,MaGioHang,MaDongMay,SoLuong,NgayBatDau,NgayKetThuc,DonGia,TienCoc,ThanhTien,MaCuaHang,NguonTao)
VALUES('$cartLinePrep','$cartPrep',@model,1,DATEADD(DAY,1,SYSDATETIME()),DATEADD(DAY,3,SYSDATETIME()),@price,@deposit,@price*2,@branch,'THUE_NGAY');
INSERT dbo.GiuCho(MaGiuCho,MaGioHang,MaKhachThue,MaCuaHang,NgayTao,HetHanLuc,TrangThai) VALUES
('$holdReview','$cartReview','$customerId',@branch,DATEADD(DAY,-8,SYSDATETIME()),DATEADD(DAY,-7,SYSDATETIME()),'DA_CHUYEN_HOP_DONG'),
('$holdDue','$cartDue','$customerId',@branch,DATEADD(DAY,-3,SYSDATETIME()),DATEADD(DAY,-2,SYSDATETIME()),'DA_CHUYEN_HOP_DONG'),
('$holdPrep','$cartPrep','$customerId',@branch,SYSDATETIME(),DATEADD(HOUR,1,SYSDATETIME()),'DA_CHUYEN_HOP_DONG');
INSERT dbo.ChiTietGiuCho(MaChiTietGiuCho,MaGiuCho,MaDongMay,SoLuong,NgayBatDau,NgayKetThuc,MaChiTietGioHang)
VALUES('$holdLinePrep','$holdPrep',@model,1,DATEADD(DAY,1,SYSDATETIME()),DATEADD(DAY,3,SYSDATETIME()),'$cartLinePrep');
INSERT dbo.HopDong(MaHopDong,MaGioHang,MaGiuCho,MaKhachThue,MaNhanVien,MaCuaHang,NgayTaoHopDong,NgayKy,ThoiGianBanGiao,ThoiGianTraDuKien,TongTien,TongTienCoc,HinhThucKy,TrangThai,TepHopDongUrl,DaDongYDieuKhoan) VALUES
('$contractReview','$cartReview','$holdReview','$customerId',NULL,@branch,DATEADD(DAY,-8,SYSDATETIME()),DATEADD(DAY,-8,SYSDATETIME()),DATEADD(DAY,-7,SYSDATETIME()),DATEADD(DAY,-5,SYSDATETIME()),@price*2,@deposit,'DIEN_TU','HOAN_THANH',NULL,1),
('$contractDue','$cartDue','$holdDue','$customerId',NULL,@branch,DATEADD(DAY,-3,SYSDATETIME()),DATEADD(DAY,-3,SYSDATETIME()),DATEADD(DAY,-2,SYSDATETIME()),DATEADD(HOUR,1,SYSDATETIME()),@price*2,@deposit,'DIEN_TU','DANG_THUE',NULL,1),
('$contractPrep','$cartPrep','$holdPrep','$customerId',NULL,@branch,SYSDATETIME(),SYSDATETIME(),DATEADD(DAY,1,SYSDATETIME()),DATEADD(DAY,3,SYSDATETIME()),@price*2,@deposit,'DIEN_TU','DA_KY',NULL,1);
INSERT dbo.ChiTietHopDong(MaChiTietHopDong,MaHopDong,MaThietBi,DonGia,TinhTrangLucGiao,NgayGiaoThucTe,NgayNhanThucTe,CoHuHong) VALUES
('$detailReview','$contractReview','$deviceReview',@price,N'Tốt',DATEADD(DAY,-7,SYSDATETIME()),DATEADD(DAY,-5,SYSDATETIME()),0),
('$detailDue','$contractDue','$deviceDue',@price,N'Tốt',DATEADD(DAY,-2,SYSDATETIME()),NULL,0);
"@
    Invoke-Sql ($fixture -replace "`r?`n", " ")

    $customerToken = (Invoke-Api POST "/api/auth/login" @{ tenDangNhap=$customerUser; matKhau=$password }).accessToken
    $adminToken = (Invoke-Api POST "/api/auth/login" @{ tenDangNhap=$adminUser; matKhau=$password }).accessToken

    $profile = Invoke-Api PUT "/api/khach-thue/cua-toi" @{
        hoTen="Khach Smoke"; soDienThoai=("08" + $suffix.Substring($suffix.Length - 8)); email="$customerUser.updated@example.test"
        diaChi="123 Smoke"; ngaySinh="2000-01-02"; gioiTinh="NAM"; quocTich="Viet Nam"
    } $customerToken
    Check ($profile.hoTen -eq "Khach Smoke" -and $profile.soDienThoai.StartsWith("08")) "customer profile update"
    $profileRead = Invoke-Api GET "/api/khach-thue/cua-toi" $null $customerToken
    Check ($profileRead.email -eq "$customerUser.updated@example.test") "customer profile persisted"

    $models = Invoke-Api GET "/api/dong-may?sapXep=GIA_TANG&kichThuocTrang=100"
    $prices = @($models.duLieu | ForEach-Object { [decimal]$_.giaThueNgay })
    Check ($prices.Count -gt 0 -and (@($prices | Sort-Object) -join ',') -eq ($prices -join ',')) "model price ascending sort"
    $targetPrice = $prices[0]
    $filtered = Invoke-Api GET "/api/dong-may?giaTu=$targetPrice&giaDen=$targetPrice&kichThuocTrang=100"
    Check (@($filtered.duLieu | Where-Object { [decimal]$_.giaThueNgay -ne $targetPrice }).Count -eq 0) "model price range filter"

    $createdReview = Invoke-Api POST "/api/danh-gia" @{
        maChiTietHopDong=$detailReview; soSao=4; nhanXet="Danh gia smoke"; diemNoiBat=@("DE_SU_DUNG")
    } $customerToken
    $reviewId = $createdReview.maDanhGia
    $updatedReview = Invoke-Api PUT "/api/danh-gia/$reviewId" @{
        soSao=5; nhanXet="Da cap nhat"; diemNoiBat=@("PHU_KIEN_DAY_DU")
    } $customerToken
    Check ($updatedReview.soSao -eq 5 -and $updatedReview.nhanXet -eq "Da cap nhat") "owner updates review"
    Invoke-Api DELETE "/api/danh-gia/$reviewId" $null $customerToken
    $reviewId = $null
    $mine = Invoke-Api GET "/api/danh-gia/cua-toi" $null $customerToken
    Check (@($mine | Where-Object { $_.maChiTietHopDong -eq $detailReview }).Count -eq 0) "owner deletes review"

    $prepared = Invoke-Api PUT "/api/hop-dong/$contractPrep/thiet-bi" @{ maThietBi=@($devicePrep) } $adminToken
    Check ($prepared.trangThai -eq "CHO_BAN_GIAO") "staff prepares handover devices"
    $notifications = Invoke-Api GET "/api/thong-bao?kichThuocTrang=100" $null $customerToken
    Check ($notifications.duLieu.eventCode -contains "CONTRACT_READY_FOR_HANDOVER") "handover ready notification"

    docker restart rentalcamera-api | Out-Null
    $ready = $false
    for ($attempt = 0; $attempt -lt 30 -and -not $ready; $attempt++) {
        Start-Sleep -Seconds 1
        try { $ready = (Invoke-Api GET "/api/health").status -eq "ok" } catch { $ready = $false }
    }
    Check $ready "API ready after restart"
    $customerToken = (Invoke-Api POST "/api/auth/login" @{ tenDangNhap=$customerUser; matKhau=$password }).accessToken
    $notifications = Invoke-Api GET "/api/thong-bao?kichThuocTrang=100" $null $customerToken
    Check ($notifications.duLieu.eventCode -contains "CONTRACT_RETURN_DUE_SOON") "return due reminder notification"
}
finally {
    if ($customerAccountId) {
        $ids = @($customerAccountId,$adminAccountId,$customerId,$cartReview,$holdReview,$contractReview,$detailReview,$deviceReview,
            $cartDue,$holdDue,$contractDue,$detailDue,$deviceDue,$cartPrep,$cartLinePrep,$holdPrep,$holdLinePrep,$contractPrep,$devicePrep,$reviewId)
        foreach ($id in $ids) { if ($id -and $id -notmatch '^[A-Za-z0-9]+$') { throw "Unsafe cleanup id." } }
        $cleanup = @"
DELETE FROM dbo.NhatKyHeThong WHERE MaTaiKhoan IN ('$customerAccountId','$adminAccountId');
DELETE FROM dbo.ThongBao WHERE MaTaiKhoan IN ('$customerAccountId','$adminAccountId');
DELETE FROM dbo.AnhDanhGia WHERE MaDanhGia IN (SELECT MaDanhGia FROM dbo.DanhGia WHERE MaKhachThue='$customerId');
DELETE FROM dbo.DanhGiaDiemNoiBat WHERE MaDanhGia IN (SELECT MaDanhGia FROM dbo.DanhGia WHERE MaKhachThue='$customerId');
DELETE FROM dbo.DanhGia WHERE MaKhachThue='$customerId';
DELETE FROM dbo.ChiTietHopDong WHERE MaHopDong IN ('$contractReview','$contractDue','$contractPrep');
DELETE FROM dbo.LichSuTrangThaiHopDong WHERE MaHopDong IN ('$contractReview','$contractDue','$contractPrep');
DELETE FROM dbo.HopDong WHERE MaHopDong IN ('$contractReview','$contractDue','$contractPrep');
DELETE FROM dbo.ChiTietGiuCho WHERE MaGiuCho IN ('$holdReview','$holdDue','$holdPrep');
DELETE FROM dbo.GiuCho WHERE MaGiuCho IN ('$holdReview','$holdDue','$holdPrep');
DELETE FROM dbo.ChiTietGioHang WHERE MaGioHang IN ('$cartReview','$cartDue','$cartPrep');
DELETE FROM dbo.GioHang WHERE MaGioHang IN ('$cartReview','$cartDue','$cartPrep');
DELETE FROM dbo.ThietBi WHERE MaThietBi IN ('$deviceReview','$deviceDue','$devicePrep');
DELETE FROM dbo.KhachThue WHERE MaKhachThue='$customerId' OR MaTaiKhoan='$adminAccountId';
DELETE FROM dbo.TaiKhoan WHERE MaTaiKhoan IN ('$customerAccountId','$adminAccountId');
"@
        Invoke-Sql ($cleanup -replace "`r?`n", " ")
    }
}
