USE RentalCameraDb20;
GO

SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.NhatKyHeThong', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.NhatKyHeThong
    (
        MaNhatKy VARCHAR(20) NOT NULL CONSTRAINT PK_NhatKyHeThong PRIMARY KEY,
        MaTaiKhoan VARCHAR(20) NULL,
        VaiTro VARCHAR(20) NULL,
        HanhDong VARCHAR(10) NOT NULL,
        DuongDan NVARCHAR(500) NOT NULL,
        DoiTuong VARCHAR(100) NULL,
        MaDoiTuong VARCHAR(100) NULL,
        MaCuaHang VARCHAR(20) NULL,
        TrangThaiHttp INT NOT NULL,
        DiaChiIp VARCHAR(45) NULL,
        ThoiGian DATETIME2 NOT NULL CONSTRAINT DF_NhatKyHeThong_ThoiGian DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_NhatKyHeThong_TaiKhoan FOREIGN KEY (MaTaiKhoan)
            REFERENCES dbo.TaiKhoan(MaTaiKhoan)
    );

    CREATE INDEX IX_NhatKyHeThong_ThoiGian
        ON dbo.NhatKyHeThong(ThoiGian DESC);
    CREATE INDEX IX_NhatKyHeThong_TaiKhoan_ThoiGian
        ON dbo.NhatKyHeThong(MaTaiKhoan, ThoiGian DESC);
END;
GO

/* Đồng bộ loại vi phạm với API hoàn trả/phụ kiện thiếu. */
IF EXISTS
(
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.PhieuPhat')
      AND name = N'CK_PhieuPhat_Loai'
)
BEGIN
    ALTER TABLE dbo.PhieuPhat DROP CONSTRAINT CK_PhieuPhat_Loai;
END;
GO

ALTER TABLE dbo.PhieuPhat WITH CHECK ADD CONSTRAINT CK_PhieuPhat_Loai
CHECK (LoaiViPham IN ('TRA_TRE','HU_HONG','THIEU_PHU_KIEN','KHAC'));
GO
