-- PREPARED ONLY. Separate DB approval required. New empty-database Schema33; never replay old DDLv1/v2.

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


BEGIN TRY

BEGIN TRANSACTION;

DECLARE @lock int; EXEC @lock=sys.sp_getapplock @Resource=N'SnapLease.Schema33.Initialize',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;

IF @lock<0 THROW 53308, 'Could not obtain Schema33 initialization lock.',1;

IF EXISTS(SELECT 1 FROM sys.objects WHERE is_ms_shipped=0) THROW 53309, 'Target schema is not empty; stop without dropping or overwriting anything.',1;

CREATE TABLE dbo.[TaiKhoan] (
    [MaTaiKhoan] varchar(20) NOT NULL,
    [TenDangNhap] varchar(100) NOT NULL,
    [MatKhauHash] varchar(500) NOT NULL,
    [VaiTro] varchar(20) NOT NULL,
    [TrangThai] varchar(20) NOT NULL CONSTRAINT [DF33_TaiKhoan_TrangThai] DEFAULT ('HOAT_DONG'),
    [NgayTao] datetime2 NOT NULL CONSTRAINT [DF33_TaiKhoan_NgayTao] DEFAULT (SYSDATETIME()),
    [PhienBanBaoMat] int NOT NULL CONSTRAINT [DF33_TaiKhoan_PhienBanBaoMat] DEFAULT (0),
    CONSTRAINT [PK_TaiKhoan] PRIMARY KEY ([MaTaiKhoan]),
    CONSTRAINT [CK_TaiKhoan_TrangThai] CHECK (TrangThai IN ('HOAT_DONG','TAM_KHOA')),
    CONSTRAINT [CK_TaiKhoan_VaiTro] CHECK (VaiTro IN ('ADMIN','NHAN_VIEN','KHACH_HANG')),
    CONSTRAINT [CKR_TaiKhoan_PhienBanBaoMat] CHECK (PhienBanBaoMat>=0)
);

CREATE TABLE dbo.[KhachThue] (
    [MaKhachThue] varchar(20) NOT NULL,
    [MaTaiKhoan] varchar(20) NOT NULL,
    [HoTen] nvarchar(150) NULL,
    [SoDienThoai] varchar(15) NOT NULL,
    [Email] varchar(255) NULL,
    [CCCD] varchar(20) NULL,
    [DiaChi] nvarchar(500) NULL,
    [NgaySinh] date NULL,
    [GioiTinh] nvarchar(10) NULL,
    [QuocTich] nvarchar(100) NULL,
    [NgayCap] date NULL,
    [NoiCap] nvarchar(200) NULL,
    [DaXacNhanThongTin] bit NOT NULL CONSTRAINT [DF33_KhachThue_DaXacNhanThongTin] DEFAULT (0),
    [EmailXacMinhLucUtc] datetime2 NULL,
    CONSTRAINT [PK_KhachThue] PRIMARY KEY ([MaKhachThue]),
    CONSTRAINT [CKR_KhachThue_EmailProof] CHECK (EmailXacMinhLucUtc IS NULL OR (Email IS NOT NULL AND LEN(LTRIM(RTRIM(Email)))>0))
);

CREATE TABLE dbo.[NhanVien] (
    [MaNhanVien] varchar(20) NOT NULL,
    [MaTaiKhoan] varchar(20) NOT NULL,
    [MaCuaHang] varchar(20) NOT NULL,
    [HoTen] nvarchar(150) NOT NULL,
    [DiaChi] nvarchar(500) NULL,
    [SoDienThoai] varchar(15) NOT NULL,
    [ChucVu] nvarchar(100) NOT NULL,
    [Email] varchar(255) NULL,
    [TrangThai] varchar(20) NOT NULL CONSTRAINT [DF33_NhanVien_TrangThai] DEFAULT ('HOAT_DONG'),
    CONSTRAINT [PK_NhanVien] PRIMARY KEY ([MaNhanVien]),
    CONSTRAINT [CK_NhanVien_TrangThai] CHECK (TrangThai IN ('HOAT_DONG','NGHI_VIEC'))
);

CREATE TABLE dbo.[GiayToTuyThan] (
    [MaGiayTo] varchar(20) NOT NULL,
    [MaKhachThue] varchar(20) NOT NULL,
    [LoaiGiayTo] varchar(20) NOT NULL,
    [SoGiayTo] varchar(30) NOT NULL,
    [MatTruocUrl] nvarchar(500) NOT NULL,
    [MatSauUrl] nvarchar(500) NULL,
    [NgayTaiLen] datetime2 NOT NULL CONSTRAINT [DF33_GiayToTuyThan_NgayTaiLen] DEFAULT (SYSDATETIME()),
    [TrangThaiXacMinh] varchar(20) NOT NULL CONSTRAINT [DF33_GiayToTuyThan_TrangThaiXacMinh] DEFAULT ('CHO_XAC_MINH'),
    [GhiChu] nvarchar(500) NULL,
    CONSTRAINT [PK_GiayToTuyThan] PRIMARY KEY ([MaGiayTo]),
    CONSTRAINT [CK_GiayTo_Loai] CHECK (LoaiGiayTo IN ('CCCD','HO_CHIEU','GPLX')),
    CONSTRAINT [CK_GiayTo_TrangThai] CHECK (TrangThaiXacMinh IN ('CHO_XAC_MINH','HOP_LE','TU_CHOI'))
);

CREATE TABLE dbo.[DanhMuc] (
    [MaDanhMuc] varchar(20) NOT NULL,
    [TenDanhMuc] nvarchar(150) NOT NULL,
    [MoTa] nvarchar(500) NULL,
    [TrangThai] varchar(20) NOT NULL CONSTRAINT [DF33_DanhMuc_TrangThai] DEFAULT ('HOAT_DONG'),
    CONSTRAINT [PK_DanhMuc] PRIMARY KEY ([MaDanhMuc]),
    CONSTRAINT [CK_DanhMuc_TrangThai] CHECK (TrangThai IN ('HOAT_DONG','TAM_AN'))
);

CREATE TABLE dbo.[ThuongHieu] (
    [MaThuongHieu] varchar(20) NOT NULL,
    [TenThuongHieu] nvarchar(150) NOT NULL,
    [QuocGia] nvarchar(100) NULL,
    CONSTRAINT [PK_ThuongHieu] PRIMARY KEY ([MaThuongHieu])
);

CREATE TABLE dbo.[DongMay] (
    [MaDongMay] varchar(20) NOT NULL,
    [MaDanhMuc] varchar(20) NOT NULL,
    [MaThuongHieu] varchar(20) NOT NULL,
    [TenDongMay] nvarchar(200) NOT NULL,
    [MoTa] nvarchar(1000) NULL,
    [GiaThueNgay] decimal(18,2) NOT NULL,
    [TienCoc] decimal(18,2) NOT NULL,
    [PhanTramGiamGia] decimal(5,2) NOT NULL CONSTRAINT [DF33_DongMay_PhanTramGiamGia] DEFAULT (0),
    CONSTRAINT [PK_DongMay] PRIMARY KEY ([MaDongMay]),
    CONSTRAINT [CK_DongMay_Gia] CHECK (GiaThueNgay >= 0 AND TienCoc >= 0),
    CONSTRAINT [CK_DongMay_GiamGia] CHECK (PhanTramGiamGia BETWEEN 0 AND 100)
);

CREATE TABLE dbo.[ThietBi] (
    [MaThietBi] varchar(20) NOT NULL,
    [MaDongMay] varchar(20) NOT NULL,
    [MaCuaHang] varchar(20) NOT NULL,
    [SoSerial] varchar(100) NOT NULL,
    [TinhTrang] nvarchar(200) NOT NULL,
    [TrangThai] varchar(20) NOT NULL CONSTRAINT [DF33_ThietBi_TrangThai] DEFAULT ('SAN_SANG'),
    [NgayNhap] date NULL,
    [RowVersion] rowversion NOT NULL,
    CONSTRAINT [PK_ThietBi] PRIMARY KEY ([MaThietBi]),
    CONSTRAINT [CK_ThietBi_TrangThai] CHECK (TrangThai IN (
            'SAN_SANG',
            'DANG_GIU',
            'DANG_THUE',
            'BAO_TRI',
            'HONG',
            'NGUNG_KINH_DOANH'
        ))
);

CREATE TABLE dbo.[AnhThietBi] (
    [MaAnh] varchar(20) NOT NULL,
    [MaDongMay] varchar(20) NOT NULL,
    [DuongDanAnh] nvarchar(500) NOT NULL,
    [LaAnhDaiDien] bit NOT NULL CONSTRAINT [DF33_AnhThietBi_LaAnhDaiDien] DEFAULT (0),
    [ThuTuHienThi] int NOT NULL CONSTRAINT [DF33_AnhThietBi_ThuTuHienThi] DEFAULT (0),
    CONSTRAINT [PK_AnhThietBi] PRIMARY KEY ([MaAnh]),
    CONSTRAINT [CK_AnhThietBi_ThuTu] CHECK (ThuTuHienThi >= 0)
);

CREATE TABLE dbo.[CuaHang] (
    [MaCuaHang] varchar(20) NOT NULL,
    [TenCuaHang] nvarchar(200) NOT NULL,
    [ViDo] decimal(9,6) NULL,
    [KinhDo] decimal(9,6) NULL,
    [DiaChi] nvarchar(500) NOT NULL,
    [SoDienThoai] varchar(15) NOT NULL,
    [Email] varchar(255) NULL,
    [MoTa] nvarchar(500) NULL,
    [TrangThai] varchar(20) NOT NULL CONSTRAINT [DF33_CuaHang_TrangThai] DEFAULT ('HOAT_DONG'),
    CONSTRAINT [PK_CuaHang] PRIMARY KEY ([MaCuaHang]),
    CONSTRAINT [CK_CuaHang_TrangThai] CHECK (TrangThai IN ('HOAT_DONG','TAM_KHOA')),
    CONSTRAINT [CK_CuaHang_ToaDo] CHECK ((ViDo IS NULL AND KinhDo IS NULL) OR
        (ViDo IS NOT NULL AND KinhDo IS NOT NULL AND
         ViDo BETWEEN -90 AND 90 AND KinhDo BETWEEN -180 AND 180))
);

