/*
=====================================================================
RENTCAM - DATABASE HOAN CHINH THEO FLOW NGHIEP VU MOI
Nen tang: Microsoft SQL Server

FLOW:
GioHang
 -> GiuCho (TTL checkout)
 -> HopDong(CHO_KY)
 -> DA_KY
 -> CHO_BAN_GIAO
 -> DANG_THUE
 -> CHO_HOAN_TRA
 -> HOAN_THANH

Ngoai le: DA_HUY

QUY UOC:
- Khong co bang DonThue.
- GioHang KHONG giu capacity.
- GiuCho la technical reservation co TTL.
- Khach thue theo DongMay + SoLuong + khoang thoi gian.
- Serial/MaThietBi duoc gan sau.
- Thanh toan quan ly rieng tai ThanhToan.
- Hoan coc la nghiep vu bat buoc truoc HOAN_THANH.
- TTL GiuCho va timeout CHO_KY do Backend/business config quyet dinh,
  KHONG hard-code trong database.
=====================================================================
*/

/*
Các SET option này là bắt buộc khi tạo filtered index trên SQL Server.
Khai báo ngay trong script để chạy nhất quán bằng SSMS lẫn sqlcmd/Docker.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF DB_ID(N'RentalCameraDb20') IS NULL
    CREATE DATABASE RentalCameraDb20;
GO

USE RentalCameraDb20;
GO

/* ================================================================
   1. DANH MUC
================================================================ */
CREATE TABLE DanhMuc (
    MaDanhMuc VARCHAR(20) NOT NULL PRIMARY KEY,
    TenDanhMuc NVARCHAR(150) NOT NULL UNIQUE,
    MoTa NVARCHAR(500) NULL,
    TrangThai VARCHAR(20) NOT NULL DEFAULT 'HOAT_DONG',

    CONSTRAINT CK_DanhMuc_TrangThai
        CHECK (TrangThai IN ('HOAT_DONG','TAM_AN'))
);
GO

/* ================================================================
   2. THUONG HIEU
================================================================ */
CREATE TABLE ThuongHieu (
    MaThuongHieu VARCHAR(20) NOT NULL PRIMARY KEY,
    TenThuongHieu NVARCHAR(150) NOT NULL UNIQUE,
    QuocGia NVARCHAR(100) NULL
);
GO

/* ================================================================
   3. DONG MAY
================================================================ */
CREATE TABLE DongMay (
    MaDongMay VARCHAR(20) NOT NULL PRIMARY KEY,
    MaDanhMuc VARCHAR(20) NOT NULL,
    MaThuongHieu VARCHAR(20) NOT NULL,
    TenDongMay NVARCHAR(200) NOT NULL,
    MoTa NVARCHAR(1000) NULL,
    GiaThueNgay DECIMAL(18,2) NOT NULL,
    TienCoc DECIMAL(18,2) NOT NULL,
    PhanTramGiamGia DECIMAL(5,2) NOT NULL DEFAULT 0,

    CONSTRAINT FK_DongMay_DanhMuc
        FOREIGN KEY (MaDanhMuc) REFERENCES DanhMuc(MaDanhMuc),

    CONSTRAINT FK_DongMay_ThuongHieu
        FOREIGN KEY (MaThuongHieu) REFERENCES ThuongHieu(MaThuongHieu),

    CONSTRAINT UQ_DongMay
        UNIQUE (MaThuongHieu, TenDongMay),

    CONSTRAINT CK_DongMay_Gia
        CHECK (GiaThueNgay >= 0 AND TienCoc >= 0),

    CONSTRAINT CK_DongMay_GiamGia
        CHECK (PhanTramGiamGia BETWEEN 0 AND 100)
);
GO

/* ================================================================
   4. ANH THIET BI / ANH DONG MAY
================================================================ */
CREATE TABLE AnhThietBi (
    MaAnh VARCHAR(20) NOT NULL PRIMARY KEY,
    MaDongMay VARCHAR(20) NOT NULL,
    DuongDanAnh NVARCHAR(500) NOT NULL,
    LaAnhDaiDien BIT NOT NULL DEFAULT 0,
    ThuTuHienThi INT NOT NULL DEFAULT 0,

    CONSTRAINT FK_AnhThietBi_DongMay
        FOREIGN KEY (MaDongMay) REFERENCES DongMay(MaDongMay),

    CONSTRAINT CK_AnhThietBi_ThuTu
        CHECK (ThuTuHienThi >= 0)
);
GO

/* ================================================================
   5. CUA HANG
================================================================ */
CREATE TABLE CuaHang (
    MaCuaHang VARCHAR(20) NOT NULL PRIMARY KEY,
    TenCuaHang NVARCHAR(200) NOT NULL,
    DiaChi NVARCHAR(500) NOT NULL,
    SoDienThoai VARCHAR(15) NOT NULL,
    Email VARCHAR(255) NULL,
    MoTa NVARCHAR(500) NULL,
    TrangThai VARCHAR(20) NOT NULL DEFAULT 'HOAT_DONG',

    CONSTRAINT CK_CuaHang_TrangThai
        CHECK (TrangThai IN ('HOAT_DONG','TAM_KHOA'))
);
GO

/* ================================================================
   6. TAI KHOAN
================================================================ */
CREATE TABLE TaiKhoan (
    MaTaiKhoan VARCHAR(20) NOT NULL PRIMARY KEY,
    TenDangNhap VARCHAR(100) NOT NULL UNIQUE,
    MatKhauHash VARCHAR(500) NOT NULL,
    NgayTao DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    TrangThai VARCHAR(20) NOT NULL DEFAULT 'HOAT_DONG',
    VaiTro VARCHAR(20) NOT NULL,

    CONSTRAINT CK_TaiKhoan_TrangThai
        CHECK (TrangThai IN ('HOAT_DONG','TAM_KHOA')),

    CONSTRAINT CK_TaiKhoan_VaiTro
        CHECK (VaiTro IN ('ADMIN','NHAN_VIEN','KHACH_HANG'))
);
GO

