param([string]$BaseUrl = "http://localhost:5000")

$ErrorActionPreference = "Stop"
$suffix = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
$username = "contract_smoke_$suffix"
$password = "SmokeTest@2026"
$phone = "06" + $suffix.Substring($suffix.Length - 8)
$accountId = $null
$customerId = $null
$cartId = "GHT" + $suffix
$cart2Id = "GHU" + $suffix
$activeHoldId = "GCA" + $suffix
$expiredHoldId = "GCE" + $suffix
$convertedHold1Id = "GC1" + $suffix
$convertedHold2Id = "GC2" + $suffix
$contract1Id = "HD1" + $suffix
$contract2Id = "HD2" + $suffix

function Invoke-Api {
    param([string]$Method, [string]$Path, $Body = $null, [string]$Token = "")
    $headers = @{}
    if ($Token) { $headers.Authorization = "Bearer $Token" }
    $args = @{
        Method = $Method
        Uri = "$BaseUrl$Path"
        Headers = $headers
        UseBasicParsing = $true
        TimeoutSec = 15
    }
    if ($null -ne $Body) {
        $args.ContentType = "application/json; charset=utf-8"
        $json = $Body | ConvertTo-Json -Depth 8 -Compress
        $args.Body = [Text.Encoding]::UTF8.GetBytes($json)
    }
    try { Invoke-RestMethod @args }
    catch {
        $detail = $_.ErrorDetails.Message
        if (-not $detail) { $detail = $_.Exception.Message }
        throw "$Method $Path failed: $detail"
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$envPath = Join-Path $repoRoot ".env"
if (-not (Test-Path $envPath)) { throw "Missing local .env file." }
$passwordLine = Get-Content $envPath | Where-Object { $_ -match '^MSSQL_SA_PASSWORD=' } | Select-Object -First 1
if (-not $passwordLine) { throw "Missing MSSQL_SA_PASSWORD in .env." }
$sqlPassword = $passwordLine.Substring($passwordLine.IndexOf('=') + 1).Trim().Trim('"').Trim("'")

function Invoke-ContainerSql([string]$Query) {
    $connectionString = "Server=localhost,14330;Database=RentalCameraDb20;User Id=sa;Password=$sqlPassword;Encrypt=True;TrustServerCertificate=True;Connect Timeout=10"
    $connection = [System.Data.SqlClient.SqlConnection]::new($connectionString)
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandTimeout = 30
        $command.CommandText = $Query
        [void]$command.ExecuteNonQuery()
    }
    finally {
        $connection.Dispose()
    }
}

function Check([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAILED: $Name" }
    Write-Host "PASS $Name"
}

try {
    Write-Host "STEP register synthetic account"
    $registered = Invoke-Api POST "/api/auth/register" @{
        tenDangNhap = $username
        matKhau = $password
        soDienThoai = $phone
        email = "$username@example.test"
    }
    $accountId = $registered.maTaiKhoan
    $customerId = $registered.maKhachThue

    $fixtureSql = @"
UPDATE dbo.TaiKhoan SET VaiTro='ADMIN' WHERE MaTaiKhoan='$accountId';
DECLARE @branch VARCHAR(20) = (SELECT TOP 1 MaCuaHang FROM dbo.CuaHang WHERE TrangThai='HOAT_DONG' ORDER BY MaCuaHang);
DECLARE @model VARCHAR(20) = (SELECT TOP 1 MaDongMay FROM dbo.DongMay WHERE TrangThai='HOAT_DONG' ORDER BY MaDongMay);
IF @branch IS NULL OR @model IS NULL THROW 50001, 'Missing branch or model fixture.', 1;

INSERT dbo.GioHang(MaGioHang, MaKhachThue, NgayTao, NgayCapNhat, TrangThai)
VALUES
('$cartId', '$customerId', SYSDATETIME(), SYSDATETIME(), 'DA_CHUYEN_HOP_DONG'),
('$cart2Id', '$customerId', SYSDATETIME(), SYSDATETIME(), 'DA_CHUYEN_HOP_DONG');

INSERT dbo.GiuCho(MaGiuCho, MaGioHang, MaKhachThue, MaCuaHang, NgayTao, HetHanLuc, TrangThai)
VALUES
('$activeHoldId', '$cartId', '$customerId', @branch, DATEADD(MINUTE,-5,SYSUTCDATETIME()), DATEADD(MINUTE,15,SYSUTCDATETIME()), 'DANG_GIU'),
('$expiredHoldId', '$cartId', '$customerId', @branch, DATEADD(HOUR,-2,SYSUTCDATETIME()), DATEADD(HOUR,-1,SYSUTCDATETIME()), 'DANG_GIU'),
('$convertedHold1Id', '$cartId', '$customerId', @branch, DATEADD(DAY,-2,SYSUTCDATETIME()), DATEADD(DAY,-1,SYSUTCDATETIME()), 'DA_CHUYEN_HOP_DONG'),
('$convertedHold2Id', '$cart2Id', '$customerId', @branch, DATEADD(DAY,-3,SYSUTCDATETIME()), DATEADD(DAY,-2,SYSUTCDATETIME()), 'DA_CHUYEN_HOP_DONG');

INSERT dbo.ChiTietGiuCho(MaChiTietGiuCho, MaGiuCho, MaDongMay, SoLuong, NgayBatDau, NgayKetThuc, MaChiTietGioHang)
VALUES
('CTA$suffix', '$activeHoldId', @model, 1, DATEADD(DAY,3,SYSDATETIME()), DATEADD(DAY,4,SYSDATETIME()), NULL),
('CTE$suffix', '$expiredHoldId', @model, 1, DATEADD(DAY,3,SYSDATETIME()), DATEADD(DAY,4,SYSDATETIME()), NULL),
('CT1$suffix', '$convertedHold1Id', @model, 1, DATEADD(DAY,3,SYSDATETIME()), DATEADD(DAY,4,SYSDATETIME()), NULL),
('CT2$suffix', '$convertedHold2Id', @model, 1, DATEADD(DAY,5,SYSDATETIME()), DATEADD(DAY,6,SYSDATETIME()), NULL);

INSERT dbo.HopDong(MaHopDong, MaGioHang, MaGiuCho, MaKhachThue, MaNhanVien, MaCuaHang,
    NgayTaoHopDong, NgayKy, ThoiGianBanGiao, ThoiGianTraDuKien, TongTien, TongTienCoc,
    HinhThucKy, TrangThai, TepHopDongUrl, DaDongYDieuKhoan)
VALUES
('$contract1Id', '$cartId', '$convertedHold1Id', '$customerId', NULL, @branch,
    SYSDATETIME(), NULL, DATEADD(DAY,3,SYSDATETIME()), DATEADD(DAY,4,SYSDATETIME()),
    100000, 500000, NULL, 'CHO_KY', NULL, 0),
('$contract2Id', '$cart2Id', '$convertedHold2Id', '$customerId', NULL, @branch,
    SYSDATETIME(), SYSDATETIME(), DATEADD(DAY,5,SYSDATETIME()), DATEADD(DAY,6,SYSDATETIME()),
    100000, 500000, 'DIEN_TU', 'DA_KY', NULL, 1);
"@
    Write-Host "STEP seed isolated reservation and contract fixtures"
    Invoke-ContainerSql ($fixtureSql -replace "`r?`n", " ")

    Write-Host "STEP login as synthetic admin"
    $login = Invoke-Api POST "/api/auth/login" @{ tenDangNhap = $username; matKhau = $password }
    $token = $login.accessToken
    Check ($login.vaiTro -eq "ADMIN") "synthetic account promoted to admin"

    $holds = Invoke-Api GET "/api/giu-cho/quan-ly?kichThuocTrang=100" $null $token
    Check (($holds.duLieu.maGiuCho -contains $activeHoldId) -and ($holds.duLieu.maGiuCho -contains $expiredHoldId)) "list reservations for admin"
    $active = Invoke-Api GET "/api/giu-cho/quan-ly?trangThai=DANG_GIU&kichThuocTrang=100" $null $token
    Check (($active.duLieu.maGiuCho -contains $activeHoldId) -and -not ($active.duLieu.maGiuCho -contains $expiredHoldId)) "filter active reservations"
    $expired = Invoke-Api GET "/api/giu-cho/quan-ly?trangThai=HET_HAN&kichThuocTrang=100" $null $token
    Check ($expired.duLieu.maGiuCho -contains $expiredHoldId) "detect and filter expired reservations"
    $converted = Invoke-Api GET "/api/giu-cho/quan-ly?trangThai=DA_CHUYEN_HOP_DONG&kichThuocTrang=100" $null $token
    Check (($converted.duLieu.maGiuCho -contains $convertedHold1Id) -and ($converted.duLieu.maGiuCho -contains $convertedHold2Id)) "filter converted reservations"
    $holdDetail = Invoke-Api GET "/api/giu-cho/quan-ly/$activeHoldId" $null $token
    Check ($holdDetail.maKhachThue -eq $customerId -and $holdDetail.chiTiet.Count -eq 1) "read reservation details"

    $contracts = Invoke-Api GET "/api/hop-dong/quan-ly?kichThuocTrang=100" $null $token
    Check ($contracts.tongSoBanGhi -gt 0 -and $contracts.duLieu.Count -gt 0) "list contracts for admin"
    $knownContract = @($contracts.duLieu)[0]
    $signed = Invoke-Api GET "/api/hop-dong/quan-ly?trangThai=$($knownContract.trangThai)&kichThuocTrang=100" $null $token
    Check (@($signed.duLieu | Where-Object { $_.trangThai -ne $knownContract.trangThai }).Count -eq 0 -and $signed.tongSoBanGhi -gt 0) "filter contracts by status"
    $searched = Invoke-Api GET "/api/hop-dong/quan-ly?maHopDong=$($knownContract.maHopDong)&kichThuocTrang=100" $null $token
    Check ($searched.tongSoBanGhi -eq 1 -and $searched.duLieu.maHopDong -eq $knownContract.maHopDong) "search contract code"

    $cancelled = Invoke-Api POST "/api/hop-dong/$contract1Id/huy?lyDo=Smoke%20test" $null $token
    Check ($cancelled.trangThai -eq "DA_HUY") "admin cancels eligible contract"
    $history = Invoke-Api GET "/api/hop-dong/$contract1Id/lich-su-trang-thai" $null $token
    Check ($history.Count -ge 1 -and $history[0].trangThaiMoi -eq "DA_HUY" -and $history[0].vaiTroNguoiThaoTac -eq "ADMIN") "persist contract status history"
}
finally {
    if ($accountId) {
        foreach ($id in @($accountId, $customerId, $cartId, $cart2Id, $activeHoldId, $expiredHoldId,
                $convertedHold1Id, $convertedHold2Id, $contract1Id, $contract2Id)) {
            if ($id -and $id -notmatch "^[A-Za-z0-9]+$") { throw "Unsafe cleanup id." }
        }
        $cleanup = @"
DELETE FROM dbo.NhatKyHeThong WHERE MaTaiKhoan='$accountId';
DELETE FROM dbo.LichSuTrangThaiHopDong WHERE MaHopDong IN ('$contract1Id','$contract2Id');
DELETE FROM dbo.HopDong WHERE MaHopDong IN ('$contract1Id','$contract2Id');
DELETE FROM dbo.ChiTietGiuCho WHERE MaGiuCho IN ('$activeHoldId','$expiredHoldId','$convertedHold1Id','$convertedHold2Id');
DELETE FROM dbo.GiuCho WHERE MaGiuCho IN ('$activeHoldId','$expiredHoldId','$convertedHold1Id','$convertedHold2Id');
DELETE FROM dbo.GioHang WHERE MaGioHang IN ('$cartId','$cart2Id');
DELETE FROM dbo.KhachThue WHERE MaKhachThue='$customerId';
DELETE FROM dbo.TaiKhoan WHERE MaTaiKhoan='$accountId';
"@
        Invoke-ContainerSql ($cleanup -replace "`r?`n", " ")
    }
}
