USE RentalCameraDb20;
GO

IF OBJECT_ID('dbo.LichSuTrangThaiTaiKhoan', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.LichSuTrangThaiTaiKhoan
    (
        MaLichSu VARCHAR(20) NOT NULL,
        MaTaiKhoan VARCHAR(20) NOT NULL,
        TrangThaiCu VARCHAR(20) NOT NULL,
        TrangThaiMoi VARCHAR(20) NOT NULL,
        LyDo NVARCHAR(500) NULL,
        NguoiThaoTac VARCHAR(20) NOT NULL,
        ThoiGian DATETIME2 NOT NULL
            CONSTRAINT DF_LichSuTrangThaiTaiKhoan_ThoiGian DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_LichSuTrangThaiTaiKhoan PRIMARY KEY (MaLichSu),
        CONSTRAINT FK_LichSuTrangThaiTaiKhoan_TaiKhoan
            FOREIGN KEY (MaTaiKhoan) REFERENCES dbo.TaiKhoan(MaTaiKhoan),
        CONSTRAINT FK_LichSuTrangThaiTaiKhoan_NguoiThaoTac
            FOREIGN KEY (NguoiThaoTac) REFERENCES dbo.TaiKhoan(MaTaiKhoan),
        CONSTRAINT CK_LichSuTrangThaiTaiKhoan_TrangThaiCu
            CHECK (TrangThaiCu IN ('HOAT_DONG', 'TAM_KHOA')),
        CONSTRAINT CK_LichSuTrangThaiTaiKhoan_TrangThaiMoi
            CHECK (TrangThaiMoi IN ('HOAT_DONG', 'TAM_KHOA'))
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_LichSuTrangThaiTaiKhoan_TaiKhoan_ThoiGian'
      AND object_id = OBJECT_ID('dbo.LichSuTrangThaiTaiKhoan')
)
BEGIN
    CREATE INDEX IX_LichSuTrangThaiTaiKhoan_TaiKhoan_ThoiGian
        ON dbo.LichSuTrangThaiTaiKhoan(MaTaiKhoan, ThoiGian DESC);
END;
GO
