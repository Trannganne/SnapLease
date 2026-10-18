USE RentalCameraDb20;
GO

/*
Du lieu bo sung de test gio hang va danh gia.
- Co the chay lai an toan.
- Ngay thue duoc tinh theo ngay chay script de du lieu gio hang luon con han.
- Khong tao tai khoan/mat khau moi; dung hai khach demo KH001 va KH002.
*/
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @Today DATE = CAST(GETDATE() AS DATE);
DECLARE @CartFrom DATETIME2 = DATEADD(HOUR, 8, CAST(DATEADD(DAY, 7, @Today) AS DATETIME2));
DECLARE @CartTo DATETIME2 = DATEADD(HOUR, 18, CAST(DATEADD(DAY, 10, @Today) AS DATETIME2));
DECLARE @PastFrom DATETIME2 = DATEADD(HOUR, 8, CAST(DATEADD(DAY, -20, @Today) AS DATETIME2));
DECLARE @PastTo DATETIME2 = DATEADD(HOUR, 18, CAST(DATEADD(DAY, -18, @Today) AS DATETIME2));

/* Tang so luong thiet bi kha dung de test so luong trong gio. */
IF NOT EXISTS (SELECT 1 FROM dbo.ThietBi WHERE MaThietBi = 'TBTEST001')
    INSERT dbo.ThietBi
        (MaThietBi, MaDongMay, MaCuaHang, SoSerial, TinhTrang, TrangThai, NgayNhap)
    VALUES
        ('TBTEST001', 'DONG001', 'CH001', 'TEST-R6-001', N'Tốt - dữ liệu kiểm thử', 'SAN_SANG', @Today);

IF NOT EXISTS (SELECT 1 FROM dbo.ThietBi WHERE MaThietBi = 'TBTEST002')
    INSERT dbo.ThietBi
        (MaThietBi, MaDongMay, MaCuaHang, SoSerial, TinhTrang, TrangThai, NgayNhap)
    VALUES
        ('TBTEST002', 'DONG001', 'CH001', 'TEST-R6-002', N'Tốt - dữ liệu kiểm thử', 'SAN_SANG', @Today);

IF NOT EXISTS (SELECT 1 FROM dbo.ThietBi WHERE MaThietBi = 'TBTEST003')
    INSERT dbo.ThietBi
        (MaThietBi, MaDongMay, MaCuaHang, SoSerial, TinhTrang, TrangThai, NgayNhap)
    VALUES
        ('TBTEST003', 'DONG002', 'CH001', 'TEST-A7-001', N'Tốt - dữ liệu kiểm thử', 'SAN_SANG', @Today);

IF NOT EXISTS (SELECT 1 FROM dbo.ThietBi WHERE MaThietBi = 'TBTEST004')
    INSERT dbo.ThietBi
        (MaThietBi, MaDongMay, MaCuaHang, SoSerial, TinhTrang, TrangThai, NgayNhap)
    VALUES
        ('TBTEST004', 'DONG004', 'CH002', 'TEST-Z6-001', N'Tốt - dữ liệu kiểm thử', 'SAN_SANG', @Today);

/* Gio hang KH001: hai dong, hai dong may khac nhau. */
DECLARE @CartKh001 VARCHAR(20) = (
    SELECT TOP (1) MaGioHang
    FROM dbo.GioHang
    WHERE MaKhachThue = 'KH001' AND TrangThai = 'DANG_CHON'
    ORDER BY NgayCapNhat DESC
);

IF @CartKh001 IS NULL
BEGIN
    SET @CartKh001 = 'GHDEMO001';
    IF NOT EXISTS (SELECT 1 FROM dbo.GioHang WHERE MaGioHang = @CartKh001)
        INSERT dbo.GioHang
            (MaGioHang, MaKhachThue, NgayTao, NgayCapNhat, TrangThai)
        VALUES
            (@CartKh001, 'KH001', SYSDATETIME(), SYSDATETIME(), 'DANG_CHON');
END;

IF NOT EXISTS (SELECT 1 FROM dbo.ChiTietGioHang WHERE MaChiTietGioHang = 'CGDEMO001')
    INSERT dbo.ChiTietGioHang
        (MaChiTietGioHang, MaGioHang, MaCuaHang, NguonTao, MaDongMay,
         SoLuong, NgayBatDau, NgayKetThuc, DonGia, TienCoc, ThanhTien)
    VALUES
        ('CGDEMO001', @CartKh001, 'CH001', 'GIO_HANG', 'DONG001',
         2, @CartFrom, @CartTo, 500000, 5000000, 4000000);

