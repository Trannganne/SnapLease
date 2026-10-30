-- PREPARED ONLY. Synthetic, idempotent baseline. No contracts/payments/PDF/signature rows are fabricated.

SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() <> N'RentalCameraDb30_Test'
    THROW 53300, 'Only RentalCameraDb30_Test is permitted by this reviewed trial package.', 1;
IF CONVERT(nvarchar(128),SESSION_CONTEXT(N'Schema33.ExpectedDatabase')) IS NULL
 OR CONVERT(nvarchar(128),SESSION_CONTEXT(N'Schema33.ExpectedDatabase')) <> DB_NAME()
    THROW 53301, 'ExpectedDatabase session guard missing or different.', 1;
IF CONVERT(nvarchar(128),SESSION_CONTEXT(N'Schema33.ExpectedServer')) IS NULL
 OR CONVERT(nvarchar(128),SESSION_CONTEXT(N'Schema33.ExpectedServer')) <> CONVERT(nvarchar(128),SERVERPROPERTY('ServerName'))
    THROW 53302, 'ExpectedServer session guard missing or different.', 1;
IF CONVERT(nvarchar(30),SESSION_CONTEXT(N'Schema33.Environment')) IS NULL
 OR CONVERT(nvarchar(30),SESSION_CONTEXT(N'Schema33.Environment')) <> N'Schema33Trial'
    THROW 53303, 'Trial environment session guard missing.', 1;
IF CONVERT(bit,SESSION_CONTEXT(N'Schema33.DatabasePackageApproved')) IS NULL
 OR CONVERT(bit,SESSION_CONTEXT(N'Schema33.DatabasePackageApproved')) <> 1
    THROW 53304, 'Separate explicit database package approval is required.', 1;
IF DATALENGTH(CONVERT(varchar(64),SESSION_CONTEXT(N'Schema33.ReviewedFileSha256'))) <> 64
 OR CONVERT(varchar(64),SESSION_CONTEXT(N'Schema33.ReviewedFileSha256')) IS NULL
 OR CONVERT(varchar(64),SESSION_CONTEXT(N'Schema33.CalculatedFileSha256')) IS NULL
 OR CONVERT(varchar(64),SESSION_CONTEXT(N'Schema33.ReviewedFileSha256')) COLLATE Latin1_General_100_BIN2
    <> CONVERT(varchar(64),SESSION_CONTEXT(N'Schema33.CalculatedFileSha256')) COLLATE Latin1_General_100_BIN2
    THROW 53305, 'Reviewed and calculated UTF8 file hashes must match in the verified runner.', 1;
IF @@TRANCOUNT <> 0 THROW 53306, 'Do not run inside another transaction.', 1;


DECLARE @ExpectedTables TABLE(SchemaName sysname NOT NULL,TableName sysname NOT NULL,PRIMARY KEY(SchemaName,TableName));
INSERT @ExpectedTables(SchemaName,TableName) VALUES
(N'dbo',N'TaiKhoan'),
(N'dbo',N'KhachThue'),
(N'dbo',N'NhanVien'),
(N'dbo',N'GiayToTuyThan'),
(N'dbo',N'DanhMuc'),
(N'dbo',N'ThuongHieu'),
(N'dbo',N'DongMay'),
(N'dbo',N'ThietBi'),
(N'dbo',N'AnhThietBi'),
(N'dbo',N'CuaHang'),
(N'dbo',N'GioHang'),
(N'dbo',N'ChiTietGioHang'),
(N'dbo',N'GiuCho'),
(N'dbo',N'ChiTietGiuCho'),
(N'dbo',N'HopDong'),
(N'dbo',N'ChiTietHopDong'),
(N'dbo',N'PhuLuc'),
(N'dbo',N'XacNhanKyHopDong'),
(N'dbo',N'ThanhToan'),
(N'dbo',N'YeuCauThanhToanVnpay'),
(N'dbo',N'PhieuPhat'),
(N'dbo',N'QuyetToanHopDong'),
(N'dbo',N'PhanBoQuyetToan'),
(N'dbo',N'DanhGia'),
(N'dbo',N'AnhDanhGia'),
(N'dbo',N'AnhBienBan'),
(N'dbo',N'ThongBao'),
(N'dbo',N'FcmDeviceToken'),
(N'dbo',N'NotificationDelivery'),
(N'dbo',N'IdempotencyKey'),
(N'dbo',N'BienBanNhanTra'),
(N'dbo',N'DoiSoatHuyHopDong'),
(N'dbo',N'XacMinhKhachKhongDen');


IF EXISTS(SELECT s.name,t.name FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id WHERE t.is_ms_shipped=0
          EXCEPT SELECT SchemaName,TableName FROM @ExpectedTables)
 OR EXISTS(SELECT SchemaName,TableName FROM @ExpectedTables EXCEPT
           SELECT s.name,t.name FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id WHERE t.is_ms_shipped=0)
    THROW 53307, 'Physical schema.table set differs from the approved exact33 list.', 1;


BEGIN TRY

BEGIN TRANSACTION;

DECLARE @l int; EXEC @l=sys.sp_getapplock @Resource=N'SnapLease.Schema33.Seed.TR33',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000; IF @l<0 THROW 53310,'Could not lock trial seed.',1;

DECLARE @UtcNow datetime2=SYSUTCDATETIME(),@LocalNow datetime2=DATEADD(hour,7,SYSUTCDATETIME());