/* ================================================================
   7. KHACH THUE
================================================================ */
CREATE TABLE KhachThue (
    MaKhachThue VARCHAR(20) NOT NULL PRIMARY KEY,
    MaTaiKhoan VARCHAR(20) NOT NULL UNIQUE,
    HoTen NVARCHAR(150) NOT NULL,
    SoDienThoai VARCHAR(15) NOT NULL UNIQUE,
    Email VARCHAR(255) NULL,
    CCCD VARCHAR(20) NULL,
    DiaChi NVARCHAR(500) NULL,
    NgaySinh DATE NULL,

    CONSTRAINT FK_KhachThue_TaiKhoan
        FOREIGN KEY (MaTaiKhoan) REFERENCES TaiKhoan(MaTaiKhoan)
);
GO

CREATE UNIQUE INDEX UX_KhachThue_CCCD_NotNull
ON KhachThue(CCCD)
WHERE CCCD IS NOT NULL;
GO

/* ================================================================
   8. GIAY TO TUY THAN
================================================================ */
CREATE TABLE GiayToTuyThan (
    MaGiayTo VARCHAR(20) NOT NULL PRIMARY KEY,
    MaKhachThue VARCHAR(20) NOT NULL,
    LoaiGiayTo VARCHAR(20) NOT NULL,
    SoGiayTo VARCHAR(30) NOT NULL UNIQUE,
    MatTruocUrl NVARCHAR(500) NOT NULL,
    MatSauUrl NVARCHAR(500) NULL,
    NgayTaiLen DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    TrangThaiXacMinh VARCHAR(20) NOT NULL DEFAULT 'CHO_XAC_MINH',
    GhiChu NVARCHAR(500) NULL,

    CONSTRAINT FK_GiayTo_KhachThue
        FOREIGN KEY (MaKhachThue) REFERENCES KhachThue(MaKhachThue),

    CONSTRAINT CK_GiayTo_Loai
        CHECK (LoaiGiayTo IN ('CCCD','HO_CHIEU','GPLX')),

    CONSTRAINT CK_GiayTo_TrangThai
        CHECK (TrangThaiXacMinh IN ('CHO_XAC_MINH','HOP_LE','TU_CHOI'))
);
GO

/* ================================================================
   9. NHAN VIEN
================================================================ */
CREATE TABLE NhanVien (
    MaNhanVien VARCHAR(20) NOT NULL PRIMARY KEY,
    MaTaiKhoan VARCHAR(20) NOT NULL UNIQUE,
    MaCuaHang VARCHAR(20) NOT NULL,
    HoTen NVARCHAR(150) NOT NULL,
    DiaChi NVARCHAR(500) NULL,
    SoDienThoai VARCHAR(15) NOT NULL,
    ChucVu NVARCHAR(100) NOT NULL,
    Email VARCHAR(255) NULL,
    TrangThai VARCHAR(20) NOT NULL DEFAULT 'HOAT_DONG',

    CONSTRAINT FK_NhanVien_TaiKhoan
        FOREIGN KEY (MaTaiKhoan) REFERENCES TaiKhoan(MaTaiKhoan),

    CONSTRAINT FK_NhanVien_CuaHang
        FOREIGN KEY (MaCuaHang) REFERENCES CuaHang(MaCuaHang),

    CONSTRAINT CK_NhanVien_TrangThai
        CHECK (TrangThai IN ('HOAT_DONG','NGHI_VIEC'))
);
GO

/* ================================================================
   10. THIET BI VAT LY
================================================================ */
CREATE TABLE ThietBi (
    MaThietBi VARCHAR(20) NOT NULL PRIMARY KEY,
    MaDongMay VARCHAR(20) NOT NULL,
    MaCuaHang VARCHAR(20) NOT NULL,
    SoSerial VARCHAR(100) NOT NULL UNIQUE,
    TinhTrang NVARCHAR(200) NOT NULL,
    TrangThai VARCHAR(20) NOT NULL DEFAULT 'SAN_SANG',
    NgayNhap DATE NULL,
    RowVersion ROWVERSION,

    CONSTRAINT FK_ThietBi_DongMay
        FOREIGN KEY (MaDongMay) REFERENCES DongMay(MaDongMay),

    CONSTRAINT FK_ThietBi_CuaHang
        FOREIGN KEY (MaCuaHang) REFERENCES CuaHang(MaCuaHang),

    CONSTRAINT CK_ThietBi_TrangThai
        CHECK (TrangThai IN (
            'SAN_SANG',
            'DANG_GIU',
            'DANG_THUE',
            'BAO_TRI',
            'HONG',
            'NGUNG_KINH_DOANH'
        ))
);
GO

/* ================================================================
   11. GIO HANG
   Luu y: GioHang khong giu capacity va khong con HetHanLuc.
================================================================ */
CREATE TABLE GioHang (
    MaGioHang VARCHAR(20) NOT NULL PRIMARY KEY,
    MaKhachThue VARCHAR(20) NOT NULL,
    MaCuaHang VARCHAR(20) NOT NULL,
    NgayTao DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    NgayCapNhat DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    TrangThai VARCHAR(25) NOT NULL DEFAULT 'DANG_CHON',

    CONSTRAINT FK_GioHang_KhachThue
        FOREIGN KEY (MaKhachThue) REFERENCES KhachThue(MaKhachThue),

    CONSTRAINT FK_GioHang_CuaHang
        FOREIGN KEY (MaCuaHang) REFERENCES CuaHang(MaCuaHang),

    CONSTRAINT UQ_GioHang_MaGioHang_MaCuaHang
        UNIQUE (MaGioHang, MaCuaHang),

    CONSTRAINT UQ_GioHang_MaGioHang_Khach_CuaHang
        UNIQUE (MaGioHang, MaKhachThue, MaCuaHang),

    CONSTRAINT CK_GioHang_TrangThai
        CHECK (TrangThai IN (
            'DANG_CHON',
            'DA_CHUYEN_HOP_DONG'
                  ))
);
GO

