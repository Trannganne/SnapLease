SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.ThietBi', N'U') IS NULL
    THROW 53601, 'Missing dbo.ThietBi; install the reviewed Schema33 package first.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.ThietBi
    WHERE TrangThai NOT IN (
        'SAN_SANG', 'DU_PHONG', 'DANG_GIU', 'DANG_THUE',
        'BAO_TRI', 'HONG', 'NGUNG_KINH_DOANH'))
    THROW 53602, 'Unexpected device status exists; review data before changing the constraint.', 1;

IF EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.ThietBi')
      AND name = N'CK_ThietBi_TrangThai')
    ALTER TABLE dbo.ThietBi DROP CONSTRAINT CK_ThietBi_TrangThai;

ALTER TABLE dbo.ThietBi WITH CHECK ADD CONSTRAINT CK_ThietBi_TrangThai
CHECK (TrangThai IN (
    'SAN_SANG', 'DU_PHONG', 'DANG_GIU', 'DANG_THUE',
    'BAO_TRI', 'HONG', 'NGUNG_KINH_DOANH'));

ALTER TABLE dbo.ThietBi CHECK CONSTRAINT CK_ThietBi_TrangThai;

COMMIT TRANSACTION;

SELECT COUNT(*) AS PhysicalApplicationTableCount
FROM sys.tables
WHERE is_ms_shipped = 0;
