-- Deployment migration: 10_review_publication.sql
-- Use sqlcmd -d <database> -v TargetDatabase=<same database>. Review backup and schema first.
IF DB_NAME() COLLATE Latin1_General_100_BIN2 <> N'$(TargetDatabase)'
    THROW 51000, 'STOP: connect only to $(TargetDatabase).', 1;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
IF @@TRANCOUNT <> 0 THROW 51001, 'STOP: use a dedicated session without an existing transaction.', 1;
BEGIN TRY
BEGIN TRANSACTION;
IF DB_NAME() COLLATE Latin1_General_100_BIN2 <> N'$(TargetDatabase)'
    THROW 51000, 'STOP: connect only to $(TargetDatabase).', 1;


-- Preserve historical comments at their existing width. Report oversized input only.
IF OBJECT_ID('dbo.DanhGia', 'U') IS NULL
    THROW 51002, 'STOP: missing baseline dbo.DanhGia.', 1;
DECLARE @OversizeComments bigint;
SELECT @OversizeComments = COUNT_BIG(*)
FROM dbo.DanhGia WITH (TABLOCKX, HOLDLOCK)
WHERE DATALENGTH(CONVERT(nvarchar(max), NhanXet)) > 1000;
SELECT @OversizeComments AS CommentsExceeding500Utf16Units;
IF EXISTS (SELECT MaChiTietHopDong FROM dbo.DanhGia GROUP BY MaChiTietHopDong HAVING COUNT_BIG(*) > 1)
    THROW 51004, 'STOP: duplicate contract details in reviews; resolve without deleting data.', 1;
IF NOT EXISTS (
 SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.DanhGia')
 AND i.is_unique=1 AND i.is_disabled=0 AND i.has_filter=0
 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id
      AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1
 AND EXISTS (SELECT 1 FROM sys.index_columns ic JOIN sys.columns c
      ON c.object_id=ic.object_id AND c.column_id=ic.column_id
      WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id
      AND ic.key_ordinal=1 AND c.name='MaChiTietHopDong'))
 THROW 51008, 'STOP: enabled unfiltered unique index on review contract detail is required.', 1;

IF COL_LENGTH('dbo.DanhGia', 'TrangThaiKiemDuyet') IS NULL
BEGIN
    EXEC(N'ALTER TABLE dbo.DanhGia ADD TrangThaiKiemDuyet VARCHAR(20) NULL;');
END;





-- Permit either historical nullable/non-nullable varchar(20); do not alter existing rows.
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.DanhGia')
    AND name='TrangThaiKiemDuyet' AND (TYPE_NAME(user_type_id)<>'varchar' OR max_length<>20))
    THROW 51005, 'STOP: unexpected status type/width.', 1;