/* ================================================================
   12. CHI TIET GIO HANG
================================================================ */
CREATE TABLE ChiTietGioHang (
    MaChiTietGioHang VARCHAR(20) NOT NULL PRIMARY KEY,
    MaGioHang VARCHAR(20) NOT NULL,
    MaDongMay VARCHAR(20) NOT NULL,
    SoLuong INT NOT NULL DEFAULT 1,
    NgayBatDau DATETIME2 NOT NULL,
    NgayKetThuc DATETIME2 NOT NULL,
    DonGia DECIMAL(18,2) NOT NULL,
    TienCoc DECIMAL(18,2) NOT NULL,
    ThanhTien DECIMAL(18,2) NOT NULL,

    CONSTRAINT FK_ChiTietGioHang_GioHang
        FOREIGN KEY (MaGioHang) REFERENCES GioHang(MaGioHang),

    CONSTRAINT FK_ChiTietGioHang_DongMay
        FOREIGN KEY (MaDongMay) REFERENCES DongMay(MaDongMay),

    CONSTRAINT UQ_ChiTietGioHang
        UNIQUE (MaGioHang, MaDongMay),

    CONSTRAINT CK_ChiTietGioHang_SoLuong
        CHECK (SoLuong > 0),

    CONSTRAINT CK_ChiTietGioHang_ThoiGian
        CHECK (NgayKetThuc > NgayBatDau),

    CONSTRAINT CK_ChiTietGioHang_SoTien
        CHECK (DonGia >= 0 AND TienCoc >= 0 AND ThanhTien >= 0)
);
GO

/* ================================================================
   13. GIU CHO
   Technical reservation co TTL.
   HetHanLuc thuoc GiuCho, KHONG thuoc GioHang.
================================================================ */
CREATE TABLE GiuCho (
    MaGiuCho VARCHAR(20) NOT NULL PRIMARY KEY,
    MaGioHang VARCHAR(20) NOT NULL,
    MaKhachThue VARCHAR(20) NOT NULL,
    MaCuaHang VARCHAR(20) NOT NULL,
    NgayTao DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    HetHanLuc DATETIME2 NOT NULL,
    TrangThai VARCHAR(30) NOT NULL DEFAULT 'DANG_GIU',

    CONSTRAINT FK_GiuCho_GioHang
        FOREIGN KEY (MaGioHang) REFERENCES GioHang(MaGioHang),

    CONSTRAINT FK_GiuCho_KhachThue
        FOREIGN KEY (MaKhachThue) REFERENCES KhachThue(MaKhachThue),

    CONSTRAINT FK_GiuCho_CuaHang
        FOREIGN KEY (MaCuaHang) REFERENCES CuaHang(MaCuaHang),

    /* Bao dam hold thuoc dung customer + store cua GioHang. */
    CONSTRAINT FK_GiuCho_GioHang_Khach_CuaHang
        FOREIGN KEY (MaGioHang, MaKhachThue, MaCuaHang)
        REFERENCES GioHang(MaGioHang, MaKhachThue, MaCuaHang),

    CONSTRAINT CK_GiuCho_TrangThai
        CHECK (TrangThai IN (
            'DANG_GIU',
            'DA_CHUYEN_HOP_DONG',
            'HET_HAN',
            'DA_HUY'
        )),

    CONSTRAINT CK_GiuCho_ThoiGian
        CHECK (HetHanLuc > NgayTao)
);
GO

/* ================================================================
   14. CHI TIET GIU CHO
================================================================ */
CREATE TABLE ChiTietGiuCho (
    MaChiTietGiuCho VARCHAR(20) NOT NULL PRIMARY KEY,
    MaGiuCho VARCHAR(20) NOT NULL,
    MaDongMay VARCHAR(20) NOT NULL,
    SoLuong INT NOT NULL,
    NgayBatDau DATETIME2 NOT NULL,
    NgayKetThuc DATETIME2 NOT NULL,

    CONSTRAINT FK_ChiTietGiuCho_GiuCho
        FOREIGN KEY (MaGiuCho) REFERENCES GiuCho(MaGiuCho),

    CONSTRAINT FK_ChiTietGiuCho_DongMay
        FOREIGN KEY (MaDongMay) REFERENCES DongMay(MaDongMay),

    CONSTRAINT UQ_ChiTietGiuCho
        UNIQUE (MaGiuCho, MaDongMay),

    CONSTRAINT CK_ChiTietGiuCho_SoLuong
        CHECK (SoLuong > 0),

    CONSTRAINT CK_ChiTietGiuCho_ThoiGian
        CHECK (NgayKetThuc > NgayBatDau)
);
GO

