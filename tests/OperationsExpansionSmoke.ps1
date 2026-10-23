param([string]$BaseUrl = "http://localhost:5000")

$ErrorActionPreference = "Stop"
$suffix = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
$username = "ops_smoke_$suffix"
$password = "SmokeTest@2026"
$phone = "05" + $suffix.Substring($suffix.Length - 8)
$accountId = $null
$customerId = $null
$cartId = "GHO" + $suffix
$holdId = "GCO" + $suffix
$contractId = "HDO" + $suffix
$contractDetailId = "CTO" + $suffix
$extensionId = "PLO" + $suffix

function Invoke-Api {
    param([string]$Method, [string]$Path, $Body = $null, [string]$Token = "")
    $headers = @{}
    if ($Token) { $headers.Authorization = "Bearer $Token" }
    $args = @{ Method=$Method; Uri="$BaseUrl$Path"; Headers=$headers; UseBasicParsing=$true; TimeoutSec=20 }
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

try {
    $health = Invoke-Api GET "/api/health"
    Check ($health.status -eq "ok") "API health"

    $registered = Invoke-Api POST "/api/auth/register" @{
        tenDangNhap=$username; matKhau=$password; soDienThoai=$phone; email="$username@example.test"
    }
    $accountId = $registered.maTaiKhoan; $customerId = $registered.maKhachThue

    $sql = @"
UPDATE dbo.TaiKhoan SET VaiTro='ADMIN' WHERE MaTaiKhoan='$accountId';
DECLARE @branch VARCHAR(20)=(SELECT TOP 1 MaCuaHang FROM dbo.CuaHang WHERE TrangThai='HOAT_DONG' ORDER BY MaCuaHang);
DECLARE @device VARCHAR(20)=(SELECT TOP 1 MaThietBi FROM dbo.ThietBi WHERE TrangThai<>'NGUNG_KINH_DOANH' ORDER BY MaThietBi);
DECLARE @model VARCHAR(20)=(SELECT MaDongMay FROM dbo.ThietBi WHERE MaThietBi=@device);
IF @branch IS NULL OR @device IS NULL THROW 50001, 'Missing branch or device fixture.', 1;
INSERT dbo.GioHang(MaGioHang,MaKhachThue,NgayTao,NgayCapNhat,TrangThai)
VALUES('$cartId','$customerId',SYSDATETIME(),SYSDATETIME(),'DA_CHUYEN_HOP_DONG');
INSERT dbo.GiuCho(MaGiuCho,MaGioHang,MaKhachThue,MaCuaHang,NgayTao,HetHanLuc,TrangThai)
VALUES('$holdId','$cartId','$customerId',@branch,DATEADD(DAY,-10,SYSDATETIME()),DATEADD(DAY,-9,SYSDATETIME()),'DA_CHUYEN_HOP_DONG');
INSERT dbo.ChiTietGiuCho(MaChiTietGiuCho,MaGiuCho,MaDongMay,SoLuong,NgayBatDau,NgayKetThuc,MaChiTietGioHang)
VALUES('CGO$suffix','$holdId',@model,1,DATEADD(DAY,-7,SYSDATETIME()),DATEADD(DAY,-3,SYSDATETIME()),NULL);
INSERT dbo.HopDong(MaHopDong,MaGioHang,MaGiuCho,MaKhachThue,MaNhanVien,MaCuaHang,NgayTaoHopDong,NgayKy,
 ThoiGianBanGiao,ThoiGianTraDuKien,TongTien,TongTienCoc,HinhThucKy,TrangThai,TepHopDongUrl,DaDongYDieuKhoan)
VALUES('$contractId','$cartId','$holdId','$customerId',NULL,@branch,DATEADD(DAY,-10,SYSDATETIME()),DATEADD(DAY,-9,SYSDATETIME()),
 DATEADD(DAY,-7,SYSDATETIME()),DATEADD(DAY,-3,SYSDATETIME()),500000,300000,'DIEN_TU','CHO_HOAN_TRA',NULL,1);
INSERT dbo.ChiTietHopDong(MaChiTietHopDong,MaHopDong,MaThietBi,DonGia,TinhTrangLucGiao,NgayGiaoThucTe,CoHuHong)
VALUES('$contractDetailId','$contractId',@device,100000,N'Tốt',DATEADD(DAY,-7,SYSDATETIME()),0);
INSERT dbo.PhuLuc(MaPhuLuc,MaHopDong,NgayLap,ThoiHanTraMoi,ChiPhiPhatSinh,TienCocBoSung,LyDoGiaHan,TrangThai)
VALUES('$extensionId','$contractId',SYSDATETIME(),DATEADD(DAY,2,SYSDATETIME()),200000,0,N'Smoke test','CHO_XAC_NHAN');
"@
    Invoke-Sql ($sql -replace "`r?`n", " ")

    $login = Invoke-Api POST "/api/auth/login" @{ tenDangNhap=$username; matKhau=$password }
    $token = $login.accessToken
    Check ($login.vaiTro -eq "ADMIN") "synthetic admin login"

    $returns = Invoke-Api GET "/api/hoan-tra/cho-nhan?kichThuocTrang=100" $null $token
    Check ($returns.duLieu.maHopDong -contains $contractId) "return waiting list"
    $lateQuote = Invoke-Api GET "/api/hop-dong/$contractId/phi-tra-tre" $null $token
    Check ($lateQuote.soNgayTre -ge 1 -and $lateQuote.soTien -gt 0) "late return fee calculation"
    $latePenalty = Invoke-Api POST "/api/hop-dong/$contractId/phi-tra-tre" @{ ghiChu="Smoke late fee" } $token
    Check ($latePenalty.phieuPhat.loaiViPham -eq "TRA_TRE") "late return penalty creation"
    $damage = Invoke-Api POST "/api/hop-dong/$contractId/phi-hu-hong" @{
        thietBi=@(@{ maChiTietHopDong=$contractDetailId; chiPhiSuaChua=120000; chiPhiPhuKienThieu=80000; ghiChu="Smoke damage" })
    } $token
    Check ($damage.duLieu.Count -eq 2 -and $damage.tongPhi -eq 200000) "damage and missing accessory fees"

    $extension = Invoke-Api PUT "/api/gia-han/$extensionId/xu-ly" @{ quyetDinh="TU_CHOI"; ghiChu="Smoke result" } $token
    Check ($extension.trangThai -eq "TU_CHOI") "extension decision"
    $notifications = Invoke-Api GET "/api/thong-bao?kichThuocTrang=100" $null $token
    Check ($notifications.duLieu.eventCode -contains "CONTRACT_EXTENSION_RESULT") "extension result notification"

    $customers = Invoke-Api GET "/api/khach-hang?tuKhoa=$username&kichThuocTrang=100" $null $token
    Check ($customers.duLieu.maKhachThue -contains $customerId) "customer management list"
    $customer = Invoke-Api GET "/api/khach-hang/$customerId" $null $token
    Check ($customer.hoSo.maKhachThue -eq $customerId) "customer management detail"
    $history = Invoke-Api GET "/api/khach-hang/$customerId/hop-dong?kichThuocTrang=100" $null $token
    Check ($history.duLieu.maHopDong -contains $contractId) "customer contract history"

    $performance = Invoke-Api GET "/api/bao-cao/hieu-suat-dong-may?tuNgay=$((Get-Date).AddDays(-30).ToString('yyyy-MM-dd'))&denNgay=$((Get-Date).ToString('yyyy-MM-dd'))" $null $token
    Check ($performance.duLieu.Count -ge 1) "model performance report"
    $utilization = Invoke-Api GET "/api/bao-cao/ty-le-su-dung-thiet-bi?tuNgay=$((Get-Date).AddDays(-30).ToString('yyyy-MM-dd'))&denNgay=$((Get-Date).ToString('yyyy-MM-dd'))" $null $token
    Check ($utilization.duLieu.Count -ge 1) "device utilization report"
    $depositFine = Invoke-Api GET "/api/bao-cao/tien-coc-va-phieu-phat?tuNgay=$((Get-Date).AddDays(-30).ToString('yyyy-MM-dd'))&denNgay=$((Get-Date).ToString('yyyy-MM-dd'))" $null $token
    Check ($depositFine.duLieu.Count -ge 1) "deposit and penalty report"

    $headers = @{ Authorization="Bearer $token" }
    $excel = Invoke-WebRequest -UseBasicParsing -Headers $headers -TimeoutSec 20 -Uri "$BaseUrl/api/bao-cao/xuat?loai=HIEU_SUAT_DONG_MAY&dinhDang=EXCEL&tuNgay=$((Get-Date).AddDays(-30).ToString('yyyy-MM-dd'))&denNgay=$((Get-Date).ToString('yyyy-MM-dd'))"
    Check ($excel.StatusCode -eq 200 -and $excel.Headers.'Content-Type' -match 'excel') "Excel report export"
    $pdf = Invoke-WebRequest -UseBasicParsing -Headers $headers -TimeoutSec 20 -Uri "$BaseUrl/api/bao-cao/xuat?loai=TIEN_COC_PHAT&dinhDang=PDF&tuNgay=$((Get-Date).AddDays(-30).ToString('yyyy-MM-dd'))&denNgay=$((Get-Date).ToString('yyyy-MM-dd'))"
    Check ($pdf.StatusCode -eq 200 -and $pdf.Headers.'Content-Type' -match 'pdf') "PDF report export"

    $audit = Invoke-Api GET "/api/he-thong/nhat-ky?maTaiKhoan=$accountId&kichThuocTrang=100" $null $token
    Check ($audit.tongSo -ge 3) "system audit trail"
}
finally {
    if ($accountId) {
        foreach ($id in @($accountId,$customerId,$cartId,$holdId,$contractId,$contractDetailId,$extensionId)) {
            if ($id -and $id -notmatch '^[A-Za-z0-9]+$') { throw "Unsafe cleanup id." }
        }
        $cleanup = @"
DELETE FROM dbo.NhatKyHeThong WHERE MaTaiKhoan='$accountId';
DELETE FROM dbo.ThongBao WHERE MaTaiKhoan='$accountId';
DELETE FROM dbo.PhieuPhat WHERE MaChiTietHopDong='$contractDetailId';
DELETE FROM dbo.PhuLuc WHERE MaPhuLuc='$extensionId';
DELETE FROM dbo.ChiTietHopDong WHERE MaChiTietHopDong='$contractDetailId';
DELETE FROM dbo.LichSuTrangThaiHopDong WHERE MaHopDong='$contractId';
DELETE FROM dbo.HopDong WHERE MaHopDong='$contractId';
DELETE FROM dbo.ChiTietGiuCho WHERE MaGiuCho='$holdId';
DELETE FROM dbo.GiuCho WHERE MaGiuCho='$holdId';
DELETE FROM dbo.GioHang WHERE MaGioHang='$cartId';
DELETE FROM dbo.KhachThue WHERE MaKhachThue='$customerId';
DELETE FROM dbo.TaiKhoan WHERE MaTaiKhoan='$accountId';
"@
        Invoke-Sql ($cleanup -replace "`r?`n", " ")
    }
}
