USE RentalCameraDb20;
GO

SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH('dbo.DongMay', 'TrangThai') IS NULL
BEGIN
    ALTER TABLE dbo.DongMay
        ADD TrangThai VARCHAR(30) NOT NULL
            CONSTRAINT DF_DongMay_TrangThai DEFAULT 'HOAT_DONG';
END;

IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = 'CK_DongMay_TrangThai'
)
BEGIN
    EXEC(N'ALTER TABLE dbo.DongMay WITH CHECK
        ADD CONSTRAINT CK_DongMay_TrangThai
        CHECK (TrangThai IN (''HOAT_DONG'', ''NGUNG_KINH_DOANH''));');
END;

IF OBJECT_ID('dbo.PhieuBaoTri', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PhieuBaoTri (
        MaPhieuBaoTri VARCHAR(20) NOT NULL PRIMARY KEY,
        MaThietBi VARCHAR(20) NOT NULL,
        MaCuaHang VARCHAR(20) NOT NULL,
        MoTaLoi NVARCHAR(1000) NOT NULL,
        TrangThai VARCHAR(20) NOT NULL CONSTRAINT DF_PhieuBaoTri_TrangThai DEFAULT 'MOI_TAO',
        ChiPhiDuKien DECIMAL(18,2) NULL,
        ChiPhiThucTe DECIMAL(18,2) NULL,
        GhiChu NVARCHAR(1000) NULL,
        NguoiTao VARCHAR(20) NOT NULL,
        ThoiGianTao DATETIME2 NOT NULL CONSTRAINT DF_PhieuBaoTri_ThoiGianTao DEFAULT SYSUTCDATETIME(),
        ThoiGianBatDau DATETIME2 NULL,
        ThoiGianHoanTat DATETIME2 NULL,
        CONSTRAINT FK_PhieuBaoTri_ThietBi FOREIGN KEY (MaThietBi) REFERENCES dbo.ThietBi(MaThietBi),
        CONSTRAINT FK_PhieuBaoTri_CuaHang FOREIGN KEY (MaCuaHang) REFERENCES dbo.CuaHang(MaCuaHang),
        CONSTRAINT CK_PhieuBaoTri_TrangThai CHECK (TrangThai IN ('MOI_TAO','DANG_XU_LY','HOAN_TAT','HUY')),
        CONSTRAINT CK_PhieuBaoTri_ChiPhi CHECK (
            (ChiPhiDuKien IS NULL OR ChiPhiDuKien >= 0) AND
            (ChiPhiThucTe IS NULL OR ChiPhiThucTe >= 0)
        )
    );
    CREATE INDEX IX_PhieuBaoTri_ThietBi_TrangThai
        ON dbo.PhieuBaoTri(MaThietBi, TrangThai);
END;

IF OBJECT_ID('dbo.HuHongThietBi', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.HuHongThietBi (
        MaHuHong VARCHAR(20) NOT NULL PRIMARY KEY,
        MaThietBi VARCHAR(20) NOT NULL,
        MaPhieuBaoTri VARCHAR(20) NULL,
        MoTa NVARCHAR(1000) NOT NULL,
        MucDo VARCHAR(20) NOT NULL,
        ChiPhiSuaChua DECIMAL(18,2) NOT NULL CONSTRAINT DF_HuHong_ChiPhi DEFAULT 0,
        TrangThai VARCHAR(20) NOT NULL CONSTRAINT DF_HuHong_TrangThai DEFAULT 'CHUA_SUA',
        TinhTrangSauSuaChua NVARCHAR(500) NULL,
        NguoiGhiNhan VARCHAR(20) NOT NULL,
        ThoiGianGhiNhan DATETIME2 NOT NULL CONSTRAINT DF_HuHong_ThoiGian DEFAULT SYSUTCDATETIME(),
        ThoiGianCapNhat DATETIME2 NULL,
        CONSTRAINT FK_HuHong_ThietBi FOREIGN KEY (MaThietBi) REFERENCES dbo.ThietBi(MaThietBi),
        CONSTRAINT FK_HuHong_PhieuBaoTri FOREIGN KEY (MaPhieuBaoTri) REFERENCES dbo.PhieuBaoTri(MaPhieuBaoTri),
        CONSTRAINT CK_HuHong_MucDo CHECK (MucDo IN ('NHE','TRUNG_BINH','NANG')),
        CONSTRAINT CK_HuHong_TrangThai CHECK (TrangThai IN ('CHUA_SUA','DANG_SUA','DA_SUA','KHONG_SUA')),
        CONSTRAINT CK_HuHong_ChiPhi CHECK (ChiPhiSuaChua >= 0)
    );
    CREATE INDEX IX_HuHong_ThietBi_ThoiGian
        ON dbo.HuHongThietBi(MaThietBi, ThoiGianGhiNhan DESC);
END;

IF OBJECT_ID('dbo.LichSuCapNhatHuHong', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.LichSuCapNhatHuHong (
        MaLichSu VARCHAR(20) NOT NULL PRIMARY KEY,
        MaHuHong VARCHAR(20) NOT NULL,
        TrangThaiCu VARCHAR(20) NOT NULL,
        TrangThaiMoi VARCHAR(20) NOT NULL,
        ChiPhiCu DECIMAL(18,2) NOT NULL,
        ChiPhiMoi DECIMAL(18,2) NOT NULL,
        NguoiThaoTac VARCHAR(20) NOT NULL,
        GhiChu NVARCHAR(1000) NULL,
        ThoiGian DATETIME2 NOT NULL CONSTRAINT DF_LichSuHuHong_ThoiGian DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_LichSuHuHong_HuHong FOREIGN KEY (MaHuHong) REFERENCES dbo.HuHongThietBi(MaHuHong)
    );
END;

IF OBJECT_ID('dbo.LichSuDieuChuyenThietBi', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.LichSuDieuChuyenThietBi (
        MaDieuChuyen VARCHAR(20) NOT NULL PRIMARY KEY,
        MaThietBi VARCHAR(20) NOT NULL,
        MaCuaHangCu VARCHAR(20) NOT NULL,
        MaCuaHangMoi VARCHAR(20) NOT NULL,
        LyDo NVARCHAR(500) NULL,
        NguoiThaoTac VARCHAR(20) NOT NULL,
        ThoiGian DATETIME2 NOT NULL CONSTRAINT DF_DieuChuyen_ThoiGian DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_DieuChuyen_ThietBi FOREIGN KEY (MaThietBi) REFERENCES dbo.ThietBi(MaThietBi),
        CONSTRAINT FK_DieuChuyen_CuaHangCu FOREIGN KEY (MaCuaHangCu) REFERENCES dbo.CuaHang(MaCuaHang),
        CONSTRAINT FK_DieuChuyen_CuaHangMoi FOREIGN KEY (MaCuaHangMoi) REFERENCES dbo.CuaHang(MaCuaHang),
        CONSTRAINT CK_DieuChuyen_KhacChiNhanh CHECK (MaCuaHangCu <> MaCuaHangMoi)
    );
    CREATE INDEX IX_DieuChuyen_ThietBi_ThoiGian
        ON dbo.LichSuDieuChuyenThietBi(MaThietBi, ThoiGian DESC);
END;

COMMIT TRANSACTION;
GO