CREATE TABLE dbo.[GioHang] (
    [MaGioHang] varchar(20) NOT NULL,
    [MaKhachThue] varchar(20) NOT NULL,
    [NgayTao] datetime2 NOT NULL CONSTRAINT [DF33_GioHang_NgayTao] DEFAULT (SYSDATETIME()),
    [NgayCapNhat] datetime2 NOT NULL CONSTRAINT [DF33_GioHang_NgayCapNhat] DEFAULT (SYSDATETIME()),
    [TrangThai] varchar(25) NOT NULL CONSTRAINT [DF33_GioHang_TrangThai] DEFAULT ('DANG_CHON'),
    CONSTRAINT [PK_GioHang] PRIMARY KEY ([MaGioHang]),
    CONSTRAINT [UQ_GioHang_MaGioHang_KhachThue] UNIQUE ([MaGioHang],[MaKhachThue]),
    CONSTRAINT [CK_GioHang_TrangThai] CHECK (TrangThai IN (
            'DANG_CHON',
            'DA_CHUYEN_HOP_DONG'
                  ))
);

CREATE TABLE dbo.[ChiTietGioHang] (
    [MaChiTietGioHang] varchar(20) NOT NULL,
    [MaGioHang] varchar(20) NOT NULL,
    [MaCuaHang] varchar(20) NOT NULL,
    [NguonTao] varchar(20) NOT NULL CONSTRAINT [DF33_ChiTietGioHang_NguonTao] DEFAULT ('GIO_HANG'),
    [PhienBan] uniqueidentifier NOT NULL CONSTRAINT [DF33_ChiTietGioHang_PhienBan] DEFAULT (NEWID()),
    [DaChuyenHopDong] bit NOT NULL CONSTRAINT [DF33_ChiTietGioHang_DaChuyenHopDong] DEFAULT (0),
    [MaDongMay] varchar(20) NOT NULL,
    [SoLuong] int NOT NULL CONSTRAINT [DF33_ChiTietGioHang_SoLuong] DEFAULT (1),
    [NgayBatDau] datetime2 NOT NULL,
    [NgayKetThuc] datetime2 NOT NULL,
    [DonGia] decimal(18,2) NOT NULL,
    [TienCoc] decimal(18,2) NOT NULL,
    [ThanhTien] decimal(18,2) NOT NULL,
    CONSTRAINT [PK_ChiTietGioHang] PRIMARY KEY ([MaChiTietGioHang]),
    CONSTRAINT [CK_ChiTietGioHang_SoLuong] CHECK (SoLuong > 0),
    CONSTRAINT [CK_ChiTietGioHang_ThoiGian] CHECK (NgayKetThuc > NgayBatDau),
    CONSTRAINT [CK_ChiTietGioHang_SoTien] CHECK (DonGia >= 0 AND TienCoc >= 0 AND ThanhTien >= 0),
    CONSTRAINT [CK_ChiTietGioHang_NguonTao] CHECK (NguonTao IN ('GIO_HANG', 'THUE_NGAY'))
);

CREATE TABLE dbo.[GiuCho] (
    [MaGiuCho] varchar(20) NOT NULL,
    [MaGioHang] varchar(20) NOT NULL,
    [MaKhachThue] varchar(20) NOT NULL,
    [MaCuaHang] varchar(20) NOT NULL,
    [NgayTao] datetime2 NOT NULL CONSTRAINT [DF33_GiuCho_NgayTao] DEFAULT (SYSDATETIME()),
    [HetHanLuc] datetime2 NOT NULL,
    [TrangThai] varchar(30) NOT NULL CONSTRAINT [DF33_GiuCho_TrangThai] DEFAULT ('DANG_GIU'),
    CONSTRAINT [PK_GiuCho] PRIMARY KEY ([MaGiuCho]),
    CONSTRAINT [CK_GiuCho_TrangThai] CHECK (TrangThai IN (
            'DANG_GIU',
            'DA_CHUYEN_HOP_DONG',
            'HET_HAN',
            'DA_HUY'
        )),
    CONSTRAINT [CK_GiuCho_ThoiGian] CHECK (HetHanLuc > NgayTao)
);

CREATE TABLE dbo.[ChiTietGiuCho] (
    [PhienBanGioHang] uniqueidentifier NOT NULL,
    [MaChiTietGiuCho] varchar(20) NOT NULL,
    [MaGiuCho] varchar(20) NOT NULL,
    [MaChiTietGioHang] varchar(20) NOT NULL,
    [MaDongMay] varchar(20) NOT NULL,
    [SoLuong] int NOT NULL,
    [NgayBatDau] datetime2 NOT NULL,
    [NgayKetThuc] datetime2 NOT NULL,
    [MaChiTietGioHangHopDong] varchar(20) NULL,
    CONSTRAINT [PK_ChiTietGiuCho] PRIMARY KEY ([MaChiTietGiuCho]),
    CONSTRAINT [CK_ChiTietGiuCho_SoLuong] CHECK (SoLuong > 0),
    CONSTRAINT [CK_ChiTietGiuCho_ThoiGian] CHECK (NgayKetThuc > NgayBatDau)
);

CREATE TABLE dbo.[HopDong] (
    [MaHopDong] varchar(20) NOT NULL,
    [MaGioHang] varchar(20) NOT NULL,
    [MaGiuCho] varchar(20) NOT NULL,
    [MaKhachThue] varchar(20) NOT NULL,
    [MaNhanVien] varchar(20) NULL,
    [MaCuaHang] varchar(20) NOT NULL,
    [NgayTaoHopDong] datetime2 NOT NULL CONSTRAINT [DF33_HopDong_NgayTaoHopDong] DEFAULT (SYSDATETIME()),
    [NgayKy] datetime2 NULL,
    [TrangThai] varchar(30) NOT NULL CONSTRAINT [DF33_HopDong_TrangThai] DEFAULT ('CHO_KY'),
    [ThoiGianBanGiao] datetime2 NOT NULL,
    [ThoiGianTraDuKien] datetime2 NOT NULL,
    [TongTien] decimal(18,2) NOT NULL,
    [TongTienCoc] decimal(18,2) NOT NULL,
    [HinhThucKy] varchar(20) NULL,
    [TepHopDongUrl] nvarchar(500) NULL,
    [DaDongYDieuKhoan] bit NOT NULL CONSTRAINT [DF33_HopDong_DaDongYDieuKhoan] DEFAULT (0),
    [PhienBanDieuKhoan] varchar(20) NULL,
    [MaBamNoiDung] char(64) NULL,
    [MaBamTepPdf] char(64) NULL,
    [NoiDungHopDongJson] nvarchar(max) NULL,
    [TrangThaiNhanTra] varchar(30) NULL,
    CONSTRAINT [PK_HopDong] PRIMARY KEY ([MaHopDong]),
    CONSTRAINT [CK_HopDong_ThoiGian] CHECK (ThoiGianTraDuKien > ThoiGianBanGiao),
    CONSTRAINT [CK_HopDong_SoTien] CHECK (TongTien >= 0 AND TongTienCoc >= 0),
    CONSTRAINT [CK_HopDong_HinhThucKy] CHECK (HinhThucKy IS NULL
            OR HinhThucKy IN ('DIEN_TU','MAN_HINH','BAN_GIAY')),
    CONSTRAINT [CK_HopDong_TrangThai] CHECK (TrangThai IN (
            'CHO_KY',
            'DA_KY',
            'CHO_BAN_GIAO',
            'DANG_THUE',
            'CHO_HOAN_TRA',
            'HOAN_THANH',
            'DA_HUY'
        )),
    CONSTRAINT [CK_HopDong_ThongTinKy] CHECK (TrangThai IN ('CHO_KY','DA_HUY')
            OR (NgayKy IS NOT NULL AND HinhThucKy IS NOT NULL)),
    CONSTRAINT [CK33_HopDong_TrangThaiNhanTra] CHECK (TrangThaiNhanTra IS NULL OR TrangThaiNhanTra IN ('DANG_KIEM_TRA','DA_KIEM_TRA','NGOAI_LE'))
);

CREATE TABLE dbo.[ChiTietHopDong] (
    [MaBienBanNhanTra] varchar(20) NULL,
    [KetQuaKiemTra] varchar(20) NULL,
    [ThieuPhuKien] bit NULL,
    [TinhTrangPhuKien] nvarchar(1000) NULL,
    [LoaiNgoaiLeNhanTra] varchar(20) NULL,
    [LyDoNgoaiLeNhanTra] nvarchar(500) NULL,
    [MaChiTietHopDong] varchar(20) NOT NULL,
    [MaHopDong] varchar(20) NOT NULL,
    [MaThietBi] varchar(20) NOT NULL,
    [DonGia] decimal(18,2) NOT NULL,
    [TinhTrangLucGiao] nvarchar(500) NULL,
    [NgayGiaoThucTe] datetime2 NULL,
    [TinhTrangLucNhan] nvarchar(500) NULL,
    [NgayNhanThucTe] datetime2 NULL,
    [CoHuHong] bit NOT NULL CONSTRAINT [DF33_ChiTietHopDong_CoHuHong] DEFAULT (0),
    CONSTRAINT [PK_ChiTietHopDong] PRIMARY KEY ([MaChiTietHopDong]),
    CONSTRAINT [CK_ChiTietHopDong_DonGia] CHECK (DonGia >= 0),
    CONSTRAINT [CK_ChiTietHopDong_NgayNhan] CHECK (NgayNhanThucTe IS NULL
            OR NgayGiaoThucTe IS NULL
            OR NgayNhanThucTe >= NgayGiaoThucTe),
    CONSTRAINT [CK_ChiTietHopDong_ReturnInspection] CHECK ((KetQuaKiemTra IS NULL OR KetQuaKiemTra IN('CHUA_KIEM_TRA','DAT','CO_VAN_DE')) AND (LoaiNgoaiLeNhanTra IS NULL OR LoaiNgoaiLeNhanTra IN('THIEU_THIET_BI','BAO_MAT')) AND (KetQuaKiemTra<>'DAT' OR (CoHuHong=0 AND ThieuPhuKien=0)))
);

