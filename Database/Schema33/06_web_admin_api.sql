SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH('dbo.DanhGia','TraLoi') IS NULL ALTER TABLE dbo.DanhGia ADD TraLoi nvarchar(500) NULL;
IF COL_LENGTH('dbo.DanhGia','NguoiTraLoi') IS NULL ALTER TABLE dbo.DanhGia ADD NguoiTraLoi varchar(20) NULL;
IF COL_LENGTH('dbo.DanhGia','TraLoiLucUtc') IS NULL ALTER TABLE dbo.DanhGia ADD TraLoiLucUtc datetime2 NULL;
IF COL_LENGTH('dbo.DanhGia','SuaTraLoiLucUtc') IS NULL ALTER TABLE dbo.DanhGia ADD SuaTraLoiLucUtc datetime2 NULL;
IF COL_LENGTH('dbo.AnhBienBan','PublicId') IS NULL ALTER TABLE dbo.AnhBienBan ADD PublicId nvarchar(200) NULL;
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_DanhGia_NguoiTraLoi')
 ALTER TABLE dbo.DanhGia ADD CONSTRAINT FK_DanhGia_NguoiTraLoi FOREIGN KEY(NguoiTraLoi) REFERENCES dbo.TaiKhoan(MaTaiKhoan);

IF OBJECT_ID('dbo.LichSuTrangThaiTaiKhoan','U') IS NULL CREATE TABLE dbo.LichSuTrangThaiTaiKhoan(
 MaLichSu varchar(20) NOT NULL PRIMARY KEY, MaTaiKhoan varchar(20) NOT NULL, TrangThaiCu varchar(20) NOT NULL,
 TrangThaiMoi varchar(20) NOT NULL, LyDo nvarchar(500) NULL, NguoiThaoTac varchar(20) NOT NULL, ThoiGian datetime2 NOT NULL,
 CONSTRAINT FK_LSTTTK_TaiKhoan FOREIGN KEY(MaTaiKhoan) REFERENCES dbo.TaiKhoan(MaTaiKhoan),
 CONSTRAINT FK_LSTTTK_Nguoi FOREIGN KEY(NguoiThaoTac) REFERENCES dbo.TaiKhoan(MaTaiKhoan));
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_LSTTTK_AccountTime') CREATE INDEX IX_LSTTTK_AccountTime ON dbo.LichSuTrangThaiTaiKhoan(MaTaiKhoan,ThoiGian);

IF OBJECT_ID('dbo.NhatKyHeThong','U') IS NULL CREATE TABLE dbo.NhatKyHeThong(
 MaNhatKy varchar(20) NOT NULL PRIMARY KEY, MaTaiKhoan varchar(20) NULL, VaiTro varchar(20) NULL, HanhDong varchar(10) NOT NULL,
 DuongDan nvarchar(500) NOT NULL, DoiTuong nvarchar(100) NULL, MaDoiTuong nvarchar(100) NULL, MaCuaHang varchar(20) NULL,
 TrangThaiHttp int NOT NULL, DiaChiIp varchar(45) NULL, ThoiGian datetime2 NOT NULL,
 CONSTRAINT FK_NhatKy_TaiKhoan FOREIGN KEY(MaTaiKhoan) REFERENCES dbo.TaiKhoan(MaTaiKhoan));
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_NhatKy_Time') CREATE INDEX IX_NhatKy_Time ON dbo.NhatKyHeThong(ThoiGian);

