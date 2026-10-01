USE RentalCameraDb20;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF NOT EXISTS (SELECT 1 FROM DongMay WHERE MaDongMay = 'DONG005')
BEGIN
    INSERT INTO DongMay
        (MaDongMay, MaDanhMuc, MaThuongHieu, TenDongMay, MoTa, GiaThueNgay, TienCoc, PhanTramGiamGia)
    VALUES
        ('DONG005','DM001','TH001',N'Canon EOS RP',N'Dòng máy mẫu chưa có ảnh và đánh giá',350000,3500000,0);
END;

IF NOT EXISTS (SELECT 1 FROM ThietBi WHERE MaThietBi = 'TB006')
BEGIN
    INSERT INTO ThietBi
        (MaThietBi, MaDongMay, MaCuaHang, SoSerial, TinhTrang, TrangThai, NgayNhap)
    VALUES
        ('TB006','DONG001','CH002','CR6-0003',N'Tốt','DANG_THUE','2026-04-01');
END;

IF NOT EXISTS (SELECT 1 FROM ThietBi WHERE MaThietBi = 'TB007')
BEGIN
    INSERT INTO ThietBi
        (MaThietBi, MaDongMay, MaCuaHang, SoSerial, TinhTrang, TrangThai, NgayNhap)
    VALUES
        ('TB007','DONG005','CH001','CRP-0001',N'Tốt','SAN_SANG','2026-04-05');
END;

COMMIT TRANSACTION;

SELECT MaDongMay, MaCuaHang, TrangThai
FROM ThietBi
WHERE MaDongMay IN ('DONG001', 'DONG005')
ORDER BY MaDongMay, MaCuaHang, MaThietBi;
GO