CREATE TABLE dbo.[PhuLuc] (
    [HanXuLyUtc] datetime2 NULL,
    [HanKyUtc] datetime2 NULL,
    [DuyetLucUtc] datetime2 NULL,
    [KyLucUtc] datetime2 NULL,
    [DongLucUtc] datetime2 NULL,
    [LyDoDong] nvarchar(500) NULL,
    [HieuLucTu] datetime2 NULL,
    [NguoiXuLy] varchar(20) NULL,
    [MaBamNoiDung] varchar(64) NULL,
    [MaBamTepPdf] varchar(64) NULL,
    [NoiDungJson] nvarchar(max) NULL,
    [PhienBanDieuKhoan] varchar(20) NULL,
    [MaOtpHash] varchar(64) NULL,
    [MuoiOtp] varchar(32) NULL,
    [OtpHetHanUtc] datetime2 NULL,
    [OtpGuiLucUtc] datetime2 NULL,
    [SoLanThuOtp] int NOT NULL CONSTRAINT [DF33_PhuLuc_SoLanThuOtp] DEFAULT (0),
    [SoLanGuiOtp] int NOT NULL CONSTRAINT [DF33_PhuLuc_SoLanGuiOtp] DEFAULT (0),
    [MaXacNhanKy] varchar(20) NULL,
    [DiaChiIpKy] varchar(45) NULL,
    [MaPhuLuc] varchar(20) NOT NULL,
    [MaHopDong] varchar(20) NOT NULL,
    [NgayLap] datetime2 NOT NULL CONSTRAINT [DF33_PhuLuc_NgayLap] DEFAULT (SYSDATETIME()),
    [TrangThai] varchar(20) NOT NULL CONSTRAINT [DF33_PhuLuc_TrangThai] DEFAULT ('CHO_XAC_NHAN'),
    [ThoiHanTraMoi] datetime2 NOT NULL,
    [ChiPhiPhatSinh] decimal(18,2) NOT NULL,
    [TienCocBoSung] decimal(18,2) NOT NULL CONSTRAINT [DF33_PhuLuc_TienCocBoSung] DEFAULT (0),
    [GhiChu] nvarchar(500) NULL,
    [LyDoGiaHan] nvarchar(500) NULL,
    CONSTRAINT [PK_PhuLuc] PRIMARY KEY ([MaPhuLuc]),
    CONSTRAINT [CK_PhuLuc_ChiPhi] CHECK (ChiPhiPhatSinh >= 0 AND TienCocBoSung >= 0),
    CONSTRAINT [CK_PhuLuc_TrangThai] CHECK (TrangThai IN('CHO_XAC_NHAN','CHO_KY','DA_XAC_NHAN','DA_HIEU_LUC','TU_CHOI','DA_HUY','HET_HAN_XU_LY','HET_HAN_KY','DONG_QUY_TRINH_CU'))
);

CREATE TABLE dbo.[XacNhanKyHopDong] (
    [MaXacNhan] varchar(20) NOT NULL,
    [MaHopDong] varchar(20) NOT NULL,
    [MaOtpHash] char(64) NOT NULL,
    [MuoiOtp] char(32) NOT NULL,
    [TaoLuc] datetime2 NOT NULL CONSTRAINT [DF33_XacNhanKyHopDong_TaoLuc] DEFAULT (SYSDATETIME()),
    [HetHanLuc] datetime2 NOT NULL,
    [SoLanThu] int NOT NULL CONSTRAINT [DF33_XacNhanKyHopDong_SoLanThu] DEFAULT (0),
    [TrangThai] varchar(20) NOT NULL CONSTRAINT [DF33_XacNhanKyHopDong_TrangThai] DEFAULT ('CHO_XAC_NHAN'),
    [XacNhanLuc] datetime2 NULL,
    [DiaChiIp] varchar(45) NULL,
    [ThietBiKy] nvarchar(500) NULL,
    [PhienBanDieuKhoan] varchar(20) NOT NULL,
    [MaBamNoiDung] char(64) NOT NULL,
    [MaBamTepPdf] char(64) NULL,
    [NoiDungHopDongJson] nvarchar(max) NOT NULL,
    CONSTRAINT [PK_XacNhanKyHopDong] PRIMARY KEY ([MaXacNhan]),
    CONSTRAINT [CK_XacNhanKyHopDong_ThoiGian] CHECK (HetHanLuc > TaoLuc),
    CONSTRAINT [CK_XacNhanKyHopDong_SoLanThu] CHECK (SoLanThu >= 0),
    CONSTRAINT [CK_XacNhanKyHopDong_TrangThai] CHECK (TrangThai IN ('CHO_XAC_NHAN','DA_XAC_NHAN','HET_HAN','DA_HUY','KHOA')),
    CONSTRAINT [CK_XacNhanKyHopDong_Json] CHECK (ISJSON(NoiDungHopDongJson) = 1)
);

CREATE TABLE dbo.[ThanhToan] (
    [MaQuyetToan] varchar(20) NULL,
    [MaThanhToan] varchar(20) NOT NULL,
    [MaHopDong] varchar(20) NOT NULL,
    [SoTien] decimal(18,2) NOT NULL,
    [LoaiThanhToan] varchar(30) NOT NULL,
    [PhuongThuc] varchar(30) NOT NULL,
    [MaGiaoDich] varchar(100) NULL,
    [ThoiGian] datetime2 NULL,
    [TrangThai] varchar(20) NOT NULL CONSTRAINT [DF33_ThanhToan_TrangThai] DEFAULT ('CHO_THANH_TOAN'),
    [NoiDungChuyenKhoan] nvarchar(500) NULL,
    [NhaCungCap] varchar(20) NULL,
    [MaThamChieu] varchar(100) NULL,
    [MaNganHang] varchar(20) NULL,
    [LoaiThe] varchar(20) NULL,
    [MaPhanHoi] varchar(10) NULL,
    [DuongDanThanhToan] varchar(2000) NULL,
    [ThoiGianHetHan] datetime2 NULL,
    [ThoiGianCapNhat] datetime2 NULL,
    [NguoiXacNhanHoan] varchar(20) NULL,
    [XacNhanHoanLucUtc] datetime2 NULL,
    [NguoiXacNhanNhanHoan] varchar(20) NULL,
    [KhachXacNhanNhanHoanLucUtc] datetime2 NULL,
    [MaDoiSoatHuyHopDong] varchar(20) NULL,
    CONSTRAINT [PK_ThanhToan] PRIMARY KEY ([MaThanhToan]),
    CONSTRAINT [AK_ThanhToan_MaThanhToan_MaHopDong] UNIQUE ([MaThanhToan],[MaHopDong]),
    CONSTRAINT [CK_ThanhToan_SoTien] CHECK (SoTien > 0),
    CONSTRAINT [CK_ThanhToan_Loai] CHECK (LoaiThanhToan IN('TIEN_COC','TIEN_THUE','PHI_GIA_HAN','PHI_PHAT','HOAN_COC','HOAN_TIEN_THUE','HOAN_THU_THUA','THU_QUYET_TOAN')),
    CONSTRAINT [CK_ThanhToan_PhuongThuc] CHECK (PhuongThuc IN (
            'TIEN_MAT',
            'CHUYEN_KHOAN',
            'VI_DIEN_TU'
        )),
    CONSTRAINT [CK_ThanhToan_TrangThai] CHECK (TrangThai IN (
            'CHO_THANH_TOAN',
            'THANH_CONG',
            'THAT_BAI',
            'DA_HOAN'
        )),
    CONSTRAINT [CKR_ThanhToan_RefundStaff] CHECK ((NguoiXacNhanHoan IS NULL AND XacNhanHoanLucUtc IS NULL) OR (NguoiXacNhanHoan IS NOT NULL AND XacNhanHoanLucUtc IS NOT NULL AND LoaiThanhToan IN ('HOAN_COC','HOAN_TIEN_THUE','HOAN_THU_THUA') AND TrangThai='DA_HOAN')),
    CONSTRAINT [CKR_ThanhToan_RefundRecorded] CHECK (LoaiThanhToan NOT IN ('HOAN_COC','HOAN_TIEN_THUE','HOAN_THU_THUA') OR TrangThai<>'DA_HOAN' OR (NguoiXacNhanHoan IS NOT NULL AND XacNhanHoanLucUtc IS NOT NULL)),
    CONSTRAINT [CKR_ThanhToan_RefundOwner] CHECK ((NguoiXacNhanNhanHoan IS NULL AND KhachXacNhanNhanHoanLucUtc IS NULL) OR (NguoiXacNhanNhanHoan IS NOT NULL AND KhachXacNhanNhanHoanLucUtc IS NOT NULL AND XacNhanHoanLucUtc IS NOT NULL AND NguoiXacNhanHoan IS NOT NULL AND KhachXacNhanNhanHoanLucUtc>=XacNhanHoanLucUtc AND LoaiThanhToan IN ('HOAN_COC','HOAN_TIEN_THUE','HOAN_THU_THUA') AND TrangThai='DA_HOAN')),
    CONSTRAINT [CK33_ThanhToan_RefundContext] CHECK ((MaDoiSoatHuyHopDong IS NULL AND ((MaQuyetToan IS NULL AND LoaiThanhToan NOT IN ('THU_QUYET_TOAN','HOAN_COC','HOAN_TIEN_THUE')) OR (MaQuyetToan IS NOT NULL AND LoaiThanhToan IN ('THU_QUYET_TOAN','HOAN_COC','HOAN_TIEN_THUE')))) OR (MaDoiSoatHuyHopDong IS NOT NULL AND MaDoiSoatHuyHopDong=MaHopDong AND MaQuyetToan IS NULL AND LoaiThanhToan IN ('HOAN_COC','HOAN_TIEN_THUE','HOAN_THU_THUA')))
);

CREATE TABLE dbo.[YeuCauThanhToanVnpay] (
    [MaYeuCau] varchar(50) NOT NULL,
    [MaThanhToan] varchar(20) NOT NULL,
    [MaThamChieu] varchar(100) NOT NULL,
    [SoTien] decimal(18,2) NOT NULL,
    [TienTe] varchar(10) NOT NULL CONSTRAINT [DF33_YeuCauThanhToanVnpay_TienTe] DEFAULT (('VND')),
    [DuongDanThanhToan] varchar(2000) NOT NULL,
    [ThoiGianHetHan] datetime2 NOT NULL,
    [TrangThai] varchar(30) NOT NULL CONSTRAINT [DF33_YeuCauThanhToanVnpay_TrangThai] DEFAULT (('CHO_THANH_TOAN')),
    [LaThuThua] bit NOT NULL CONSTRAINT [DF33_YeuCauThanhToanVnpay_LaThuThua] DEFAULT ((0)),
    [MaGiaoDich] varchar(100) NULL,
    [MaNganHang] varchar(20) NULL,
    [LoaiThe] varchar(20) NULL,
    [MaPhanHoi] varchar(10) NULL,
    [GhiChu] nvarchar(500) NULL,
    [ThoiGianTao] datetime2 NOT NULL CONSTRAINT [DF33_YeuCauThanhToanVnpay_ThoiGianTao] DEFAULT (SYSUTCDATETIME()),
    [ThoiGianCapNhat] datetime2 NULL,
    CONSTRAINT [PK_YeuCauThanhToanVnpay] PRIMARY KEY ([MaYeuCau]),
    CONSTRAINT [CK_YeuCauThanhToanVnpay_TrangThai] CHECK (TrangThai IN ('CHO_THANH_TOAN', 'THANH_CONG', 'THAT_BAI', 'HET_HAN'))
);

