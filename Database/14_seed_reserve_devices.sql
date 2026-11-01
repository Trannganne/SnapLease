SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.ThietBi', N'U') IS NULL
    THROW 53611, 'Missing dbo.ThietBi; install Schema33 before preparing reserve devices.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.ThietBi')
      AND name = N'CK_ThietBi_TrangThai'
      AND definition LIKE N'%DU_PHONG%')
    THROW 53612, 'Apply 13_add_reserve_device_status.sql before preparing reserve devices.', 1;

;WITH Candidate AS (
    SELECT t.MaThietBi,
           ROW_NUMBER() OVER (
               PARTITION BY t.MaCuaHang, t.MaDongMay
               ORDER BY t.MaThietBi DESC) AS ThuTu
    FROM dbo.ThietBi t WITH (UPDLOCK, HOLDLOCK)
    WHERE t.MaThietBi LIKE 'TR33[_]%'
      AND t.TrangThai = 'SAN_SANG'
      AND NOT EXISTS (
          SELECT 1
          FROM dbo.ThietBi reserveDevice
          WHERE reserveDevice.MaCuaHang = t.MaCuaHang
            AND reserveDevice.MaDongMay = t.MaDongMay
            AND reserveDevice.TrangThai = 'DU_PHONG')
)
UPDATE device
SET TrangThai = 'DU_PHONG',
    TinhTrang = N'Dự phòng đã kiểm tra, chỉ cấp khi xử lý sự cố'
FROM dbo.ThietBi device
JOIN Candidate candidate ON candidate.MaThietBi = device.MaThietBi
WHERE candidate.ThuTu = 1;

IF EXISTS (
    SELECT MaCuaHang, MaDongMay
    FROM dbo.ThietBi
    WHERE MaThietBi LIKE 'TR33[_]%'
    GROUP BY MaCuaHang, MaDongMay
    HAVING SUM(CASE WHEN TrangThai = 'DU_PHONG' THEN 1 ELSE 0 END) <> 1)
    THROW 53613, 'Each Schema33 trial branch/model must have exactly one reserve device.', 1;

COMMIT TRANSACTION;

SELECT MaCuaHang,
       MaDongMay,
       COUNT(*) AS TongThietBi,
       SUM(CASE WHEN TrangThai = 'SAN_SANG' THEN 1 ELSE 0 END) AS SanSang,
       SUM(CASE WHEN TrangThai = 'DU_PHONG' THEN 1 ELSE 0 END) AS DuPhong,
       SUM(CASE WHEN TrangThai = 'BAO_TRI' THEN 1 ELSE 0 END) AS BaoTri
FROM dbo.ThietBi
WHERE MaThietBi LIKE 'TR33[_]%'
GROUP BY MaCuaHang, MaDongMay
ORDER BY MaCuaHang, MaDongMay;