/* ================================================================
   15. HOP DONG
================================================================ */
CREATE TABLE HopDong (
    MaHopDong VARCHAR(20) NOT NULL PRIMARY KEY,
    MaGioHang VARCHAR(20) NOT NULL UNIQUE,
    MaGiuCho VARCHAR(20) NOT NULL UNIQUE,
    MaKhachThue VARCHAR(20) NOT NULL,
    MaNhanVien VARCHAR(20) NULL,
    MaCuaHang VARCHAR(20) NOT NULL,

    NgayTaoHopDong DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    NgayKy DATETIME2 NULL,

    ThoiGianBanGiao DATETIME2 NOT NULL,
    ThoiGianTraDuKien DATETIME2 NOT NULL,

    TongTien DECIMAL(18,2) NOT NULL,
    TongTienCoc DECIMAL(18,2) NOT NULL,

    HinhThucKy VARCHAR(20) NULL,
    TrangThai VARCHAR(30) NOT NULL DEFAULT 'CHO_KY',
    TepHopDongUrl NVARCHAR(500) NULL,
    DaDongYDieuKhoan BIT NOT NULL DEFAULT 0,
    PhienBanDieuKhoan VARCHAR(20) NULL,
    MaBamNoiDung CHAR(64) NULL,
    MaBamTepPdf CHAR(64) NULL,
    NoiDungHopDongJson NVARCHAR(MAX) NULL,

    CONSTRAINT FK_HopDong_GioHang
        FOREIGN KEY (MaGioHang) REFERENCES GioHang(MaGioHang),

    CONSTRAINT FK_HopDong_GiuCho
        FOREIGN KEY (MaGiuCho) REFERENCES GiuCho(MaGiuCho),

    CONSTRAINT FK_HopDong_KhachThue
        FOREIGN KEY (MaKhachThue) REFERENCES KhachThue(MaKhachThue),

    CONSTRAINT FK_HopDong_NhanVien
        FOREIGN KEY (MaNhanVien) REFERENCES NhanVien(MaNhanVien),

    CONSTRAINT FK_HopDong_CuaHang
        FOREIGN KEY (MaCuaHang) REFERENCES CuaHang(MaCuaHang),

    CONSTRAINT FK_HopDong_GioHang_Khach_CuaHang
        FOREIGN KEY (MaGioHang, MaKhachThue, MaCuaHang)
        REFERENCES GioHang(MaGioHang, MaKhachThue, MaCuaHang),

    CONSTRAINT CK_HopDong_ThoiGian
        CHECK (ThoiGianTraDuKien > ThoiGianBanGiao),

    CONSTRAINT CK_HopDong_SoTien
        CHECK (TongTien >= 0 AND TongTienCoc >= 0),

    CONSTRAINT CK_HopDong_HinhThucKy
        CHECK (
            HinhThucKy IS NULL
            OR HinhThucKy IN ('DIEN_TU','MAN_HINH','BAN_GIAY')
        ),

    CONSTRAINT CK_HopDong_TrangThai
        CHECK (TrangThai IN (
            'CHO_KY',
            'DA_KY',
            'CHO_BAN_GIAO',
            'DANG_THUE',
            'CHO_HOAN_TRA',
            'HOAN_THANH',
            'DA_HUY'
        )),

    CONSTRAINT CK_HopDong_ThongTinKy
        CHECK (
            TrangThai IN ('CHO_KY','DA_HUY')
            OR (NgayKy IS NOT NULL AND HinhThucKy IS NOT NULL)
        )
);
GO

/* ================================================================
   16. XAC NHAN KY HOP DONG
   OTP chi luu dang bam; day la ky dien tu mo phong, khong phai chu ky
   so duoc nha cung cap chung thu so chung thuc.
================================================================ */
CREATE TABLE XacNhanKyHopDong (
    MaXacNhan VARCHAR(20) NOT NULL PRIMARY KEY,
    MaHopDong VARCHAR(20) NOT NULL,
    MaOtpHash CHAR(64) NOT NULL,
    MuoiOtp CHAR(32) NOT NULL,
    TaoLuc DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    HetHanLuc DATETIME2 NOT NULL,
    SoLanThu INT NOT NULL DEFAULT 0,
    TrangThai VARCHAR(20) NOT NULL DEFAULT 'CHO_XAC_NHAN',
    XacNhanLuc DATETIME2 NULL,
    DiaChiIp VARCHAR(45) NULL,
    ThietBiKy NVARCHAR(500) NULL,
    PhienBanDieuKhoan VARCHAR(20) NOT NULL,
    MaBamNoiDung CHAR(64) NOT NULL,
    MaBamTepPdf CHAR(64) NULL,
    NoiDungHopDongJson NVARCHAR(MAX) NOT NULL,

    CONSTRAINT FK_XacNhanKyHopDong_HopDong
        FOREIGN KEY (MaHopDong) REFERENCES HopDong(MaHopDong),

    CONSTRAINT CK_XacNhanKyHopDong_ThoiGian
        CHECK (HetHanLuc > TaoLuc),

    CONSTRAINT CK_XacNhanKyHopDong_SoLanThu
        CHECK (SoLanThu >= 0),

    CONSTRAINT CK_XacNhanKyHopDong_TrangThai
        CHECK (TrangThai IN ('CHO_XAC_NHAN','DA_XAC_NHAN','HET_HAN','DA_HUY','KHOA')),

    CONSTRAINT CK_XacNhanKyHopDong_Json
        CHECK (ISJSON(NoiDungHopDongJson) = 1)
);
GO

CREATE INDEX IX_XacNhanKyHopDong_HopDong_TrangThai
    ON XacNhanKyHopDong(MaHopDong, TrangThai);
GO