CREATE TABLE dbo.[PhieuPhat] (
    [MaPhieuPhat] varchar(20) NOT NULL,
    [MaChiTietHopDong] varchar(20) NOT NULL,
    [LoaiViPham] varchar(30) NOT NULL,
    [SoTien] decimal(18,2) NOT NULL,
    [MoTa] nvarchar(500) NOT NULL,
    [NgayLap] datetime2 NOT NULL CONSTRAINT [DF33_PhieuPhat_NgayLap] DEFAULT (SYSDATETIME()),
    [TrangThai] varchar(20) NOT NULL CONSTRAINT [DF33_PhieuPhat_TrangThai] DEFAULT ('CHO_XAC_NHAN'),
    [NguoiLap] varchar(20) NOT NULL,
    [NguoiXuLy] varchar(20) NULL,
    [XuLyLucUtc] datetime2 NULL,
    CONSTRAINT [PK_PhieuPhat] PRIMARY KEY ([MaPhieuPhat]),
    CONSTRAINT [CK_PhieuPhat_Loai] CHECK (LoaiViPham IN('TRA_TRE','HU_HONG','KHAC','THIEU_PHU_KIEN')),
    CONSTRAINT [CK_PhieuPhat_SoTien] CHECK (SoTien >= 0),
    CONSTRAINT [CK_PhieuPhat_TrangThai] CHECK (TrangThai IN (
            'CHO_XAC_NHAN',
            'DA_XAC_NHAN',
            'DA_THANH_TOAN',
            'HUY'
        )),
    CONSTRAINT [CKR_PhieuPhat_Actor] CHECK ((TrangThai='CHO_XAC_NHAN' AND NguoiXuLy IS NULL AND XuLyLucUtc IS NULL) OR (TrangThai IN ('DA_XAC_NHAN','DA_THANH_TOAN','HUY') AND NguoiXuLy IS NOT NULL AND XuLyLucUtc IS NOT NULL))
);

CREATE TABLE dbo.[QuyetToanHopDong] (
    [Id] varchar(20) NOT NULL,
    [MaHopDong] varchar(20) NOT NULL,
    [MaBienBan] varchar(20) NOT NULL,
    [PhienBan] int NOT NULL,
    [MaBam] varchar(64) NOT NULL,
    [NguoiChot] varchar(20) NOT NULL,
    [ChotLucUtc] datetime2 NOT NULL,
    [HanTraHieuLuc] datetime2 NOT NULL,
    [TienThue] decimal(18,2) NOT NULL,
    [PhiGiaHan] decimal(18,2) NOT NULL,
    [PhiTraTre] decimal(18,2) NOT NULL,
    [BoiThuong] decimal(18,2) NOT NULL,
    [TongNghiaVu] decimal(18,2) NOT NULL,
    [ThuePhiDaThu] decimal(18,2) NOT NULL,
    [CocDaThu] decimal(18,2) NOT NULL,
    [CocKhauTru] decimal(18,2) NOT NULL,
    [ConPhaiThuBanDau] decimal(18,2) NOT NULL,
    [HoanCocBanDau] decimal(18,2) NOT NULL,
    [HoanKhacBanDau] decimal(18,2) NOT NULL,
    [HoanThanhLucUtc] datetime2 NULL,
    [KhachXacNhanHoanTatLucUtc] datetime2 NULL,
    [NguoiXacNhanHoanTat] varchar(20) NULL,
    CONSTRAINT [PK_QuyetToanHopDong] PRIMARY KEY ([Id]),
    CONSTRAINT [AK_QuyetToanHopDong_Id_MaHopDong] UNIQUE ([Id],[MaHopDong]),
    CONSTRAINT [CK_QuyetToanHopDong_Money] CHECK (TienThue>=0 AND PhiGiaHan>=0 AND PhiTraTre>=0 AND BoiThuong>=0 AND ThuePhiDaThu>=0 AND CocDaThu>=0 AND CocKhauTru>=0 AND CocKhauTru<=CocDaThu AND ConPhaiThuBanDau>=0 AND HoanCocBanDau>=0 AND HoanKhacBanDau>=0 AND TongNghiaVu=TienThue+PhiGiaHan+PhiTraTre+BoiThuong AND ThuePhiDaThu+CocDaThu+ConPhaiThuBanDau=TongNghiaVu+HoanCocBanDau+HoanKhacBanDau),
    CONSTRAINT [CK_QuyetToanHopDong_Version] CHECK (PhienBan=1 AND LEN(MaBam)=64),
    CONSTRAINT [CK33_QuyetToanHopDong_NoRefundAck] CHECK ((KhachXacNhanHoanTatLucUtc IS NULL AND NguoiXacNhanHoanTat IS NULL) OR (KhachXacNhanHoanTatLucUtc IS NOT NULL AND NguoiXacNhanHoanTat IS NOT NULL AND HoanCocBanDau+HoanKhacBanDau=0 AND KhachXacNhanHoanTatLucUtc>=ChotLucUtc))
);

CREATE TABLE dbo.[PhanBoQuyetToan] (
    [Id] varchar(20) NOT NULL,
    [MaHopDong] varchar(20) NOT NULL,
    [MaQuyetToan] varchar(20) NOT NULL,
    [LoaiDong] varchar(20) NOT NULL,
    [LoaiNghiaVu] varchar(20) NOT NULL,
    [MoTa] nvarchar(500) NOT NULL,
    [SoTien] decimal(18,2) NOT NULL,
    [MaNghiaVu] varchar(20) NULL,
    [MaThanhToan] varchar(20) NULL,
    [MaChiTietHopDong] varchar(20) NULL,
    [MaPhuLuc] varchar(20) NULL,
    [MaPhieuPhat] varchar(20) NULL,
    [DonGia] decimal(18,2) NULL,
    [SoNgay] int NULL,
    [TaoLucUtc] datetime2 NOT NULL,
    CONSTRAINT [PK_PhanBoQuyetToan] PRIMARY KEY ([Id]),
    CONSTRAINT [AK_PhanBoQuyetToan_MaQuyetToan_Id] UNIQUE ([MaQuyetToan],[Id]),
    CONSTRAINT [CK_PhanBoQuyetToan_Kind] CHECK (LoaiNghiaVu IN('TIEN_THUE','PHI_GIA_HAN','TRA_TRE','BOI_THUONG') AND (DonGia IS NULL OR DonGia>=0) AND (SoNgay IS NULL OR SoNgay>=0)),
    CONSTRAINT [CK_PhanBoQuyetToan_Line] CHECK ((LoaiDong='NGHIA_VU' AND SoTien>=0 AND MaNghiaVu IS NULL AND MaThanhToan IS NULL) OR (LoaiDong='PHAN_BO' AND SoTien>0 AND MaNghiaVu IS NOT NULL AND MaThanhToan IS NOT NULL AND Id<>MaNghiaVu))
);

CREATE TABLE dbo.[DanhGia] (
    [MaDanhGia] varchar(20) NOT NULL,
    [MaChiTietHopDong] varchar(20) NOT NULL,
    [MaKhachThue] varchar(20) NOT NULL,
    [NhanXet] nvarchar(1000) NULL,
    [SoSao] tinyint NOT NULL,
    [NgayDanhGia] datetime2 NOT NULL CONSTRAINT [DF33_DanhGia_NgayDanhGia] DEFAULT (SYSDATETIME()),
    [TrangThaiKiemDuyet] varchar(20) NULL CONSTRAINT [DF33_DanhGia_TrangThaiKiemDuyet] DEFAULT ('CONG_KHAI'),
    [GhiChuKiemDuyet] nvarchar(500) NULL,
    [NgayKiemDuyet] datetime2 NULL,
    [NguoiCapNhatHienThi] varchar(20) NULL,
    CONSTRAINT [PK_DanhGia] PRIMARY KEY ([MaDanhGia]),
    CONSTRAINT [CK_DanhGia_SoSao] CHECK (SoSao BETWEEN 1 AND 5),
    CONSTRAINT [CK_DanhGia_TrangThaiKiemDuyet] CHECK (TrangThaiKiemDuyet IS NULL OR TrangThaiKiemDuyet IN ('CONG_KHAI','AN','CHO_DUYET','DA_DUYET','TU_CHOI'))
);

CREATE TABLE dbo.[AnhDanhGia] (
    [MaAnhDanhGia] varchar(20) NOT NULL,
    [MaDanhGia] varchar(20) NOT NULL,
    [DuongDanAnh] nvarchar(500) NOT NULL,
    [PublicId] nvarchar(200) NOT NULL,
    [ThuTu] tinyint NOT NULL,
    [NgayTao] datetime2 NOT NULL CONSTRAINT [DF33_AnhDanhGia_NgayTao] DEFAULT (SYSDATETIME()),
    CONSTRAINT [PK_AnhDanhGia] PRIMARY KEY ([MaAnhDanhGia]),
    CONSTRAINT [CK_AnhDanhGia_ThuTu] CHECK (ThuTu BETWEEN 1 AND 4)
);

CREATE TABLE dbo.[AnhBienBan] (
    [MaAnhBienBan] varchar(20) NOT NULL,
    [MaChiTietHopDong] varchar(20) NOT NULL,
    [Loai] varchar(20) NOT NULL,
    [DuongDanAnh] nvarchar(500) NOT NULL,
    [MoTa] nvarchar(300) NULL,
    [ThoiGianChup] datetime2 NOT NULL CONSTRAINT [DF33_AnhBienBan_ThoiGianChup] DEFAULT (SYSDATETIME()),
    CONSTRAINT [PK_AnhBienBan] PRIMARY KEY ([MaAnhBienBan]),
    CONSTRAINT [CK_AnhBienBan_Loai] CHECK (Loai IN ('BAN_GIAO','NHAN_LAI','HU_HONG'))
);

CREATE TABLE dbo.[ThongBao] (
    [HanTraNhac] datetime2 NULL,
    [EventKey] varchar(200) NULL,
    [MaThongBao] varchar(20) NOT NULL,
    [MaTaiKhoan] varchar(20) NOT NULL,
    [Loai] varchar(30) NOT NULL,
    [TieuDe] nvarchar(200) NOT NULL,
    [NoiDung] nvarchar(1000) NOT NULL,
    [ThoiGianGui] datetime2 NOT NULL CONSTRAINT [DF33_ThongBao_ThoiGianGui] DEFAULT (SYSDATETIME()),
    [DaDoc] bit NOT NULL CONSTRAINT [DF33_ThongBao_DaDoc] DEFAULT (0),
    [EventCode] varchar(50) NULL,
    [TargetType] varchar(30) NULL,
    [TargetId] varchar(50) NULL,
    CONSTRAINT [PK_ThongBao] PRIMARY KEY ([MaThongBao])
);

