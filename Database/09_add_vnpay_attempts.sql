-- Deployment migration: 09_add_vnpay_attempts.sql
-- Use sqlcmd -d <database> -v TargetDatabase=<same database>. Review backup and schema first.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET XACT_ABORT ON;

-- 2. FAIL-SAFE: Kiem tra dich danh ten database truoc moi thao tac DDL
IF DB_NAME() <> '$(TargetDatabase)'
BEGIN
    THROW 51000, N'LOI BAO VE: Script nay CHI DUOC PHEP chay tren database [$(TargetDatabase)]. Thao tac bi huy bo!', 1;
END;

BEGIN TRANSACTION;

-- 3. Kiem tra bang cha ThanhToan & doi chieu kieu/do dai MaThanhToan
IF OBJECT_ID('dbo.ThanhToan', 'U') IS NULL
BEGIN
    THROW 51001, N'LOI SCHEMA: Bang cha dbo.ThanhToan khong ton tai trong database!', 1;
END;

DECLARE @ParentColType NVARCHAR(50);
DECLARE @ParentColLen INT;

SELECT
    @ParentColType = DATA_TYPE,
    @ParentColLen = CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ThanhToan' AND COLUMN_NAME = 'MaThanhToan';

IF @ParentColType IS NULL OR @ParentColType NOT IN ('varchar', 'nvarchar') OR @ParentColLen <> 20
BEGIN
    DECLARE @ErrMsg NVARCHAR(200) = N'LOI SCHEMA: Cot MaThanhToan cua bang ThanhToan khong khop schema runtime (mong doi varchar/nvarchar(20), thuc te: ' + ISNULL(@ParentColType, 'NULL') + '(' + CAST(ISNULL(@ParentColLen, 0) AS NVARCHAR(10)) + '))!';
    THROW 51002, @ErrMsg, 1;
END;