/* ================================================================
   17. CHI TIET HOP DONG
   Serial vat ly duoc gan sau.
================================================================ */
CREATE TABLE ChiTietHopDong (
    MaChiTietHopDong VARCHAR(20) NOT NULL PRIMARY KEY,
    MaHopDong VARCHAR(20) NOT NULL,
    MaThietBi VARCHAR(20) NOT NULL,
    DonGia DECIMAL(18,2) NOT NULL,

    TinhTrangLucGiao NVARCHAR(500) NULL,
    NgayGiaoThucTe DATETIME2 NULL,

    TinhTrangLucNhan NVARCHAR(500) NULL,
    NgayNhanThucTe DATETIME2 NULL,

    CoHuHong BIT NOT NULL DEFAULT 0,

    CONSTRAINT FK_ChiTietHopDong_HopDong
        FOREIGN KEY (MaHopDong) REFERENCES HopDong(MaHopDong),

    CONSTRAINT FK_ChiTietHopDong_ThietBi
        FOREIGN KEY (MaThietBi) REFERENCES ThietBi(MaThietBi),

    CONSTRAINT UQ_ChiTietHopDong
        UNIQUE (MaHopDong, MaThietBi),

    CONSTRAINT CK_ChiTietHopDong_DonGia
        CHECK (DonGia >= 0),

    CONSTRAINT CK_ChiTietHopDong_NgayNhan
        CHECK (
            NgayNhanThucTe IS NULL
            OR NgayGiaoThucTe IS NULL
            OR NgayNhanThucTe >= NgayGiaoThucTe
        )
);
GO

/* ================================================================
   17. THANH TOAN
================================================================ */
CREATE TABLE ThanhToan (
    MaThanhToan VARCHAR(20) NOT NULL PRIMARY KEY,
    MaHopDong VARCHAR(20) NOT NULL,
    SoTien DECIMAL(18,2) NOT NULL,
    LoaiThanhToan VARCHAR(30) NOT NULL,
    PhuongThuc VARCHAR(30) NOT NULL,
    MaGiaoDich VARCHAR(100) NULL,
    ThoiGian DATETIME2 NULL,
    TrangThai VARCHAR(20) NOT NULL DEFAULT 'CHO_THANH_TOAN',
    NoiDungChuyenKhoan NVARCHAR(500) NULL,
    NhaCungCap VARCHAR(20) NULL,
    MaThamChieu VARCHAR(100) NULL,
    MaNganHang VARCHAR(20) NULL,
    LoaiThe VARCHAR(20) NULL,
    MaPhanHoi VARCHAR(10) NULL,
    DuongDanThanhToan VARCHAR(2000) NULL,
    ThoiGianHetHan DATETIME2 NULL,
    ThoiGianCapNhat DATETIME2 NULL,

    CONSTRAINT FK_ThanhToan_HopDong
        FOREIGN KEY (MaHopDong) REFERENCES HopDong(MaHopDong),

    CONSTRAINT CK_ThanhToan_SoTien
        CHECK (SoTien > 0),

    CONSTRAINT CK_ThanhToan_Loai
        CHECK (LoaiThanhToan IN (
            'TIEN_COC',
            'TIEN_THUE',
            'PHI_GIA_HAN',
            'PHI_PHAT',
            'HOAN_COC'
        )),

    CONSTRAINT CK_ThanhToan_PhuongThuc
        CHECK (PhuongThuc IN (
            'TIEN_MAT',
            'CHUYEN_KHOAN',
            'VI_DIEN_TU'
        )),

    CONSTRAINT CK_ThanhToan_TrangThai
        CHECK (TrangThai IN (
            'CHO_THANH_TOAN',
            'THANH_CONG',
            'THAT_BAI',
            'DA_HOAN'
        ))
);
GO

/* ================================================================
   18. PHU LUC GIA HAN
================================================================ */
CREATE TABLE PhuLuc (
    MaPhuLuc VARCHAR(20) NOT NULL PRIMARY KEY,
    MaHopDong VARCHAR(20) NOT NULL,
    NgayLap DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    ThoiHanTraMoi DATETIME2 NOT NULL,
    ChiPhiPhatSinh DECIMAL(18,2) NOT NULL,
    TienCocBoSung DECIMAL(18,2) NOT NULL DEFAULT 0,
    GhiChu NVARCHAR(500) NULL,
    LyDoGiaHan NVARCHAR(500) NULL,
    TrangThai VARCHAR(20) NOT NULL DEFAULT 'CHO_XAC_NHAN',

    CONSTRAINT FK_PhuLuc_HopDong
        FOREIGN KEY (MaHopDong) REFERENCES HopDong(MaHopDong),

    CONSTRAINT CK_PhuLuc_ChiPhi
        CHECK (ChiPhiPhatSinh >= 0 AND TienCocBoSung >= 0),

    CONSTRAINT CK_PhuLuc_TrangThai
        CHECK (TrangThai IN (
            'CHO_XAC_NHAN',
            'DA_XAC_NHAN',
            'TU_CHOI'
        ))
);
GO

/* ================================================================
   19. PHIEU PHAT
================================================================ */
CREATE TABLE PhieuPhat (
    MaPhieuPhat VARCHAR(20) NOT NULL PRIMARY KEY,
    MaChiTietHopDong VARCHAR(20) NOT NULL,
    LoaiViPham VARCHAR(30) NOT NULL,
    SoTien DECIMAL(18,2) NOT NULL,
    MoTa NVARCHAR(500) NOT NULL,
    NgayLap DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    TrangThai VARCHAR(20) NOT NULL DEFAULT 'CHO_XAC_NHAN',

    CONSTRAINT FK_PhieuPhat_ChiTietHopDong
        FOREIGN KEY (MaChiTietHopDong) REFERENCES ChiTietHopDong(MaChiTietHopDong),

    CONSTRAINT CK_PhieuPhat_Loai
        CHECK (LoaiViPham IN (
            'TRA_TRE',
            'HU_HONG',
            'KHAC'
        )),

    CONSTRAINT CK_PhieuPhat_SoTien
        CHECK (SoTien >= 0),

    CONSTRAINT CK_PhieuPhat_TrangThai
        CHECK (TrangThai IN (
            'CHO_XAC_NHAN',
            'DA_XAC_NHAN',
            'DA_THANH_TOAN',
            'HUY'
        ))
);
GO