CREATE TABLE dbo.[FcmDeviceToken] (
    [Id] varchar(36) NOT NULL,
    [MaTaiKhoan] varchar(20) NOT NULL,
    [Token] nvarchar(2048) NOT NULL,
    [TokenHash] char(64) NOT NULL,
    [Platform] varchar(20) NOT NULL,
    [DeviceId] nvarchar(200) NULL,
    [IsActive] bit NOT NULL CONSTRAINT [DF33_FcmDeviceToken_IsActive] DEFAULT (1),
    [CreatedAt] datetime2 NOT NULL CONSTRAINT [DF33_FcmDeviceToken_CreatedAt] DEFAULT (SYSUTCDATETIME()),
    [UpdatedAt] datetime2 NOT NULL CONSTRAINT [DF33_FcmDeviceToken_UpdatedAt] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_FcmDeviceToken] PRIMARY KEY ([Id])
);

CREATE TABLE dbo.[NotificationDelivery] (
    [Id] varchar(36) NOT NULL,
    [MaThongBao] varchar(20) NOT NULL,
    [DeviceTokenId] varchar(36) NOT NULL,
    [State] varchar(20) NOT NULL CONSTRAINT [DF33_NotificationDelivery_State] DEFAULT ('PENDING'),
    [Attempts] int NOT NULL CONSTRAINT [DF33_NotificationDelivery_Attempts] DEFAULT (0),
    [NextAttemptUtc] datetime2 NOT NULL,
    [LeaseUntilUtc] datetime2 NULL,
    [LastErrorCode] varchar(100) NULL,
    CONSTRAINT [PK_NotificationDelivery] PRIMARY KEY ([Id])
);

CREATE TABLE dbo.[IdempotencyKey] (
    [IdempotencyKey] varchar(100) NOT NULL,
    [MaKhachThue] varchar(20) NOT NULL,
    [LoaiThaoTac] varchar(50) NOT NULL,
    [PayloadHash] varchar(64) NOT NULL,
    [MaThucThe] varchar(50) NOT NULL,
    [NgayTao] datetime2 NOT NULL CONSTRAINT [DF33_IdempotencyKey_NgayTao] DEFAULT (SYSDATETIME()),
    CONSTRAINT [PK_IdempotencyKey] PRIMARY KEY ([IdempotencyKey],[MaKhachThue],[LoaiThaoTac])
);

CREATE TABLE dbo.[BienBanNhanTra] (
    [Id] varchar(20) NOT NULL,
    [MaHopDong] varchar(20) NOT NULL,
    [ThucNhanLuc] datetime2 NULL,
    [NguoiGhiNhan] varchar(20) NOT NULL,
    [GhiNhanLucUtc] datetime2 NOT NULL,
    [LyDoGhiNhanMuon] nvarchar(500) NULL,
    [KiemTraLucUtc] datetime2 NULL,
    [NguoiKiemTra] varchar(20) NULL,
    [ThucNhanLucTruocSua] datetime2 NULL,
    [NguoiSuaThucNhan] varchar(20) NULL,
    [SuaThucNhanLucUtc] datetime2 NULL,
    [LyDoSuaThucNhan] nvarchar(500) NULL,
    CONSTRAINT [PK_BienBanNhanTra] PRIMARY KEY ([Id]),
    CONSTRAINT [AK_BienBanNhanTra_Id_MaHopDong] UNIQUE ([Id],[MaHopDong]),
    CONSTRAINT [CK33_BienBanNhanTra_Inspection] CHECK ((KiemTraLucUtc IS NULL AND NguoiKiemTra IS NULL) OR (KiemTraLucUtc IS NOT NULL AND NguoiKiemTra IS NOT NULL AND ThucNhanLuc IS NOT NULL)),
    CONSTRAINT [CK33_BienBanNhanTra_LastCorrection] CHECK ((ThucNhanLucTruocSua IS NULL AND NguoiSuaThucNhan IS NULL AND SuaThucNhanLucUtc IS NULL AND LyDoSuaThucNhan IS NULL) OR (ThucNhanLucTruocSua IS NOT NULL AND NguoiSuaThucNhan IS NOT NULL AND SuaThucNhanLucUtc IS NOT NULL AND LyDoSuaThucNhan IS NOT NULL AND LEN(LTRIM(RTRIM(LyDoSuaThucNhan)))>0 AND ThucNhanLuc IS NOT NULL))
);

CREATE TABLE dbo.[DoiSoatHuyHopDong] (
    [MaHopDong] varchar(20) NOT NULL,
    [HuyLucUtc] datetime2 NOT NULL,
    [NguoiHuy] varchar(20) NULL,
    [LoaiTacNhanHuy] varchar(20) NOT NULL,
    [LoaiHuy] varchar(30) NOT NULL,
    [LyDoHuy] nvarchar(500) NOT NULL,
    [TyLeKhauTruHuy] decimal(5,2) NOT NULL,
    [TienCocDaThuKhiHuy] decimal(18,2) NOT NULL,
    [TienThueDaThuKhiHuy] decimal(18,2) NOT NULL,
    [TienThuThuaDaThuKhiHuy] decimal(18,2) NOT NULL,
    [TienKhauTruHuy] decimal(18,2) NOT NULL,
    [TienCocPhaiHoanKhiHuy] decimal(18,2) NOT NULL,
    [TienThuePhaiHoanKhiHuy] decimal(18,2) NOT NULL,
    [TienThuThuaPhaiHoanKhiHuy] decimal(18,2) NOT NULL,
    [DoiSoatHuyLucUtc] datetime2 NOT NULL,
    [CanCuNgoaiLeHuy] varchar(30) NULL,
    [LyDoNgoaiLeHuy] nvarchar(500) NULL,
    [TaiLieuNgoaiLeHuyUrl] nvarchar(500) NULL,
    CONSTRAINT [PK33_DoiSoatHuyHopDong] PRIMARY KEY ([MaHopDong]),
    CONSTRAINT [CK33_DoiSoatHuyHopDong_Actor] CHECK (LoaiTacNhanHuy IN ('KHACH_HANG','NHAN_VIEN','ADMIN','HE_THONG') AND ((LoaiTacNhanHuy='HE_THONG' AND NguoiHuy IS NULL) OR (LoaiTacNhanHuy<>'HE_THONG' AND NguoiHuy IS NOT NULL)) AND LoaiHuy IN ('KHACH_HUY','KHONG_DEN','CUA_HANG_HUY','HET_HAN_KY') AND LEN(LTRIM(RTRIM(LyDoHuy)))>0 AND DoiSoatHuyLucUtc>=HuyLucUtc),
    CONSTRAINT [CK33_DoiSoatHuyHopDong_Money] CHECK (TyLeKhauTruHuy IN (0,0.30,1) AND TienCocDaThuKhiHuy>=0 AND TienThueDaThuKhiHuy>=0 AND TienThuThuaDaThuKhiHuy>=0 AND TienKhauTruHuy>=0 AND TienCocPhaiHoanKhiHuy>=0 AND TienThuePhaiHoanKhiHuy>=0 AND TienThuThuaPhaiHoanKhiHuy>=0 AND TienKhauTruHuy=ROUND(TienCocDaThuKhiHuy*TyLeKhauTruHuy,2) AND TienCocPhaiHoanKhiHuy=TienCocDaThuKhiHuy-TienKhauTruHuy AND TienThuePhaiHoanKhiHuy=TienThueDaThuKhiHuy AND TienThuThuaPhaiHoanKhiHuy=TienThuThuaDaThuKhiHuy AND (LoaiHuy NOT IN ('CUA_HANG_HUY','HET_HAN_KY') OR TyLeKhauTruHuy=0)),
    CONSTRAINT [CK33_DoiSoatHuyHopDong_UnsignedExpiry] CHECK (LoaiHuy<>'HET_HAN_KY' OR (TienCocDaThuKhiHuy=0 AND TienThueDaThuKhiHuy=0 AND TienThuThuaDaThuKhiHuy=0 AND TienKhauTruHuy=0 AND TienCocPhaiHoanKhiHuy=0 AND TienThuePhaiHoanKhiHuy=0 AND TienThuThuaPhaiHoanKhiHuy=0)),
    CONSTRAINT [CK33_DoiSoatHuyHopDong_NoShowReason] CHECK (LoaiHuy<>'KHONG_DEN' OR LyDoHuy=N'Khách không đến nhận bàn giao thiết bị'),
    CONSTRAINT [CK33_DoiSoatHuyHopDong_NoShowRate] CHECK (LoaiHuy<>'KHONG_DEN' OR TyLeKhauTruHuy=1 OR (TyLeKhauTruHuy=0 AND CanCuNgoaiLeHuy IS NOT NULL AND CanCuNgoaiLeHuy IN ('BAT_KHA_KHANG','LOI_CUA_HANG'))),
    CONSTRAINT [CK33_DoiSoatHuyHopDong_Exception] CHECK ((CanCuNgoaiLeHuy IS NULL AND LyDoNgoaiLeHuy IS NULL) OR (CanCuNgoaiLeHuy IS NOT NULL AND CanCuNgoaiLeHuy IN ('BAT_KHA_KHANG','LOI_CUA_HANG') AND LyDoNgoaiLeHuy IS NOT NULL AND LEN(LTRIM(RTRIM(LyDoNgoaiLeHuy)))>0 AND TyLeKhauTruHuy=0 AND (CanCuNgoaiLeHuy<>'BAT_KHA_KHANG' OR LoaiTacNhanHuy='ADMIN')))
);