IF EXISTS(SELECT 1 FROM dbo.[CuaHang] WHERE [MaCuaHang]=N'TR33_S01')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[CuaHang] WHERE [MaCuaHang]=N'TR33_S01' AND (([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([TenCuaHang] IS NULL AND N'SnapLease Nguyễn Huệ' IS NOT NULL) OR ([TenCuaHang] IS NOT NULL AND N'SnapLease Nguyễn Huệ' IS NULL) OR ([TenCuaHang] <> N'SnapLease Nguyễn Huệ') OR ([ViDo] IS NULL AND NULL IS NOT NULL) OR ([ViDo] IS NOT NULL AND NULL IS NULL) OR ([ViDo] <> NULL) OR ([KinhDo] IS NULL AND NULL IS NOT NULL) OR ([KinhDo] IS NOT NULL AND NULL IS NULL) OR ([KinhDo] <> NULL) OR ([DiaChi] IS NULL AND N'01 Nguyễn Huệ, Quận 1, TP.HCM' IS NOT NULL) OR ([DiaChi] IS NOT NULL AND N'01 Nguyễn Huệ, Quận 1, TP.HCM' IS NULL) OR ([DiaChi] <> N'01 Nguyễn Huệ, Quận 1, TP.HCM') OR ([SoDienThoai] IS NULL AND N'0900000001' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0900000001' IS NULL) OR ([SoDienThoai] <> N'0900000001') OR ([Email] IS NULL AND N'branch1@example.invalid' IS NOT NULL) OR ([Email] IS NOT NULL AND N'branch1@example.invalid' IS NULL) OR ([Email] <> N'branch1@example.invalid') OR ([MoTa] IS NULL AND N'FAKE TRIAL DATA ONLY' IS NOT NULL) OR ([MoTa] IS NOT NULL AND N'FAKE TRIAL DATA ONLY' IS NULL) OR ([MoTa] <> N'FAKE TRIAL DATA ONLY'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[CuaHang] ([MaCuaHang],[TenCuaHang],[ViDo],[KinhDo],[DiaChi],[SoDienThoai],[Email],[MoTa],[TrangThai]) VALUES (N'TR33_S01',N'SnapLease Nguyễn Huệ',NULL,NULL,N'01 Nguyễn Huệ, Quận 1, TP.HCM',N'0900000001',N'branch1@example.invalid',N'FAKE TRIAL DATA ONLY',N'HOAT_DONG');

IF EXISTS(SELECT 1 FROM dbo.[CuaHang] WHERE [MaCuaHang]=N'TR33_S02')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[CuaHang] WHERE [MaCuaHang]=N'TR33_S02' AND (([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([TenCuaHang] IS NULL AND N'SnapLease Võ Văn Ngân' IS NOT NULL) OR ([TenCuaHang] IS NOT NULL AND N'SnapLease Võ Văn Ngân' IS NULL) OR ([TenCuaHang] <> N'SnapLease Võ Văn Ngân') OR ([ViDo] IS NULL AND NULL IS NOT NULL) OR ([ViDo] IS NOT NULL AND NULL IS NULL) OR ([ViDo] <> NULL) OR ([KinhDo] IS NULL AND NULL IS NOT NULL) OR ([KinhDo] IS NOT NULL AND NULL IS NULL) OR ([KinhDo] <> NULL) OR ([DiaChi] IS NULL AND N'20 Võ Văn Ngân, TP. Thủ Đức, TP.HCM' IS NOT NULL) OR ([DiaChi] IS NOT NULL AND N'20 Võ Văn Ngân, TP. Thủ Đức, TP.HCM' IS NULL) OR ([DiaChi] <> N'20 Võ Văn Ngân, TP. Thủ Đức, TP.HCM') OR ([SoDienThoai] IS NULL AND N'0900000002' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0900000002' IS NULL) OR ([SoDienThoai] <> N'0900000002') OR ([Email] IS NULL AND N'branch2@example.invalid' IS NOT NULL) OR ([Email] IS NOT NULL AND N'branch2@example.invalid' IS NULL) OR ([Email] <> N'branch2@example.invalid') OR ([MoTa] IS NULL AND N'FAKE TRIAL DATA ONLY' IS NOT NULL) OR ([MoTa] IS NOT NULL AND N'FAKE TRIAL DATA ONLY' IS NULL) OR ([MoTa] <> N'FAKE TRIAL DATA ONLY'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[CuaHang] ([MaCuaHang],[TenCuaHang],[ViDo],[KinhDo],[DiaChi],[SoDienThoai],[Email],[MoTa],[TrangThai]) VALUES (N'TR33_S02',N'SnapLease Võ Văn Ngân',NULL,NULL,N'20 Võ Văn Ngân, TP. Thủ Đức, TP.HCM',N'0900000002',N'branch2@example.invalid',N'FAKE TRIAL DATA ONLY',N'HOAT_DONG');

IF EXISTS(SELECT 1 FROM dbo.[CuaHang] WHERE [MaCuaHang]=N'TR33_S03')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[CuaHang] WHERE [MaCuaHang]=N'TR33_S03' AND (([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([TenCuaHang] IS NULL AND N'SnapLease Lý Thường Kiệt' IS NOT NULL) OR ([TenCuaHang] IS NOT NULL AND N'SnapLease Lý Thường Kiệt' IS NULL) OR ([TenCuaHang] <> N'SnapLease Lý Thường Kiệt') OR ([ViDo] IS NULL AND NULL IS NOT NULL) OR ([ViDo] IS NOT NULL AND NULL IS NULL) OR ([ViDo] <> NULL) OR ([KinhDo] IS NULL AND NULL IS NOT NULL) OR ([KinhDo] IS NOT NULL AND NULL IS NULL) OR ([KinhDo] <> NULL) OR ([DiaChi] IS NULL AND N'268 Lý Thường Kiệt, Quận 10, TP.HCM' IS NOT NULL) OR ([DiaChi] IS NOT NULL AND N'268 Lý Thường Kiệt, Quận 10, TP.HCM' IS NULL) OR ([DiaChi] <> N'268 Lý Thường Kiệt, Quận 10, TP.HCM') OR ([SoDienThoai] IS NULL AND N'0900000003' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0900000003' IS NULL) OR ([SoDienThoai] <> N'0900000003') OR ([Email] IS NULL AND N'branch3@example.invalid' IS NOT NULL) OR ([Email] IS NOT NULL AND N'branch3@example.invalid' IS NULL) OR ([Email] <> N'branch3@example.invalid') OR ([MoTa] IS NULL AND N'FAKE TRIAL DATA ONLY' IS NOT NULL) OR ([MoTa] IS NOT NULL AND N'FAKE TRIAL DATA ONLY' IS NULL) OR ([MoTa] <> N'FAKE TRIAL DATA ONLY'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[CuaHang] ([MaCuaHang],[TenCuaHang],[ViDo],[KinhDo],[DiaChi],[SoDienThoai],[Email],[MoTa],[TrangThai]) VALUES (N'TR33_S03',N'SnapLease Lý Thường Kiệt',NULL,NULL,N'268 Lý Thường Kiệt, Quận 10, TP.HCM',N'0900000003',N'branch3@example.invalid',N'FAKE TRIAL DATA ONLY',N'HOAT_DONG');

IF EXISTS(SELECT 1 FROM dbo.[DanhMuc] WHERE [MaDanhMuc]=N'TR33_CAT')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[DanhMuc] WHERE [MaDanhMuc]=N'TR33_CAT' AND (([MaDanhMuc] IS NULL AND N'TR33_CAT' IS NOT NULL) OR ([MaDanhMuc] IS NOT NULL AND N'TR33_CAT' IS NULL) OR ([MaDanhMuc] <> N'TR33_CAT') OR ([TenDanhMuc] IS NULL AND N'TRIAL33 Cameras' IS NOT NULL) OR ([TenDanhMuc] IS NOT NULL AND N'TRIAL33 Cameras' IS NULL) OR ([TenDanhMuc] <> N'TRIAL33 Cameras') OR ([MoTa] IS NULL AND N'Synthetic catalog' IS NOT NULL) OR ([MoTa] IS NOT NULL AND N'Synthetic catalog' IS NULL) OR ([MoTa] <> N'Synthetic catalog'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[DanhMuc] ([MaDanhMuc],[TenDanhMuc],[MoTa],[TrangThai]) VALUES (N'TR33_CAT',N'TRIAL33 Cameras',N'Synthetic catalog',N'HOAT_DONG');

IF EXISTS(SELECT 1 FROM dbo.[ThuongHieu] WHERE [MaThuongHieu]=N'TR33_BR1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThuongHieu] WHERE [MaThuongHieu]=N'TR33_BR1' AND (([MaThuongHieu] IS NULL AND N'TR33_BR1' IS NOT NULL) OR ([MaThuongHieu] IS NOT NULL AND N'TR33_BR1' IS NULL) OR ([MaThuongHieu] <> N'TR33_BR1') OR ([TenThuongHieu] IS NULL AND N'TRIAL33 Brand 1' IS NOT NULL) OR ([TenThuongHieu] IS NOT NULL AND N'TRIAL33 Brand 1' IS NULL) OR ([TenThuongHieu] <> N'TRIAL33 Brand 1') OR ([QuocGia] IS NULL AND N'Synthetic' IS NOT NULL) OR ([QuocGia] IS NOT NULL AND N'Synthetic' IS NULL) OR ([QuocGia] <> N'Synthetic'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThuongHieu] ([MaThuongHieu],[TenThuongHieu],[QuocGia]) VALUES (N'TR33_BR1',N'TRIAL33 Brand 1',N'Synthetic');

IF EXISTS(SELECT 1 FROM dbo.[ThuongHieu] WHERE [MaThuongHieu]=N'TR33_BR2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThuongHieu] WHERE [MaThuongHieu]=N'TR33_BR2' AND (([MaThuongHieu] IS NULL AND N'TR33_BR2' IS NOT NULL) OR ([MaThuongHieu] IS NOT NULL AND N'TR33_BR2' IS NULL) OR ([MaThuongHieu] <> N'TR33_BR2') OR ([TenThuongHieu] IS NULL AND N'TRIAL33 Brand 2' IS NOT NULL) OR ([TenThuongHieu] IS NOT NULL AND N'TRIAL33 Brand 2' IS NULL) OR ([TenThuongHieu] <> N'TRIAL33 Brand 2') OR ([QuocGia] IS NULL AND N'Synthetic' IS NOT NULL) OR ([QuocGia] IS NOT NULL AND N'Synthetic' IS NULL) OR ([QuocGia] <> N'Synthetic'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThuongHieu] ([MaThuongHieu],[TenThuongHieu],[QuocGia]) VALUES (N'TR33_BR2',N'TRIAL33 Brand 2',N'Synthetic');

IF EXISTS(SELECT 1 FROM dbo.[DongMay] WHERE [MaDongMay]=N'TR33_M01')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[DongMay] WHERE [MaDongMay]=N'TR33_M01' AND (([MaDongMay] IS NULL AND N'TR33_M01' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M01' IS NULL) OR ([MaDongMay] <> N'TR33_M01') OR ([MaDanhMuc] IS NULL AND N'TR33_CAT' IS NOT NULL) OR ([MaDanhMuc] IS NOT NULL AND N'TR33_CAT' IS NULL) OR ([MaDanhMuc] <> N'TR33_CAT') OR ([MaThuongHieu] IS NULL AND N'TR33_BR1' IS NOT NULL) OR ([MaThuongHieu] IS NOT NULL AND N'TR33_BR1' IS NULL) OR ([MaThuongHieu] <> N'TR33_BR1') OR ([TenDongMay] IS NULL AND N'TRIAL33 Camera Model 01' IS NOT NULL) OR ([TenDongMay] IS NOT NULL AND N'TRIAL33 Camera Model 01' IS NULL) OR ([TenDongMay] <> N'TRIAL33 Camera Model 01') OR ([MoTa] IS NULL AND N'Synthetic camera model' IS NOT NULL) OR ([MoTa] IS NOT NULL AND N'Synthetic camera model' IS NULL) OR ([MoTa] <> N'Synthetic camera model') OR ([GiaThueNgay] IS NULL AND 125000 IS NOT NULL) OR ([GiaThueNgay] IS NOT NULL AND 125000 IS NULL) OR ([GiaThueNgay] <> 125000) OR ([TienCoc] IS NULL AND 1250000 IS NOT NULL) OR ([TienCoc] IS NOT NULL AND 1250000 IS NULL) OR ([TienCoc] <> 1250000) OR ([PhanTramGiamGia] IS NULL AND 0 IS NOT NULL) OR ([PhanTramGiamGia] IS NOT NULL AND 0 IS NULL) OR ([PhanTramGiamGia] <> 0))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[DongMay] ([MaDongMay],[MaDanhMuc],[MaThuongHieu],[TenDongMay],[MoTa],[GiaThueNgay],[TienCoc],[PhanTramGiamGia]) VALUES (N'TR33_M01',N'TR33_CAT',N'TR33_BR1',N'TRIAL33 Camera Model 01',N'Synthetic camera model',125000,1250000,0);

IF EXISTS(SELECT 1 FROM dbo.[DongMay] WHERE [MaDongMay]=N'TR33_M02')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[DongMay] WHERE [MaDongMay]=N'TR33_M02' AND (([MaDongMay] IS NULL AND N'TR33_M02' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M02' IS NULL) OR ([MaDongMay] <> N'TR33_M02') OR ([MaDanhMuc] IS NULL AND N'TR33_CAT' IS NOT NULL) OR ([MaDanhMuc] IS NOT NULL AND N'TR33_CAT' IS NULL) OR ([MaDanhMuc] <> N'TR33_CAT') OR ([MaThuongHieu] IS NULL AND N'TR33_BR1' IS NOT NULL) OR ([MaThuongHieu] IS NOT NULL AND N'TR33_BR1' IS NULL) OR ([MaThuongHieu] <> N'TR33_BR1') OR ([TenDongMay] IS NULL AND N'TRIAL33 Camera Model 02' IS NOT NULL) OR ([TenDongMay] IS NOT NULL AND N'TRIAL33 Camera Model 02' IS NULL) OR ([TenDongMay] <> N'TRIAL33 Camera Model 02') OR ([MoTa] IS NULL AND N'Synthetic camera model' IS NOT NULL) OR ([MoTa] IS NOT NULL AND N'Synthetic camera model' IS NULL) OR ([MoTa] <> N'Synthetic camera model') OR ([GiaThueNgay] IS NULL AND 150000 IS NOT NULL) OR ([GiaThueNgay] IS NOT NULL AND 150000 IS NULL) OR ([GiaThueNgay] <> 150000) OR ([TienCoc] IS NULL AND 1500000 IS NOT NULL) OR ([TienCoc] IS NOT NULL AND 1500000 IS NULL) OR ([TienCoc] <> 1500000) OR ([PhanTramGiamGia] IS NULL AND 0 IS NOT NULL) OR ([PhanTramGiamGia] IS NOT NULL AND 0 IS NULL) OR ([PhanTramGiamGia] <> 0))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[DongMay] ([MaDongMay],[MaDanhMuc],[MaThuongHieu],[TenDongMay],[MoTa],[GiaThueNgay],[TienCoc],[PhanTramGiamGia]) VALUES (N'TR33_M02',N'TR33_CAT',N'TR33_BR1',N'TRIAL33 Camera Model 02',N'Synthetic camera model',150000,1500000,0);

IF EXISTS(SELECT 1 FROM dbo.[DongMay] WHERE [MaDongMay]=N'TR33_M03')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[DongMay] WHERE [MaDongMay]=N'TR33_M03' AND (([MaDongMay] IS NULL AND N'TR33_M03' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M03' IS NULL) OR ([MaDongMay] <> N'TR33_M03') OR ([MaDanhMuc] IS NULL AND N'TR33_CAT' IS NOT NULL) OR ([MaDanhMuc] IS NOT NULL AND N'TR33_CAT' IS NULL) OR ([MaDanhMuc] <> N'TR33_CAT') OR ([MaThuongHieu] IS NULL AND N'TR33_BR1' IS NOT NULL) OR ([MaThuongHieu] IS NOT NULL AND N'TR33_BR1' IS NULL) OR ([MaThuongHieu] <> N'TR33_BR1') OR ([TenDongMay] IS NULL AND N'TRIAL33 Camera Model 03' IS NOT NULL) OR ([TenDongMay] IS NOT NULL AND N'TRIAL33 Camera Model 03' IS NULL) OR ([TenDongMay] <> N'TRIAL33 Camera Model 03') OR ([MoTa] IS NULL AND N'Synthetic camera model' IS NOT NULL) OR ([MoTa] IS NOT NULL AND N'Synthetic camera model' IS NULL) OR ([MoTa] <> N'Synthetic camera model') OR ([GiaThueNgay] IS NULL AND 175000 IS NOT NULL) OR ([GiaThueNgay] IS NOT NULL AND 175000 IS NULL) OR ([GiaThueNgay] <> 175000) OR ([TienCoc] IS NULL AND 1750000 IS NOT NULL) OR ([TienCoc] IS NOT NULL AND 1750000 IS NULL) OR ([TienCoc] <> 1750000) OR ([PhanTramGiamGia] IS NULL AND 0 IS NOT NULL) OR ([PhanTramGiamGia] IS NOT NULL AND 0 IS NULL) OR ([PhanTramGiamGia] <> 0))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[DongMay] ([MaDongMay],[MaDanhMuc],[MaThuongHieu],[TenDongMay],[MoTa],[GiaThueNgay],[TienCoc],[PhanTramGiamGia]) VALUES (N'TR33_M03',N'TR33_CAT',N'TR33_BR1',N'TRIAL33 Camera Model 03',N'Synthetic camera model',175000,1750000,0);

IF EXISTS(SELECT 1 FROM dbo.[DongMay] WHERE [MaDongMay]=N'TR33_M04')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[DongMay] WHERE [MaDongMay]=N'TR33_M04' AND (([MaDongMay] IS NULL AND N'TR33_M04' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M04' IS NULL) OR ([MaDongMay] <> N'TR33_M04') OR ([MaDanhMuc] IS NULL AND N'TR33_CAT' IS NOT NULL) OR ([MaDanhMuc] IS NOT NULL AND N'TR33_CAT' IS NULL) OR ([MaDanhMuc] <> N'TR33_CAT') OR ([MaThuongHieu] IS NULL AND N'TR33_BR2' IS NOT NULL) OR ([MaThuongHieu] IS NOT NULL AND N'TR33_BR2' IS NULL) OR ([MaThuongHieu] <> N'TR33_BR2') OR ([TenDongMay] IS NULL AND N'TRIAL33 Camera Model 04' IS NOT NULL) OR ([TenDongMay] IS NOT NULL AND N'TRIAL33 Camera Model 04' IS NULL) OR ([TenDongMay] <> N'TRIAL33 Camera Model 04') OR ([MoTa] IS NULL AND N'Synthetic camera model' IS NOT NULL) OR ([MoTa] IS NOT NULL AND N'Synthetic camera model' IS NULL) OR ([MoTa] <> N'Synthetic camera model') OR ([GiaThueNgay] IS NULL AND 200000 IS NOT NULL) OR ([GiaThueNgay] IS NOT NULL AND 200000 IS NULL) OR ([GiaThueNgay] <> 200000) OR ([TienCoc] IS NULL AND 2000000 IS NOT NULL) OR ([TienCoc] IS NOT NULL AND 2000000 IS NULL) OR ([TienCoc] <> 2000000) OR ([PhanTramGiamGia] IS NULL AND 0 IS NOT NULL) OR ([PhanTramGiamGia] IS NOT NULL AND 0 IS NULL) OR ([PhanTramGiamGia] <> 0))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[DongMay] ([MaDongMay],[MaDanhMuc],[MaThuongHieu],[TenDongMay],[MoTa],[GiaThueNgay],[TienCoc],[PhanTramGiamGia]) VALUES (N'TR33_M04',N'TR33_CAT',N'TR33_BR2',N'TRIAL33 Camera Model 04',N'Synthetic camera model',200000,2000000,0);

IF EXISTS(SELECT 1 FROM dbo.[DongMay] WHERE [MaDongMay]=N'TR33_M05')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[DongMay] WHERE [MaDongMay]=N'TR33_M05' AND (([MaDongMay] IS NULL AND N'TR33_M05' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M05' IS NULL) OR ([MaDongMay] <> N'TR33_M05') OR ([MaDanhMuc] IS NULL AND N'TR33_CAT' IS NOT NULL) OR ([MaDanhMuc] IS NOT NULL AND N'TR33_CAT' IS NULL) OR ([MaDanhMuc] <> N'TR33_CAT') OR ([MaThuongHieu] IS NULL AND N'TR33_BR2' IS NOT NULL) OR ([MaThuongHieu] IS NOT NULL AND N'TR33_BR2' IS NULL) OR ([MaThuongHieu] <> N'TR33_BR2') OR ([TenDongMay] IS NULL AND N'TRIAL33 Camera Model 05' IS NOT NULL) OR ([TenDongMay] IS NOT NULL AND N'TRIAL33 Camera Model 05' IS NULL) OR ([TenDongMay] <> N'TRIAL33 Camera Model 05') OR ([MoTa] IS NULL AND N'Synthetic camera model' IS NOT NULL) OR ([MoTa] IS NOT NULL AND N'Synthetic camera model' IS NULL) OR ([MoTa] <> N'Synthetic camera model') OR ([GiaThueNgay] IS NULL AND 225000 IS NOT NULL) OR ([GiaThueNgay] IS NOT NULL AND 225000 IS NULL) OR ([GiaThueNgay] <> 225000) OR ([TienCoc] IS NULL AND 2250000 IS NOT NULL) OR ([TienCoc] IS NOT NULL AND 2250000 IS NULL) OR ([TienCoc] <> 2250000) OR ([PhanTramGiamGia] IS NULL AND 0 IS NOT NULL) OR ([PhanTramGiamGia] IS NOT NULL AND 0 IS NULL) OR ([PhanTramGiamGia] <> 0))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[DongMay] ([MaDongMay],[MaDanhMuc],[MaThuongHieu],[TenDongMay],[MoTa],[GiaThueNgay],[TienCoc],[PhanTramGiamGia]) VALUES (N'TR33_M05',N'TR33_CAT',N'TR33_BR2',N'TRIAL33 Camera Model 05',N'Synthetic camera model',225000,2250000,0);

IF EXISTS(SELECT 1 FROM dbo.[DongMay] WHERE [MaDongMay]=N'TR33_M06')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[DongMay] WHERE [MaDongMay]=N'TR33_M06' AND (([MaDongMay] IS NULL AND N'TR33_M06' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M06' IS NULL) OR ([MaDongMay] <> N'TR33_M06') OR ([MaDanhMuc] IS NULL AND N'TR33_CAT' IS NOT NULL) OR ([MaDanhMuc] IS NOT NULL AND N'TR33_CAT' IS NULL) OR ([MaDanhMuc] <> N'TR33_CAT') OR ([MaThuongHieu] IS NULL AND N'TR33_BR2' IS NOT NULL) OR ([MaThuongHieu] IS NOT NULL AND N'TR33_BR2' IS NULL) OR ([MaThuongHieu] <> N'TR33_BR2') OR ([TenDongMay] IS NULL AND N'TRIAL33 Camera Model 06' IS NOT NULL) OR ([TenDongMay] IS NOT NULL AND N'TRIAL33 Camera Model 06' IS NULL) OR ([TenDongMay] <> N'TRIAL33 Camera Model 06') OR ([MoTa] IS NULL AND N'Synthetic camera model' IS NOT NULL) OR ([MoTa] IS NOT NULL AND N'Synthetic camera model' IS NULL) OR ([MoTa] <> N'Synthetic camera model') OR ([GiaThueNgay] IS NULL AND 250000 IS NOT NULL) OR ([GiaThueNgay] IS NOT NULL AND 250000 IS NULL) OR ([GiaThueNgay] <> 250000) OR ([TienCoc] IS NULL AND 2500000 IS NOT NULL) OR ([TienCoc] IS NOT NULL AND 2500000 IS NULL) OR ([TienCoc] <> 2500000) OR ([PhanTramGiamGia] IS NULL AND 0 IS NOT NULL) OR ([PhanTramGiamGia] IS NOT NULL AND 0 IS NULL) OR ([PhanTramGiamGia] <> 0))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[DongMay] ([MaDongMay],[MaDanhMuc],[MaThuongHieu],[TenDongMay],[MoTa],[GiaThueNgay],[TienCoc],[PhanTramGiamGia]) VALUES (N'TR33_M06',N'TR33_CAT',N'TR33_BR2',N'TRIAL33 Camera Model 06',N'Synthetic camera model',250000,2500000,0);

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M01D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M01D1' AND (([MaThietBi] IS NULL AND N'TR33_S01M01D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M01D1' IS NULL) OR ([MaThietBi] <> N'TR33_S01M01D1') OR ([MaDongMay] IS NULL AND N'TR33_M01' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M01' IS NULL) OR ([MaDongMay] <> N'TR33_M01') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M01-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M01-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M01-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M01D1',N'TR33_M01',N'TR33_S01',N'SN-TR33-S01-M01-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M01D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M01D2' AND (([MaThietBi] IS NULL AND N'TR33_S01M01D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M01D2' IS NULL) OR ([MaThietBi] <> N'TR33_S01M01D2') OR ([MaDongMay] IS NULL AND N'TR33_M01' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M01' IS NULL) OR ([MaDongMay] <> N'TR33_M01') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M01-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M01-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M01-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M01D2',N'TR33_M01',N'TR33_S01',N'SN-TR33-S01-M01-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M01D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M01D3' AND (([MaThietBi] IS NULL AND N'TR33_S01M01D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M01D3' IS NULL) OR ([MaThietBi] <> N'TR33_S01M01D3') OR ([MaDongMay] IS NULL AND N'TR33_M01' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M01' IS NULL) OR ([MaDongMay] <> N'TR33_M01') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M01-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M01-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M01-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M01D3',N'TR33_M01',N'TR33_S01',N'SN-TR33-S01-M01-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M01D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M01D4' AND (([MaThietBi] IS NULL AND N'TR33_S01M01D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M01D4' IS NULL) OR ([MaThietBi] <> N'TR33_S01M01D4') OR ([MaDongMay] IS NULL AND N'TR33_M01' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M01' IS NULL) OR ([MaDongMay] <> N'TR33_M01') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M01-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M01-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M01-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M01D4',N'TR33_M01',N'TR33_S01',N'SN-TR33-S01-M01-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M01D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M01D5' AND (([MaThietBi] IS NULL AND N'TR33_S01M01D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M01D5' IS NULL) OR ([MaThietBi] <> N'TR33_S01M01D5') OR ([MaDongMay] IS NULL AND N'TR33_M01' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M01' IS NULL) OR ([MaDongMay] <> N'TR33_M01') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M01-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M01-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M01-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M01D5',N'TR33_M01',N'TR33_S01',N'SN-TR33-S01-M01-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M01D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M01D1' AND (([MaThietBi] IS NULL AND N'TR33_S02M01D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M01D1' IS NULL) OR ([MaThietBi] <> N'TR33_S02M01D1') OR ([MaDongMay] IS NULL AND N'TR33_M01' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M01' IS NULL) OR ([MaDongMay] <> N'TR33_M01') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M01-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M01-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M01-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M01D1',N'TR33_M01',N'TR33_S02',N'SN-TR33-S02-M01-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M01D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M01D2' AND (([MaThietBi] IS NULL AND N'TR33_S02M01D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M01D2' IS NULL) OR ([MaThietBi] <> N'TR33_S02M01D2') OR ([MaDongMay] IS NULL AND N'TR33_M01' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M01' IS NULL) OR ([MaDongMay] <> N'TR33_M01') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M01-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M01-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M01-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M01D2',N'TR33_M01',N'TR33_S02',N'SN-TR33-S02-M01-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M01D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M01D3' AND (([MaThietBi] IS NULL AND N'TR33_S02M01D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M01D3' IS NULL) OR ([MaThietBi] <> N'TR33_S02M01D3') OR ([MaDongMay] IS NULL AND N'TR33_M01' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M01' IS NULL) OR ([MaDongMay] <> N'TR33_M01') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M01-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M01-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M01-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M01D3',N'TR33_M01',N'TR33_S02',N'SN-TR33-S02-M01-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M01D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M01D4' AND (([MaThietBi] IS NULL AND N'TR33_S02M01D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M01D4' IS NULL) OR ([MaThietBi] <> N'TR33_S02M01D4') OR ([MaDongMay] IS NULL AND N'TR33_M01' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M01' IS NULL) OR ([MaDongMay] <> N'TR33_M01') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M01-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M01-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M01-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M01D4',N'TR33_M01',N'TR33_S02',N'SN-TR33-S02-M01-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M01D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M01D5' AND (([MaThietBi] IS NULL AND N'TR33_S02M01D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M01D5' IS NULL) OR ([MaThietBi] <> N'TR33_S02M01D5') OR ([MaDongMay] IS NULL AND N'TR33_M01' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M01' IS NULL) OR ([MaDongMay] <> N'TR33_M01') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M01-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M01-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M01-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M01D5',N'TR33_M01',N'TR33_S02',N'SN-TR33-S02-M01-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M01D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M01D1' AND (([MaThietBi] IS NULL AND N'TR33_S03M01D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M01D1' IS NULL) OR ([MaThietBi] <> N'TR33_S03M01D1') OR ([MaDongMay] IS NULL AND N'TR33_M01' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M01' IS NULL) OR ([MaDongMay] <> N'TR33_M01') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M01-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M01-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M01-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M01D1',N'TR33_M01',N'TR33_S03',N'SN-TR33-S03-M01-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M01D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M01D2' AND (([MaThietBi] IS NULL AND N'TR33_S03M01D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M01D2' IS NULL) OR ([MaThietBi] <> N'TR33_S03M01D2') OR ([MaDongMay] IS NULL AND N'TR33_M01' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M01' IS NULL) OR ([MaDongMay] <> N'TR33_M01') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M01-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M01-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M01-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M01D2',N'TR33_M01',N'TR33_S03',N'SN-TR33-S03-M01-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M01D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M01D3' AND (([MaThietBi] IS NULL AND N'TR33_S03M01D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M01D3' IS NULL) OR ([MaThietBi] <> N'TR33_S03M01D3') OR ([MaDongMay] IS NULL AND N'TR33_M01' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M01' IS NULL) OR ([MaDongMay] <> N'TR33_M01') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M01-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M01-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M01-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M01D3',N'TR33_M01',N'TR33_S03',N'SN-TR33-S03-M01-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M01D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M01D4' AND (([MaThietBi] IS NULL AND N'TR33_S03M01D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M01D4' IS NULL) OR ([MaThietBi] <> N'TR33_S03M01D4') OR ([MaDongMay] IS NULL AND N'TR33_M01' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M01' IS NULL) OR ([MaDongMay] <> N'TR33_M01') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M01-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M01-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M01-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M01D4',N'TR33_M01',N'TR33_S03',N'SN-TR33-S03-M01-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M01D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M01D5' AND (([MaThietBi] IS NULL AND N'TR33_S03M01D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M01D5' IS NULL) OR ([MaThietBi] <> N'TR33_S03M01D5') OR ([MaDongMay] IS NULL AND N'TR33_M01' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M01' IS NULL) OR ([MaDongMay] <> N'TR33_M01') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M01-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M01-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M01-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M01D5',N'TR33_M01',N'TR33_S03',N'SN-TR33-S03-M01-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M02D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M02D1' AND (([MaThietBi] IS NULL AND N'TR33_S01M02D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M02D1' IS NULL) OR ([MaThietBi] <> N'TR33_S01M02D1') OR ([MaDongMay] IS NULL AND N'TR33_M02' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M02' IS NULL) OR ([MaDongMay] <> N'TR33_M02') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M02-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M02-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M02-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M02D1',N'TR33_M02',N'TR33_S01',N'SN-TR33-S01-M02-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M02D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M02D2' AND (([MaThietBi] IS NULL AND N'TR33_S01M02D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M02D2' IS NULL) OR ([MaThietBi] <> N'TR33_S01M02D2') OR ([MaDongMay] IS NULL AND N'TR33_M02' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M02' IS NULL) OR ([MaDongMay] <> N'TR33_M02') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M02-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M02-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M02-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M02D2',N'TR33_M02',N'TR33_S01',N'SN-TR33-S01-M02-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M02D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M02D3' AND (([MaThietBi] IS NULL AND N'TR33_S01M02D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M02D3' IS NULL) OR ([MaThietBi] <> N'TR33_S01M02D3') OR ([MaDongMay] IS NULL AND N'TR33_M02' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M02' IS NULL) OR ([MaDongMay] <> N'TR33_M02') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M02-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M02-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M02-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M02D3',N'TR33_M02',N'TR33_S01',N'SN-TR33-S01-M02-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M02D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M02D4' AND (([MaThietBi] IS NULL AND N'TR33_S01M02D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M02D4' IS NULL) OR ([MaThietBi] <> N'TR33_S01M02D4') OR ([MaDongMay] IS NULL AND N'TR33_M02' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M02' IS NULL) OR ([MaDongMay] <> N'TR33_M02') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M02-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M02-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M02-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M02D4',N'TR33_M02',N'TR33_S01',N'SN-TR33-S01-M02-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M02D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M02D5' AND (([MaThietBi] IS NULL AND N'TR33_S01M02D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M02D5' IS NULL) OR ([MaThietBi] <> N'TR33_S01M02D5') OR ([MaDongMay] IS NULL AND N'TR33_M02' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M02' IS NULL) OR ([MaDongMay] <> N'TR33_M02') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M02-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M02-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M02-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M02D5',N'TR33_M02',N'TR33_S01',N'SN-TR33-S01-M02-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M02D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M02D1' AND (([MaThietBi] IS NULL AND N'TR33_S02M02D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M02D1' IS NULL) OR ([MaThietBi] <> N'TR33_S02M02D1') OR ([MaDongMay] IS NULL AND N'TR33_M02' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M02' IS NULL) OR ([MaDongMay] <> N'TR33_M02') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M02-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M02-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M02-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M02D1',N'TR33_M02',N'TR33_S02',N'SN-TR33-S02-M02-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M02D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M02D2' AND (([MaThietBi] IS NULL AND N'TR33_S02M02D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M02D2' IS NULL) OR ([MaThietBi] <> N'TR33_S02M02D2') OR ([MaDongMay] IS NULL AND N'TR33_M02' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M02' IS NULL) OR ([MaDongMay] <> N'TR33_M02') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M02-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M02-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M02-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M02D2',N'TR33_M02',N'TR33_S02',N'SN-TR33-S02-M02-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M02D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M02D3' AND (([MaThietBi] IS NULL AND N'TR33_S02M02D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M02D3' IS NULL) OR ([MaThietBi] <> N'TR33_S02M02D3') OR ([MaDongMay] IS NULL AND N'TR33_M02' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M02' IS NULL) OR ([MaDongMay] <> N'TR33_M02') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M02-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M02-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M02-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M02D3',N'TR33_M02',N'TR33_S02',N'SN-TR33-S02-M02-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M02D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M02D4' AND (([MaThietBi] IS NULL AND N'TR33_S02M02D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M02D4' IS NULL) OR ([MaThietBi] <> N'TR33_S02M02D4') OR ([MaDongMay] IS NULL AND N'TR33_M02' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M02' IS NULL) OR ([MaDongMay] <> N'TR33_M02') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M02-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M02-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M02-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M02D4',N'TR33_M02',N'TR33_S02',N'SN-TR33-S02-M02-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M02D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M02D5' AND (([MaThietBi] IS NULL AND N'TR33_S02M02D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M02D5' IS NULL) OR ([MaThietBi] <> N'TR33_S02M02D5') OR ([MaDongMay] IS NULL AND N'TR33_M02' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M02' IS NULL) OR ([MaDongMay] <> N'TR33_M02') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M02-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M02-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M02-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M02D5',N'TR33_M02',N'TR33_S02',N'SN-TR33-S02-M02-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M02D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M02D1' AND (([MaThietBi] IS NULL AND N'TR33_S03M02D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M02D1' IS NULL) OR ([MaThietBi] <> N'TR33_S03M02D1') OR ([MaDongMay] IS NULL AND N'TR33_M02' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M02' IS NULL) OR ([MaDongMay] <> N'TR33_M02') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M02-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M02-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M02-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M02D1',N'TR33_M02',N'TR33_S03',N'SN-TR33-S03-M02-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M02D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M02D2' AND (([MaThietBi] IS NULL AND N'TR33_S03M02D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M02D2' IS NULL) OR ([MaThietBi] <> N'TR33_S03M02D2') OR ([MaDongMay] IS NULL AND N'TR33_M02' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M02' IS NULL) OR ([MaDongMay] <> N'TR33_M02') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M02-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M02-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M02-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M02D2',N'TR33_M02',N'TR33_S03',N'SN-TR33-S03-M02-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M02D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M02D3' AND (([MaThietBi] IS NULL AND N'TR33_S03M02D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M02D3' IS NULL) OR ([MaThietBi] <> N'TR33_S03M02D3') OR ([MaDongMay] IS NULL AND N'TR33_M02' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M02' IS NULL) OR ([MaDongMay] <> N'TR33_M02') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M02-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M02-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M02-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M02D3',N'TR33_M02',N'TR33_S03',N'SN-TR33-S03-M02-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M02D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M02D4' AND (([MaThietBi] IS NULL AND N'TR33_S03M02D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M02D4' IS NULL) OR ([MaThietBi] <> N'TR33_S03M02D4') OR ([MaDongMay] IS NULL AND N'TR33_M02' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M02' IS NULL) OR ([MaDongMay] <> N'TR33_M02') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M02-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M02-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M02-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M02D4',N'TR33_M02',N'TR33_S03',N'SN-TR33-S03-M02-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M02D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M02D5' AND (([MaThietBi] IS NULL AND N'TR33_S03M02D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M02D5' IS NULL) OR ([MaThietBi] <> N'TR33_S03M02D5') OR ([MaDongMay] IS NULL AND N'TR33_M02' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M02' IS NULL) OR ([MaDongMay] <> N'TR33_M02') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M02-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M02-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M02-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M02D5',N'TR33_M02',N'TR33_S03',N'SN-TR33-S03-M02-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M03D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M03D1' AND (([MaThietBi] IS NULL AND N'TR33_S01M03D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M03D1' IS NULL) OR ([MaThietBi] <> N'TR33_S01M03D1') OR ([MaDongMay] IS NULL AND N'TR33_M03' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M03' IS NULL) OR ([MaDongMay] <> N'TR33_M03') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M03-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M03-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M03-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M03D1',N'TR33_M03',N'TR33_S01',N'SN-TR33-S01-M03-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M03D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M03D2' AND (([MaThietBi] IS NULL AND N'TR33_S01M03D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M03D2' IS NULL) OR ([MaThietBi] <> N'TR33_S01M03D2') OR ([MaDongMay] IS NULL AND N'TR33_M03' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M03' IS NULL) OR ([MaDongMay] <> N'TR33_M03') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M03-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M03-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M03-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M03D2',N'TR33_M03',N'TR33_S01',N'SN-TR33-S01-M03-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M03D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M03D3' AND (([MaThietBi] IS NULL AND N'TR33_S01M03D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M03D3' IS NULL) OR ([MaThietBi] <> N'TR33_S01M03D3') OR ([MaDongMay] IS NULL AND N'TR33_M03' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M03' IS NULL) OR ([MaDongMay] <> N'TR33_M03') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M03-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M03-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M03-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M03D3',N'TR33_M03',N'TR33_S01',N'SN-TR33-S01-M03-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M03D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M03D4' AND (([MaThietBi] IS NULL AND N'TR33_S01M03D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M03D4' IS NULL) OR ([MaThietBi] <> N'TR33_S01M03D4') OR ([MaDongMay] IS NULL AND N'TR33_M03' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M03' IS NULL) OR ([MaDongMay] <> N'TR33_M03') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M03-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M03-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M03-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M03D4',N'TR33_M03',N'TR33_S01',N'SN-TR33-S01-M03-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M03D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M03D5' AND (([MaThietBi] IS NULL AND N'TR33_S01M03D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M03D5' IS NULL) OR ([MaThietBi] <> N'TR33_S01M03D5') OR ([MaDongMay] IS NULL AND N'TR33_M03' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M03' IS NULL) OR ([MaDongMay] <> N'TR33_M03') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M03-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M03-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M03-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M03D5',N'TR33_M03',N'TR33_S01',N'SN-TR33-S01-M03-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M03D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M03D1' AND (([MaThietBi] IS NULL AND N'TR33_S02M03D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M03D1' IS NULL) OR ([MaThietBi] <> N'TR33_S02M03D1') OR ([MaDongMay] IS NULL AND N'TR33_M03' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M03' IS NULL) OR ([MaDongMay] <> N'TR33_M03') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M03-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M03-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M03-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M03D1',N'TR33_M03',N'TR33_S02',N'SN-TR33-S02-M03-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M03D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M03D2' AND (([MaThietBi] IS NULL AND N'TR33_S02M03D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M03D2' IS NULL) OR ([MaThietBi] <> N'TR33_S02M03D2') OR ([MaDongMay] IS NULL AND N'TR33_M03' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M03' IS NULL) OR ([MaDongMay] <> N'TR33_M03') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M03-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M03-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M03-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M03D2',N'TR33_M03',N'TR33_S02',N'SN-TR33-S02-M03-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M03D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M03D3' AND (([MaThietBi] IS NULL AND N'TR33_S02M03D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M03D3' IS NULL) OR ([MaThietBi] <> N'TR33_S02M03D3') OR ([MaDongMay] IS NULL AND N'TR33_M03' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M03' IS NULL) OR ([MaDongMay] <> N'TR33_M03') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M03-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M03-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M03-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M03D3',N'TR33_M03',N'TR33_S02',N'SN-TR33-S02-M03-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M03D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M03D4' AND (([MaThietBi] IS NULL AND N'TR33_S02M03D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M03D4' IS NULL) OR ([MaThietBi] <> N'TR33_S02M03D4') OR ([MaDongMay] IS NULL AND N'TR33_M03' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M03' IS NULL) OR ([MaDongMay] <> N'TR33_M03') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M03-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M03-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M03-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M03D4',N'TR33_M03',N'TR33_S02',N'SN-TR33-S02-M03-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M03D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M03D5' AND (([MaThietBi] IS NULL AND N'TR33_S02M03D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M03D5' IS NULL) OR ([MaThietBi] <> N'TR33_S02M03D5') OR ([MaDongMay] IS NULL AND N'TR33_M03' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M03' IS NULL) OR ([MaDongMay] <> N'TR33_M03') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M03-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M03-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M03-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M03D5',N'TR33_M03',N'TR33_S02',N'SN-TR33-S02-M03-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M03D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M03D1' AND (([MaThietBi] IS NULL AND N'TR33_S03M03D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M03D1' IS NULL) OR ([MaThietBi] <> N'TR33_S03M03D1') OR ([MaDongMay] IS NULL AND N'TR33_M03' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M03' IS NULL) OR ([MaDongMay] <> N'TR33_M03') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M03-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M03-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M03-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M03D1',N'TR33_M03',N'TR33_S03',N'SN-TR33-S03-M03-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M03D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M03D2' AND (([MaThietBi] IS NULL AND N'TR33_S03M03D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M03D2' IS NULL) OR ([MaThietBi] <> N'TR33_S03M03D2') OR ([MaDongMay] IS NULL AND N'TR33_M03' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M03' IS NULL) OR ([MaDongMay] <> N'TR33_M03') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M03-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M03-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M03-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M03D2',N'TR33_M03',N'TR33_S03',N'SN-TR33-S03-M03-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M03D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M03D3' AND (([MaThietBi] IS NULL AND N'TR33_S03M03D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M03D3' IS NULL) OR ([MaThietBi] <> N'TR33_S03M03D3') OR ([MaDongMay] IS NULL AND N'TR33_M03' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M03' IS NULL) OR ([MaDongMay] <> N'TR33_M03') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M03-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M03-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M03-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M03D3',N'TR33_M03',N'TR33_S03',N'SN-TR33-S03-M03-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M03D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M03D4' AND (([MaThietBi] IS NULL AND N'TR33_S03M03D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M03D4' IS NULL) OR ([MaThietBi] <> N'TR33_S03M03D4') OR ([MaDongMay] IS NULL AND N'TR33_M03' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M03' IS NULL) OR ([MaDongMay] <> N'TR33_M03') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M03-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M03-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M03-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M03D4',N'TR33_M03',N'TR33_S03',N'SN-TR33-S03-M03-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M03D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M03D5' AND (([MaThietBi] IS NULL AND N'TR33_S03M03D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M03D5' IS NULL) OR ([MaThietBi] <> N'TR33_S03M03D5') OR ([MaDongMay] IS NULL AND N'TR33_M03' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M03' IS NULL) OR ([MaDongMay] <> N'TR33_M03') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M03-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M03-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M03-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M03D5',N'TR33_M03',N'TR33_S03',N'SN-TR33-S03-M03-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M04D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M04D1' AND (([MaThietBi] IS NULL AND N'TR33_S01M04D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M04D1' IS NULL) OR ([MaThietBi] <> N'TR33_S01M04D1') OR ([MaDongMay] IS NULL AND N'TR33_M04' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M04' IS NULL) OR ([MaDongMay] <> N'TR33_M04') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M04-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M04-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M04-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M04D1',N'TR33_M04',N'TR33_S01',N'SN-TR33-S01-M04-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M04D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M04D2' AND (([MaThietBi] IS NULL AND N'TR33_S01M04D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M04D2' IS NULL) OR ([MaThietBi] <> N'TR33_S01M04D2') OR ([MaDongMay] IS NULL AND N'TR33_M04' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M04' IS NULL) OR ([MaDongMay] <> N'TR33_M04') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M04-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M04-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M04-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M04D2',N'TR33_M04',N'TR33_S01',N'SN-TR33-S01-M04-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M04D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M04D3' AND (([MaThietBi] IS NULL AND N'TR33_S01M04D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M04D3' IS NULL) OR ([MaThietBi] <> N'TR33_S01M04D3') OR ([MaDongMay] IS NULL AND N'TR33_M04' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M04' IS NULL) OR ([MaDongMay] <> N'TR33_M04') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M04-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M04-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M04-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M04D3',N'TR33_M04',N'TR33_S01',N'SN-TR33-S01-M04-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M04D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M04D4' AND (([MaThietBi] IS NULL AND N'TR33_S01M04D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M04D4' IS NULL) OR ([MaThietBi] <> N'TR33_S01M04D4') OR ([MaDongMay] IS NULL AND N'TR33_M04' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M04' IS NULL) OR ([MaDongMay] <> N'TR33_M04') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M04-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M04-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M04-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M04D4',N'TR33_M04',N'TR33_S01',N'SN-TR33-S01-M04-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M04D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M04D5' AND (([MaThietBi] IS NULL AND N'TR33_S01M04D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M04D5' IS NULL) OR ([MaThietBi] <> N'TR33_S01M04D5') OR ([MaDongMay] IS NULL AND N'TR33_M04' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M04' IS NULL) OR ([MaDongMay] <> N'TR33_M04') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M04-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M04-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M04-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M04D5',N'TR33_M04',N'TR33_S01',N'SN-TR33-S01-M04-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M04D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M04D1' AND (([MaThietBi] IS NULL AND N'TR33_S02M04D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M04D1' IS NULL) OR ([MaThietBi] <> N'TR33_S02M04D1') OR ([MaDongMay] IS NULL AND N'TR33_M04' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M04' IS NULL) OR ([MaDongMay] <> N'TR33_M04') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M04-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M04-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M04-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M04D1',N'TR33_M04',N'TR33_S02',N'SN-TR33-S02-M04-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M04D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M04D2' AND (([MaThietBi] IS NULL AND N'TR33_S02M04D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M04D2' IS NULL) OR ([MaThietBi] <> N'TR33_S02M04D2') OR ([MaDongMay] IS NULL AND N'TR33_M04' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M04' IS NULL) OR ([MaDongMay] <> N'TR33_M04') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M04-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M04-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M04-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M04D2',N'TR33_M04',N'TR33_S02',N'SN-TR33-S02-M04-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M04D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M04D3' AND (([MaThietBi] IS NULL AND N'TR33_S02M04D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M04D3' IS NULL) OR ([MaThietBi] <> N'TR33_S02M04D3') OR ([MaDongMay] IS NULL AND N'TR33_M04' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M04' IS NULL) OR ([MaDongMay] <> N'TR33_M04') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M04-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M04-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M04-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M04D3',N'TR33_M04',N'TR33_S02',N'SN-TR33-S02-M04-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M04D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M04D4' AND (([MaThietBi] IS NULL AND N'TR33_S02M04D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M04D4' IS NULL) OR ([MaThietBi] <> N'TR33_S02M04D4') OR ([MaDongMay] IS NULL AND N'TR33_M04' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M04' IS NULL) OR ([MaDongMay] <> N'TR33_M04') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M04-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M04-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M04-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M04D4',N'TR33_M04',N'TR33_S02',N'SN-TR33-S02-M04-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M04D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M04D5' AND (([MaThietBi] IS NULL AND N'TR33_S02M04D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M04D5' IS NULL) OR ([MaThietBi] <> N'TR33_S02M04D5') OR ([MaDongMay] IS NULL AND N'TR33_M04' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M04' IS NULL) OR ([MaDongMay] <> N'TR33_M04') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M04-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M04-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M04-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M04D5',N'TR33_M04',N'TR33_S02',N'SN-TR33-S02-M04-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M04D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M04D1' AND (([MaThietBi] IS NULL AND N'TR33_S03M04D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M04D1' IS NULL) OR ([MaThietBi] <> N'TR33_S03M04D1') OR ([MaDongMay] IS NULL AND N'TR33_M04' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M04' IS NULL) OR ([MaDongMay] <> N'TR33_M04') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M04-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M04-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M04-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M04D1',N'TR33_M04',N'TR33_S03',N'SN-TR33-S03-M04-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M04D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M04D2' AND (([MaThietBi] IS NULL AND N'TR33_S03M04D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M04D2' IS NULL) OR ([MaThietBi] <> N'TR33_S03M04D2') OR ([MaDongMay] IS NULL AND N'TR33_M04' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M04' IS NULL) OR ([MaDongMay] <> N'TR33_M04') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M04-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M04-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M04-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M04D2',N'TR33_M04',N'TR33_S03',N'SN-TR33-S03-M04-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M04D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M04D3' AND (([MaThietBi] IS NULL AND N'TR33_S03M04D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M04D3' IS NULL) OR ([MaThietBi] <> N'TR33_S03M04D3') OR ([MaDongMay] IS NULL AND N'TR33_M04' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M04' IS NULL) OR ([MaDongMay] <> N'TR33_M04') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M04-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M04-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M04-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M04D3',N'TR33_M04',N'TR33_S03',N'SN-TR33-S03-M04-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M04D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M04D4' AND (([MaThietBi] IS NULL AND N'TR33_S03M04D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M04D4' IS NULL) OR ([MaThietBi] <> N'TR33_S03M04D4') OR ([MaDongMay] IS NULL AND N'TR33_M04' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M04' IS NULL) OR ([MaDongMay] <> N'TR33_M04') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M04-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M04-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M04-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M04D4',N'TR33_M04',N'TR33_S03',N'SN-TR33-S03-M04-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M04D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M04D5' AND (([MaThietBi] IS NULL AND N'TR33_S03M04D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M04D5' IS NULL) OR ([MaThietBi] <> N'TR33_S03M04D5') OR ([MaDongMay] IS NULL AND N'TR33_M04' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M04' IS NULL) OR ([MaDongMay] <> N'TR33_M04') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M04-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M04-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M04-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M04D5',N'TR33_M04',N'TR33_S03',N'SN-TR33-S03-M04-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M05D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M05D1' AND (([MaThietBi] IS NULL AND N'TR33_S01M05D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M05D1' IS NULL) OR ([MaThietBi] <> N'TR33_S01M05D1') OR ([MaDongMay] IS NULL AND N'TR33_M05' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M05' IS NULL) OR ([MaDongMay] <> N'TR33_M05') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M05-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M05-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M05-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M05D1',N'TR33_M05',N'TR33_S01',N'SN-TR33-S01-M05-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M05D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M05D2' AND (([MaThietBi] IS NULL AND N'TR33_S01M05D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M05D2' IS NULL) OR ([MaThietBi] <> N'TR33_S01M05D2') OR ([MaDongMay] IS NULL AND N'TR33_M05' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M05' IS NULL) OR ([MaDongMay] <> N'TR33_M05') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M05-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M05-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M05-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M05D2',N'TR33_M05',N'TR33_S01',N'SN-TR33-S01-M05-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M05D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M05D3' AND (([MaThietBi] IS NULL AND N'TR33_S01M05D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M05D3' IS NULL) OR ([MaThietBi] <> N'TR33_S01M05D3') OR ([MaDongMay] IS NULL AND N'TR33_M05' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M05' IS NULL) OR ([MaDongMay] <> N'TR33_M05') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M05-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M05-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M05-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M05D3',N'TR33_M05',N'TR33_S01',N'SN-TR33-S01-M05-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M05D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M05D4' AND (([MaThietBi] IS NULL AND N'TR33_S01M05D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M05D4' IS NULL) OR ([MaThietBi] <> N'TR33_S01M05D4') OR ([MaDongMay] IS NULL AND N'TR33_M05' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M05' IS NULL) OR ([MaDongMay] <> N'TR33_M05') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M05-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M05-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M05-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M05D4',N'TR33_M05',N'TR33_S01',N'SN-TR33-S01-M05-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M05D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M05D5' AND (([MaThietBi] IS NULL AND N'TR33_S01M05D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M05D5' IS NULL) OR ([MaThietBi] <> N'TR33_S01M05D5') OR ([MaDongMay] IS NULL AND N'TR33_M05' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M05' IS NULL) OR ([MaDongMay] <> N'TR33_M05') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M05-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M05-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M05-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M05D5',N'TR33_M05',N'TR33_S01',N'SN-TR33-S01-M05-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M05D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M05D1' AND (([MaThietBi] IS NULL AND N'TR33_S02M05D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M05D1' IS NULL) OR ([MaThietBi] <> N'TR33_S02M05D1') OR ([MaDongMay] IS NULL AND N'TR33_M05' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M05' IS NULL) OR ([MaDongMay] <> N'TR33_M05') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M05-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M05-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M05-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M05D1',N'TR33_M05',N'TR33_S02',N'SN-TR33-S02-M05-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M05D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M05D2' AND (([MaThietBi] IS NULL AND N'TR33_S02M05D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M05D2' IS NULL) OR ([MaThietBi] <> N'TR33_S02M05D2') OR ([MaDongMay] IS NULL AND N'TR33_M05' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M05' IS NULL) OR ([MaDongMay] <> N'TR33_M05') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M05-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M05-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M05-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M05D2',N'TR33_M05',N'TR33_S02',N'SN-TR33-S02-M05-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M05D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M05D3' AND (([MaThietBi] IS NULL AND N'TR33_S02M05D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M05D3' IS NULL) OR ([MaThietBi] <> N'TR33_S02M05D3') OR ([MaDongMay] IS NULL AND N'TR33_M05' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M05' IS NULL) OR ([MaDongMay] <> N'TR33_M05') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M05-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M05-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M05-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M05D3',N'TR33_M05',N'TR33_S02',N'SN-TR33-S02-M05-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M05D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M05D4' AND (([MaThietBi] IS NULL AND N'TR33_S02M05D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M05D4' IS NULL) OR ([MaThietBi] <> N'TR33_S02M05D4') OR ([MaDongMay] IS NULL AND N'TR33_M05' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M05' IS NULL) OR ([MaDongMay] <> N'TR33_M05') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M05-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M05-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M05-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M05D4',N'TR33_M05',N'TR33_S02',N'SN-TR33-S02-M05-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M05D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M05D5' AND (([MaThietBi] IS NULL AND N'TR33_S02M05D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M05D5' IS NULL) OR ([MaThietBi] <> N'TR33_S02M05D5') OR ([MaDongMay] IS NULL AND N'TR33_M05' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M05' IS NULL) OR ([MaDongMay] <> N'TR33_M05') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M05-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M05-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M05-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M05D5',N'TR33_M05',N'TR33_S02',N'SN-TR33-S02-M05-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M05D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M05D1' AND (([MaThietBi] IS NULL AND N'TR33_S03M05D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M05D1' IS NULL) OR ([MaThietBi] <> N'TR33_S03M05D1') OR ([MaDongMay] IS NULL AND N'TR33_M05' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M05' IS NULL) OR ([MaDongMay] <> N'TR33_M05') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M05-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M05-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M05-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M05D1',N'TR33_M05',N'TR33_S03',N'SN-TR33-S03-M05-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M05D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M05D2' AND (([MaThietBi] IS NULL AND N'TR33_S03M05D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M05D2' IS NULL) OR ([MaThietBi] <> N'TR33_S03M05D2') OR ([MaDongMay] IS NULL AND N'TR33_M05' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M05' IS NULL) OR ([MaDongMay] <> N'TR33_M05') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M05-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M05-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M05-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M05D2',N'TR33_M05',N'TR33_S03',N'SN-TR33-S03-M05-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M05D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M05D3' AND (([MaThietBi] IS NULL AND N'TR33_S03M05D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M05D3' IS NULL) OR ([MaThietBi] <> N'TR33_S03M05D3') OR ([MaDongMay] IS NULL AND N'TR33_M05' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M05' IS NULL) OR ([MaDongMay] <> N'TR33_M05') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M05-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M05-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M05-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M05D3',N'TR33_M05',N'TR33_S03',N'SN-TR33-S03-M05-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M05D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M05D4' AND (([MaThietBi] IS NULL AND N'TR33_S03M05D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M05D4' IS NULL) OR ([MaThietBi] <> N'TR33_S03M05D4') OR ([MaDongMay] IS NULL AND N'TR33_M05' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M05' IS NULL) OR ([MaDongMay] <> N'TR33_M05') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M05-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M05-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M05-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M05D4',N'TR33_M05',N'TR33_S03',N'SN-TR33-S03-M05-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M05D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M05D5' AND (([MaThietBi] IS NULL AND N'TR33_S03M05D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M05D5' IS NULL) OR ([MaThietBi] <> N'TR33_S03M05D5') OR ([MaDongMay] IS NULL AND N'TR33_M05' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M05' IS NULL) OR ([MaDongMay] <> N'TR33_M05') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M05-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M05-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M05-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M05D5',N'TR33_M05',N'TR33_S03',N'SN-TR33-S03-M05-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M06D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M06D1' AND (([MaThietBi] IS NULL AND N'TR33_S01M06D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M06D1' IS NULL) OR ([MaThietBi] <> N'TR33_S01M06D1') OR ([MaDongMay] IS NULL AND N'TR33_M06' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M06' IS NULL) OR ([MaDongMay] <> N'TR33_M06') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M06-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M06-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M06-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M06D1',N'TR33_M06',N'TR33_S01',N'SN-TR33-S01-M06-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M06D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M06D2' AND (([MaThietBi] IS NULL AND N'TR33_S01M06D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M06D2' IS NULL) OR ([MaThietBi] <> N'TR33_S01M06D2') OR ([MaDongMay] IS NULL AND N'TR33_M06' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M06' IS NULL) OR ([MaDongMay] <> N'TR33_M06') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M06-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M06-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M06-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M06D2',N'TR33_M06',N'TR33_S01',N'SN-TR33-S01-M06-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M06D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M06D3' AND (([MaThietBi] IS NULL AND N'TR33_S01M06D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M06D3' IS NULL) OR ([MaThietBi] <> N'TR33_S01M06D3') OR ([MaDongMay] IS NULL AND N'TR33_M06' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M06' IS NULL) OR ([MaDongMay] <> N'TR33_M06') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M06-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M06-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M06-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M06D3',N'TR33_M06',N'TR33_S01',N'SN-TR33-S01-M06-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M06D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M06D4' AND (([MaThietBi] IS NULL AND N'TR33_S01M06D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M06D4' IS NULL) OR ([MaThietBi] <> N'TR33_S01M06D4') OR ([MaDongMay] IS NULL AND N'TR33_M06' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M06' IS NULL) OR ([MaDongMay] <> N'TR33_M06') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M06-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M06-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M06-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M06D4',N'TR33_M06',N'TR33_S01',N'SN-TR33-S01-M06-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M06D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S01M06D5' AND (([MaThietBi] IS NULL AND N'TR33_S01M06D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S01M06D5' IS NULL) OR ([MaThietBi] <> N'TR33_S01M06D5') OR ([MaDongMay] IS NULL AND N'TR33_M06' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M06' IS NULL) OR ([MaDongMay] <> N'TR33_M06') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([SoSerial] IS NULL AND N'SN-TR33-S01-M06-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S01-M06-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S01-M06-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S01M06D5',N'TR33_M06',N'TR33_S01',N'SN-TR33-S01-M06-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M06D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M06D1' AND (([MaThietBi] IS NULL AND N'TR33_S02M06D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M06D1' IS NULL) OR ([MaThietBi] <> N'TR33_S02M06D1') OR ([MaDongMay] IS NULL AND N'TR33_M06' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M06' IS NULL) OR ([MaDongMay] <> N'TR33_M06') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M06-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M06-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M06-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M06D1',N'TR33_M06',N'TR33_S02',N'SN-TR33-S02-M06-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M06D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M06D2' AND (([MaThietBi] IS NULL AND N'TR33_S02M06D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M06D2' IS NULL) OR ([MaThietBi] <> N'TR33_S02M06D2') OR ([MaDongMay] IS NULL AND N'TR33_M06' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M06' IS NULL) OR ([MaDongMay] <> N'TR33_M06') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M06-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M06-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M06-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M06D2',N'TR33_M06',N'TR33_S02',N'SN-TR33-S02-M06-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M06D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M06D3' AND (([MaThietBi] IS NULL AND N'TR33_S02M06D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M06D3' IS NULL) OR ([MaThietBi] <> N'TR33_S02M06D3') OR ([MaDongMay] IS NULL AND N'TR33_M06' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M06' IS NULL) OR ([MaDongMay] <> N'TR33_M06') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M06-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M06-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M06-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M06D3',N'TR33_M06',N'TR33_S02',N'SN-TR33-S02-M06-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M06D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M06D4' AND (([MaThietBi] IS NULL AND N'TR33_S02M06D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M06D4' IS NULL) OR ([MaThietBi] <> N'TR33_S02M06D4') OR ([MaDongMay] IS NULL AND N'TR33_M06' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M06' IS NULL) OR ([MaDongMay] <> N'TR33_M06') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M06-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M06-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M06-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M06D4',N'TR33_M06',N'TR33_S02',N'SN-TR33-S02-M06-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M06D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S02M06D5' AND (([MaThietBi] IS NULL AND N'TR33_S02M06D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S02M06D5' IS NULL) OR ([MaThietBi] <> N'TR33_S02M06D5') OR ([MaDongMay] IS NULL AND N'TR33_M06' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M06' IS NULL) OR ([MaDongMay] <> N'TR33_M06') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([SoSerial] IS NULL AND N'SN-TR33-S02-M06-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S02-M06-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S02-M06-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S02M06D5',N'TR33_M06',N'TR33_S02',N'SN-TR33-S02-M06-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M06D1')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M06D1' AND (([MaThietBi] IS NULL AND N'TR33_S03M06D1' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M06D1' IS NULL) OR ([MaThietBi] <> N'TR33_S03M06D1') OR ([MaDongMay] IS NULL AND N'TR33_M06' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M06' IS NULL) OR ([MaDongMay] <> N'TR33_M06') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M06-01' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M06-01' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M06-01') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M06D1',N'TR33_M06',N'TR33_S03',N'SN-TR33-S03-M06-01',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M06D2')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M06D2' AND (([MaThietBi] IS NULL AND N'TR33_S03M06D2' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M06D2' IS NULL) OR ([MaThietBi] <> N'TR33_S03M06D2') OR ([MaDongMay] IS NULL AND N'TR33_M06' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M06' IS NULL) OR ([MaDongMay] <> N'TR33_M06') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M06-02' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M06-02' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M06-02') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M06D2',N'TR33_M06',N'TR33_S03',N'SN-TR33-S03-M06-02',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M06D3')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M06D3' AND (([MaThietBi] IS NULL AND N'TR33_S03M06D3' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M06D3' IS NULL) OR ([MaThietBi] <> N'TR33_S03M06D3') OR ([MaDongMay] IS NULL AND N'TR33_M06' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M06' IS NULL) OR ([MaDongMay] <> N'TR33_M06') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M06-03' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M06-03' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M06-03') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M06D3',N'TR33_M06',N'TR33_S03',N'SN-TR33-S03-M06-03',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M06D4')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M06D4' AND (([MaThietBi] IS NULL AND N'TR33_S03M06D4' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M06D4' IS NULL) OR ([MaThietBi] <> N'TR33_S03M06D4') OR ([MaDongMay] IS NULL AND N'TR33_M06' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M06' IS NULL) OR ([MaDongMay] <> N'TR33_M06') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M06-04' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M06-04' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M06-04') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M06D4',N'TR33_M06',N'TR33_S03',N'SN-TR33-S03-M06-04',N'Synthetic ready',N'SAN_SANG',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M06D5')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[ThietBi] WHERE [MaThietBi]=N'TR33_S03M06D5' AND (([MaThietBi] IS NULL AND N'TR33_S03M06D5' IS NOT NULL) OR ([MaThietBi] IS NOT NULL AND N'TR33_S03M06D5' IS NULL) OR ([MaThietBi] <> N'TR33_S03M06D5') OR ([MaDongMay] IS NULL AND N'TR33_M06' IS NOT NULL) OR ([MaDongMay] IS NOT NULL AND N'TR33_M06' IS NULL) OR ([MaDongMay] <> N'TR33_M06') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([SoSerial] IS NULL AND N'SN-TR33-S03-M06-05' IS NOT NULL) OR ([SoSerial] IS NOT NULL AND N'SN-TR33-S03-M06-05' IS NULL) OR ([SoSerial] <> N'SN-TR33-S03-M06-05') OR ([NgayNhap] IS NULL AND N'2026-10-27' IS NOT NULL) OR ([NgayNhap] IS NOT NULL AND N'2026-10-27' IS NULL) OR ([NgayNhap] <> N'2026-10-27'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[ThietBi] ([MaThietBi],[MaDongMay],[MaCuaHang],[SoSerial],[TinhTrang],[TrangThai],[NgayNhap]) VALUES (N'TR33_S03M06D5',N'TR33_M06',N'TR33_S03',N'SN-TR33-S03-M06-05',N'Synthetic maintenance',N'BAO_TRI',N'2026-10-27');

IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C01')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C01' AND (([MaTaiKhoan] IS NULL AND N'TR33_C01' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C01' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C01') OR ([TenDangNhap] IS NULL AND N'trial33.customer01' IS NOT NULL) OR ([TenDangNhap] IS NOT NULL AND N'trial33.customer01' IS NULL) OR ([TenDangNhap] <> N'trial33.customer01') OR ([VaiTro] IS NULL AND N'KHACH_HANG' IS NOT NULL) OR ([VaiTro] IS NOT NULL AND N'KHACH_HANG' IS NULL) OR ([VaiTro] <> N'KHACH_HANG'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[TaiKhoan] ([MaTaiKhoan],[TenDangNhap],[MatKhauHash],[VaiTro],[TrangThai],[NgayTao],[PhienBanBaoMat]) VALUES (N'TR33_C01',N'trial33.customer01',N'AQAAAAIAAYagAAAAEG+G7VXnEGatOiFkkyUkCN+TpBwkHgCnWBH/6gQsyaT0FHMPOXAdBrRSOWgAtyhHMg==',N'KHACH_HANG',N'HOAT_DONG',@LocalNow,0);

IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C02')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C02' AND (([MaTaiKhoan] IS NULL AND N'TR33_C02' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C02' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C02') OR ([TenDangNhap] IS NULL AND N'trial33.customer02' IS NOT NULL) OR ([TenDangNhap] IS NOT NULL AND N'trial33.customer02' IS NULL) OR ([TenDangNhap] <> N'trial33.customer02') OR ([VaiTro] IS NULL AND N'KHACH_HANG' IS NOT NULL) OR ([VaiTro] IS NOT NULL AND N'KHACH_HANG' IS NULL) OR ([VaiTro] <> N'KHACH_HANG'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[TaiKhoan] ([MaTaiKhoan],[TenDangNhap],[MatKhauHash],[VaiTro],[TrangThai],[NgayTao],[PhienBanBaoMat]) VALUES (N'TR33_C02',N'trial33.customer02',N'AQAAAAIAAYagAAAAEPT1pSBRVCB1GWjyVHKKA/ijzD79oWInnHqgTB0v2EslRhCs4vvZ5m/c56Z6yIZ7qw==',N'KHACH_HANG',N'HOAT_DONG',@LocalNow,0);

IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C03')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C03' AND (([MaTaiKhoan] IS NULL AND N'TR33_C03' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C03' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C03') OR ([TenDangNhap] IS NULL AND N'trial33.customer03' IS NOT NULL) OR ([TenDangNhap] IS NOT NULL AND N'trial33.customer03' IS NULL) OR ([TenDangNhap] <> N'trial33.customer03') OR ([VaiTro] IS NULL AND N'KHACH_HANG' IS NOT NULL) OR ([VaiTro] IS NOT NULL AND N'KHACH_HANG' IS NULL) OR ([VaiTro] <> N'KHACH_HANG'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[TaiKhoan] ([MaTaiKhoan],[TenDangNhap],[MatKhauHash],[VaiTro],[TrangThai],[NgayTao],[PhienBanBaoMat]) VALUES (N'TR33_C03',N'trial33.customer03',N'AQAAAAIAAYagAAAAEJiugqC3eT4aX8GRW/pD41gZ8nhZINV8seyqVoPCtk+OB9pKKlyalxhbmChCUjBNiA==',N'KHACH_HANG',N'HOAT_DONG',@LocalNow,0);

IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C04')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C04' AND (([MaTaiKhoan] IS NULL AND N'TR33_C04' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C04' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C04') OR ([TenDangNhap] IS NULL AND N'trial33.customer04' IS NOT NULL) OR ([TenDangNhap] IS NOT NULL AND N'trial33.customer04' IS NULL) OR ([TenDangNhap] <> N'trial33.customer04') OR ([VaiTro] IS NULL AND N'KHACH_HANG' IS NOT NULL) OR ([VaiTro] IS NOT NULL AND N'KHACH_HANG' IS NULL) OR ([VaiTro] <> N'KHACH_HANG'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[TaiKhoan] ([MaTaiKhoan],[TenDangNhap],[MatKhauHash],[VaiTro],[TrangThai],[NgayTao],[PhienBanBaoMat]) VALUES (N'TR33_C04',N'trial33.customer04',N'AQAAAAIAAYagAAAAEFCWLlfe1uxTiKSxGhwR4VV/wISve7XUL429IV9+sSMKdiFRtfMdYqCVrpqJfcqGvA==',N'KHACH_HANG',N'HOAT_DONG',@LocalNow,0);

IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C05')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C05' AND (([MaTaiKhoan] IS NULL AND N'TR33_C05' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C05' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C05') OR ([TenDangNhap] IS NULL AND N'trial33.customer05' IS NOT NULL) OR ([TenDangNhap] IS NOT NULL AND N'trial33.customer05' IS NULL) OR ([TenDangNhap] <> N'trial33.customer05') OR ([VaiTro] IS NULL AND N'KHACH_HANG' IS NOT NULL) OR ([VaiTro] IS NOT NULL AND N'KHACH_HANG' IS NULL) OR ([VaiTro] <> N'KHACH_HANG'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[TaiKhoan] ([MaTaiKhoan],[TenDangNhap],[MatKhauHash],[VaiTro],[TrangThai],[NgayTao],[PhienBanBaoMat]) VALUES (N'TR33_C05',N'trial33.customer05',N'AQAAAAIAAYagAAAAEAb8BVy0RJQ7L63p55PxrIEhSnAbA6QI43esvdL4AxFpFrWeTS3XMvHjCORXVzrvCg==',N'KHACH_HANG',N'HOAT_DONG',@LocalNow,0);

IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C06')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C06' AND (([MaTaiKhoan] IS NULL AND N'TR33_C06' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C06' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C06') OR ([TenDangNhap] IS NULL AND N'trial33.customer06' IS NOT NULL) OR ([TenDangNhap] IS NOT NULL AND N'trial33.customer06' IS NULL) OR ([TenDangNhap] <> N'trial33.customer06') OR ([VaiTro] IS NULL AND N'KHACH_HANG' IS NOT NULL) OR ([VaiTro] IS NOT NULL AND N'KHACH_HANG' IS NULL) OR ([VaiTro] <> N'KHACH_HANG'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[TaiKhoan] ([MaTaiKhoan],[TenDangNhap],[MatKhauHash],[VaiTro],[TrangThai],[NgayTao],[PhienBanBaoMat]) VALUES (N'TR33_C06',N'trial33.customer06',N'AQAAAAIAAYagAAAAECQXNUTpo/C7h/so8j6cLyLm1L0XhYZfq7E7s/dQ/TYPj4oQGV6+t9SE0VQK3iHStw==',N'KHACH_HANG',N'HOAT_DONG',@LocalNow,0);

IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C07')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C07' AND (([MaTaiKhoan] IS NULL AND N'TR33_C07' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C07' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C07') OR ([TenDangNhap] IS NULL AND N'trial33.customer07' IS NOT NULL) OR ([TenDangNhap] IS NOT NULL AND N'trial33.customer07' IS NULL) OR ([TenDangNhap] <> N'trial33.customer07') OR ([VaiTro] IS NULL AND N'KHACH_HANG' IS NOT NULL) OR ([VaiTro] IS NOT NULL AND N'KHACH_HANG' IS NULL) OR ([VaiTro] <> N'KHACH_HANG'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[TaiKhoan] ([MaTaiKhoan],[TenDangNhap],[MatKhauHash],[VaiTro],[TrangThai],[NgayTao],[PhienBanBaoMat]) VALUES (N'TR33_C07',N'trial33.customer07',N'AQAAAAIAAYagAAAAEGL9L3BsdZbS80P+fHGvHYm+qigZieYxzkvt2IY8yKDnDX5PsOpJSU4mQVBZoKDsoQ==',N'KHACH_HANG',N'HOAT_DONG',@LocalNow,0);

IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C08')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C08' AND (([MaTaiKhoan] IS NULL AND N'TR33_C08' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C08' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C08') OR ([TenDangNhap] IS NULL AND N'trial33.customer08' IS NOT NULL) OR ([TenDangNhap] IS NOT NULL AND N'trial33.customer08' IS NULL) OR ([TenDangNhap] <> N'trial33.customer08') OR ([VaiTro] IS NULL AND N'KHACH_HANG' IS NOT NULL) OR ([VaiTro] IS NOT NULL AND N'KHACH_HANG' IS NULL) OR ([VaiTro] <> N'KHACH_HANG'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[TaiKhoan] ([MaTaiKhoan],[TenDangNhap],[MatKhauHash],[VaiTro],[TrangThai],[NgayTao],[PhienBanBaoMat]) VALUES (N'TR33_C08',N'trial33.customer08',N'AQAAAAIAAYagAAAAEGPWP75s+wtjXelKIyp1h1Cy6KIb9B4iMk65fE4duSRzMzOs7cf/jYgxQjmDb4sWqw==',N'KHACH_HANG',N'HOAT_DONG',@LocalNow,0);

IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C09')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C09' AND (([MaTaiKhoan] IS NULL AND N'TR33_C09' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C09' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C09') OR ([TenDangNhap] IS NULL AND N'trial33.customer09' IS NOT NULL) OR ([TenDangNhap] IS NOT NULL AND N'trial33.customer09' IS NULL) OR ([TenDangNhap] <> N'trial33.customer09') OR ([VaiTro] IS NULL AND N'KHACH_HANG' IS NOT NULL) OR ([VaiTro] IS NOT NULL AND N'KHACH_HANG' IS NULL) OR ([VaiTro] <> N'KHACH_HANG'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[TaiKhoan] ([MaTaiKhoan],[TenDangNhap],[MatKhauHash],[VaiTro],[TrangThai],[NgayTao],[PhienBanBaoMat]) VALUES (N'TR33_C09',N'trial33.customer09',N'AQAAAAIAAYagAAAAEBZbkpiRJv1bGdpcIS5dI9+G1m/sWa+TELzsagveRkhOjG9U2Aqu1d5VxTtPvi0Uow==',N'KHACH_HANG',N'HOAT_DONG',@LocalNow,0);

IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C10')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C10' AND (([MaTaiKhoan] IS NULL AND N'TR33_C10' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C10' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C10') OR ([TenDangNhap] IS NULL AND N'trial33.customer10' IS NOT NULL) OR ([TenDangNhap] IS NOT NULL AND N'trial33.customer10' IS NULL) OR ([TenDangNhap] <> N'trial33.customer10') OR ([VaiTro] IS NULL AND N'KHACH_HANG' IS NOT NULL) OR ([VaiTro] IS NOT NULL AND N'KHACH_HANG' IS NULL) OR ([VaiTro] <> N'KHACH_HANG'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[TaiKhoan] ([MaTaiKhoan],[TenDangNhap],[MatKhauHash],[VaiTro],[TrangThai],[NgayTao],[PhienBanBaoMat]) VALUES (N'TR33_C10',N'trial33.customer10',N'AQAAAAIAAYagAAAAEJpm2a0rilVzvRPiTQGBFGViQH1PKICBwtoj6f1yakQF/GbQZeA3J+aIOqwyVlyjIA==',N'KHACH_HANG',N'HOAT_DONG',@LocalNow,0);

IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C11')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C11' AND (([MaTaiKhoan] IS NULL AND N'TR33_C11' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C11' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C11') OR ([TenDangNhap] IS NULL AND N'trial33.customer11' IS NOT NULL) OR ([TenDangNhap] IS NOT NULL AND N'trial33.customer11' IS NULL) OR ([TenDangNhap] <> N'trial33.customer11') OR ([VaiTro] IS NULL AND N'KHACH_HANG' IS NOT NULL) OR ([VaiTro] IS NOT NULL AND N'KHACH_HANG' IS NULL) OR ([VaiTro] <> N'KHACH_HANG'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[TaiKhoan] ([MaTaiKhoan],[TenDangNhap],[MatKhauHash],[VaiTro],[TrangThai],[NgayTao],[PhienBanBaoMat]) VALUES (N'TR33_C11',N'trial33.customer11',N'AQAAAAIAAYagAAAAEPqZUYRx6bqxMkX18ooE5vNwfAvwZtrUFngBMQpqS/KU/IWAL2wLBOXuELvXyLvLeg==',N'KHACH_HANG',N'HOAT_DONG',@LocalNow,0);

IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C12')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_C12' AND (([MaTaiKhoan] IS NULL AND N'TR33_C12' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C12' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C12') OR ([TenDangNhap] IS NULL AND N'trial33.customer12' IS NOT NULL) OR ([TenDangNhap] IS NOT NULL AND N'trial33.customer12' IS NULL) OR ([TenDangNhap] <> N'trial33.customer12') OR ([VaiTro] IS NULL AND N'KHACH_HANG' IS NOT NULL) OR ([VaiTro] IS NOT NULL AND N'KHACH_HANG' IS NULL) OR ([VaiTro] <> N'KHACH_HANG'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[TaiKhoan] ([MaTaiKhoan],[TenDangNhap],[MatKhauHash],[VaiTro],[TrangThai],[NgayTao],[PhienBanBaoMat]) VALUES (N'TR33_C12',N'trial33.customer12',N'AQAAAAIAAYagAAAAEAW80CgvSFHMniJ0sGka/Nz8coRTnTas/X/K1L2ertZao1TbDfj9rTfUn9wOXS7bIQ==',N'KHACH_HANG',N'HOAT_DONG',@LocalNow,0);

IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_N01')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_N01' AND (([MaTaiKhoan] IS NULL AND N'TR33_N01' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_N01' IS NULL) OR ([MaTaiKhoan] <> N'TR33_N01') OR ([TenDangNhap] IS NULL AND N'trial33.staff01' IS NOT NULL) OR ([TenDangNhap] IS NOT NULL AND N'trial33.staff01' IS NULL) OR ([TenDangNhap] <> N'trial33.staff01') OR ([VaiTro] IS NULL AND N'NHAN_VIEN' IS NOT NULL) OR ([VaiTro] IS NOT NULL AND N'NHAN_VIEN' IS NULL) OR ([VaiTro] <> N'NHAN_VIEN'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[TaiKhoan] ([MaTaiKhoan],[TenDangNhap],[MatKhauHash],[VaiTro],[TrangThai],[NgayTao],[PhienBanBaoMat]) VALUES (N'TR33_N01',N'trial33.staff01',N'AQAAAAIAAYagAAAAEEdzDxYHcgzRpWd+dgVslHni816m8x9bCStEdjomvf1bztiX8sf9r808KtoBzqA8wA==',N'NHAN_VIEN',N'HOAT_DONG',@LocalNow,0);

IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_N02')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_N02' AND (([MaTaiKhoan] IS NULL AND N'TR33_N02' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_N02' IS NULL) OR ([MaTaiKhoan] <> N'TR33_N02') OR ([TenDangNhap] IS NULL AND N'trial33.staff02' IS NOT NULL) OR ([TenDangNhap] IS NOT NULL AND N'trial33.staff02' IS NULL) OR ([TenDangNhap] <> N'trial33.staff02') OR ([VaiTro] IS NULL AND N'NHAN_VIEN' IS NOT NULL) OR ([VaiTro] IS NOT NULL AND N'NHAN_VIEN' IS NULL) OR ([VaiTro] <> N'NHAN_VIEN'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[TaiKhoan] ([MaTaiKhoan],[TenDangNhap],[MatKhauHash],[VaiTro],[TrangThai],[NgayTao],[PhienBanBaoMat]) VALUES (N'TR33_N02',N'trial33.staff02',N'AQAAAAIAAYagAAAAEGfD4fcTkgoe5sbEneOwGkKql77ERk9z6NOTDyApcbgSwglF/W5NB8X2H7MHIX5CTQ==',N'NHAN_VIEN',N'HOAT_DONG',@LocalNow,0);

IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_N03')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_N03' AND (([MaTaiKhoan] IS NULL AND N'TR33_N03' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_N03' IS NULL) OR ([MaTaiKhoan] <> N'TR33_N03') OR ([TenDangNhap] IS NULL AND N'trial33.staff03' IS NOT NULL) OR ([TenDangNhap] IS NOT NULL AND N'trial33.staff03' IS NULL) OR ([TenDangNhap] <> N'trial33.staff03') OR ([VaiTro] IS NULL AND N'NHAN_VIEN' IS NOT NULL) OR ([VaiTro] IS NOT NULL AND N'NHAN_VIEN' IS NULL) OR ([VaiTro] <> N'NHAN_VIEN'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[TaiKhoan] ([MaTaiKhoan],[TenDangNhap],[MatKhauHash],[VaiTro],[TrangThai],[NgayTao],[PhienBanBaoMat]) VALUES (N'TR33_N03',N'trial33.staff03',N'AQAAAAIAAYagAAAAEPOo2t2+ocIu/UBdGwASQ7KL71fOhHTlUPRlkyukzZZUjY/0I+NcZzaeZNs68y8r3A==',N'NHAN_VIEN',N'HOAT_DONG',@LocalNow,0);

IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_N04')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[TaiKhoan] WHERE [MaTaiKhoan]=N'TR33_N04' AND (([MaTaiKhoan] IS NULL AND N'TR33_N04' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_N04' IS NULL) OR ([MaTaiKhoan] <> N'TR33_N04') OR ([TenDangNhap] IS NULL AND N'trial33.admin' IS NOT NULL) OR ([TenDangNhap] IS NOT NULL AND N'trial33.admin' IS NULL) OR ([TenDangNhap] <> N'trial33.admin') OR ([VaiTro] IS NULL AND N'ADMIN' IS NOT NULL) OR ([VaiTro] IS NOT NULL AND N'ADMIN' IS NULL) OR ([VaiTro] <> N'ADMIN'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[TaiKhoan] ([MaTaiKhoan],[TenDangNhap],[MatKhauHash],[VaiTro],[TrangThai],[NgayTao],[PhienBanBaoMat]) VALUES (N'TR33_N04',N'trial33.admin',N'AQAAAAIAAYagAAAAEOywMCr0/9+walSsVvG8spPiWBCG67n6mRjVtzyTBX/c8WA//ts85aPJah5GHxS4Rw==',N'ADMIN',N'HOAT_DONG',@LocalNow,0);

IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K01')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K01' AND (([MaKhachThue] IS NULL AND N'TR33_K01' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K01' IS NULL) OR ([MaKhachThue] <> N'TR33_K01') OR ([MaTaiKhoan] IS NULL AND N'TR33_C01' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C01' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C01') OR ([HoTen] IS NULL AND N'TRIAL33 Customer 01' IS NOT NULL) OR ([HoTen] IS NOT NULL AND N'TRIAL33 Customer 01' IS NULL) OR ([HoTen] <> N'TRIAL33 Customer 01') OR ([SoDienThoai] IS NULL AND N'0910000001' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0910000001' IS NULL) OR ([SoDienThoai] <> N'0910000001') OR ([Email] IS NULL AND N'TRIAL33.CUSTOMER01@EXAMPLE.INVALID' IS NOT NULL) OR ([Email] IS NOT NULL AND N'TRIAL33.CUSTOMER01@EXAMPLE.INVALID' IS NULL) OR ([Email] <> N'TRIAL33.CUSTOMER01@EXAMPLE.INVALID') OR ([CCCD] IS NULL AND N'TR33-DOC-01' IS NOT NULL) OR ([CCCD] IS NOT NULL AND N'TR33-DOC-01' IS NULL) OR ([CCCD] <> N'TR33-DOC-01') OR ([DiaChi] IS NULL AND N'SYNTHETIC ONLY' IS NOT NULL) OR ([DiaChi] IS NOT NULL AND N'SYNTHETIC ONLY' IS NULL) OR ([DiaChi] <> N'SYNTHETIC ONLY'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[KhachThue] ([MaKhachThue],[MaTaiKhoan],[HoTen],[SoDienThoai],[Email],[CCCD],[DiaChi],[DaXacNhanThongTin],[EmailXacMinhLucUtc]) VALUES (N'TR33_K01',N'TR33_C01',N'TRIAL33 Customer 01',N'0910000001',N'TRIAL33.CUSTOMER01@EXAMPLE.INVALID',N'TR33-DOC-01',N'SYNTHETIC ONLY',1,@UtcNow);

IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K02')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K02' AND (([MaKhachThue] IS NULL AND N'TR33_K02' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K02' IS NULL) OR ([MaKhachThue] <> N'TR33_K02') OR ([MaTaiKhoan] IS NULL AND N'TR33_C02' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C02' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C02') OR ([HoTen] IS NULL AND N'TRIAL33 Customer 02' IS NOT NULL) OR ([HoTen] IS NOT NULL AND N'TRIAL33 Customer 02' IS NULL) OR ([HoTen] <> N'TRIAL33 Customer 02') OR ([SoDienThoai] IS NULL AND N'0910000002' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0910000002' IS NULL) OR ([SoDienThoai] <> N'0910000002') OR ([Email] IS NULL AND N'TRIAL33.CUSTOMER02@EXAMPLE.INVALID' IS NOT NULL) OR ([Email] IS NOT NULL AND N'TRIAL33.CUSTOMER02@EXAMPLE.INVALID' IS NULL) OR ([Email] <> N'TRIAL33.CUSTOMER02@EXAMPLE.INVALID') OR ([CCCD] IS NULL AND N'TR33-DOC-02' IS NOT NULL) OR ([CCCD] IS NOT NULL AND N'TR33-DOC-02' IS NULL) OR ([CCCD] <> N'TR33-DOC-02') OR ([DiaChi] IS NULL AND N'SYNTHETIC ONLY' IS NOT NULL) OR ([DiaChi] IS NOT NULL AND N'SYNTHETIC ONLY' IS NULL) OR ([DiaChi] <> N'SYNTHETIC ONLY'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[KhachThue] ([MaKhachThue],[MaTaiKhoan],[HoTen],[SoDienThoai],[Email],[CCCD],[DiaChi],[DaXacNhanThongTin],[EmailXacMinhLucUtc]) VALUES (N'TR33_K02',N'TR33_C02',N'TRIAL33 Customer 02',N'0910000002',N'TRIAL33.CUSTOMER02@EXAMPLE.INVALID',N'TR33-DOC-02',N'SYNTHETIC ONLY',1,@UtcNow);

IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K03')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K03' AND (([MaKhachThue] IS NULL AND N'TR33_K03' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K03' IS NULL) OR ([MaKhachThue] <> N'TR33_K03') OR ([MaTaiKhoan] IS NULL AND N'TR33_C03' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C03' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C03') OR ([HoTen] IS NULL AND N'TRIAL33 Customer 03' IS NOT NULL) OR ([HoTen] IS NOT NULL AND N'TRIAL33 Customer 03' IS NULL) OR ([HoTen] <> N'TRIAL33 Customer 03') OR ([SoDienThoai] IS NULL AND N'0910000003' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0910000003' IS NULL) OR ([SoDienThoai] <> N'0910000003') OR ([Email] IS NULL AND N'TRIAL33.CUSTOMER03@EXAMPLE.INVALID' IS NOT NULL) OR ([Email] IS NOT NULL AND N'TRIAL33.CUSTOMER03@EXAMPLE.INVALID' IS NULL) OR ([Email] <> N'TRIAL33.CUSTOMER03@EXAMPLE.INVALID') OR ([CCCD] IS NULL AND N'TR33-DOC-03' IS NOT NULL) OR ([CCCD] IS NOT NULL AND N'TR33-DOC-03' IS NULL) OR ([CCCD] <> N'TR33-DOC-03') OR ([DiaChi] IS NULL AND N'SYNTHETIC ONLY' IS NOT NULL) OR ([DiaChi] IS NOT NULL AND N'SYNTHETIC ONLY' IS NULL) OR ([DiaChi] <> N'SYNTHETIC ONLY'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[KhachThue] ([MaKhachThue],[MaTaiKhoan],[HoTen],[SoDienThoai],[Email],[CCCD],[DiaChi],[DaXacNhanThongTin],[EmailXacMinhLucUtc]) VALUES (N'TR33_K03',N'TR33_C03',N'TRIAL33 Customer 03',N'0910000003',N'TRIAL33.CUSTOMER03@EXAMPLE.INVALID',N'TR33-DOC-03',N'SYNTHETIC ONLY',1,@UtcNow);

IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K04')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K04' AND (([MaKhachThue] IS NULL AND N'TR33_K04' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K04' IS NULL) OR ([MaKhachThue] <> N'TR33_K04') OR ([MaTaiKhoan] IS NULL AND N'TR33_C04' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C04' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C04') OR ([HoTen] IS NULL AND N'TRIAL33 Customer 04' IS NOT NULL) OR ([HoTen] IS NOT NULL AND N'TRIAL33 Customer 04' IS NULL) OR ([HoTen] <> N'TRIAL33 Customer 04') OR ([SoDienThoai] IS NULL AND N'0910000004' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0910000004' IS NULL) OR ([SoDienThoai] <> N'0910000004') OR ([Email] IS NULL AND N'TRIAL33.CUSTOMER04@EXAMPLE.INVALID' IS NOT NULL) OR ([Email] IS NOT NULL AND N'TRIAL33.CUSTOMER04@EXAMPLE.INVALID' IS NULL) OR ([Email] <> N'TRIAL33.CUSTOMER04@EXAMPLE.INVALID') OR ([CCCD] IS NULL AND N'TR33-DOC-04' IS NOT NULL) OR ([CCCD] IS NOT NULL AND N'TR33-DOC-04' IS NULL) OR ([CCCD] <> N'TR33-DOC-04') OR ([DiaChi] IS NULL AND N'SYNTHETIC ONLY' IS NOT NULL) OR ([DiaChi] IS NOT NULL AND N'SYNTHETIC ONLY' IS NULL) OR ([DiaChi] <> N'SYNTHETIC ONLY'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[KhachThue] ([MaKhachThue],[MaTaiKhoan],[HoTen],[SoDienThoai],[Email],[CCCD],[DiaChi],[DaXacNhanThongTin],[EmailXacMinhLucUtc]) VALUES (N'TR33_K04',N'TR33_C04',N'TRIAL33 Customer 04',N'0910000004',N'TRIAL33.CUSTOMER04@EXAMPLE.INVALID',N'TR33-DOC-04',N'SYNTHETIC ONLY',1,@UtcNow);

IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K05')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K05' AND (([MaKhachThue] IS NULL AND N'TR33_K05' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K05' IS NULL) OR ([MaKhachThue] <> N'TR33_K05') OR ([MaTaiKhoan] IS NULL AND N'TR33_C05' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C05' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C05') OR ([HoTen] IS NULL AND N'TRIAL33 Customer 05' IS NOT NULL) OR ([HoTen] IS NOT NULL AND N'TRIAL33 Customer 05' IS NULL) OR ([HoTen] <> N'TRIAL33 Customer 05') OR ([SoDienThoai] IS NULL AND N'0910000005' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0910000005' IS NULL) OR ([SoDienThoai] <> N'0910000005') OR ([Email] IS NULL AND N'TRIAL33.CUSTOMER05@EXAMPLE.INVALID' IS NOT NULL) OR ([Email] IS NOT NULL AND N'TRIAL33.CUSTOMER05@EXAMPLE.INVALID' IS NULL) OR ([Email] <> N'TRIAL33.CUSTOMER05@EXAMPLE.INVALID') OR ([CCCD] IS NULL AND N'TR33-DOC-05' IS NOT NULL) OR ([CCCD] IS NOT NULL AND N'TR33-DOC-05' IS NULL) OR ([CCCD] <> N'TR33-DOC-05') OR ([DiaChi] IS NULL AND N'SYNTHETIC ONLY' IS NOT NULL) OR ([DiaChi] IS NOT NULL AND N'SYNTHETIC ONLY' IS NULL) OR ([DiaChi] <> N'SYNTHETIC ONLY'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[KhachThue] ([MaKhachThue],[MaTaiKhoan],[HoTen],[SoDienThoai],[Email],[CCCD],[DiaChi],[DaXacNhanThongTin],[EmailXacMinhLucUtc]) VALUES (N'TR33_K05',N'TR33_C05',N'TRIAL33 Customer 05',N'0910000005',N'TRIAL33.CUSTOMER05@EXAMPLE.INVALID',N'TR33-DOC-05',N'SYNTHETIC ONLY',1,@UtcNow);

IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K06')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K06' AND (([MaKhachThue] IS NULL AND N'TR33_K06' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K06' IS NULL) OR ([MaKhachThue] <> N'TR33_K06') OR ([MaTaiKhoan] IS NULL AND N'TR33_C06' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C06' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C06') OR ([HoTen] IS NULL AND N'TRIAL33 Customer 06' IS NOT NULL) OR ([HoTen] IS NOT NULL AND N'TRIAL33 Customer 06' IS NULL) OR ([HoTen] <> N'TRIAL33 Customer 06') OR ([SoDienThoai] IS NULL AND N'0910000006' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0910000006' IS NULL) OR ([SoDienThoai] <> N'0910000006') OR ([Email] IS NULL AND N'TRIAL33.CUSTOMER06@EXAMPLE.INVALID' IS NOT NULL) OR ([Email] IS NOT NULL AND N'TRIAL33.CUSTOMER06@EXAMPLE.INVALID' IS NULL) OR ([Email] <> N'TRIAL33.CUSTOMER06@EXAMPLE.INVALID') OR ([CCCD] IS NULL AND N'TR33-DOC-06' IS NOT NULL) OR ([CCCD] IS NOT NULL AND N'TR33-DOC-06' IS NULL) OR ([CCCD] <> N'TR33-DOC-06') OR ([DiaChi] IS NULL AND N'SYNTHETIC ONLY' IS NOT NULL) OR ([DiaChi] IS NOT NULL AND N'SYNTHETIC ONLY' IS NULL) OR ([DiaChi] <> N'SYNTHETIC ONLY'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[KhachThue] ([MaKhachThue],[MaTaiKhoan],[HoTen],[SoDienThoai],[Email],[CCCD],[DiaChi],[DaXacNhanThongTin],[EmailXacMinhLucUtc]) VALUES (N'TR33_K06',N'TR33_C06',N'TRIAL33 Customer 06',N'0910000006',N'TRIAL33.CUSTOMER06@EXAMPLE.INVALID',N'TR33-DOC-06',N'SYNTHETIC ONLY',1,@UtcNow);

IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K07')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K07' AND (([MaKhachThue] IS NULL AND N'TR33_K07' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K07' IS NULL) OR ([MaKhachThue] <> N'TR33_K07') OR ([MaTaiKhoan] IS NULL AND N'TR33_C07' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C07' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C07') OR ([HoTen] IS NULL AND N'TRIAL33 Customer 07' IS NOT NULL) OR ([HoTen] IS NOT NULL AND N'TRIAL33 Customer 07' IS NULL) OR ([HoTen] <> N'TRIAL33 Customer 07') OR ([SoDienThoai] IS NULL AND N'0910000007' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0910000007' IS NULL) OR ([SoDienThoai] <> N'0910000007') OR ([Email] IS NULL AND N'TRIAL33.CUSTOMER07@EXAMPLE.INVALID' IS NOT NULL) OR ([Email] IS NOT NULL AND N'TRIAL33.CUSTOMER07@EXAMPLE.INVALID' IS NULL) OR ([Email] <> N'TRIAL33.CUSTOMER07@EXAMPLE.INVALID') OR ([CCCD] IS NULL AND N'TR33-DOC-07' IS NOT NULL) OR ([CCCD] IS NOT NULL AND N'TR33-DOC-07' IS NULL) OR ([CCCD] <> N'TR33-DOC-07') OR ([DiaChi] IS NULL AND N'SYNTHETIC ONLY' IS NOT NULL) OR ([DiaChi] IS NOT NULL AND N'SYNTHETIC ONLY' IS NULL) OR ([DiaChi] <> N'SYNTHETIC ONLY'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[KhachThue] ([MaKhachThue],[MaTaiKhoan],[HoTen],[SoDienThoai],[Email],[CCCD],[DiaChi],[DaXacNhanThongTin],[EmailXacMinhLucUtc]) VALUES (N'TR33_K07',N'TR33_C07',N'TRIAL33 Customer 07',N'0910000007',N'TRIAL33.CUSTOMER07@EXAMPLE.INVALID',N'TR33-DOC-07',N'SYNTHETIC ONLY',1,@UtcNow);

IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K08')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K08' AND (([MaKhachThue] IS NULL AND N'TR33_K08' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K08' IS NULL) OR ([MaKhachThue] <> N'TR33_K08') OR ([MaTaiKhoan] IS NULL AND N'TR33_C08' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C08' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C08') OR ([HoTen] IS NULL AND N'TRIAL33 Customer 08' IS NOT NULL) OR ([HoTen] IS NOT NULL AND N'TRIAL33 Customer 08' IS NULL) OR ([HoTen] <> N'TRIAL33 Customer 08') OR ([SoDienThoai] IS NULL AND N'0910000008' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0910000008' IS NULL) OR ([SoDienThoai] <> N'0910000008') OR ([Email] IS NULL AND N'TRIAL33.CUSTOMER08@EXAMPLE.INVALID' IS NOT NULL) OR ([Email] IS NOT NULL AND N'TRIAL33.CUSTOMER08@EXAMPLE.INVALID' IS NULL) OR ([Email] <> N'TRIAL33.CUSTOMER08@EXAMPLE.INVALID') OR ([CCCD] IS NULL AND N'TR33-DOC-08' IS NOT NULL) OR ([CCCD] IS NOT NULL AND N'TR33-DOC-08' IS NULL) OR ([CCCD] <> N'TR33-DOC-08') OR ([DiaChi] IS NULL AND N'SYNTHETIC ONLY' IS NOT NULL) OR ([DiaChi] IS NOT NULL AND N'SYNTHETIC ONLY' IS NULL) OR ([DiaChi] <> N'SYNTHETIC ONLY'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[KhachThue] ([MaKhachThue],[MaTaiKhoan],[HoTen],[SoDienThoai],[Email],[CCCD],[DiaChi],[DaXacNhanThongTin],[EmailXacMinhLucUtc]) VALUES (N'TR33_K08',N'TR33_C08',N'TRIAL33 Customer 08',N'0910000008',N'TRIAL33.CUSTOMER08@EXAMPLE.INVALID',N'TR33-DOC-08',N'SYNTHETIC ONLY',1,@UtcNow);

IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K09')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K09' AND (([MaKhachThue] IS NULL AND N'TR33_K09' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K09' IS NULL) OR ([MaKhachThue] <> N'TR33_K09') OR ([MaTaiKhoan] IS NULL AND N'TR33_C09' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C09' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C09') OR ([HoTen] IS NULL AND N'TRIAL33 Customer 09' IS NOT NULL) OR ([HoTen] IS NOT NULL AND N'TRIAL33 Customer 09' IS NULL) OR ([HoTen] <> N'TRIAL33 Customer 09') OR ([SoDienThoai] IS NULL AND N'0910000009' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0910000009' IS NULL) OR ([SoDienThoai] <> N'0910000009') OR ([Email] IS NULL AND N'TRIAL33.CUSTOMER09@EXAMPLE.INVALID' IS NOT NULL) OR ([Email] IS NOT NULL AND N'TRIAL33.CUSTOMER09@EXAMPLE.INVALID' IS NULL) OR ([Email] <> N'TRIAL33.CUSTOMER09@EXAMPLE.INVALID') OR ([CCCD] IS NULL AND N'TR33-DOC-09' IS NOT NULL) OR ([CCCD] IS NOT NULL AND N'TR33-DOC-09' IS NULL) OR ([CCCD] <> N'TR33-DOC-09') OR ([DiaChi] IS NULL AND N'SYNTHETIC ONLY' IS NOT NULL) OR ([DiaChi] IS NOT NULL AND N'SYNTHETIC ONLY' IS NULL) OR ([DiaChi] <> N'SYNTHETIC ONLY'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[KhachThue] ([MaKhachThue],[MaTaiKhoan],[HoTen],[SoDienThoai],[Email],[CCCD],[DiaChi],[DaXacNhanThongTin],[EmailXacMinhLucUtc]) VALUES (N'TR33_K09',N'TR33_C09',N'TRIAL33 Customer 09',N'0910000009',N'TRIAL33.CUSTOMER09@EXAMPLE.INVALID',N'TR33-DOC-09',N'SYNTHETIC ONLY',1,@UtcNow);

IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K10')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K10' AND (([MaKhachThue] IS NULL AND N'TR33_K10' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K10' IS NULL) OR ([MaKhachThue] <> N'TR33_K10') OR ([MaTaiKhoan] IS NULL AND N'TR33_C10' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C10' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C10') OR ([HoTen] IS NULL AND N'TRIAL33 Customer 10' IS NOT NULL) OR ([HoTen] IS NOT NULL AND N'TRIAL33 Customer 10' IS NULL) OR ([HoTen] <> N'TRIAL33 Customer 10') OR ([SoDienThoai] IS NULL AND N'0910000010' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0910000010' IS NULL) OR ([SoDienThoai] <> N'0910000010') OR ([Email] IS NULL AND N'TRIAL33.CUSTOMER10@EXAMPLE.INVALID' IS NOT NULL) OR ([Email] IS NOT NULL AND N'TRIAL33.CUSTOMER10@EXAMPLE.INVALID' IS NULL) OR ([Email] <> N'TRIAL33.CUSTOMER10@EXAMPLE.INVALID') OR ([CCCD] IS NULL AND N'TR33-DOC-10' IS NOT NULL) OR ([CCCD] IS NOT NULL AND N'TR33-DOC-10' IS NULL) OR ([CCCD] <> N'TR33-DOC-10') OR ([DiaChi] IS NULL AND N'SYNTHETIC ONLY' IS NOT NULL) OR ([DiaChi] IS NOT NULL AND N'SYNTHETIC ONLY' IS NULL) OR ([DiaChi] <> N'SYNTHETIC ONLY'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[KhachThue] ([MaKhachThue],[MaTaiKhoan],[HoTen],[SoDienThoai],[Email],[CCCD],[DiaChi],[DaXacNhanThongTin],[EmailXacMinhLucUtc]) VALUES (N'TR33_K10',N'TR33_C10',N'TRIAL33 Customer 10',N'0910000010',N'TRIAL33.CUSTOMER10@EXAMPLE.INVALID',N'TR33-DOC-10',N'SYNTHETIC ONLY',1,@UtcNow);

IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K11')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K11' AND (([MaKhachThue] IS NULL AND N'TR33_K11' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K11' IS NULL) OR ([MaKhachThue] <> N'TR33_K11') OR ([MaTaiKhoan] IS NULL AND N'TR33_C11' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C11' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C11') OR ([HoTen] IS NULL AND N'TRIAL33 Customer 11' IS NOT NULL) OR ([HoTen] IS NOT NULL AND N'TRIAL33 Customer 11' IS NULL) OR ([HoTen] <> N'TRIAL33 Customer 11') OR ([SoDienThoai] IS NULL AND N'0910000011' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0910000011' IS NULL) OR ([SoDienThoai] <> N'0910000011') OR ([Email] IS NULL AND N'TRIAL33.CUSTOMER11@EXAMPLE.INVALID' IS NOT NULL) OR ([Email] IS NOT NULL AND N'TRIAL33.CUSTOMER11@EXAMPLE.INVALID' IS NULL) OR ([Email] <> N'TRIAL33.CUSTOMER11@EXAMPLE.INVALID') OR ([CCCD] IS NULL AND N'TR33-DOC-11' IS NOT NULL) OR ([CCCD] IS NOT NULL AND N'TR33-DOC-11' IS NULL) OR ([CCCD] <> N'TR33-DOC-11') OR ([DiaChi] IS NULL AND N'SYNTHETIC ONLY' IS NOT NULL) OR ([DiaChi] IS NOT NULL AND N'SYNTHETIC ONLY' IS NULL) OR ([DiaChi] <> N'SYNTHETIC ONLY'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[KhachThue] ([MaKhachThue],[MaTaiKhoan],[HoTen],[SoDienThoai],[Email],[CCCD],[DiaChi],[DaXacNhanThongTin],[EmailXacMinhLucUtc]) VALUES (N'TR33_K11',N'TR33_C11',N'TRIAL33 Customer 11',N'0910000011',N'TRIAL33.CUSTOMER11@EXAMPLE.INVALID',N'TR33-DOC-11',N'SYNTHETIC ONLY',1,@UtcNow);

IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K12')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[KhachThue] WHERE [MaKhachThue]=N'TR33_K12' AND (([MaKhachThue] IS NULL AND N'TR33_K12' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K12' IS NULL) OR ([MaKhachThue] <> N'TR33_K12') OR ([MaTaiKhoan] IS NULL AND N'TR33_C12' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_C12' IS NULL) OR ([MaTaiKhoan] <> N'TR33_C12') OR ([HoTen] IS NULL AND N'TRIAL33 Customer 12' IS NOT NULL) OR ([HoTen] IS NOT NULL AND N'TRIAL33 Customer 12' IS NULL) OR ([HoTen] <> N'TRIAL33 Customer 12') OR ([SoDienThoai] IS NULL AND N'0910000012' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0910000012' IS NULL) OR ([SoDienThoai] <> N'0910000012') OR ([Email] IS NULL AND N'TRIAL33.CUSTOMER12@EXAMPLE.INVALID' IS NOT NULL) OR ([Email] IS NOT NULL AND N'TRIAL33.CUSTOMER12@EXAMPLE.INVALID' IS NULL) OR ([Email] <> N'TRIAL33.CUSTOMER12@EXAMPLE.INVALID') OR ([CCCD] IS NULL AND N'TR33-DOC-12' IS NOT NULL) OR ([CCCD] IS NOT NULL AND N'TR33-DOC-12' IS NULL) OR ([CCCD] <> N'TR33-DOC-12') OR ([DiaChi] IS NULL AND N'SYNTHETIC ONLY' IS NOT NULL) OR ([DiaChi] IS NOT NULL AND N'SYNTHETIC ONLY' IS NULL) OR ([DiaChi] <> N'SYNTHETIC ONLY'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[KhachThue] ([MaKhachThue],[MaTaiKhoan],[HoTen],[SoDienThoai],[Email],[CCCD],[DiaChi],[DaXacNhanThongTin],[EmailXacMinhLucUtc]) VALUES (N'TR33_K12',N'TR33_C12',N'TRIAL33 Customer 12',N'0910000012',N'TRIAL33.CUSTOMER12@EXAMPLE.INVALID',N'TR33-DOC-12',N'SYNTHETIC ONLY',1,@UtcNow);

-- Complete only missing synthetic profile fields; never overwrite values edited during tests.
UPDATE dbo.[KhachThue]
SET [NgaySinh]=COALESCE([NgaySinh],CONVERT(date,'1995-01-01')),
    [GioiTinh]=COALESCE([GioiTinh],N'KHAC'),
    [QuocTich]=COALESCE([QuocTich],N'VIET_NAM'),
    [NgayCap]=COALESCE([NgayCap],CONVERT(date,'2020-01-01')),
    [NoiCap]=COALESCE([NoiCap],N'TRIAL33 SYNTHETIC AUTHORITY')
WHERE [MaKhachThue] IN (N'TR33_K01',N'TR33_K02',N'TR33_K03',N'TR33_K04',N'TR33_K05',N'TR33_K06',N'TR33_K07',N'TR33_K08',N'TR33_K09',N'TR33_K10',N'TR33_K11',N'TR33_K12');

-- Normalize the known synthetic back-image value so the generated collision checks remain
-- idempotent, then restore/backfill it after all 12 identity rows are validated.
UPDATE dbo.[GiayToTuyThan]
SET [MatSauUrl]=NULL
WHERE [MaGiayTo] IN (N'TR33_ID01',N'TR33_ID02',N'TR33_ID03',N'TR33_ID04',N'TR33_ID05',N'TR33_ID06',N'TR33_ID07',N'TR33_ID08',N'TR33_ID09',N'TR33_ID10',N'TR33_ID11',N'TR33_ID12')
  AND [MatSauUrl]=N'/fixtures/schema33/fake-identity-back.png';

IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID01')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID01' AND (([MaGiayTo] IS NULL AND N'TR33_ID01' IS NOT NULL) OR ([MaGiayTo] IS NOT NULL AND N'TR33_ID01' IS NULL) OR ([MaGiayTo] <> N'TR33_ID01') OR ([MaKhachThue] IS NULL AND N'TR33_K01' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K01' IS NULL) OR ([MaKhachThue] <> N'TR33_K01') OR ([LoaiGiayTo] IS NULL AND N'CCCD' IS NOT NULL) OR ([LoaiGiayTo] IS NOT NULL AND N'CCCD' IS NULL) OR ([LoaiGiayTo] <> N'CCCD') OR ([SoGiayTo] IS NULL AND N'TR33-DOC-01' IS NOT NULL) OR ([SoGiayTo] IS NOT NULL AND N'TR33-DOC-01' IS NULL) OR ([SoGiayTo] <> N'TR33-DOC-01') OR ([MatTruocUrl] IS NULL AND N'/fixtures/schema33/fake-identity.png' IS NOT NULL) OR ([MatTruocUrl] IS NOT NULL AND N'/fixtures/schema33/fake-identity.png' IS NULL) OR ([MatTruocUrl] <> N'/fixtures/schema33/fake-identity.png') OR ([MatSauUrl] IS NULL AND NULL IS NOT NULL) OR ([MatSauUrl] IS NOT NULL AND NULL IS NULL) OR ([MatSauUrl] <> NULL) OR ([TrangThaiXacMinh] IS NULL AND N'HOP_LE' IS NOT NULL) OR ([TrangThaiXacMinh] IS NOT NULL AND N'HOP_LE' IS NULL) OR ([TrangThaiXacMinh] <> N'HOP_LE'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[GiayToTuyThan] ([MaGiayTo],[MaKhachThue],[LoaiGiayTo],[SoGiayTo],[MatTruocUrl],[MatSauUrl],[NgayTaiLen],[TrangThaiXacMinh],[GhiChu]) VALUES (N'TR33_ID01',N'TR33_K01',N'CCCD',N'TR33-DOC-01',N'/fixtures/schema33/fake-identity.png',NULL,@LocalNow,N'HOP_LE',N'SYNTHETIC VERIFIED IDENTITY FIXTURE; not a real document');

IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID02')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID02' AND (([MaGiayTo] IS NULL AND N'TR33_ID02' IS NOT NULL) OR ([MaGiayTo] IS NOT NULL AND N'TR33_ID02' IS NULL) OR ([MaGiayTo] <> N'TR33_ID02') OR ([MaKhachThue] IS NULL AND N'TR33_K02' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K02' IS NULL) OR ([MaKhachThue] <> N'TR33_K02') OR ([LoaiGiayTo] IS NULL AND N'CCCD' IS NOT NULL) OR ([LoaiGiayTo] IS NOT NULL AND N'CCCD' IS NULL) OR ([LoaiGiayTo] <> N'CCCD') OR ([SoGiayTo] IS NULL AND N'TR33-DOC-02' IS NOT NULL) OR ([SoGiayTo] IS NOT NULL AND N'TR33-DOC-02' IS NULL) OR ([SoGiayTo] <> N'TR33-DOC-02') OR ([MatTruocUrl] IS NULL AND N'/fixtures/schema33/fake-identity.png' IS NOT NULL) OR ([MatTruocUrl] IS NOT NULL AND N'/fixtures/schema33/fake-identity.png' IS NULL) OR ([MatTruocUrl] <> N'/fixtures/schema33/fake-identity.png') OR ([MatSauUrl] IS NULL AND NULL IS NOT NULL) OR ([MatSauUrl] IS NOT NULL AND NULL IS NULL) OR ([MatSauUrl] <> NULL) OR ([TrangThaiXacMinh] IS NULL AND N'HOP_LE' IS NOT NULL) OR ([TrangThaiXacMinh] IS NOT NULL AND N'HOP_LE' IS NULL) OR ([TrangThaiXacMinh] <> N'HOP_LE'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[GiayToTuyThan] ([MaGiayTo],[MaKhachThue],[LoaiGiayTo],[SoGiayTo],[MatTruocUrl],[MatSauUrl],[NgayTaiLen],[TrangThaiXacMinh],[GhiChu]) VALUES (N'TR33_ID02',N'TR33_K02',N'CCCD',N'TR33-DOC-02',N'/fixtures/schema33/fake-identity.png',NULL,@LocalNow,N'HOP_LE',N'SYNTHETIC VERIFIED IDENTITY FIXTURE; not a real document');

IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID03')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID03' AND (([MaGiayTo] IS NULL AND N'TR33_ID03' IS NOT NULL) OR ([MaGiayTo] IS NOT NULL AND N'TR33_ID03' IS NULL) OR ([MaGiayTo] <> N'TR33_ID03') OR ([MaKhachThue] IS NULL AND N'TR33_K03' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K03' IS NULL) OR ([MaKhachThue] <> N'TR33_K03') OR ([LoaiGiayTo] IS NULL AND N'CCCD' IS NOT NULL) OR ([LoaiGiayTo] IS NOT NULL AND N'CCCD' IS NULL) OR ([LoaiGiayTo] <> N'CCCD') OR ([SoGiayTo] IS NULL AND N'TR33-DOC-03' IS NOT NULL) OR ([SoGiayTo] IS NOT NULL AND N'TR33-DOC-03' IS NULL) OR ([SoGiayTo] <> N'TR33-DOC-03') OR ([MatTruocUrl] IS NULL AND N'/fixtures/schema33/fake-identity.png' IS NOT NULL) OR ([MatTruocUrl] IS NOT NULL AND N'/fixtures/schema33/fake-identity.png' IS NULL) OR ([MatTruocUrl] <> N'/fixtures/schema33/fake-identity.png') OR ([MatSauUrl] IS NULL AND NULL IS NOT NULL) OR ([MatSauUrl] IS NOT NULL AND NULL IS NULL) OR ([MatSauUrl] <> NULL) OR ([TrangThaiXacMinh] IS NULL AND N'HOP_LE' IS NOT NULL) OR ([TrangThaiXacMinh] IS NOT NULL AND N'HOP_LE' IS NULL) OR ([TrangThaiXacMinh] <> N'HOP_LE'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[GiayToTuyThan] ([MaGiayTo],[MaKhachThue],[LoaiGiayTo],[SoGiayTo],[MatTruocUrl],[MatSauUrl],[NgayTaiLen],[TrangThaiXacMinh],[GhiChu]) VALUES (N'TR33_ID03',N'TR33_K03',N'CCCD',N'TR33-DOC-03',N'/fixtures/schema33/fake-identity.png',NULL,@LocalNow,N'HOP_LE',N'SYNTHETIC VERIFIED IDENTITY FIXTURE; not a real document');

IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID04')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID04' AND (([MaGiayTo] IS NULL AND N'TR33_ID04' IS NOT NULL) OR ([MaGiayTo] IS NOT NULL AND N'TR33_ID04' IS NULL) OR ([MaGiayTo] <> N'TR33_ID04') OR ([MaKhachThue] IS NULL AND N'TR33_K04' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K04' IS NULL) OR ([MaKhachThue] <> N'TR33_K04') OR ([LoaiGiayTo] IS NULL AND N'CCCD' IS NOT NULL) OR ([LoaiGiayTo] IS NOT NULL AND N'CCCD' IS NULL) OR ([LoaiGiayTo] <> N'CCCD') OR ([SoGiayTo] IS NULL AND N'TR33-DOC-04' IS NOT NULL) OR ([SoGiayTo] IS NOT NULL AND N'TR33-DOC-04' IS NULL) OR ([SoGiayTo] <> N'TR33-DOC-04') OR ([MatTruocUrl] IS NULL AND N'/fixtures/schema33/fake-identity.png' IS NOT NULL) OR ([MatTruocUrl] IS NOT NULL AND N'/fixtures/schema33/fake-identity.png' IS NULL) OR ([MatTruocUrl] <> N'/fixtures/schema33/fake-identity.png') OR ([MatSauUrl] IS NULL AND NULL IS NOT NULL) OR ([MatSauUrl] IS NOT NULL AND NULL IS NULL) OR ([MatSauUrl] <> NULL) OR ([TrangThaiXacMinh] IS NULL AND N'HOP_LE' IS NOT NULL) OR ([TrangThaiXacMinh] IS NOT NULL AND N'HOP_LE' IS NULL) OR ([TrangThaiXacMinh] <> N'HOP_LE'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[GiayToTuyThan] ([MaGiayTo],[MaKhachThue],[LoaiGiayTo],[SoGiayTo],[MatTruocUrl],[MatSauUrl],[NgayTaiLen],[TrangThaiXacMinh],[GhiChu]) VALUES (N'TR33_ID04',N'TR33_K04',N'CCCD',N'TR33-DOC-04',N'/fixtures/schema33/fake-identity.png',NULL,@LocalNow,N'HOP_LE',N'SYNTHETIC VERIFIED IDENTITY FIXTURE; not a real document');

IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID05')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID05' AND (([MaGiayTo] IS NULL AND N'TR33_ID05' IS NOT NULL) OR ([MaGiayTo] IS NOT NULL AND N'TR33_ID05' IS NULL) OR ([MaGiayTo] <> N'TR33_ID05') OR ([MaKhachThue] IS NULL AND N'TR33_K05' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K05' IS NULL) OR ([MaKhachThue] <> N'TR33_K05') OR ([LoaiGiayTo] IS NULL AND N'CCCD' IS NOT NULL) OR ([LoaiGiayTo] IS NOT NULL AND N'CCCD' IS NULL) OR ([LoaiGiayTo] <> N'CCCD') OR ([SoGiayTo] IS NULL AND N'TR33-DOC-05' IS NOT NULL) OR ([SoGiayTo] IS NOT NULL AND N'TR33-DOC-05' IS NULL) OR ([SoGiayTo] <> N'TR33-DOC-05') OR ([MatTruocUrl] IS NULL AND N'/fixtures/schema33/fake-identity.png' IS NOT NULL) OR ([MatTruocUrl] IS NOT NULL AND N'/fixtures/schema33/fake-identity.png' IS NULL) OR ([MatTruocUrl] <> N'/fixtures/schema33/fake-identity.png') OR ([MatSauUrl] IS NULL AND NULL IS NOT NULL) OR ([MatSauUrl] IS NOT NULL AND NULL IS NULL) OR ([MatSauUrl] <> NULL) OR ([TrangThaiXacMinh] IS NULL AND N'HOP_LE' IS NOT NULL) OR ([TrangThaiXacMinh] IS NOT NULL AND N'HOP_LE' IS NULL) OR ([TrangThaiXacMinh] <> N'HOP_LE'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[GiayToTuyThan] ([MaGiayTo],[MaKhachThue],[LoaiGiayTo],[SoGiayTo],[MatTruocUrl],[MatSauUrl],[NgayTaiLen],[TrangThaiXacMinh],[GhiChu]) VALUES (N'TR33_ID05',N'TR33_K05',N'CCCD',N'TR33-DOC-05',N'/fixtures/schema33/fake-identity.png',NULL,@LocalNow,N'HOP_LE',N'SYNTHETIC VERIFIED IDENTITY FIXTURE; not a real document');

IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID06')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID06' AND (([MaGiayTo] IS NULL AND N'TR33_ID06' IS NOT NULL) OR ([MaGiayTo] IS NOT NULL AND N'TR33_ID06' IS NULL) OR ([MaGiayTo] <> N'TR33_ID06') OR ([MaKhachThue] IS NULL AND N'TR33_K06' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K06' IS NULL) OR ([MaKhachThue] <> N'TR33_K06') OR ([LoaiGiayTo] IS NULL AND N'CCCD' IS NOT NULL) OR ([LoaiGiayTo] IS NOT NULL AND N'CCCD' IS NULL) OR ([LoaiGiayTo] <> N'CCCD') OR ([SoGiayTo] IS NULL AND N'TR33-DOC-06' IS NOT NULL) OR ([SoGiayTo] IS NOT NULL AND N'TR33-DOC-06' IS NULL) OR ([SoGiayTo] <> N'TR33-DOC-06') OR ([MatTruocUrl] IS NULL AND N'/fixtures/schema33/fake-identity.png' IS NOT NULL) OR ([MatTruocUrl] IS NOT NULL AND N'/fixtures/schema33/fake-identity.png' IS NULL) OR ([MatTruocUrl] <> N'/fixtures/schema33/fake-identity.png') OR ([MatSauUrl] IS NULL AND NULL IS NOT NULL) OR ([MatSauUrl] IS NOT NULL AND NULL IS NULL) OR ([MatSauUrl] <> NULL) OR ([TrangThaiXacMinh] IS NULL AND N'HOP_LE' IS NOT NULL) OR ([TrangThaiXacMinh] IS NOT NULL AND N'HOP_LE' IS NULL) OR ([TrangThaiXacMinh] <> N'HOP_LE'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[GiayToTuyThan] ([MaGiayTo],[MaKhachThue],[LoaiGiayTo],[SoGiayTo],[MatTruocUrl],[MatSauUrl],[NgayTaiLen],[TrangThaiXacMinh],[GhiChu]) VALUES (N'TR33_ID06',N'TR33_K06',N'CCCD',N'TR33-DOC-06',N'/fixtures/schema33/fake-identity.png',NULL,@LocalNow,N'HOP_LE',N'SYNTHETIC VERIFIED IDENTITY FIXTURE; not a real document');

IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID07')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID07' AND (([MaGiayTo] IS NULL AND N'TR33_ID07' IS NOT NULL) OR ([MaGiayTo] IS NOT NULL AND N'TR33_ID07' IS NULL) OR ([MaGiayTo] <> N'TR33_ID07') OR ([MaKhachThue] IS NULL AND N'TR33_K07' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K07' IS NULL) OR ([MaKhachThue] <> N'TR33_K07') OR ([LoaiGiayTo] IS NULL AND N'CCCD' IS NOT NULL) OR ([LoaiGiayTo] IS NOT NULL AND N'CCCD' IS NULL) OR ([LoaiGiayTo] <> N'CCCD') OR ([SoGiayTo] IS NULL AND N'TR33-DOC-07' IS NOT NULL) OR ([SoGiayTo] IS NOT NULL AND N'TR33-DOC-07' IS NULL) OR ([SoGiayTo] <> N'TR33-DOC-07') OR ([MatTruocUrl] IS NULL AND N'/fixtures/schema33/fake-identity.png' IS NOT NULL) OR ([MatTruocUrl] IS NOT NULL AND N'/fixtures/schema33/fake-identity.png' IS NULL) OR ([MatTruocUrl] <> N'/fixtures/schema33/fake-identity.png') OR ([MatSauUrl] IS NULL AND NULL IS NOT NULL) OR ([MatSauUrl] IS NOT NULL AND NULL IS NULL) OR ([MatSauUrl] <> NULL) OR ([TrangThaiXacMinh] IS NULL AND N'HOP_LE' IS NOT NULL) OR ([TrangThaiXacMinh] IS NOT NULL AND N'HOP_LE' IS NULL) OR ([TrangThaiXacMinh] <> N'HOP_LE'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[GiayToTuyThan] ([MaGiayTo],[MaKhachThue],[LoaiGiayTo],[SoGiayTo],[MatTruocUrl],[MatSauUrl],[NgayTaiLen],[TrangThaiXacMinh],[GhiChu]) VALUES (N'TR33_ID07',N'TR33_K07',N'CCCD',N'TR33-DOC-07',N'/fixtures/schema33/fake-identity.png',NULL,@LocalNow,N'HOP_LE',N'SYNTHETIC VERIFIED IDENTITY FIXTURE; not a real document');

IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID08')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID08' AND (([MaGiayTo] IS NULL AND N'TR33_ID08' IS NOT NULL) OR ([MaGiayTo] IS NOT NULL AND N'TR33_ID08' IS NULL) OR ([MaGiayTo] <> N'TR33_ID08') OR ([MaKhachThue] IS NULL AND N'TR33_K08' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K08' IS NULL) OR ([MaKhachThue] <> N'TR33_K08') OR ([LoaiGiayTo] IS NULL AND N'CCCD' IS NOT NULL) OR ([LoaiGiayTo] IS NOT NULL AND N'CCCD' IS NULL) OR ([LoaiGiayTo] <> N'CCCD') OR ([SoGiayTo] IS NULL AND N'TR33-DOC-08' IS NOT NULL) OR ([SoGiayTo] IS NOT NULL AND N'TR33-DOC-08' IS NULL) OR ([SoGiayTo] <> N'TR33-DOC-08') OR ([MatTruocUrl] IS NULL AND N'/fixtures/schema33/fake-identity.png' IS NOT NULL) OR ([MatTruocUrl] IS NOT NULL AND N'/fixtures/schema33/fake-identity.png' IS NULL) OR ([MatTruocUrl] <> N'/fixtures/schema33/fake-identity.png') OR ([MatSauUrl] IS NULL AND NULL IS NOT NULL) OR ([MatSauUrl] IS NOT NULL AND NULL IS NULL) OR ([MatSauUrl] <> NULL) OR ([TrangThaiXacMinh] IS NULL AND N'HOP_LE' IS NOT NULL) OR ([TrangThaiXacMinh] IS NOT NULL AND N'HOP_LE' IS NULL) OR ([TrangThaiXacMinh] <> N'HOP_LE'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[GiayToTuyThan] ([MaGiayTo],[MaKhachThue],[LoaiGiayTo],[SoGiayTo],[MatTruocUrl],[MatSauUrl],[NgayTaiLen],[TrangThaiXacMinh],[GhiChu]) VALUES (N'TR33_ID08',N'TR33_K08',N'CCCD',N'TR33-DOC-08',N'/fixtures/schema33/fake-identity.png',NULL,@LocalNow,N'HOP_LE',N'SYNTHETIC VERIFIED IDENTITY FIXTURE; not a real document');

IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID09')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID09' AND (([MaGiayTo] IS NULL AND N'TR33_ID09' IS NOT NULL) OR ([MaGiayTo] IS NOT NULL AND N'TR33_ID09' IS NULL) OR ([MaGiayTo] <> N'TR33_ID09') OR ([MaKhachThue] IS NULL AND N'TR33_K09' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K09' IS NULL) OR ([MaKhachThue] <> N'TR33_K09') OR ([LoaiGiayTo] IS NULL AND N'CCCD' IS NOT NULL) OR ([LoaiGiayTo] IS NOT NULL AND N'CCCD' IS NULL) OR ([LoaiGiayTo] <> N'CCCD') OR ([SoGiayTo] IS NULL AND N'TR33-DOC-09' IS NOT NULL) OR ([SoGiayTo] IS NOT NULL AND N'TR33-DOC-09' IS NULL) OR ([SoGiayTo] <> N'TR33-DOC-09') OR ([MatTruocUrl] IS NULL AND N'/fixtures/schema33/fake-identity.png' IS NOT NULL) OR ([MatTruocUrl] IS NOT NULL AND N'/fixtures/schema33/fake-identity.png' IS NULL) OR ([MatTruocUrl] <> N'/fixtures/schema33/fake-identity.png') OR ([MatSauUrl] IS NULL AND NULL IS NOT NULL) OR ([MatSauUrl] IS NOT NULL AND NULL IS NULL) OR ([MatSauUrl] <> NULL) OR ([TrangThaiXacMinh] IS NULL AND N'HOP_LE' IS NOT NULL) OR ([TrangThaiXacMinh] IS NOT NULL AND N'HOP_LE' IS NULL) OR ([TrangThaiXacMinh] <> N'HOP_LE'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[GiayToTuyThan] ([MaGiayTo],[MaKhachThue],[LoaiGiayTo],[SoGiayTo],[MatTruocUrl],[MatSauUrl],[NgayTaiLen],[TrangThaiXacMinh],[GhiChu]) VALUES (N'TR33_ID09',N'TR33_K09',N'CCCD',N'TR33-DOC-09',N'/fixtures/schema33/fake-identity.png',NULL,@LocalNow,N'HOP_LE',N'SYNTHETIC VERIFIED IDENTITY FIXTURE; not a real document');

IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID10')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID10' AND (([MaGiayTo] IS NULL AND N'TR33_ID10' IS NOT NULL) OR ([MaGiayTo] IS NOT NULL AND N'TR33_ID10' IS NULL) OR ([MaGiayTo] <> N'TR33_ID10') OR ([MaKhachThue] IS NULL AND N'TR33_K10' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K10' IS NULL) OR ([MaKhachThue] <> N'TR33_K10') OR ([LoaiGiayTo] IS NULL AND N'CCCD' IS NOT NULL) OR ([LoaiGiayTo] IS NOT NULL AND N'CCCD' IS NULL) OR ([LoaiGiayTo] <> N'CCCD') OR ([SoGiayTo] IS NULL AND N'TR33-DOC-10' IS NOT NULL) OR ([SoGiayTo] IS NOT NULL AND N'TR33-DOC-10' IS NULL) OR ([SoGiayTo] <> N'TR33-DOC-10') OR ([MatTruocUrl] IS NULL AND N'/fixtures/schema33/fake-identity.png' IS NOT NULL) OR ([MatTruocUrl] IS NOT NULL AND N'/fixtures/schema33/fake-identity.png' IS NULL) OR ([MatTruocUrl] <> N'/fixtures/schema33/fake-identity.png') OR ([MatSauUrl] IS NULL AND NULL IS NOT NULL) OR ([MatSauUrl] IS NOT NULL AND NULL IS NULL) OR ([MatSauUrl] <> NULL) OR ([TrangThaiXacMinh] IS NULL AND N'HOP_LE' IS NOT NULL) OR ([TrangThaiXacMinh] IS NOT NULL AND N'HOP_LE' IS NULL) OR ([TrangThaiXacMinh] <> N'HOP_LE'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[GiayToTuyThan] ([MaGiayTo],[MaKhachThue],[LoaiGiayTo],[SoGiayTo],[MatTruocUrl],[MatSauUrl],[NgayTaiLen],[TrangThaiXacMinh],[GhiChu]) VALUES (N'TR33_ID10',N'TR33_K10',N'CCCD',N'TR33-DOC-10',N'/fixtures/schema33/fake-identity.png',NULL,@LocalNow,N'HOP_LE',N'SYNTHETIC VERIFIED IDENTITY FIXTURE; not a real document');

IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID11')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID11' AND (([MaGiayTo] IS NULL AND N'TR33_ID11' IS NOT NULL) OR ([MaGiayTo] IS NOT NULL AND N'TR33_ID11' IS NULL) OR ([MaGiayTo] <> N'TR33_ID11') OR ([MaKhachThue] IS NULL AND N'TR33_K11' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K11' IS NULL) OR ([MaKhachThue] <> N'TR33_K11') OR ([LoaiGiayTo] IS NULL AND N'CCCD' IS NOT NULL) OR ([LoaiGiayTo] IS NOT NULL AND N'CCCD' IS NULL) OR ([LoaiGiayTo] <> N'CCCD') OR ([SoGiayTo] IS NULL AND N'TR33-DOC-11' IS NOT NULL) OR ([SoGiayTo] IS NOT NULL AND N'TR33-DOC-11' IS NULL) OR ([SoGiayTo] <> N'TR33-DOC-11') OR ([MatTruocUrl] IS NULL AND N'/fixtures/schema33/fake-identity.png' IS NOT NULL) OR ([MatTruocUrl] IS NOT NULL AND N'/fixtures/schema33/fake-identity.png' IS NULL) OR ([MatTruocUrl] <> N'/fixtures/schema33/fake-identity.png') OR ([MatSauUrl] IS NULL AND NULL IS NOT NULL) OR ([MatSauUrl] IS NOT NULL AND NULL IS NULL) OR ([MatSauUrl] <> NULL) OR ([TrangThaiXacMinh] IS NULL AND N'HOP_LE' IS NOT NULL) OR ([TrangThaiXacMinh] IS NOT NULL AND N'HOP_LE' IS NULL) OR ([TrangThaiXacMinh] <> N'HOP_LE'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[GiayToTuyThan] ([MaGiayTo],[MaKhachThue],[LoaiGiayTo],[SoGiayTo],[MatTruocUrl],[MatSauUrl],[NgayTaiLen],[TrangThaiXacMinh],[GhiChu]) VALUES (N'TR33_ID11',N'TR33_K11',N'CCCD',N'TR33-DOC-11',N'/fixtures/schema33/fake-identity.png',NULL,@LocalNow,N'HOP_LE',N'SYNTHETIC VERIFIED IDENTITY FIXTURE; not a real document');

IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID12')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[GiayToTuyThan] WHERE [MaGiayTo]=N'TR33_ID12' AND (([MaGiayTo] IS NULL AND N'TR33_ID12' IS NOT NULL) OR ([MaGiayTo] IS NOT NULL AND N'TR33_ID12' IS NULL) OR ([MaGiayTo] <> N'TR33_ID12') OR ([MaKhachThue] IS NULL AND N'TR33_K12' IS NOT NULL) OR ([MaKhachThue] IS NOT NULL AND N'TR33_K12' IS NULL) OR ([MaKhachThue] <> N'TR33_K12') OR ([LoaiGiayTo] IS NULL AND N'CCCD' IS NOT NULL) OR ([LoaiGiayTo] IS NOT NULL AND N'CCCD' IS NULL) OR ([LoaiGiayTo] <> N'CCCD') OR ([SoGiayTo] IS NULL AND N'TR33-DOC-12' IS NOT NULL) OR ([SoGiayTo] IS NOT NULL AND N'TR33-DOC-12' IS NULL) OR ([SoGiayTo] <> N'TR33-DOC-12') OR ([MatTruocUrl] IS NULL AND N'/fixtures/schema33/fake-identity.png' IS NOT NULL) OR ([MatTruocUrl] IS NOT NULL AND N'/fixtures/schema33/fake-identity.png' IS NULL) OR ([MatTruocUrl] <> N'/fixtures/schema33/fake-identity.png') OR ([MatSauUrl] IS NULL AND NULL IS NOT NULL) OR ([MatSauUrl] IS NOT NULL AND NULL IS NULL) OR ([MatSauUrl] <> NULL) OR ([TrangThaiXacMinh] IS NULL AND N'HOP_LE' IS NOT NULL) OR ([TrangThaiXacMinh] IS NOT NULL AND N'HOP_LE' IS NULL) OR ([TrangThaiXacMinh] <> N'HOP_LE'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[GiayToTuyThan] ([MaGiayTo],[MaKhachThue],[LoaiGiayTo],[SoGiayTo],[MatTruocUrl],[MatSauUrl],[NgayTaiLen],[TrangThaiXacMinh],[GhiChu]) VALUES (N'TR33_ID12',N'TR33_K12',N'CCCD',N'TR33-DOC-12',N'/fixtures/schema33/fake-identity.png',NULL,@LocalNow,N'HOP_LE',N'SYNTHETIC VERIFIED IDENTITY FIXTURE; not a real document');

UPDATE dbo.[GiayToTuyThan]
SET [MatSauUrl]=N'/fixtures/schema33/fake-identity-back.png'
WHERE [MaGiayTo] IN (N'TR33_ID01',N'TR33_ID02',N'TR33_ID03',N'TR33_ID04',N'TR33_ID05',N'TR33_ID06',N'TR33_ID07',N'TR33_ID08',N'TR33_ID09',N'TR33_ID10',N'TR33_ID11',N'TR33_ID12')
  AND [MatSauUrl] IS NULL;

IF EXISTS(SELECT 1 FROM dbo.[NhanVien] WHERE [MaNhanVien]=N'TR33_NV01')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[NhanVien] WHERE [MaNhanVien]=N'TR33_NV01' AND (([MaNhanVien] IS NULL AND N'TR33_NV01' IS NOT NULL) OR ([MaNhanVien] IS NOT NULL AND N'TR33_NV01' IS NULL) OR ([MaNhanVien] <> N'TR33_NV01') OR ([MaTaiKhoan] IS NULL AND N'TR33_N01' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_N01' IS NULL) OR ([MaTaiKhoan] <> N'TR33_N01') OR ([MaCuaHang] IS NULL AND N'TR33_S01' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S01' IS NULL) OR ([MaCuaHang] <> N'TR33_S01') OR ([HoTen] IS NULL AND N'TRIAL33 Staff 1' IS NOT NULL) OR ([HoTen] IS NOT NULL AND N'TRIAL33 Staff 1' IS NULL) OR ([HoTen] <> N'TRIAL33 Staff 1') OR ([SoDienThoai] IS NULL AND N'0920000001' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0920000001' IS NULL) OR ([SoDienThoai] <> N'0920000001') OR ([ChucVu] IS NULL AND N'TRIAL_STAFF' IS NOT NULL) OR ([ChucVu] IS NOT NULL AND N'TRIAL_STAFF' IS NULL) OR ([ChucVu] <> N'TRIAL_STAFF') OR ([Email] IS NULL AND N'staff1@example.invalid' IS NOT NULL) OR ([Email] IS NOT NULL AND N'staff1@example.invalid' IS NULL) OR ([Email] <> N'staff1@example.invalid'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[NhanVien] ([MaNhanVien],[MaTaiKhoan],[MaCuaHang],[HoTen],[SoDienThoai],[ChucVu],[Email],[TrangThai]) VALUES (N'TR33_NV01',N'TR33_N01',N'TR33_S01',N'TRIAL33 Staff 1',N'0920000001',N'TRIAL_STAFF',N'staff1@example.invalid',N'HOAT_DONG');

IF EXISTS(SELECT 1 FROM dbo.[NhanVien] WHERE [MaNhanVien]=N'TR33_NV02')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[NhanVien] WHERE [MaNhanVien]=N'TR33_NV02' AND (([MaNhanVien] IS NULL AND N'TR33_NV02' IS NOT NULL) OR ([MaNhanVien] IS NOT NULL AND N'TR33_NV02' IS NULL) OR ([MaNhanVien] <> N'TR33_NV02') OR ([MaTaiKhoan] IS NULL AND N'TR33_N02' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_N02' IS NULL) OR ([MaTaiKhoan] <> N'TR33_N02') OR ([MaCuaHang] IS NULL AND N'TR33_S02' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S02' IS NULL) OR ([MaCuaHang] <> N'TR33_S02') OR ([HoTen] IS NULL AND N'TRIAL33 Staff 2' IS NOT NULL) OR ([HoTen] IS NOT NULL AND N'TRIAL33 Staff 2' IS NULL) OR ([HoTen] <> N'TRIAL33 Staff 2') OR ([SoDienThoai] IS NULL AND N'0920000002' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0920000002' IS NULL) OR ([SoDienThoai] <> N'0920000002') OR ([ChucVu] IS NULL AND N'TRIAL_STAFF' IS NOT NULL) OR ([ChucVu] IS NOT NULL AND N'TRIAL_STAFF' IS NULL) OR ([ChucVu] <> N'TRIAL_STAFF') OR ([Email] IS NULL AND N'staff2@example.invalid' IS NOT NULL) OR ([Email] IS NOT NULL AND N'staff2@example.invalid' IS NULL) OR ([Email] <> N'staff2@example.invalid'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[NhanVien] ([MaNhanVien],[MaTaiKhoan],[MaCuaHang],[HoTen],[SoDienThoai],[ChucVu],[Email],[TrangThai]) VALUES (N'TR33_NV02',N'TR33_N02',N'TR33_S02',N'TRIAL33 Staff 2',N'0920000002',N'TRIAL_STAFF',N'staff2@example.invalid',N'HOAT_DONG');

IF EXISTS(SELECT 1 FROM dbo.[NhanVien] WHERE [MaNhanVien]=N'TR33_NV03')
BEGIN
 IF EXISTS(SELECT 1 FROM dbo.[NhanVien] WHERE [MaNhanVien]=N'TR33_NV03' AND (([MaNhanVien] IS NULL AND N'TR33_NV03' IS NOT NULL) OR ([MaNhanVien] IS NOT NULL AND N'TR33_NV03' IS NULL) OR ([MaNhanVien] <> N'TR33_NV03') OR ([MaTaiKhoan] IS NULL AND N'TR33_N03' IS NOT NULL) OR ([MaTaiKhoan] IS NOT NULL AND N'TR33_N03' IS NULL) OR ([MaTaiKhoan] <> N'TR33_N03') OR ([MaCuaHang] IS NULL AND N'TR33_S03' IS NOT NULL) OR ([MaCuaHang] IS NOT NULL AND N'TR33_S03' IS NULL) OR ([MaCuaHang] <> N'TR33_S03') OR ([HoTen] IS NULL AND N'TRIAL33 Staff 3' IS NOT NULL) OR ([HoTen] IS NOT NULL AND N'TRIAL33 Staff 3' IS NULL) OR ([HoTen] <> N'TRIAL33 Staff 3') OR ([SoDienThoai] IS NULL AND N'0920000003' IS NOT NULL) OR ([SoDienThoai] IS NOT NULL AND N'0920000003' IS NULL) OR ([SoDienThoai] <> N'0920000003') OR ([ChucVu] IS NULL AND N'TRIAL_STAFF' IS NOT NULL) OR ([ChucVu] IS NOT NULL AND N'TRIAL_STAFF' IS NULL) OR ([ChucVu] <> N'TRIAL_STAFF') OR ([Email] IS NULL AND N'staff3@example.invalid' IS NOT NULL) OR ([Email] IS NOT NULL AND N'staff3@example.invalid' IS NULL) OR ([Email] <> N'staff3@example.invalid'))) THROW 53311,'Seed ID collides with different identity; stop without updating data.',1;
END
ELSE
 INSERT dbo.[NhanVien] ([MaNhanVien],[MaTaiKhoan],[MaCuaHang],[HoTen],[SoDienThoai],[ChucVu],[Email],[TrangThai]) VALUES (N'TR33_NV03',N'TR33_N03',N'TR33_S03',N'TRIAL33 Staff 3',N'0920000003',N'TRIAL_STAFF',N'staff3@example.invalid',N'HOAT_DONG');

COMMIT TRANSACTION;

END TRY

BEGIN CATCH

IF XACT_STATE()<>0 ROLLBACK TRANSACTION;

THROW;

END CATCH;

SELECT MaCuaHang,MaDongMay,COUNT(*) DeviceCount,SUM(CASE WHEN TrangThai='SAN_SANG' THEN 1 ELSE 0 END) ReadyByStatus,SUM(CASE WHEN TrangThai='BAO_TRI' THEN 1 ELSE 0 END) MaintenanceByStatus FROM dbo.ThietBi WHERE MaThietBi LIKE 'TR33[_]%' GROUP BY MaCuaHang,MaDongMay ORDER BY MaCuaHang,MaDongMay;
