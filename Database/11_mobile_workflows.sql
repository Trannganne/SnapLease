-- Deployment migration: 11_mobile_workflows.sql
-- Use sqlcmd -d <database> -v TargetDatabase=<same database>. Review backup and schema first.
IF DB_NAME() COLLATE Latin1_General_100_BIN2 <> N'$(TargetDatabase)'
    THROW 51100,'STOP: connect only to $(TargetDatabase).',1;
IF @@TRANCOUNT<>0 THROW 51101,'STOP: dedicated connection required.',1;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
BEGIN TRY
BEGIN TRANSACTION;
IF OBJECT_ID('dbo.LichSuHienThiDanhGia','U') IS NULL THROW 51102,'STOP: review publication migration prerequisite missing.',1;
IF OBJECT_ID('dbo.PhuLuc','U') IS NULL OR OBJECT_ID('dbo.ChiTietGioHang','U') IS NULL THROW 51103,'STOP: baseline schema missing.',1;
IF EXISTS(SELECT MaHopDong FROM dbo.PhuLuc WHERE TrangThai IN('CHO_XAC_NHAN','CHO_KY') GROUP BY MaHopDong HAVING COUNT(*)>1)
    THROW 51104,'STOP: duplicate legacy active extensions require review; no rows modified.',1;

IF OBJECT_ID('dbo.FcmDeviceToken','U') IS NULL
CREATE TABLE dbo.FcmDeviceToken(
 Id varchar(36) NOT NULL PRIMARY KEY,MaTaiKhoan varchar(20) NOT NULL REFERENCES dbo.TaiKhoan(MaTaiKhoan),
 Token nvarchar(2048) NOT NULL,TokenHash char(64) NOT NULL,Platform varchar(20) NOT NULL,DeviceId nvarchar(200) NULL,
 IsActive bit NOT NULL DEFAULT 1,CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),UpdatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT UX_FcmDeviceToken_TokenHash UNIQUE(TokenHash));
IF COL_LENGTH('dbo.ThongBao','EventCode') IS NULL ALTER TABLE dbo.ThongBao ADD EventCode varchar(50) NULL;
IF COL_LENGTH('dbo.ThongBao','TargetType') IS NULL ALTER TABLE dbo.ThongBao ADD TargetType varchar(30) NULL;
IF COL_LENGTH('dbo.ThongBao','TargetId') IS NULL ALTER TABLE dbo.ThongBao ADD TargetId varchar(50) NULL;
IF COL_LENGTH('dbo.ThongBao','EventKey') IS NULL ALTER TABLE dbo.ThongBao ADD EventKey varchar(200) NULL;
IF COL_LENGTH('dbo.ThongBao','HanTraNhac') IS NULL ALTER TABLE dbo.ThongBao ADD HanTraNhac datetime2 NULL;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.ThongBao') AND name='UX_ThongBao_EventKey')
 EXEC(N'CREATE UNIQUE INDEX UX_ThongBao_EventKey ON dbo.ThongBao(EventKey) WHERE EventKey IS NOT NULL;');
IF OBJECT_ID('dbo.NotificationDelivery','U') IS NULL
CREATE TABLE dbo.NotificationDelivery(
 Id varchar(36) NOT NULL PRIMARY KEY,MaThongBao varchar(20) NOT NULL REFERENCES dbo.ThongBao(MaThongBao),
 DeviceTokenId varchar(36) NOT NULL REFERENCES dbo.FcmDeviceToken(Id),State varchar(20) NOT NULL DEFAULT 'PENDING',
 Attempts int NOT NULL DEFAULT 0,NextAttemptUtc datetime2 NOT NULL,LeaseUntilUtc datetime2 NULL,LastErrorCode varchar(100) NULL,
 CONSTRAINT UX_NotificationDelivery_Target UNIQUE(MaThongBao,DeviceTokenId));

IF COL_LENGTH('dbo.ChiTietGioHang','PhienBan') IS NULL
 ALTER TABLE dbo.ChiTietGioHang ADD PhienBan uniqueidentifier NOT NULL CONSTRAINT DF_ChiTietGioHang_PhienBan DEFAULT NEWID() WITH VALUES;
IF COL_LENGTH('dbo.ChiTietGioHang','DaChuyenHopDong') IS NULL
 ALTER TABLE dbo.ChiTietGioHang ADD DaChuyenHopDong bit NOT NULL CONSTRAINT DF_ChiTietGioHang_DaChuyen DEFAULT 0 WITH VALUES;
IF COL_LENGTH('dbo.ChiTietGiuCho','PhienBanGioHang') IS NULL ALTER TABLE dbo.ChiTietGiuCho ADD PhienBanGioHang uniqueidentifier NULL;

