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
DECLARE @ExpectedTables TABLE(SchemaName sysname NOT NULL,TableName sysname NOT NULL,PRIMARY KEY(SchemaName,TableName));
INSERT @ExpectedTables(SchemaName,TableName) VALUES
(N'dbo',N'TaiKhoan'),
(N'dbo',N'KhachThue'),
(N'dbo',N'NhanVien'),
(N'dbo',N'GiayToTuyThan'),
(N'dbo',N'DanhMuc'),
(N'dbo',N'ThuongHieu'),
(N'dbo',N'DongMay'),
(N'dbo',N'ThietBi'),
(N'dbo',N'AnhThietBi'),
(N'dbo',N'CuaHang'),
(N'dbo',N'GioHang'),
(N'dbo',N'ChiTietGioHang'),
(N'dbo',N'GiuCho'),
(N'dbo',N'ChiTietGiuCho'),
(N'dbo',N'HopDong'),
(N'dbo',N'ChiTietHopDong'),
(N'dbo',N'PhuLuc'),
(N'dbo',N'XacNhanKyHopDong'),
(N'dbo',N'ThanhToan'),
(N'dbo',N'YeuCauThanhToanVnpay'),
(N'dbo',N'PhieuPhat'),
(N'dbo',N'QuyetToanHopDong'),
(N'dbo',N'PhanBoQuyetToan'),
(N'dbo',N'DanhGia'),
(N'dbo',N'AnhDanhGia'),
(N'dbo',N'AnhBienBan'),
(N'dbo',N'ThongBao'),
(N'dbo',N'FcmDeviceToken'),
(N'dbo',N'NotificationDelivery'),
(N'dbo',N'IdempotencyKey'),
(N'dbo',N'BienBanNhanTra'),
(N'dbo',N'DoiSoatHuyHopDong'),
(N'dbo',N'XacMinhKhachKhongDen');

SELECT SYSUTCDATETIME() CheckedUtc,CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) ServerName,
       DB_NAME() DatabaseName,DATABASEPROPERTYEX(DB_NAME(),'Status') DatabaseStatus,
       DATABASEPROPERTYEX(DB_NAME(),'Collation') DatabaseCollation,@@TRANCOUNT CallerTransactionCount;
SELECT COUNT_BIG(*) UserTableCount FROM sys.tables WHERE is_ms_shipped=0;
SELECT s.name SchemaName,t.name TableName FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id WHERE t.is_ms_shipped=0 ORDER BY s.name,t.name;
SELECT o.type_desc,COUNT_BIG(*) ObjectCount FROM sys.objects o WHERE o.is_ms_shipped=0 GROUP BY o.type_desc;
SELECT COUNT_BIG(*) UserTransactionCount FROM sys.dm_tran_database_transactions d JOIN sys.dm_tran_session_transactions st ON st.transaction_id=d.transaction_id WHERE d.database_id=DB_ID() AND st.is_user_transaction=1;
SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM sys.objects WHERE is_ms_shipped=0) THEN N'EMPTY_READY_FOR_REVIEWED_SCHEMA'
            WHEN NOT EXISTS(SELECT SchemaName,TableName FROM @ExpectedTables EXCEPT SELECT s.name,t.name FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id WHERE t.is_ms_shipped=0)
             AND NOT EXISTS(SELECT s.name,t.name FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id WHERE t.is_ms_shipped=0 EXCEPT SELECT SchemaName,TableName FROM @ExpectedTables)
            THEN N'EXACT_TABLE_NAMES_ONLY_REQUIRES_FULL_METADATA_VERIFY' ELSE N'STOP_UNEXPECTED_SCHEMA' END PreflightClassification;
