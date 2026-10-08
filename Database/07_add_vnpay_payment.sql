USE RentalCameraDb20;
GO

SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH('dbo.ThanhToan', 'NhaCungCap') IS NULL
    ALTER TABLE dbo.ThanhToan ADD NhaCungCap VARCHAR(20) NULL;
IF COL_LENGTH('dbo.ThanhToan', 'MaThamChieu') IS NULL
    ALTER TABLE dbo.ThanhToan ADD MaThamChieu VARCHAR(100) NULL;
IF COL_LENGTH('dbo.ThanhToan', 'MaNganHang') IS NULL
    ALTER TABLE dbo.ThanhToan ADD MaNganHang VARCHAR(20) NULL;
IF COL_LENGTH('dbo.ThanhToan', 'LoaiThe') IS NULL
    ALTER TABLE dbo.ThanhToan ADD LoaiThe VARCHAR(20) NULL;
IF COL_LENGTH('dbo.ThanhToan', 'MaPhanHoi') IS NULL
    ALTER TABLE dbo.ThanhToan ADD MaPhanHoi VARCHAR(10) NULL;
IF COL_LENGTH('dbo.ThanhToan', 'DuongDanThanhToan') IS NULL
    ALTER TABLE dbo.ThanhToan ADD DuongDanThanhToan VARCHAR(2000) NULL;
IF COL_LENGTH('dbo.ThanhToan', 'ThoiGianHetHan') IS NULL
    ALTER TABLE dbo.ThanhToan ADD ThoiGianHetHan DATETIME2 NULL;
IF COL_LENGTH('dbo.ThanhToan', 'ThoiGianCapNhat') IS NULL
    ALTER TABLE dbo.ThanhToan ADD ThoiGianCapNhat DATETIME2 NULL;

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'UX_ThanhToan_MaThamChieu'
      AND object_id = OBJECT_ID('dbo.ThanhToan')
)
    CREATE UNIQUE INDEX UX_ThanhToan_MaThamChieu
        ON dbo.ThanhToan(MaThamChieu)
        WHERE MaThamChieu IS NOT NULL;

COMMIT TRANSACTION;
GO