CREATE TABLE dbo.[XacMinhKhachKhongDen] (
    [MaHopDong] varchar(20) NOT NULL,
    [NguoiXacMinh] varchar(20) NOT NULL,
    [XacMinhLucUtc] datetime2 NOT NULL,
    [GioHenKhiXacMinhKhongDen] datetime2 NOT NULL,
    [KhongCoLichHenMoi] bit NOT NULL,
    [CuaHangSanSangBanGiao] bit NOT NULL,
    [KhachChuaCheckIn] bit NOT NULL,
    [DaThuLienHe] bit NOT NULL,
    [LienHeLucUtc] datetime2 NOT NULL,
    [KenhLienHe] nvarchar(100) NOT NULL,
    [KetQuaLienHe] nvarchar(500) NOT NULL,
    [CoTranhChapKhongDen] bit NOT NULL,
    [GhiChuKhongDen] nvarchar(500) NOT NULL,
    CONSTRAINT [PK33_XacMinhKhachKhongDen] PRIMARY KEY ([MaHopDong]),
    CONSTRAINT [CK33_XacMinhKhachKhongDen_Time] CHECK (XacMinhLucUtc>=DATEADD(hour,-5,GioHenKhiXacMinhKhongDen) AND LienHeLucUtc<=XacMinhLucUtc),
    CONSTRAINT [CK33_XacMinhKhachKhongDen_Text] CHECK (LEN(LTRIM(RTRIM(KenhLienHe)))>0 AND LEN(LTRIM(RTRIM(KetQuaLienHe)))>0 AND LEN(LTRIM(RTRIM(GhiChuKhongDen)))>0)
);

CREATE UNIQUE INDEX [UQ_TaiKhoan_TenDangNhap] ON dbo.[TaiKhoan] ([TenDangNhap]);

CREATE UNIQUE INDEX [UQ_KhachThue_MaTaiKhoan] ON dbo.[KhachThue] ([MaTaiKhoan]);

CREATE UNIQUE INDEX [UQ_KhachThue_SoDienThoai] ON dbo.[KhachThue] ([SoDienThoai]);

CREATE UNIQUE INDEX [UX_KhachThue_CCCD_NotNull] ON dbo.[KhachThue] ([CCCD]) WHERE CCCD IS NOT NULL;

CREATE UNIQUE INDEX [UQ_NhanVien_MaTaiKhoan] ON dbo.[NhanVien] ([MaTaiKhoan]);

CREATE UNIQUE INDEX [UQ_GiayToTuyThan_SoGiayTo] ON dbo.[GiayToTuyThan] ([SoGiayTo]);

CREATE UNIQUE INDEX [UQ_DanhMuc_TenDanhMuc] ON dbo.[DanhMuc] ([TenDanhMuc]);

CREATE UNIQUE INDEX [UQ_ThuongHieu_TenThuongHieu] ON dbo.[ThuongHieu] ([TenThuongHieu]);

CREATE UNIQUE INDEX [UQ_DongMay] ON dbo.[DongMay] ([MaThuongHieu],[TenDongMay]);

CREATE UNIQUE INDEX [UQ_ThietBi_SoSerial] ON dbo.[ThietBi] ([SoSerial]);

CREATE INDEX [IX_ThietBi_TimKiem] ON dbo.[ThietBi] ([MaCuaHang],[MaDongMay],[TrangThai]);

CREATE UNIQUE INDEX [UX_AnhThietBi_DaiDien] ON dbo.[AnhThietBi] ([MaDongMay]) WHERE LaAnhDaiDien = 1;

CREATE INDEX [IX_GioHang_KhachHang] ON dbo.[GioHang] ([MaKhachThue],[TrangThai],[NgayCapNhat]);

CREATE INDEX [IX_ChiTietGioHang_Lich] ON dbo.[ChiTietGioHang] ([MaDongMay],[NgayBatDau],[NgayKetThuc]);

CREATE INDEX [IX_GiuCho_Availability] ON dbo.[GiuCho] ([MaCuaHang],[TrangThai],[HetHanLuc]);

CREATE INDEX [IX_GiuCho_KhachHang] ON dbo.[GiuCho] ([MaKhachThue],[TrangThai],[HetHanLuc]);

CREATE INDEX [IX_ChiTietGiuCho_Lich] ON dbo.[ChiTietGiuCho] ([MaDongMay],[NgayBatDau],[NgayKetThuc]);

CREATE UNIQUE INDEX [UQ_HopDong_MaGiuCho] ON dbo.[HopDong] ([MaGiuCho]);

CREATE INDEX [IX_HopDong_Lich] ON dbo.[HopDong] ([MaCuaHang],[TrangThai],[ThoiGianBanGiao],[ThoiGianTraDuKien]);

CREATE INDEX [IX_HopDong_KhachHang] ON dbo.[HopDong] ([MaKhachThue],[TrangThai],[NgayTaoHopDong]);

CREATE INDEX [IX_HopDong_HanTra] ON dbo.[HopDong] ([TrangThai],[ThoiGianTraDuKien]);

CREATE UNIQUE INDEX [UQ_ChiTietHopDong] ON dbo.[ChiTietHopDong] ([MaHopDong],[MaThietBi]);

CREATE INDEX [IX_ChiTietHopDong_ThietBi] ON dbo.[ChiTietHopDong] ([MaThietBi],[MaHopDong]);

CREATE INDEX [IX_PhuLuc_HopDong] ON dbo.[PhuLuc] ([MaHopDong],[TrangThai],[ThoiHanTraMoi]);

CREATE UNIQUE INDEX [UX_PhuLuc_Active] ON dbo.[PhuLuc] ([MaHopDong]) WHERE TrangThai IN('CHO_XAC_NHAN','CHO_KY');

CREATE INDEX [IX_XacNhanKyHopDong_HopDong_TrangThai] ON dbo.[XacNhanKyHopDong] ([MaHopDong],[TrangThai]);

CREATE UNIQUE INDEX [UX_ThanhToan_MaGiaoDich] ON dbo.[ThanhToan] ([MaGiaoDich]) WHERE MaGiaoDich IS NOT NULL;

CREATE UNIQUE INDEX [UX_ThanhToan_MaThamChieu] ON dbo.[ThanhToan] ([MaThamChieu]) WHERE MaThamChieu IS NOT NULL;

CREATE INDEX [IX_ThanhToan_HopDong] ON dbo.[ThanhToan] ([MaHopDong],[LoaiThanhToan],[TrangThai]);

CREATE UNIQUE INDEX [IX_ThanhToan_MaQuyetToan_LoaiThanhToan] ON dbo.[ThanhToan] ([MaQuyetToan],[LoaiThanhToan]) WHERE [MaQuyetToan] IS NOT NULL AND [TrangThai]='CHO_THANH_TOAN';

CREATE INDEX [IX_ThanhToan_MaQuyetToan_MaHopDong] ON dbo.[ThanhToan] ([MaQuyetToan],[MaHopDong]);

CREATE INDEX [IX_PhieuPhat_ChiTietHopDong] ON dbo.[PhieuPhat] ([MaChiTietHopDong],[TrangThai]);

CREATE UNIQUE INDEX [AK_QuyetToanHopDong_Id_PhienBan_MaBam] ON dbo.[QuyetToanHopDong] ([Id],[PhienBan],[MaBam]);

CREATE UNIQUE INDEX [IX_QuyetToanHopDong_MaHopDong] ON dbo.[QuyetToanHopDong] ([MaHopDong]);

CREATE INDEX [IX_QuyetToanHopDong_NguoiChot] ON dbo.[QuyetToanHopDong] ([NguoiChot]);

CREATE INDEX [IX_PhanBoQuyetToan_MaChiTietHopDong] ON dbo.[PhanBoQuyetToan] ([MaChiTietHopDong]);

CREATE INDEX [IX_PhanBoQuyetToan_MaPhieuPhat] ON dbo.[PhanBoQuyetToan] ([MaPhieuPhat]);

CREATE INDEX [IX_PhanBoQuyetToan_MaPhuLuc] ON dbo.[PhanBoQuyetToan] ([MaPhuLuc]);

CREATE INDEX [IX_PhanBoQuyetToan_MaQuyetToan_MaHopDong] ON dbo.[PhanBoQuyetToan] ([MaQuyetToan],[MaHopDong]);

CREATE INDEX [IX_PhanBoQuyetToan_MaQuyetToan_MaNghiaVu] ON dbo.[PhanBoQuyetToan] ([MaQuyetToan],[MaNghiaVu]);

CREATE UNIQUE INDEX [IX_PhanBoQuyetToan_MaQuyetToan_MaThanhToan_MaNghiaVu] ON dbo.[PhanBoQuyetToan] ([MaQuyetToan],[MaThanhToan],[MaNghiaVu]) WHERE [LoaiDong]='PHAN_BO';

CREATE INDEX [IX_PhanBoQuyetToan_MaThanhToan_MaHopDong] ON dbo.[PhanBoQuyetToan] ([MaThanhToan],[MaHopDong]);

CREATE UNIQUE INDEX [UQ_DanhGia_MaChiTietHopDong] ON dbo.[DanhGia] ([MaChiTietHopDong]);

CREATE UNIQUE INDEX [UQ_AnhDanhGia_ThuTu] ON dbo.[AnhDanhGia] ([MaDanhGia],[ThuTu]);

CREATE INDEX [IX_ThongBao_ChuaDoc] ON dbo.[ThongBao] ([MaTaiKhoan],[DaDoc],[ThoiGianGui]);

CREATE UNIQUE INDEX [UX_ThongBao_EventKey] ON dbo.[ThongBao] ([EventKey]) WHERE EventKey IS NOT NULL;

CREATE UNIQUE INDEX [UX_FcmDeviceToken_TokenHash] ON dbo.[FcmDeviceToken] ([TokenHash]);

CREATE INDEX [IX_FcmDeviceToken_MaTaiKhoan_IsActive] ON dbo.[FcmDeviceToken] ([MaTaiKhoan],[IsActive]);

CREATE UNIQUE INDEX [UX_NotificationDelivery_Target] ON dbo.[NotificationDelivery] ([MaThongBao],[DeviceTokenId]);

CREATE UNIQUE INDEX [UXR_KhachThue_EmailDaXacMinh] ON dbo.[KhachThue] ([Email]) WHERE Email IS NOT NULL AND EmailXacMinhLucUtc IS NOT NULL;

CREATE UNIQUE INDEX [UXR_ChiTietGiuCho_Selection] ON dbo.[ChiTietGiuCho] ([MaGiuCho],[MaChiTietGioHang]);

CREATE INDEX [IXR_ChiTietGiuCho_Capacity] ON dbo.[ChiTietGiuCho] ([MaDongMay],[NgayBatDau],[NgayKetThuc],[MaGiuCho]);

CREATE INDEX [IXR_HopDong_NoShow] ON dbo.[HopDong] ([TrangThai],[ThoiGianBanGiao],[MaCuaHang]);

CREATE UNIQUE INDEX [IX_BienBanNhanTra_MaHopDong] ON dbo.[BienBanNhanTra] ([MaHopDong]);

