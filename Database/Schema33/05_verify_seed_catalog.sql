-- READ ONLY; execute only after permission to read SQL metadata. No data rows are selected.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() <> N'RentalCameraDb30_Test'
    THROW 53300, 'Only RentalCameraDb30_Test is permitted by this reviewed trial package.', 1;
IF CONVERT(nvarchar(128),SESSION_CONTEXT(N'Schema33.ExpectedDatabase')) IS NULL
 OR CONVERT(nvarchar(128),SESSION_CONTEXT(N'Schema33.ExpectedDatabase')) <> DB_NAME()
    THROW 53301, 'ExpectedDatabase session guard missing or different.', 1;
IF CONVERT(nvarchar(128),SESSION_CONTEXT(N'Schema33.ExpectedServer')) IS NULL
 OR CONVERT(nvarchar(128),SESSION_CONTEXT(N'Schema33.ExpectedServer')) <> CONVERT(nvarchar(128),SERVERPROPERTY('ServerName'))
    THROW 53302, 'ExpectedServer session guard missing or different.', 1;
IF CONVERT(nvarchar(30),SESSION_CONTEXT(N'Schema33.Environment')) IS NULL
 OR CONVERT(nvarchar(30),SESSION_CONTEXT(N'Schema33.Environment')) <> N'Schema33Trial'
    THROW 53303, 'Trial environment session guard missing.', 1;
IF EXISTS(SELECT MaCuaHang,MaDongMay FROM dbo.ThietBi WHERE MaThietBi LIKE 'TR33[_]%' GROUP BY MaCuaHang,MaDongMay HAVING SUM(CASE WHEN TrangThai='SAN_SANG' THEN 1 ELSE 0 END)<>4 OR SUM(CASE WHEN TrangThai='BAO_TRI' THEN 1 ELSE 0 END)<>1) THROW 53335,'Baseline seed must have4 ready and1maintenance per branch/model; run before workflow fixtures, never repair states automatically.',1;
-- Read only. Catalog rows are synthetic TR33 namespace only.
IF (SELECT COUNT(*) FROM dbo.ThietBi WHERE MaThietBi LIKE 'TR33[_]%')<>90 THROW 53330,'Expected90 synthetic devices.',1;
IF (SELECT COUNT(DISTINCT MaCuaHang) FROM dbo.ThietBi WHERE MaThietBi LIKE 'TR33[_]%')<>3 THROW 53331,'Expected3 branches.',1;
IF (SELECT COUNT(DISTINCT MaDongMay) FROM dbo.ThietBi WHERE MaThietBi LIKE 'TR33[_]%')<>6 THROW 53332,'Expected6 models.',1;
IF EXISTS(SELECT MaCuaHang,MaDongMay FROM dbo.ThietBi WHERE MaThietBi LIKE 'TR33[_]%' GROUP BY MaCuaHang,MaDongMay HAVING COUNT(*)<>5) THROW 53333,'Each branch-model pair must have5 devices.',1;
IF EXISTS(SELECT SoSerial FROM dbo.ThietBi WHERE MaThietBi LIKE 'TR33[_]%' GROUP BY SoSerial HAVING COUNT(*)<>1) THROW 53334,'Duplicate serial.',1;
SELECT MaCuaHang,MaDongMay,COUNT(*) TotalDevices,SUM(CASE WHEN TrangThai='SAN_SANG' THEN 1 ELSE 0 END) ReadyStatus,SUM(CASE WHEN TrangThai='BAO_TRI' THEN 1 ELSE 0 END) MaintenanceStatus FROM dbo.ThietBi WHERE MaThietBi LIKE 'TR33[_]%' GROUP BY MaCuaHang,MaDongMay ORDER BY MaCuaHang,MaDongMay;
-- 4ready/1maintenance applies immediately after baseline seed. Workflow fixtures legitimately change status later.
SELECT N'CATALOG_COUNT_MATCH; RUN_INTERVAL_AVAILABILITY_FIXTURES_SEPARATELY' Result;

-- Baseline installation/catalog verification only. Workflow invariants are in backend/tests/Sql/Schema33.