/* ================================================================
   20. ANH BIEN BAN
================================================================ */
CREATE TABLE AnhBienBan (
    MaAnhBienBan VARCHAR(20) NOT NULL PRIMARY KEY,
    MaChiTietHopDong VARCHAR(20) NOT NULL,
    Loai VARCHAR(20) NOT NULL,
    DuongDanAnh NVARCHAR(500) NOT NULL,
    MoTa NVARCHAR(300) NULL,
    ThoiGianChup DATETIME2 NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT FK_AnhBienBan_ChiTietHopDong
        FOREIGN KEY (MaChiTietHopDong) REFERENCES ChiTietHopDong(MaChiTietHopDong),

    CONSTRAINT CK_AnhBienBan_Loai
        CHECK (Loai IN ('BAN_GIAO','NHAN_LAI','HU_HONG'))
);
GO

/* ================================================================
   21. DANH GIA
================================================================ */
CREATE TABLE DanhGia (
    MaDanhGia VARCHAR(20) NOT NULL PRIMARY KEY,
    MaChiTietHopDong VARCHAR(20) NOT NULL UNIQUE,
    MaKhachThue VARCHAR(20) NOT NULL,
    NhanXet NVARCHAR(1000) NULL,
    SoSao TINYINT NOT NULL,
    NgayDanhGia DATETIME2 NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT FK_DanhGia_ChiTietHopDong
        FOREIGN KEY (MaChiTietHopDong) REFERENCES ChiTietHopDong(MaChiTietHopDong),

    CONSTRAINT FK_DanhGia_KhachThue
        FOREIGN KEY (MaKhachThue) REFERENCES KhachThue(MaKhachThue),

    CONSTRAINT CK_DanhGia_SoSao
        CHECK (SoSao BETWEEN 1 AND 5)
);
GO

/* ================================================================
   22. THONG BAO
================================================================ */
CREATE TABLE ThongBao (
    MaThongBao VARCHAR(20) NOT NULL PRIMARY KEY,
    MaTaiKhoan VARCHAR(20) NOT NULL,
    Loai VARCHAR(30) NOT NULL,
    TieuDe NVARCHAR(200) NOT NULL,
    NoiDung NVARCHAR(1000) NOT NULL,
    ThoiGianGui DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    DaDoc BIT NOT NULL DEFAULT 0,

    CONSTRAINT FK_ThongBao_TaiKhoan
        FOREIGN KEY (MaTaiKhoan) REFERENCES TaiKhoan(MaTaiKhoan)
);
GO

/* ================================================================
   INDEXES
================================================================ */

CREATE UNIQUE INDEX UX_AnhThietBi_DaiDien
ON AnhThietBi(MaDongMay)
WHERE LaAnhDaiDien = 1;
GO

CREATE INDEX IX_ThietBi_TimKiem
ON ThietBi(MaCuaHang, MaDongMay, TrangThai);
GO

CREATE INDEX IX_GioHang_KhachHang
ON GioHang(MaKhachThue, TrangThai, NgayCapNhat DESC);
GO

CREATE INDEX IX_ChiTietGioHang_Lich
ON ChiTietGioHang(MaDongMay, NgayBatDau, NgayKetThuc)
INCLUDE (MaGioHang, SoLuong);
GO

CREATE INDEX IX_GiuCho_Availability
ON GiuCho(MaCuaHang, TrangThai, HetHanLuc)
INCLUDE (MaKhachThue, MaGioHang, NgayTao);
GO

CREATE INDEX IX_GiuCho_KhachHang
ON GiuCho(MaKhachThue, TrangThai, HetHanLuc DESC);
GO

CREATE INDEX IX_ChiTietGiuCho_Lich
ON ChiTietGiuCho(MaDongMay, NgayBatDau, NgayKetThuc)
INCLUDE (MaGiuCho, SoLuong);
GO

CREATE INDEX IX_HopDong_Lich
ON HopDong(
    MaCuaHang,
    TrangThai,
    ThoiGianBanGiao,
    ThoiGianTraDuKien
)
INCLUDE (
    MaGioHang,
    MaGiuCho,
    MaKhachThue
);
GO

CREATE INDEX IX_HopDong_KhachHang
ON HopDong(MaKhachThue, TrangThai, NgayTaoHopDong DESC);
GO

CREATE INDEX IX_HopDong_HanTra
ON HopDong(TrangThai, ThoiGianTraDuKien);
GO

CREATE INDEX IX_ChiTietHopDong_ThietBi
ON ChiTietHopDong(MaThietBi, MaHopDong);
GO

CREATE UNIQUE INDEX UX_ThanhToan_MaGiaoDich
ON ThanhToan(MaGiaoDich)
WHERE MaGiaoDich IS NOT NULL;
GO

CREATE UNIQUE INDEX UX_ThanhToan_MaThamChieu
ON ThanhToan(MaThamChieu)
WHERE MaThamChieu IS NOT NULL;
GO

CREATE INDEX IX_ThanhToan_HopDong
ON ThanhToan(MaHopDong, LoaiThanhToan, TrangThai);
GO

CREATE INDEX IX_PhuLuc_HopDong
ON PhuLuc(MaHopDong, TrangThai, ThoiHanTraMoi);
GO

CREATE INDEX IX_PhieuPhat_ChiTietHopDong
ON PhieuPhat(MaChiTietHopDong, TrangThai);
GO

CREATE INDEX IX_ThongBao_ChuaDoc
ON ThongBao(MaTaiKhoan, DaDoc, ThoiGianGui DESC);
GO