IF NOT EXISTS (SELECT 1 FROM dbo.ChiTietGioHang WHERE MaChiTietGioHang = 'CGDEMO002')
    INSERT dbo.ChiTietGioHang
        (MaChiTietGioHang, MaGioHang, MaCuaHang, NguonTao, MaDongMay,
         SoLuong, NgayBatDau, NgayKetThuc, DonGia, TienCoc, ThanhTien)
    VALUES
        ('CGDEMO002', @CartKh001, 'CH001', 'GIO_HANG', 'DONG002',
         1, @CartFrom, @CartTo, 427500, 4500000, 1710000);

UPDATE dbo.ChiTietGioHang
SET NgayBatDau = @CartFrom,
    NgayKetThuc = @CartTo
WHERE MaChiTietGioHang IN ('CGDEMO001', 'CGDEMO002');

UPDATE dbo.GioHang
SET NgayCapNhat = SYSDATETIME()
WHERE MaGioHang = @CartKh001;

/* Dong demo cu CTGH004 co ngay co dinh; dua ve cung khoang test neu van con ton tai. */
UPDATE dbo.ChiTietGioHang
SET NgayBatDau = @CartFrom,
    NgayKetThuc = @CartTo,
    ThanhTien = 2000000
WHERE MaChiTietGioHang = 'CTGH004'
  AND MaGioHang = 'GH003'
  AND NguonTao = 'GIO_HANG';

/* Gio hang KH002: mot dong o chi nhanh khac de test loc chi nhanh. */
DECLARE @CartKh002 VARCHAR(20) = (
    SELECT TOP (1) MaGioHang
    FROM dbo.GioHang
    WHERE MaKhachThue = 'KH002' AND TrangThai = 'DANG_CHON'
    ORDER BY NgayCapNhat DESC
);

IF @CartKh002 IS NULL
BEGIN
    SET @CartKh002 = 'GHDEMO002';
    IF NOT EXISTS (SELECT 1 FROM dbo.GioHang WHERE MaGioHang = @CartKh002)
        INSERT dbo.GioHang
            (MaGioHang, MaKhachThue, NgayTao, NgayCapNhat, TrangThai)
        VALUES
            (@CartKh002, 'KH002', SYSDATETIME(), SYSDATETIME(), 'DANG_CHON');
END;

IF NOT EXISTS (SELECT 1 FROM dbo.ChiTietGioHang WHERE MaChiTietGioHang = 'CGDEMO003')
    INSERT dbo.ChiTietGioHang
        (MaChiTietGioHang, MaGioHang, MaCuaHang, NguonTao, MaDongMay,
         SoLuong, NgayBatDau, NgayKetThuc, DonGia, TienCoc, ThanhTien)
    VALUES
        ('CGDEMO003', @CartKh002, 'CH002', 'GIO_HANG', 'DONG004',
         1, @CartFrom, @CartTo, 470000, 4700000, 1880000);

UPDATE dbo.ChiTietGioHang
SET NgayBatDau = @CartFrom,
    NgayKetThuc = @CartTo
WHERE MaChiTietGioHang = 'CGDEMO003';

UPDATE dbo.GioHang
SET NgayCapNhat = SYSDATETIME()
WHERE MaGioHang = @CartKh002;

/* Hop dong hoan thanh chua co danh gia: KH002 dung de test tao review moi. */
IF NOT EXISTS (SELECT 1 FROM dbo.GioHang WHERE MaGioHang = 'GHREV001')
    INSERT dbo.GioHang
        (MaGioHang, MaKhachThue, NgayTao, NgayCapNhat, TrangThai)
    VALUES
        ('GHREV001', 'KH002', DATEADD(DAY, -22, SYSDATETIME()),
         DATEADD(DAY, -22, SYSDATETIME()), 'DA_CHUYEN_HOP_DONG');