IF OBJECT_ID('dbo.PhieuBaoTri','U') IS NULL CREATE TABLE dbo.PhieuBaoTri(
 MaPhieuBaoTri varchar(20) NOT NULL PRIMARY KEY, MaThietBi varchar(20) NOT NULL, MaCuaHang varchar(20) NOT NULL,
 MoTaLoi nvarchar(max) NOT NULL, TrangThai varchar(20) NOT NULL, ChiPhiDuKien decimal(18,2) NULL, ChiPhiThucTe decimal(18,2) NULL,
 GhiChu nvarchar(max) NULL, NguoiTao varchar(20) NOT NULL, ThoiGianTao datetime2 NOT NULL, ThoiGianBatDau datetime2 NULL, ThoiGianHoanTat datetime2 NULL,
 CONSTRAINT FK_PBT_ThietBi FOREIGN KEY(MaThietBi) REFERENCES dbo.ThietBi(MaThietBi), CONSTRAINT FK_PBT_CuaHang FOREIGN KEY(MaCuaHang) REFERENCES dbo.CuaHang(MaCuaHang));
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_PBT_DeviceState') CREATE INDEX IX_PBT_DeviceState ON dbo.PhieuBaoTri(MaThietBi,TrangThai);

IF OBJECT_ID('dbo.HuHongThietBi','U') IS NULL CREATE TABLE dbo.HuHongThietBi(
 MaHuHong varchar(20) NOT NULL PRIMARY KEY, MaThietBi varchar(20) NOT NULL, MaPhieuBaoTri varchar(20) NULL, MoTa nvarchar(max) NOT NULL,
 MucDo varchar(20) NOT NULL, ChiPhiSuaChua decimal(18,2) NOT NULL, TrangThai varchar(20) NOT NULL, TinhTrangSauSuaChua nvarchar(max) NULL,
 NguoiGhiNhan varchar(20) NOT NULL, ThoiGianGhiNhan datetime2 NOT NULL, ThoiGianCapNhat datetime2 NULL,
 CONSTRAINT FK_HHTB_ThietBi FOREIGN KEY(MaThietBi) REFERENCES dbo.ThietBi(MaThietBi), CONSTRAINT FK_HHTB_PBT FOREIGN KEY(MaPhieuBaoTri) REFERENCES dbo.PhieuBaoTri(MaPhieuBaoTri));
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_HHTB_DeviceTime') CREATE INDEX IX_HHTB_DeviceTime ON dbo.HuHongThietBi(MaThietBi,ThoiGianGhiNhan);

IF OBJECT_ID('dbo.LichSuCapNhatHuHong','U') IS NULL CREATE TABLE dbo.LichSuCapNhatHuHong(
 MaLichSu varchar(20) NOT NULL PRIMARY KEY, MaHuHong varchar(20) NOT NULL, TrangThaiCu varchar(20) NOT NULL, TrangThaiMoi varchar(20) NOT NULL,
 ChiPhiCu decimal(18,2) NOT NULL, ChiPhiMoi decimal(18,2) NOT NULL, NguoiThaoTac varchar(20) NOT NULL, GhiChu nvarchar(max) NULL, ThoiGian datetime2 NOT NULL,
 CONSTRAINT FK_LSCHH_HuHong FOREIGN KEY(MaHuHong) REFERENCES dbo.HuHongThietBi(MaHuHong));

IF OBJECT_ID('dbo.TinNhan','U') IS NULL CREATE TABLE dbo.TinNhan(
 MaTinNhan varchar(20) NOT NULL PRIMARY KEY, MaKhachThue varchar(20) NOT NULL, MaCuaHang varchar(20) NULL, NguoiGui varchar(20) NOT NULL,
 LaKhach bit NOT NULL, NoiDung nvarchar(1000) NOT NULL, GuiLucUtc datetime2 NOT NULL, DaDocLucUtc datetime2 NULL,
 CONSTRAINT FK_TinNhan_Khach FOREIGN KEY(MaKhachThue) REFERENCES dbo.KhachThue(MaKhachThue),
 CONSTRAINT FK_TinNhan_CuaHang FOREIGN KEY(MaCuaHang) REFERENCES dbo.CuaHang(MaCuaHang), CONSTRAINT FK_TinNhan_NguoiGui FOREIGN KEY(NguoiGui) REFERENCES dbo.TaiKhoan(MaTaiKhoan));
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_TinNhan_Khach_Time') CREATE INDEX IX_TinNhan_Khach_Time ON dbo.TinNhan(MaKhachThue,GuiLucUtc);

COMMIT TRANSACTION;