-- Do not guess how pending/rejected/hidden rows should migrate. Report counts only.
EXEC(N'SELECT TrangThaiKiemDuyet AS StatusCode, COUNT_BIG(*) AS [RowCount] FROM dbo.DanhGia GROUP BY TrangThaiKiemDuyet;
IF EXISTS (SELECT 1 FROM dbo.DanhGia WHERE TrangThaiKiemDuyet IS NOT NULL
 AND TrangThaiKiemDuyet NOT IN (''DA_DUYET'',''CONG_KHAI''))
 THROW 51006, ''STOP: pending/rejected/hidden/unknown rows require a reviewed mapping. No statuses changed.'', 1;');
DECLARE @DefaultName sysname;
SELECT @DefaultName=dc.name FROM sys.default_constraints dc JOIN sys.columns c
 ON c.object_id=dc.parent_object_id AND c.column_id=dc.parent_column_id
 WHERE c.object_id=OBJECT_ID('dbo.DanhGia') AND c.name='TrangThaiKiemDuyet';
IF @DefaultName IS NOT NULL
BEGIN
 DECLARE @DropDefaultSql nvarchar(max)=N'ALTER TABLE dbo.DanhGia DROP CONSTRAINT '+QUOTENAME(@DefaultName)+N';';
 EXEC(@DropDefaultSql);
END;
EXEC(N'ALTER TABLE dbo.DanhGia ADD CONSTRAINT DF_DanhGia_TrangThaiKiemDuyet DEFAULT ''CONG_KHAI'' FOR TrangThaiKiemDuyet;');

IF COL_LENGTH('dbo.DanhGia', 'GhiChuKiemDuyet') IS NULL
    ALTER TABLE dbo.DanhGia ADD GhiChuKiemDuyet NVARCHAR(500) NULL;

IF COL_LENGTH('dbo.DanhGia', 'NgayKiemDuyet') IS NULL
    ALTER TABLE dbo.DanhGia ADD NgayKiemDuyet DATETIME2 NULL;

-- Preserve the existing NhanXet column width and all comment contents.

-- Replace only the known status CHECK; unknown checks/schema must be reviewed before execution.
IF OBJECT_ID('dbo.CK_DanhGia_TrangThaiKiemDuyet', 'C') IS NOT NULL
 ALTER TABLE dbo.DanhGia DROP CONSTRAINT CK_DanhGia_TrangThaiKiemDuyet;
EXEC(N'ALTER TABLE dbo.DanhGia WITH CHECK ADD CONSTRAINT CK_DanhGia_TrangThaiKiemDuyet
 CHECK (TrangThaiKiemDuyet IS NULL OR TrangThaiKiemDuyet IN (''CONG_KHAI'',''AN'',''CHO_DUYET'',''DA_DUYET'',''TU_CHOI''));');

IF OBJECT_ID('dbo.DanhGiaDiemNoiBat', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DanhGiaDiemNoiBat
    (
        MaDanhGia VARCHAR(20) NOT NULL,
        MaDiemNoiBat VARCHAR(50) NOT NULL,

        CONSTRAINT PK_DanhGiaDiemNoiBat
            PRIMARY KEY (MaDanhGia, MaDiemNoiBat),
        CONSTRAINT FK_DanhGiaDiemNoiBat_DanhGia
            FOREIGN KEY (MaDanhGia) REFERENCES dbo.DanhGia(MaDanhGia) ON DELETE CASCADE,
        CONSTRAINT CK_DanhGiaDiemNoiBat_Ma
            CHECK (MaDiemNoiBat IN
            (
                'CHAT_LUONG_HINH_ANH_TOT',
                'THIET_BI_HOAT_DONG_ON_DINH',
                'NGOAI_HINH_CON_MOI',
                'PIN_SU_DUNG_TOT',
                'DE_SU_DUNG',
                'PHU_KIEN_DAY_DU'
            ))
    );
END;

IF OBJECT_ID('dbo.AnhDanhGia', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AnhDanhGia
    (
        MaAnhDanhGia VARCHAR(20) NOT NULL,
        MaDanhGia VARCHAR(20) NOT NULL,
        DuongDanAnh NVARCHAR(500) NOT NULL,
        PublicId NVARCHAR(200) NOT NULL,
        ThuTu TINYINT NOT NULL,
        NgayTao DATETIME2 NOT NULL
            CONSTRAINT DF_AnhDanhGia_NgayTao DEFAULT SYSDATETIME(),

        CONSTRAINT PK_AnhDanhGia PRIMARY KEY (MaAnhDanhGia),
        CONSTRAINT FK_AnhDanhGia_DanhGia
            FOREIGN KEY (MaDanhGia) REFERENCES dbo.DanhGia(MaDanhGia) ON DELETE CASCADE,
        CONSTRAINT UQ_AnhDanhGia_ThuTu UNIQUE (MaDanhGia, ThuTu),
        CONSTRAINT CK_AnhDanhGia_ThuTu CHECK (ThuTu BETWEEN 1 AND 4)
    );
END;

IF OBJECT_ID('dbo.LichSuHienThiDanhGia','U') IS NOT NULL
 THROW 51007, 'STOP: audit table already exists; verify prior publication migration rather than rerunning.', 1;
CREATE TABLE dbo.LichSuHienThiDanhGia (
 Id VARCHAR(20) NOT NULL PRIMARY KEY,
 MaDanhGia VARCHAR(20) NOT NULL REFERENCES dbo.DanhGia(MaDanhGia),
 MaTaiKhoan VARCHAR(20) NOT NULL REFERENCES dbo.TaiKhoan(MaTaiKhoan),
 TrangThaiTruoc VARCHAR(20) NULL, TrangThaiSau VARCHAR(20) NOT NULL,
 LyDo NVARCHAR(500) NOT NULL, ThoiGianUtc DATETIME2 NOT NULL,
 CONSTRAINT CK_LichSuHienThiDanhGia_Status CHECK (TrangThaiSau IN ('CONG_KHAI','AN')),
 CONSTRAINT CK_LichSuHienThiDanhGia_Reason CHECK (LEN(LTRIM(RTRIM(LyDo))) > 0)
);
CREATE INDEX IX_LichSuHienThiDanhGia_ReviewTime ON dbo.LichSuHienThiDanhGia(MaDanhGia,ThoiGianUtc);

COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