IF OBJECT_ID('dbo.LichLamViec','U') IS NULL
CREATE TABLE dbo.LichLamViec(MaCuaHang varchar(20) NOT NULL,NgayTrongTuan int NOT NULL,GioMoCua time NOT NULL,GioDongCua time NOT NULL,
 CONSTRAINT PK_LichLamViec PRIMARY KEY(MaCuaHang,NgayTrongTuan),CONSTRAINT CK_LichLamViec_Gio CHECK(NgayTrongTuan BETWEEN 0 AND 6 AND GioDongCua>GioMoCua));
-- Approved global schedule; no inferred public holidays. No existing branch/day rule overwritten.
EXEC(N'INSERT dbo.LichLamViec(MaCuaHang,NgayTrongTuan,GioMoCua,GioDongCua)
 SELECT ''*'',n,''08:00'',''20:00'' FROM (VALUES(0),(1),(2),(3),(4),(5),(6)) d(n)
 WHERE NOT EXISTS(SELECT 1 FROM dbo.LichLamViec w WHERE w.MaCuaHang=''*'' AND w.NgayTrongTuan=d.n);');
IF OBJECT_ID('dbo.LichLamViecDacBiet','U') IS NULL
CREATE TABLE dbo.LichLamViecDacBiet(MaCuaHang varchar(20) NOT NULL REFERENCES dbo.CuaHang(MaCuaHang),Ngay date NOT NULL,
 GioMoCua time NULL,GioDongCua time NULL,LyDo nvarchar(500) NOT NULL,
 CONSTRAINT PK_LichLamViecDacBiet PRIMARY KEY(MaCuaHang,Ngay),
 CONSTRAINT CK_LichLamViecDacBiet_Gio CHECK((GioMoCua IS NULL AND GioDongCua IS NULL) OR
  (GioMoCua IS NOT NULL AND GioDongCua IS NOT NULL AND GioDongCua>GioMoCua)));
IF OBJECT_ID('dbo.NhatKyNghiepVu','U') IS NULL
CREATE TABLE dbo.NhatKyNghiepVu(Id varchar(20) NOT NULL PRIMARY KEY,HanhDong varchar(50) NOT NULL,DoiTuongId varchar(50) NOT NULL,
 MaTaiKhoan varchar(20) NOT NULL REFERENCES dbo.TaiKhoan(MaTaiKhoan),ThoiGianUtc datetime2 NOT NULL,LyDo nvarchar(500) NOT NULL,DuLieuJson nvarchar(max) NOT NULL);

-- Dynamic DDL avoids SQL Server binding newly added columns before this batch executes.
DECLARE @columns TABLE(Name sysname,Definition nvarchar(300));
INSERT @columns VALUES
 ('HanXuLyUtc','datetime2 NULL'),('HanKyUtc','datetime2 NULL'),('DuyetLucUtc','datetime2 NULL'),('KyLucUtc','datetime2 NULL'),('DongLucUtc','datetime2 NULL'),('HieuLucTu','datetime2 NULL'),
 ('NguoiXuLy','varchar(20) NULL'),('LyDoDong','nvarchar(500) NULL'),('MaBamNoiDung','varchar(64) NULL'),('MaBamTepPdf','varchar(64) NULL'),('NoiDungJson','nvarchar(max) NULL'),('PhienBanDieuKhoan','varchar(20) NULL'),
 ('MaOtpHash','varchar(64) NULL'),('MuoiOtp','varchar(32) NULL'),('OtpHetHanUtc','datetime2 NULL'),('OtpGuiLucUtc','datetime2 NULL'),
 ('SoLanThuOtp','int NOT NULL CONSTRAINT DF_PhuLuc_SoLanThuOtp DEFAULT 0 WITH VALUES'),('SoLanGuiOtp','int NOT NULL CONSTRAINT DF_PhuLuc_SoLanGuiOtp DEFAULT 0 WITH VALUES'),('MaXacNhanKy','varchar(20) NULL'),('DiaChiIpKy','varchar(45) NULL');
DECLARE @name sysname,@definition nvarchar(300),@columnSql nvarchar(max);
DECLARE column_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT Name,Definition FROM @columns;
OPEN column_cursor;FETCH NEXT FROM column_cursor INTO @name,@definition;
WHILE @@FETCH_STATUS=0 BEGIN
 IF COL_LENGTH('dbo.PhuLuc',@name) IS NULL BEGIN
  SET @columnSql=N'ALTER TABLE dbo.PhuLuc ADD '+QUOTENAME(@name)+N' '+@definition+N';';
  EXEC(@columnSql);
 END;
 FETCH NEXT FROM column_cursor INTO @name,@definition;
END;
CLOSE column_cursor;DEALLOCATE column_cursor;
IF OBJECT_ID('dbo.CK_PhuLuc_TrangThai','C') IS NOT NULL ALTER TABLE dbo.PhuLuc DROP CONSTRAINT CK_PhuLuc_TrangThai;
EXEC(N'ALTER TABLE dbo.PhuLuc WITH CHECK ADD CONSTRAINT CK_PhuLuc_TrangThai CHECK(TrangThai IN(''CHO_XAC_NHAN'',''CHO_KY'',''DA_XAC_NHAN'',''DA_HIEU_LUC'',''TU_CHOI'',''DA_HUY'',''HET_HAN_XU_LY'',''HET_HAN_KY'',''DONG_QUY_TRINH_CU''));');
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.PhuLuc') AND name='UX_PhuLuc_Active')
 CREATE UNIQUE INDEX UX_PhuLuc_Active ON dbo.PhuLuc(MaHopDong) WHERE TrangThai IN('CHO_XAC_NHAN','CHO_KY');

IF OBJECT_ID('dbo.YeuCauHuyHopDong','U') IS NULL
CREATE TABLE dbo.YeuCauHuyHopDong(
 Id varchar(20) NOT NULL PRIMARY KEY,MaHopDong varchar(20) NOT NULL REFERENCES dbo.HopDong(MaHopDong),TrangThai varchar(20) NOT NULL,
 LoaiYeuCau varchar(20) NOT NULL DEFAULT 'KHACH_YEU_CAU',BangChung nvarchar(max) NULL,CanAdminXuLy bit NOT NULL DEFAULT 0,
 YeuCauLucUtc datetime2 NOT NULL,LyDo nvarchar(500) NOT NULL,NguoiXuLy varchar(20) NULL REFERENCES dbo.TaiKhoan(MaTaiKhoan),
 XuLyLucUtc datetime2 NULL,LyDoXuLy nvarchar(500) NULL,MienKhauTru bit NOT NULL DEFAULT 0,TyLeKhauTru decimal(5,2) NOT NULL,
 TienCocDaThu decimal(18,2) NOT NULL,TienThueDaThu decimal(18,2) NOT NULL,TienThuThuaDaThu decimal(18,2) NOT NULL,TienKhauTru decimal(18,2) NOT NULL,
 TienCocPhaiHoan decimal(18,2) NOT NULL,TienThuePhaiHoan decimal(18,2) NOT NULL,TienThuThuaPhaiHoan decimal(18,2) NOT NULL,
 CONSTRAINT CK_YeuCauHuy_Tien CHECK(TyLeKhauTru IN(0,.30,1) AND TienKhauTru>=0 AND TienCocPhaiHoan>=0 AND TienThuePhaiHoan>=0));
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.YeuCauHuyHopDong') AND name='UX_YeuCauHuy_Active')
 CREATE UNIQUE INDEX UX_YeuCauHuy_Active ON dbo.YeuCauHuyHopDong(MaHopDong) WHERE TrangThai='CHO_XAC_NHAN';
IF COL_LENGTH('dbo.ThanhToan','MaYeuCauHuy') IS NULL ALTER TABLE dbo.ThanhToan ADD MaYeuCauHuy varchar(20) NULL;
IF OBJECT_ID('dbo.FK_ThanhToan_YeuCauHuy','F') IS NULL EXEC(N'ALTER TABLE dbo.ThanhToan WITH CHECK ADD CONSTRAINT FK_ThanhToan_YeuCauHuy FOREIGN KEY(MaYeuCauHuy) REFERENCES dbo.YeuCauHuyHopDong(Id);');
IF OBJECT_ID('dbo.CK_ThanhToan_Loai','C') IS NOT NULL ALTER TABLE dbo.ThanhToan DROP CONSTRAINT CK_ThanhToan_Loai;
ALTER TABLE dbo.ThanhToan WITH CHECK ADD CONSTRAINT CK_ThanhToan_Loai CHECK(LoaiThanhToan IN('TIEN_COC','TIEN_THUE','PHI_GIA_HAN','PHI_PHAT','HOAN_COC','HOAN_TIEN_THUE','HOAN_THU_THUA'));
IF OBJECT_ID('dbo.HoanTienAudit','U') IS NULL
CREATE TABLE dbo.HoanTienAudit(Id varchar(20) NOT NULL PRIMARY KEY,MaThanhToan varchar(20) NOT NULL REFERENCES dbo.ThanhToan(MaThanhToan),
 MaTaiKhoan varchar(20) NOT NULL REFERENCES dbo.TaiKhoan(MaTaiKhoan),ChungTu nvarchar(500) NOT NULL,ThoiGianUtc datetime2 NOT NULL);
IF DB_NAME() COLLATE Latin1_General_100_BIN2<>N'$(TargetDatabase)' THROW 51100,'STOP: wrong database.',1;
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