CREATE INDEX [IX_BienBanNhanTra_NguoiGhiNhan] ON dbo.[BienBanNhanTra] ([NguoiGhiNhan]);

CREATE INDEX [IX_BienBanNhanTra_NguoiKiemTra] ON dbo.[BienBanNhanTra] ([NguoiKiemTra]);

CREATE INDEX [IX_ChiTietHopDong_MaBienBanNhanTra_MaHopDong] ON dbo.[ChiTietHopDong] ([MaBienBanNhanTra],[MaHopDong]);

CREATE UNIQUE INDEX [IX_QuyetToanHopDong_MaBienBan_MaHopDong] ON dbo.[QuyetToanHopDong] ([MaBienBan],[MaHopDong]);

CREATE INDEX [IX33_DoiSoatHuyHopDong_Time] ON dbo.[DoiSoatHuyHopDong] ([HuyLucUtc],[LoaiHuy]);

CREATE INDEX [IX33_XacMinhKhachKhongDen_Time] ON dbo.[XacMinhKhachKhongDen] ([XacMinhLucUtc],[CoTranhChapKhongDen]);

CREATE INDEX [IX33_ThanhToan_RefundCancellation] ON dbo.[ThanhToan] ([MaDoiSoatHuyHopDong],[LoaiThanhToan],[TrangThai]);