/*
=====================================================================
BUSINESS RULES BAT BUOC CHO BACKEND/API
=====================================================================

A. GIO HANG
-----------
1. Them vao GioHang KHONG giu capacity.
2. GioHang khong con dung HetHanLuc cho reservation.

B. TAO GIU CHO - "TIEP TUC THUE"
---------------------------------
3. Chi tao GiuCho khi da co:
   - MaDongMay
   - MaCuaHang
   - SoLuong
   - NgayBatDau
   - NgayKetThuc

4. Check availability + tao GiuCho phai nam trong CUNG transaction.
5. Request tao hold commit thanh cong truoc duoc uu tien capacity truoc.
6. TTL GiuCho do Backend/business config; khong hard-code tai DB.

C. DOI THONG TIN TRONG MAN HINH XAC NHAN THUE
----------------------------------------------
7. Khach co the doi thoi gian/cua hang/so luong.
8. Moi lan doi phai check availability lai.
9. KHONG reset HetHanLuc.
10. Neu lua chon moi khong kha dung, KHONG duoc lam mat hold cu.
11. Chuyen hold cu -> lua chon moi phai atomic.

D. HOLD HET HAN
---------------
12. CurrentTime >= HetHanLuc => hold khong con chiem capacity.
13. DANG_GIU -> HET_HAN co the duoc dong bo bang background job.
14. Backend phai dung HetHanLuc lam source of truth

E. XAC NHAN THUE
----------------
15. Khi khach bam "XAC NHAN THUE":
    - validate hold dung owner
    - TrangThai = DANG_GIU
    - hold chua het han
    - server tinh/xac nhan lai gia
    - tao HopDong = CHO_KY
    - GiuCho = DA_CHUYEN_HOP_DONG
    - GioHang = DA_CHUYEN_HOP_DONG
    Tat ca trong CUNG transaction.

16. Sau khi convert:
    - GiuCho.DA_CHUYEN_HOP_DONG KHONG con chiem capacity.
    - HopDong.CHO_KY tiep tuc chiem capacity.
    - Khong duoc tru availability hai lan.

F. AVAILABILITY
---------------
17. Availability KHONG chi dua vao ThietBi.TrangThai.
18. Phai tinh theo:
    - CuaHang
    - DongMay
    - SoLuong
    - NgayBatDau
    - NgayKetThuc

19. Overlap co ban:
       ExistingStart < RequestedEnd
       AND ExistingEnd > RequestedStart

20. Capacity bi chiem boi:
    - GiuCho DANG_GIU con han va overlap.
    - HopDong dang giu lich va overlap.
    - Gia han DA_XAC_NHAN phai duoc tinh den.

21. Cac HopDong toi thieu can xem la giu lich:
    CHO_KY, DA_KY, CHO_BAN_GIAO, DANG_THUE, CHO_HOAN_TRA.

22. HOAN_THANH va DA_HUY khong giu booking tuong lai.

G. HOP DONG
-----------
23. Flow:
    CHO_KY
      -> DA_KY
      -> CHO_BAN_GIAO
      -> DANG_THUE
      -> CHO_HOAN_TRA
      -> HOAN_THANH

    Ngoai le: DA_HUY.

24. Khong dung CHO_KIEM_TRA va CHO_HOAN_COC.
25. CHO_KY can timeout rieng do Backend/business config.
26. Khi ky:
    - set NgayKy
    - set HinhThucKy
    - CHO_KY -> DA_KY

H. SERIAL / THIET BI VAT LY
---------------------------
27. Khach dat theo DongMay + SoLuong, khong chon serial.
28. MaThietBi duoc gan sau khi cua hang chuan bi may.
29. Truoc ban giao, TinhTrangLucGiao va NgayGiaoThucTe co the NULL.
30. Backend phai dam bao serial duoc gan dung DongMay + CuaHang.

I. GIA / THANH TOAN
-------------------
31. Backend tinh/xac nhan lai gia, coc, tong tien.
32. Khong tin DonGia/TienCoc/TongTien tu client.
33. Khong them CHUA_THANH_TOAN vao HopDong.
34. Thanh toan quan ly rieng tai ThanhToan.
35. Tien thue/tien coc co the thanh toan luc ban giao theo policy.

J. HOAN TRA / HOAN COC
----------------------
36. DANG_THUE -> CHO_HOAN_TRA.
37. Trong CHO_HOAN_TRA:
    - nhan may
    - ghi NgayNhanThucTe
    - ghi TinhTrangLucNhan
    - ghi CoHuHong
    - AnhBienBan neu can
    - PhieuPhat neu can
    - xu ly thanh toan/phat
    - xu ly hoan coc
    - cap nhat ThietBi

38. Hoan coc la nghiep vu bat buoc truoc HOAN_THANH.
39. Rule phat >= coc va hoan coc = 0 can business/backend chot.
40. ThanhToan.SoTien hien CHECK > 0, nen truong hop refund 0
    KHONG duoc tu y insert giao dich HOAN_COC so tien 0 neu chua doi rule.

K. GIA HAN
----------
41. Truoc khi PhuLuc -> DA_XAC_NHAN, Backend phai check overlap.
42. Gia han thanh cong phai anh huong availability tuong lai.

L. CONCURRENCY
--------------
43. SQL CHECK constraint khong tu ngan duoc overlap.
44. Backend phai dung transaction + isolation/locking phu hop cho:
    - create hold
    - update hold
    - convert hold -> contract
    - extension confirmation

=====================================================================
CAC POLICY CHUA HARD-CODE / CAN CHOT
=====================================================================
1. TTL GiuCho bao nhieu phut?
2. Timeout CHO_KY bao nhieu phut?
3. DA_KY -> CHO_BAN_GIAO tu dong hay do nhan vien/system?
4. Khoan thanh toan nao bat buoc truoc ban giao?
5. Phat < coc / = coc / > coc xu ly chi tiet the nao?
6. Refund = 0 ghi nhan nhu the nao?
7. Khach co duoc chu dong huy GiuCho / CHO_KY khong?
8. Policy hop dong tre han/tra thuc te anh huong availability ra sao?

=====================================================================
*/

