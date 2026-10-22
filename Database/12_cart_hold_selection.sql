-- Deployment migration: 12_cart_hold_selection.sql
-- Use sqlcmd -d <database> -v TargetDatabase=<same database>. Review backup and schema first.
IF DB_NAME() COLLATE Latin1_General_100_BIN2<>N'$(TargetDatabase)'
 THROW 51600,'STOP: connect only to $(TargetDatabase).',1;
IF @@TRANCOUNT<>0 THROW 51601,'STOP: dedicated connection required.',1;
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
IF OBJECT_ID('dbo.LichLamViecDacBiet','U') IS NULL OR COL_LENGTH('dbo.ChiTietGiuCho','PhienBanGioHang') IS NULL
 THROW 51602,'STOP: migration11 prerequisite missing.',1;
IF OBJECT_ID('dbo.LuaChonGioHangGiuCho','U') IS NOT NULL
 THROW 51603,'STOP: selection table already exists; inspect prior execution, never replay.',1;
CREATE TABLE dbo.LuaChonGioHangGiuCho(
 MaGiuCho varchar(20) NOT NULL,MaChiTietGioHang varchar(20) NOT NULL,
 MaDongMay varchar(20) NOT NULL,PhienBanGioHang uniqueidentifier NOT NULL,SoLuong int NOT NULL,
 CONSTRAINT PK_LuaChonGioHangGiuCho PRIMARY KEY(MaGiuCho,MaChiTietGioHang),
 CONSTRAINT FK_LuaChonGioHangGiuCho_GiuCho FOREIGN KEY(MaGiuCho) REFERENCES dbo.GiuCho(MaGiuCho),
 CONSTRAINT FK_LuaChonGioHangGiuCho_Cart FOREIGN KEY(MaChiTietGioHang) REFERENCES dbo.ChiTietGioHang(MaChiTietGioHang),
 CONSTRAINT FK_LuaChonGioHangGiuCho_Model FOREIGN KEY(MaDongMay) REFERENCES dbo.DongMay(MaDongMay),
 CONSTRAINT CK_LuaChonGioHangGiuCho_Qty CHECK(SoLuong>0));
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