IF NOT EXISTS (SELECT 1 FROM dbo.ChiTietGioHang WHERE MaChiTietGioHang = 'CGREV001')
    INSERT dbo.ChiTietGioHang
        (MaChiTietGioHang, MaGioHang, MaCuaHang, NguonTao, MaDongMay,
         SoLuong, NgayBatDau, NgayKetThuc, DonGia, TienCoc, ThanhTien)
    VALUES
        ('CGREV001', 'GHREV001', 'CH001', 'GIO_HANG', 'DONG002',
         1, @PastFrom, @PastTo, 427500, 4500000, 1282500);

IF NOT EXISTS (SELECT 1 FROM dbo.GiuCho WHERE MaGiuCho = 'GCREV001')
    INSERT dbo.GiuCho
        (MaGiuCho, MaGioHang, MaKhachThue, MaCuaHang, NgayTao, HetHanLuc, TrangThai)
    VALUES
        ('GCREV001', 'GHREV001', 'KH002', 'CH001',
         DATEADD(DAY, -22, SYSDATETIME()), DATEADD(MINUTE, 20, DATEADD(DAY, -22, SYSDATETIME())),
         'DA_CHUYEN_HOP_DONG');

IF NOT EXISTS (SELECT 1 FROM dbo.ChiTietGiuCho WHERE MaChiTietGiuCho = 'GCDREV001')
    INSERT dbo.ChiTietGiuCho
        (MaChiTietGiuCho, MaGiuCho, MaChiTietGioHang, MaDongMay, SoLuong, NgayBatDau, NgayKetThuc)
    VALUES
        ('GCDREV001', 'GCREV001', 'CGREV001', 'DONG002', 1, @PastFrom, @PastTo);

IF NOT EXISTS (SELECT 1 FROM dbo.HopDong WHERE MaHopDong = 'HDREV001')
    INSERT dbo.HopDong
        (MaHopDong, MaGioHang, MaGiuCho, MaKhachThue, MaNhanVien, MaCuaHang,
         NgayTaoHopDong, NgayKy, ThoiGianBanGiao, ThoiGianTraDuKien,
         TongTien, TongTienCoc, HinhThucKy, TrangThai, TepHopDongUrl)
    VALUES
        ('HDREV001', 'GHREV001', 'GCREV001', 'KH002', 'NV001', 'CH001',
         DATEADD(DAY, -22, SYSDATETIME()), DATEADD(DAY, -22, SYSDATETIME()),
         @PastFrom, @PastTo, 1282500, 4500000, 'DIEN_TU', 'HOAN_THANH',
         N'/contracts/demo-review-001.pdf');

IF NOT EXISTS (SELECT 1 FROM dbo.ChiTietHopDong WHERE MaChiTietHopDong = 'CTHDREV001')
    INSERT dbo.ChiTietHopDong
        (MaChiTietHopDong, MaHopDong, MaThietBi, DonGia,
         TinhTrangLucGiao, NgayGiaoThucTe, TinhTrangLucNhan, NgayNhanThucTe, CoHuHong)
    VALUES
        ('CTHDREV001', 'HDREV001', 'TBTEST003', 427500,
         N'Tốt, đầy đủ phụ kiện', @PastFrom, N'Tốt, đầy đủ phụ kiện', @PastTo, 0);

/* Them review cong khai mau de test danh sach/rating. */
IF NOT EXISTS (SELECT 1 FROM dbo.DanhGia WHERE MaDanhGia = 'DGDEMO002')
   AND NOT EXISTS (SELECT 1 FROM dbo.DanhGia WHERE MaChiTietHopDong = 'CTHD002')
BEGIN
    INSERT dbo.DanhGia
        (MaDanhGia, MaChiTietHopDong, MaKhachThue, NhanXet, SoSao,
         NgayDanhGia, TrangThaiKiemDuyet, GhiChuKiemDuyet, NgayKiemDuyet)
    VALUES
        ('DGDEMO002', 'CTHD002', 'KH001',
         N'Ống kính sắc nét, ngoại hình còn mới và phụ kiện đầy đủ.', 4,
         DATEADD(DAY, -17, SYSDATETIME()), 'DA_DUYET', NULL, SYSDATETIME());

    INSERT dbo.DanhGiaDiemNoiBat (MaDanhGia, MaDiemNoiBat) VALUES
        ('DGDEMO002', 'CHAT_LUONG_HINH_ANH_TOT'),
        ('DGDEMO002', 'NGOAI_HINH_CON_MOI'),
        ('DGDEMO002', 'PHU_KIEN_DAY_DU');
END;

COMMIT TRANSACTION;
GO