USE RentalCameraDb20;
GO

-- Thay bằng dữ liệu khách đang chọn.
DECLARE @MaCuaHang  VARCHAR(20) = 'CH001';
DECLARE @MaDongMay  VARCHAR(20) = 'DONG001';
DECLARE @Start      DATETIME2   = '2026-10-01T08:00:00';
DECLARE @End        DATETIME2   = '2026-10-03T08:00:00';
DECLARE @SoLuongCan INT         = 2;

IF @Start IS NULL OR @End IS NULL OR @Start >= @End
    THROW 50001, N'Khoảng thời gian thuê không hợp lệ.', 1;

IF @SoLuongCan IS NULL OR @SoLuongCan <= 0
    THROW 50002, N'Số lượng cần thuê phải lớn hơn 0.', 1;

DECLARE @Now DATETIME2 = SYSDATETIME();

;WITH Capacity AS (
    SELECT COUNT(*) AS TongMayCoTheChoThue
    FROM ThietBi
    WHERE MaCuaHang = @MaCuaHang
      AND MaDongMay = @MaDongMay
      AND TrangThai IN ('SAN_SANG', 'DANG_GIU', 'DANG_THUE')
),
LichChiem AS (
    -- 1. Giữ chỗ còn hạn, chưa chuyển thành hợp đồng.
    SELECT
        ct.NgayBatDau AS BatDau,
        ct.NgayKetThuc AS KetThuc,
        ct.SoLuong
    FROM GiuCho AS gc
    JOIN ChiTietGiuCho AS ct
        ON ct.MaGiuCho = gc.MaGiuCho
    WHERE gc.MaCuaHang = @MaCuaHang
      AND ct.MaDongMay = @MaDongMay
      AND gc.TrangThai = 'DANG_GIU'
      AND gc.HetHanLuc > @Now
      AND ct.NgayBatDau < @End
      AND ct.NgayKetThuc > @Start

    UNION ALL

    -- 2. Hợp đồng đang giữ lịch; lấy số lượng đã đặt từ ChiTietGiuCho.
    SELECT
        ct.NgayBatDau AS BatDau,
        CASE
            WHEN pl.ThoiHanGiaHan > hd.ThoiGianTraDuKien
                THEN pl.ThoiHanGiaHan
            ELSE hd.ThoiGianTraDuKien
        END AS KetThuc,
        ct.SoLuong
    FROM HopDong AS hd
    JOIN ChiTietGiuCho AS ct
        ON ct.MaGiuCho = hd.MaGiuCho
    OUTER APPLY (
        SELECT MAX(p.ThoiHanTraMoi) AS ThoiHanGiaHan
        FROM PhuLuc AS p
        WHERE p.MaHopDong = hd.MaHopDong
          AND p.TrangThai = 'DA_XAC_NHAN'
    ) AS pl
    WHERE hd.MaCuaHang = @MaCuaHang
      AND ct.MaDongMay = @MaDongMay
      AND hd.TrangThai IN (
          'CHO_KY',
          'DA_KY',
          'CHO_BAN_GIAO',
          'DANG_THUE',
          'CHO_HOAN_TRA'
      )
      AND ct.NgayBatDau < @End
      AND (
          CASE
              WHEN pl.ThoiHanGiaHan > hd.ThoiGianTraDuKien
                  THEN pl.ThoiHanGiaHan
              ELSE hd.ThoiGianTraDuKien
          END
      ) > @Start
),
MocThoiGian AS (
    -- Kiểm tra ở đầu khoảng yêu cầu và mỗi lúc có lượt chiếm mới bắt đầu.
    SELECT @Start AS ThoiDiem

    UNION

    SELECT BatDau
    FROM LichChiem
    WHERE BatDau > @Start
      AND BatDau < @End
),
SucChuaTaiTungMoc AS (
    SELECT
        m.ThoiDiem,
        c.TongMayCoTheChoThue,
        COALESCE(SUM(
            CASE
                WHEN l.BatDau <= m.ThoiDiem
                 AND l.KetThuc > m.ThoiDiem
                    THEN l.SoLuong
                ELSE 0
            END
        ), 0) AS SoMayDangBiChiem
    FROM MocThoiGian AS m
    CROSS JOIN Capacity AS c
    LEFT JOIN LichChiem AS l
        ON l.BatDau <= m.ThoiDiem
       AND l.KetThuc > m.ThoiDiem
    GROUP BY m.ThoiDiem, c.TongMayCoTheChoThue
)
SELECT
    @MaCuaHang AS MaCuaHang,
    @MaDongMay AS MaDongMay,
    @Start AS NgayBatDau,
    @End AS NgayKetThuc,
    @SoLuongCan AS SoLuongCan,
    MAX(TongMayCoTheChoThue) AS TongMayCoTheChoThue,
    MAX(SoMayDangBiChiem) AS SoMayBiChiemNhieuNhat,
    MIN(TongMayCoTheChoThue - SoMayDangBiChiem) AS AvailableCapacity,
    CASE
        WHEN MIN(TongMayCoTheChoThue - SoMayDangBiChiem) >= @SoLuongCan
            THEN CAST(1 AS BIT)
        ELSE CAST(0 AS BIT)
    END AS CoDuMay
FROM SucChuaTaiTungMoc;