ALTER TABLE dbo.[KhachThue] WITH CHECK ADD CONSTRAINT [FK_KhachThue_MaTaiKhoan] FOREIGN KEY ([MaTaiKhoan]) REFERENCES dbo.[TaiKhoan] ([MaTaiKhoan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[NhanVien] WITH CHECK ADD CONSTRAINT [FK_NhanVien_MaTaiKhoan] FOREIGN KEY ([MaTaiKhoan]) REFERENCES dbo.[TaiKhoan] ([MaTaiKhoan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[NhanVien] WITH CHECK ADD CONSTRAINT [FK_NhanVien_MaCuaHang] FOREIGN KEY ([MaCuaHang]) REFERENCES dbo.[CuaHang] ([MaCuaHang]) ON DELETE NO ACTION;

ALTER TABLE dbo.[GiayToTuyThan] WITH CHECK ADD CONSTRAINT [FK_GiayToTuyThan_MaKhachThue] FOREIGN KEY ([MaKhachThue]) REFERENCES dbo.[KhachThue] ([MaKhachThue]) ON DELETE NO ACTION;

ALTER TABLE dbo.[DongMay] WITH CHECK ADD CONSTRAINT [FK_DongMay_MaDanhMuc] FOREIGN KEY ([MaDanhMuc]) REFERENCES dbo.[DanhMuc] ([MaDanhMuc]) ON DELETE NO ACTION;

ALTER TABLE dbo.[DongMay] WITH CHECK ADD CONSTRAINT [FK_DongMay_MaThuongHieu] FOREIGN KEY ([MaThuongHieu]) REFERENCES dbo.[ThuongHieu] ([MaThuongHieu]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ThietBi] WITH CHECK ADD CONSTRAINT [FK_ThietBi_MaDongMay] FOREIGN KEY ([MaDongMay]) REFERENCES dbo.[DongMay] ([MaDongMay]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ThietBi] WITH CHECK ADD CONSTRAINT [FK_ThietBi_MaCuaHang] FOREIGN KEY ([MaCuaHang]) REFERENCES dbo.[CuaHang] ([MaCuaHang]) ON DELETE NO ACTION;

ALTER TABLE dbo.[AnhThietBi] WITH CHECK ADD CONSTRAINT [FK_AnhThietBi_MaDongMay] FOREIGN KEY ([MaDongMay]) REFERENCES dbo.[DongMay] ([MaDongMay]) ON DELETE NO ACTION;

ALTER TABLE dbo.[GioHang] WITH CHECK ADD CONSTRAINT [FK_GioHang_MaKhachThue] FOREIGN KEY ([MaKhachThue]) REFERENCES dbo.[KhachThue] ([MaKhachThue]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ChiTietGioHang] WITH CHECK ADD CONSTRAINT [FK_ChiTietGioHang_MaGioHang] FOREIGN KEY ([MaGioHang]) REFERENCES dbo.[GioHang] ([MaGioHang]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ChiTietGioHang] WITH CHECK ADD CONSTRAINT [FK_ChiTietGioHang_MaDongMay] FOREIGN KEY ([MaDongMay]) REFERENCES dbo.[DongMay] ([MaDongMay]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ChiTietGioHang] WITH CHECK ADD CONSTRAINT [FK_ChiTietGioHang_MaCuaHang] FOREIGN KEY ([MaCuaHang]) REFERENCES dbo.[CuaHang] ([MaCuaHang]) ON DELETE NO ACTION;

ALTER TABLE dbo.[GiuCho] WITH CHECK ADD CONSTRAINT [FK_GiuCho_MaGioHang] FOREIGN KEY ([MaGioHang]) REFERENCES dbo.[GioHang] ([MaGioHang]) ON DELETE NO ACTION;

ALTER TABLE dbo.[GiuCho] WITH CHECK ADD CONSTRAINT [FK_GiuCho_MaKhachThue] FOREIGN KEY ([MaKhachThue]) REFERENCES dbo.[KhachThue] ([MaKhachThue]) ON DELETE NO ACTION;

ALTER TABLE dbo.[GiuCho] WITH CHECK ADD CONSTRAINT [FK_GiuCho_MaCuaHang] FOREIGN KEY ([MaCuaHang]) REFERENCES dbo.[CuaHang] ([MaCuaHang]) ON DELETE NO ACTION;

ALTER TABLE dbo.[GiuCho] WITH CHECK ADD CONSTRAINT [FK_GiuCho_MaGioHang_MaKhachThue] FOREIGN KEY ([MaGioHang],[MaKhachThue]) REFERENCES dbo.[GioHang] ([MaGioHang],[MaKhachThue]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ChiTietGiuCho] WITH CHECK ADD CONSTRAINT [FK_ChiTietGiuCho_MaGiuCho] FOREIGN KEY ([MaGiuCho]) REFERENCES dbo.[GiuCho] ([MaGiuCho]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ChiTietGiuCho] WITH CHECK ADD CONSTRAINT [FK_ChiTietGiuCho_MaDongMay] FOREIGN KEY ([MaDongMay]) REFERENCES dbo.[DongMay] ([MaDongMay]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ChiTietGiuCho] WITH CHECK ADD CONSTRAINT [FK_ChiTietGiuCho_MaChiTietGioHang] FOREIGN KEY ([MaChiTietGioHang]) REFERENCES dbo.[ChiTietGioHang] ([MaChiTietGioHang]) ON DELETE NO ACTION;

ALTER TABLE dbo.[HopDong] WITH CHECK ADD CONSTRAINT [FK_HopDong_MaGioHang] FOREIGN KEY ([MaGioHang]) REFERENCES dbo.[GioHang] ([MaGioHang]) ON DELETE NO ACTION;

ALTER TABLE dbo.[HopDong] WITH CHECK ADD CONSTRAINT [FK_HopDong_MaGiuCho] FOREIGN KEY ([MaGiuCho]) REFERENCES dbo.[GiuCho] ([MaGiuCho]) ON DELETE NO ACTION;

ALTER TABLE dbo.[HopDong] WITH CHECK ADD CONSTRAINT [FK_HopDong_MaKhachThue] FOREIGN KEY ([MaKhachThue]) REFERENCES dbo.[KhachThue] ([MaKhachThue]) ON DELETE NO ACTION;

ALTER TABLE dbo.[HopDong] WITH CHECK ADD CONSTRAINT [FK_HopDong_MaNhanVien] FOREIGN KEY ([MaNhanVien]) REFERENCES dbo.[NhanVien] ([MaNhanVien]) ON DELETE NO ACTION;

ALTER TABLE dbo.[HopDong] WITH CHECK ADD CONSTRAINT [FK_HopDong_MaCuaHang] FOREIGN KEY ([MaCuaHang]) REFERENCES dbo.[CuaHang] ([MaCuaHang]) ON DELETE NO ACTION;

ALTER TABLE dbo.[HopDong] WITH CHECK ADD CONSTRAINT [FK_HopDong_MaGioHang_MaKhachThue] FOREIGN KEY ([MaGioHang],[MaKhachThue]) REFERENCES dbo.[GioHang] ([MaGioHang],[MaKhachThue]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ChiTietHopDong] WITH CHECK ADD CONSTRAINT [FK_ChiTietHopDong_MaHopDong] FOREIGN KEY ([MaHopDong]) REFERENCES dbo.[HopDong] ([MaHopDong]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ChiTietHopDong] WITH CHECK ADD CONSTRAINT [FK_ChiTietHopDong_MaThietBi] FOREIGN KEY ([MaThietBi]) REFERENCES dbo.[ThietBi] ([MaThietBi]) ON DELETE NO ACTION;

ALTER TABLE dbo.[PhuLuc] WITH CHECK ADD CONSTRAINT [FK_PhuLuc_MaHopDong] FOREIGN KEY ([MaHopDong]) REFERENCES dbo.[HopDong] ([MaHopDong]) ON DELETE NO ACTION;

ALTER TABLE dbo.[XacNhanKyHopDong] WITH CHECK ADD CONSTRAINT [FK_XacNhanKyHopDong_MaHopDong] FOREIGN KEY ([MaHopDong]) REFERENCES dbo.[HopDong] ([MaHopDong]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ThanhToan] WITH CHECK ADD CONSTRAINT [FK_ThanhToan_MaHopDong] FOREIGN KEY ([MaHopDong]) REFERENCES dbo.[HopDong] ([MaHopDong]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ThanhToan] WITH CHECK ADD CONSTRAINT [FK_ThanhToan_MaQuyetToan_MaHopDong] FOREIGN KEY ([MaQuyetToan],[MaHopDong]) REFERENCES dbo.[QuyetToanHopDong] ([Id],[MaHopDong]) ON DELETE NO ACTION;

ALTER TABLE dbo.[YeuCauThanhToanVnpay] WITH CHECK ADD CONSTRAINT [FK_YeuCauThanhToanVnpay_MaThanhToan] FOREIGN KEY ([MaThanhToan]) REFERENCES dbo.[ThanhToan] ([MaThanhToan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[PhieuPhat] WITH CHECK ADD CONSTRAINT [FK_PhieuPhat_MaChiTietHopDong] FOREIGN KEY ([MaChiTietHopDong]) REFERENCES dbo.[ChiTietHopDong] ([MaChiTietHopDong]) ON DELETE NO ACTION;

ALTER TABLE dbo.[QuyetToanHopDong] WITH CHECK ADD CONSTRAINT [FK_QuyetToanHopDong_MaHopDong] FOREIGN KEY ([MaHopDong]) REFERENCES dbo.[HopDong] ([MaHopDong]) ON DELETE NO ACTION;

ALTER TABLE dbo.[QuyetToanHopDong] WITH CHECK ADD CONSTRAINT [FK_QuyetToanHopDong_NguoiChot] FOREIGN KEY ([NguoiChot]) REFERENCES dbo.[TaiKhoan] ([MaTaiKhoan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[PhanBoQuyetToan] WITH CHECK ADD CONSTRAINT [FK_PhanBoQuyetToan_MaChiTietHopDong] FOREIGN KEY ([MaChiTietHopDong]) REFERENCES dbo.[ChiTietHopDong] ([MaChiTietHopDong]) ON DELETE NO ACTION;

ALTER TABLE dbo.[PhanBoQuyetToan] WITH CHECK ADD CONSTRAINT [FK_PhanBoQuyetToan_MaQuyetToan_MaNghiaVu] FOREIGN KEY ([MaQuyetToan],[MaNghiaVu]) REFERENCES dbo.[PhanBoQuyetToan] ([MaQuyetToan],[Id]) ON DELETE NO ACTION;

ALTER TABLE dbo.[PhanBoQuyetToan] WITH CHECK ADD CONSTRAINT [FK_PhanBoQuyetToan_MaPhieuPhat] FOREIGN KEY ([MaPhieuPhat]) REFERENCES dbo.[PhieuPhat] ([MaPhieuPhat]) ON DELETE NO ACTION;

ALTER TABLE dbo.[PhanBoQuyetToan] WITH CHECK ADD CONSTRAINT [FK_PhanBoQuyetToan_MaPhuLuc] FOREIGN KEY ([MaPhuLuc]) REFERENCES dbo.[PhuLuc] ([MaPhuLuc]) ON DELETE NO ACTION;

ALTER TABLE dbo.[PhanBoQuyetToan] WITH CHECK ADD CONSTRAINT [FK_PhanBoQuyetToan_MaQuyetToan_MaHopDong] FOREIGN KEY ([MaQuyetToan],[MaHopDong]) REFERENCES dbo.[QuyetToanHopDong] ([Id],[MaHopDong]) ON DELETE NO ACTION;

ALTER TABLE dbo.[PhanBoQuyetToan] WITH CHECK ADD CONSTRAINT [FK_PhanBoQuyetToan_MaThanhToan_MaHopDong] FOREIGN KEY ([MaThanhToan],[MaHopDong]) REFERENCES dbo.[ThanhToan] ([MaThanhToan],[MaHopDong]) ON DELETE NO ACTION;

ALTER TABLE dbo.[DanhGia] WITH CHECK ADD CONSTRAINT [FK_DanhGia_MaChiTietHopDong] FOREIGN KEY ([MaChiTietHopDong]) REFERENCES dbo.[ChiTietHopDong] ([MaChiTietHopDong]) ON DELETE NO ACTION;

ALTER TABLE dbo.[DanhGia] WITH CHECK ADD CONSTRAINT [FK_DanhGia_MaKhachThue] FOREIGN KEY ([MaKhachThue]) REFERENCES dbo.[KhachThue] ([MaKhachThue]) ON DELETE NO ACTION;

ALTER TABLE dbo.[AnhDanhGia] WITH CHECK ADD CONSTRAINT [FK_AnhDanhGia_MaDanhGia] FOREIGN KEY ([MaDanhGia]) REFERENCES dbo.[DanhGia] ([MaDanhGia]) ON DELETE NO ACTION;

ALTER TABLE dbo.[AnhBienBan] WITH CHECK ADD CONSTRAINT [FK_AnhBienBan_MaChiTietHopDong] FOREIGN KEY ([MaChiTietHopDong]) REFERENCES dbo.[ChiTietHopDong] ([MaChiTietHopDong]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ThongBao] WITH CHECK ADD CONSTRAINT [FK_ThongBao_MaTaiKhoan] FOREIGN KEY ([MaTaiKhoan]) REFERENCES dbo.[TaiKhoan] ([MaTaiKhoan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[FcmDeviceToken] WITH CHECK ADD CONSTRAINT [FK_FcmDeviceToken_MaTaiKhoan] FOREIGN KEY ([MaTaiKhoan]) REFERENCES dbo.[TaiKhoan] ([MaTaiKhoan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[IdempotencyKey] WITH CHECK ADD CONSTRAINT [FK_IdempotencyKey_MaKhachThue] FOREIGN KEY ([MaKhachThue]) REFERENCES dbo.[KhachThue] ([MaKhachThue]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ChiTietGiuCho] WITH CHECK ADD CONSTRAINT [FKR_ChiTietGiuCho_MaChiTietGioHangHopDong] FOREIGN KEY ([MaChiTietGioHangHopDong]) REFERENCES dbo.[ChiTietGioHang] ([MaChiTietGioHang]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ThanhToan] WITH CHECK ADD CONSTRAINT [FKR_ThanhToan_NguoiXacNhanHoan] FOREIGN KEY ([NguoiXacNhanHoan]) REFERENCES dbo.[TaiKhoan] ([MaTaiKhoan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ThanhToan] WITH CHECK ADD CONSTRAINT [FKR_ThanhToan_NguoiXacNhanNhanHoan] FOREIGN KEY ([NguoiXacNhanNhanHoan]) REFERENCES dbo.[TaiKhoan] ([MaTaiKhoan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[PhieuPhat] WITH CHECK ADD CONSTRAINT [FKR_PhieuPhat_NguoiLap] FOREIGN KEY ([NguoiLap]) REFERENCES dbo.[TaiKhoan] ([MaTaiKhoan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[PhieuPhat] WITH CHECK ADD CONSTRAINT [FKR_PhieuPhat_NguoiXuLy] FOREIGN KEY ([NguoiXuLy]) REFERENCES dbo.[TaiKhoan] ([MaTaiKhoan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[DanhGia] WITH CHECK ADD CONSTRAINT [FKR_DanhGia_NguoiCapNhatHienThi] FOREIGN KEY ([NguoiCapNhatHienThi]) REFERENCES dbo.[TaiKhoan] ([MaTaiKhoan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[PhuLuc] WITH CHECK ADD CONSTRAINT [FKR_PhuLuc_NguoiXuLy] FOREIGN KEY ([NguoiXuLy]) REFERENCES dbo.[TaiKhoan] ([MaTaiKhoan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[BienBanNhanTra] WITH CHECK ADD CONSTRAINT [FK_BienBanNhanTra_HopDong_MaHopDong] FOREIGN KEY ([MaHopDong]) REFERENCES dbo.[HopDong] ([MaHopDong]) ON DELETE NO ACTION;

ALTER TABLE dbo.[BienBanNhanTra] WITH CHECK ADD CONSTRAINT [FK_BienBanNhanTra_TaiKhoan_NguoiGhiNhan] FOREIGN KEY ([NguoiGhiNhan]) REFERENCES dbo.[TaiKhoan] ([MaTaiKhoan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[BienBanNhanTra] WITH CHECK ADD CONSTRAINT [FK_BienBanNhanTra_TaiKhoan_NguoiKiemTra] FOREIGN KEY ([NguoiKiemTra]) REFERENCES dbo.[TaiKhoan] ([MaTaiKhoan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[BienBanNhanTra] WITH CHECK ADD CONSTRAINT [FK33_BienBanNhanTra_NguoiSua] FOREIGN KEY ([NguoiSuaThucNhan]) REFERENCES dbo.[TaiKhoan] ([MaTaiKhoan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ChiTietHopDong] WITH CHECK ADD CONSTRAINT [FK_ChiTietHopDong_BienBanNhanTra_MaBienBanNhanTra_MaHopDong] FOREIGN KEY ([MaBienBanNhanTra],[MaHopDong]) REFERENCES dbo.[BienBanNhanTra] ([Id],[MaHopDong]) ON DELETE NO ACTION;

ALTER TABLE dbo.[QuyetToanHopDong] WITH CHECK ADD CONSTRAINT [FK_QuyetToanHopDong_BienBanNhanTra_MaBienBan_MaHopDong] FOREIGN KEY ([MaBienBan],[MaHopDong]) REFERENCES dbo.[BienBanNhanTra] ([Id],[MaHopDong]) ON DELETE NO ACTION;

ALTER TABLE dbo.[QuyetToanHopDong] WITH CHECK ADD CONSTRAINT [FK33_QuyetToanHopDong_NguoiXacNhanHoanTat] FOREIGN KEY ([NguoiXacNhanHoanTat]) REFERENCES dbo.[TaiKhoan] ([MaTaiKhoan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[DoiSoatHuyHopDong] WITH CHECK ADD CONSTRAINT [FK33_DoiSoatHuyHopDong_HopDong] FOREIGN KEY ([MaHopDong]) REFERENCES dbo.[HopDong] ([MaHopDong]) ON DELETE NO ACTION;

ALTER TABLE dbo.[XacMinhKhachKhongDen] WITH CHECK ADD CONSTRAINT [FK33_XacMinhKhachKhongDen_HopDong] FOREIGN KEY ([MaHopDong]) REFERENCES dbo.[HopDong] ([MaHopDong]) ON DELETE NO ACTION;

ALTER TABLE dbo.[DoiSoatHuyHopDong] WITH CHECK ADD CONSTRAINT [FK33_DoiSoatHuyHopDong_NguoiHuy] FOREIGN KEY ([NguoiHuy]) REFERENCES dbo.[TaiKhoan] ([MaTaiKhoan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[XacMinhKhachKhongDen] WITH CHECK ADD CONSTRAINT [FK33_XacMinhKhachKhongDen_NguoiXacMinh] FOREIGN KEY ([NguoiXacMinh]) REFERENCES dbo.[TaiKhoan] ([MaTaiKhoan]) ON DELETE NO ACTION;

ALTER TABLE dbo.[ThanhToan] WITH CHECK ADD CONSTRAINT [FK33_ThanhToan_DoiSoatHuyHopDong] FOREIGN KEY ([MaDoiSoatHuyHopDong]) REFERENCES dbo.[DoiSoatHuyHopDong] ([MaHopDong]) ON DELETE NO ACTION;

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


COMMIT TRANSACTION;

SELECT N'SCHEMA33_CREATED' Result,33 PhysicalApplicationTableCount;

END TRY

BEGIN CATCH

IF XACT_STATE()<>0 ROLLBACK TRANSACTION;

THROW;

END CATCH;