-- 4. Tao hoac kiem tra bang YeuCauThanhToanVnpay
IF OBJECT_ID('dbo.YeuCauThanhToanVnpay', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.YeuCauThanhToanVnpay (
        MaYeuCau VARCHAR(50) NOT NULL,
        MaThanhToan VARCHAR(20) NOT NULL,
        MaThamChieu VARCHAR(100) NOT NULL,
        SoTien DECIMAL(18, 2) NOT NULL,
        TienTe VARCHAR(10) NOT NULL CONSTRAINT DF_YeuCauThanhToanVnpay_TienTe DEFAULT ('VND'),
        DuongDanThanhToan VARCHAR(2000) NOT NULL,
        ThoiGianHetHan DATETIME2 NOT NULL,
        TrangThai VARCHAR(30) NOT NULL CONSTRAINT DF_YeuCauThanhToanVnpay_TrangThai DEFAULT ('CHO_THANH_TOAN'),
        LaThuThua BIT NOT NULL CONSTRAINT DF_YeuCauThanhToanVnpay_LaThuThua DEFAULT (0),
        MaGiaoDich VARCHAR(100) NULL,
        MaNganHang VARCHAR(20) NULL,
        LoaiThe VARCHAR(20) NULL,
        MaPhanHoi VARCHAR(10) NULL,
        GhiChu NVARCHAR(500) NULL,
        ThoiGianTao DATETIME2 NOT NULL CONSTRAINT DF_YeuCauThanhToanVnpay_ThoiGianTao DEFAULT SYSUTCDATETIME(),
        ThoiGianCapNhat DATETIME2 NULL,
        CONSTRAINT PK_YeuCauThanhToanVnpay PRIMARY KEY CLUSTERED (MaYeuCau ASC),
        CONSTRAINT CK_YeuCauThanhToanVnpay_TrangThai CHECK (TrangThai IN ('CHO_THANH_TOAN', 'THANH_CONG', 'THAT_BAI', 'HET_HAN')),
        CONSTRAINT FK_YeuCauThanhToanVnpay_ThanhToan FOREIGN KEY (MaThanhToan) REFERENCES dbo.ThanhToan(MaThanhToan)
    );

    PRINT 'Tao moi bang dbo.YeuCauThanhToanVnpay thanh cong.';
END
ELSE
BEGIN
    -- Kiem tra tinh toan ven schema neu bang da ton tai
    IF COL_LENGTH('dbo.YeuCauThanhToanVnpay', 'MaYeuCau') IS NULL
        OR COL_LENGTH('dbo.YeuCauThanhToanVnpay', 'MaThanhToan') IS NULL
        OR COL_LENGTH('dbo.YeuCauThanhToanVnpay', 'MaThamChieu') IS NULL
        OR COL_LENGTH('dbo.YeuCauThanhToanVnpay', 'SoTien') IS NULL
        OR COL_LENGTH('dbo.YeuCauThanhToanVnpay', 'TienTe') IS NULL
        OR COL_LENGTH('dbo.YeuCauThanhToanVnpay', 'DuongDanThanhToan') IS NULL
        OR COL_LENGTH('dbo.YeuCauThanhToanVnpay', 'ThoiGianHetHan') IS NULL
        OR COL_LENGTH('dbo.YeuCauThanhToanVnpay', 'TrangThai') IS NULL
        OR COL_LENGTH('dbo.YeuCauThanhToanVnpay', 'LaThuThua') IS NULL
    BEGIN
        THROW 51003, N'LOI SCHEMA: Bang dbo.YeuCauThanhToanVnpay da ton tai nhung thieu cac cot bat buoc!', 1;
    END;

    PRINT 'Bang dbo.YeuCauThanhToanVnpay da ton tai va day du cot co ban.';
END;

-- 5. Kiem tra va tao Index Unique MaThamChieu
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'UX_YeuCauThanhToanVnpay_MaThamChieu'
      AND object_id = OBJECT_ID('dbo.YeuCauThanhToanVnpay')
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_YeuCauThanhToanVnpay_MaThamChieu
        ON dbo.YeuCauThanhToanVnpay (MaThamChieu ASC);
    PRINT 'Tao Index UX_YeuCauThanhToanVnpay_MaThamChieu thanh cong.';
END;

-- 6. Kiem tra va tao Index FK MaThanhToan
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_YeuCauThanhToanVnpay_MaThanhToan'
      AND object_id = OBJECT_ID('dbo.YeuCauThanhToanVnpay')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_YeuCauThanhToanVnpay_MaThanhToan
        ON dbo.YeuCauThanhToanVnpay (MaThanhToan ASC);
    PRINT 'Tao Index IX_YeuCauThanhToanVnpay_MaThanhToan thanh cong.';
END;

-- 7. Kiem tra va tao Filtered Index LaThuThua
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_YeuCauThanhToanVnpay_LaThuThua'
      AND object_id = OBJECT_ID('dbo.YeuCauThanhToanVnpay')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_YeuCauThanhToanVnpay_LaThuThua
        ON dbo.YeuCauThanhToanVnpay (LaThuThua ASC)
        WHERE (LaThuThua = 1);
    PRINT 'Tao Filtered Index IX_YeuCauThanhToanVnpay_LaThuThua thanh cong.';
END;

-- 8. Kiem tra Check Constraint TrangThai
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = 'CK_YeuCauThanhToanVnpay_TrangThai'
      AND parent_object_id = OBJECT_ID('dbo.YeuCauThanhToanVnpay')
)
BEGIN
    ALTER TABLE dbo.YeuCauThanhToanVnpay
        ADD CONSTRAINT CK_YeuCauThanhToanVnpay_TrangThai
        CHECK (TrangThai IN ('CHO_THANH_TOAN', 'THANH_CONG', 'THAT_BAI', 'HET_HAN'));
    PRINT 'Tao Check Constraint CK_YeuCauThanhToanVnpay_TrangThai thanh cong.';
END;

-- 9. Kiem tra Foreign Key
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name = 'FK_YeuCauThanhToanVnpay_ThanhToan'
      AND parent_object_id = OBJECT_ID('dbo.YeuCauThanhToanVnpay')
)
BEGIN
    ALTER TABLE dbo.YeuCauThanhToanVnpay
        ADD CONSTRAINT FK_YeuCauThanhToanVnpay_ThanhToan
        FOREIGN KEY (MaThanhToan) REFERENCES dbo.ThanhToan(MaThanhToan);
    PRINT 'Tao Foreign Key FK_YeuCauThanhToanVnpay_ThanhToan thanh cong.';
END;

COMMIT TRANSACTION;
PRINT 'Migration 09 hoan tat thanh cong tren $(TargetDatabase).';
