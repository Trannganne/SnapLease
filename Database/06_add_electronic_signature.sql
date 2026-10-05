USE RentalCameraDb20;
GO

IF COL_LENGTH('dbo.HopDong', 'DaDongYDieuKhoan') IS NULL
    ALTER TABLE dbo.HopDong ADD DaDongYDieuKhoan BIT NOT NULL
        CONSTRAINT DF_HopDong_DaDongYDieuKhoan DEFAULT 0 WITH VALUES;
GO

IF COL_LENGTH('dbo.HopDong', 'PhienBanDieuKhoan') IS NULL
    ALTER TABLE dbo.HopDong ADD PhienBanDieuKhoan VARCHAR(20) NULL;
GO

IF COL_LENGTH('dbo.HopDong', 'MaBamNoiDung') IS NULL
    ALTER TABLE dbo.HopDong ADD MaBamNoiDung CHAR(64) NULL;
GO

IF COL_LENGTH('dbo.HopDong', 'NoiDungHopDongJson') IS NULL
    ALTER TABLE dbo.HopDong ADD NoiDungHopDongJson NVARCHAR(MAX) NULL;
GO

IF OBJECT_ID(N'dbo.XacNhanKyHopDong', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.XacNhanKyHopDong (
        MaXacNhan VARCHAR(20) NOT NULL PRIMARY KEY,
        MaHopDong VARCHAR(20) NOT NULL,
        MaOtpHash CHAR(64) NOT NULL,
        MuoiOtp CHAR(32) NOT NULL,
        TaoLuc DATETIME2 NOT NULL CONSTRAINT DF_XacNhanKyHopDong_TaoLuc DEFAULT SYSDATETIME(),
        HetHanLuc DATETIME2 NOT NULL,
        SoLanThu INT NOT NULL CONSTRAINT DF_XacNhanKyHopDong_SoLanThu DEFAULT 0,
        TrangThai VARCHAR(20) NOT NULL
            CONSTRAINT DF_XacNhanKyHopDong_TrangThai DEFAULT 'CHO_XAC_NHAN',
        XacNhanLuc DATETIME2 NULL,
        DiaChiIp VARCHAR(45) NULL,
        ThietBiKy NVARCHAR(500) NULL,
        PhienBanDieuKhoan VARCHAR(20) NOT NULL,
        MaBamNoiDung CHAR(64) NOT NULL,
        NoiDungHopDongJson NVARCHAR(MAX) NOT NULL,
        CONSTRAINT FK_XacNhanKyHopDong_HopDong
            FOREIGN KEY (MaHopDong) REFERENCES dbo.HopDong(MaHopDong),
        CONSTRAINT CK_XacNhanKyHopDong_ThoiGian CHECK (HetHanLuc > TaoLuc),
        CONSTRAINT CK_XacNhanKyHopDong_SoLanThu CHECK (SoLanThu >= 0),
        CONSTRAINT CK_XacNhanKyHopDong_TrangThai
            CHECK (TrangThai IN ('CHO_XAC_NHAN','DA_XAC_NHAN','HET_HAN','DA_HUY','KHOA')),
        CONSTRAINT CK_XacNhanKyHopDong_Json CHECK (ISJSON(NoiDungHopDongJson) = 1)
    );
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_XacNhanKyHopDong_HopDong_TrangThai'
      AND object_id = OBJECT_ID(N'dbo.XacNhanKyHopDong')
)
    CREATE INDEX IX_XacNhanKyHopDong_HopDong_TrangThai
        ON dbo.XacNhanKyHopDong(MaHopDong, TrangThai);
GO
