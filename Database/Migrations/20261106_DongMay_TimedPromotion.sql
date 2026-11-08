SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() IS NULL
    THROW 53401, 'Khong xac dinh duoc database dich.', 1;

BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.DongMay', N'TGBatDau') IS NULL
    ALTER TABLE dbo.DongMay ADD TGBatDau datetime2 NULL;

IF COL_LENGTH(N'dbo.DongMay', N'TGKetThuc') IS NULL
    ALTER TABLE dbo.DongMay ADD TGKetThuc datetime2 NULL;

EXEC sys.sp_executesql N'
IF EXISTS
(
    SELECT 1
    FROM dbo.DongMay
    WHERE (TGBatDau IS NULL AND TGKetThuc IS NOT NULL)
       OR (TGBatDau IS NOT NULL AND TGKetThuc IS NULL)
       OR (TGBatDau IS NOT NULL AND TGKetThuc <= TGBatDau)
)
    THROW 53402, ''Du lieu khuyen mai hien tai khong hop le; khong them CHECK.'', 1;';

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.DongMay')
      AND name = N'CK_DongMay_ThoiGianGiamGia'
)
BEGIN
    EXEC sys.sp_executesql N'
    ALTER TABLE dbo.DongMay WITH CHECK ADD CONSTRAINT CK_DongMay_ThoiGianGiamGia
        CHECK
        (
            (TGBatDau IS NULL AND TGKetThuc IS NULL)
            OR
            (TGBatDau IS NOT NULL AND TGKetThuc IS NOT NULL AND TGKetThuc > TGBatDau)
        );';
    ALTER TABLE dbo.DongMay CHECK CONSTRAINT CK_DongMay_ThoiGianGiamGia;
END;

COMMIT TRANSACTION;

EXEC sys.sp_executesql N'
SELECT
    DB_NAME() AS DatabaseName,
    COUNT_BIG(*) AS DongMayCount,
    SUM(CASE WHEN TGBatDau IS NOT NULL THEN 1 ELSE 0 END) AS TimedPromotionCount
FROM dbo.DongMay;';
