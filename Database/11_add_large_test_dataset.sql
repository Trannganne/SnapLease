USE RentalCameraDb20;
GO

/*
Bo du lieu kiem thu mo rong cho dashboard, loc, phan trang va cac luong nghiep vu.

Sau khi nap thanh cong, script bo sung toi thieu:
- 8 khach hang va 8 bo giay to voi nhieu trang thai xac minh.
- 24 thiet bi vat ly voi day du trang thai van hanh.
- 4 gio hang dang chon, 10 gio lich su va 20 dong gio hang.
- 10 hop dong trai rong qua cac trang thai chinh.
- 18 giao dich thanh toan, 6 danh gia, phu luc, phieu phat va thong bao.

Script co the chay lai an toan: moi ban ghi dung ma DEMO rieng va chi duoc chen
khi chua ton tai. Tai khoan du lieu chi dung de hien thi/quan tri; hash mau co y
khong dang nhap duoc. Neu can dang nhap, dung lenh set-password nhu README.
*/
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @Today DATE = CAST(GETDATE() AS DATE);
DECLARE @Now DATETIME2 = SYSDATETIME();

/* -----------------------------------------------------------------
   Khach hang va giay to
----------------------------------------------------------------- */
INSERT dbo.TaiKhoan (MaTaiKhoan, TenDangNhap, MatKhauHash, NgayTao, TrangThai, VaiTro)
SELECT v.MaTaiKhoan, v.TenDangNhap, '$2a$demo_large_dataset',
       DATEADD(DAY, -v.NgayCu, @Now), v.TrangThai, 'KHACH_HANG'
FROM (VALUES
    ('TKD101', 'demo_customer_01', 210, 'HOAT_DONG'),
    ('TKD102', 'demo_customer_02', 180, 'HOAT_DONG'),
    ('TKD103', 'demo_customer_03', 150, 'HOAT_DONG'),
    ('TKD104', 'demo_customer_04', 120, 'HOAT_DONG'),
    ('TKD105', 'demo_customer_05',  90, 'HOAT_DONG'),
    ('TKD106', 'demo_customer_06',  60, 'HOAT_DONG'),
    ('TKD107', 'demo_customer_07',  30, 'HOAT_DONG'),
    ('TKD108', 'demo_customer_08',  10, 'TAM_KHOA')
) v(MaTaiKhoan, TenDangNhap, NgayCu, TrangThai)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.TaiKhoan x
    WHERE x.MaTaiKhoan = v.MaTaiKhoan OR x.TenDangNhap = v.TenDangNhap
);

INSERT dbo.KhachThue
    (MaKhachThue, MaTaiKhoan, HoTen, SoDienThoai, Email, CCCD, DiaChi, NgaySinh,
     GioiTinh, QuocTich, NgayCap, NoiCap, DaXacNhanThongTin)
SELECT v.MaKhachThue, v.MaTaiKhoan, v.HoTen, v.SoDienThoai, v.Email, v.CCCD,
       v.DiaChi, v.NgaySinh, v.GioiTinh, N'Việt Nam', v.NgayCap,
       N'Cục Cảnh sát quản lý hành chính về trật tự xã hội', v.DaXacNhan
FROM (VALUES
    ('KH101','TKD101',N'Phan Minh Khang','0938100101','demo01@snaplease.test','079201000101',N'Quận 1, TP.HCM',CAST('1998-02-14' AS DATE),N'Nam',CAST('2022-03-01' AS DATE),CAST(1 AS BIT)),
    ('KH102','TKD102',N'Võ Ngọc Trâm','0938100102','demo02@snaplease.test','079201000102',N'Quận 3, TP.HCM',CAST('2001-07-22' AS DATE),N'Nữ',CAST('2023-01-12' AS DATE),CAST(1 AS BIT)),
    ('KH103','TKD103',N'Đặng Quốc Bảo','0938100103','demo03@snaplease.test','079201000103',N'Quận 5, TP.HCM',CAST('1997-11-05' AS DATE),N'Nam',CAST('2021-09-20' AS DATE),CAST(1 AS BIT)),
    ('KH104','TKD104',N'Nguyễn Hà My','0938100104','demo04@snaplease.test','079201000104',N'Quận 7, TP.HCM',CAST('2000-04-19' AS DATE),N'Nữ',CAST('2022-06-08' AS DATE),CAST(1 AS BIT)),
    ('KH105','TKD105',N'Lý Hoàng Phúc','0938100105','demo05@snaplease.test','079201000105',N'Bình Thạnh, TP.HCM',CAST('1996-08-30' AS DATE),N'Nam',CAST('2020-12-15' AS DATE),CAST(1 AS BIT)),
    ('KH106','TKD106',N'Trần Thảo Vy','0938100106','demo06@snaplease.test','079201000106',N'Phú Nhuận, TP.HCM',CAST('2002-01-11' AS DATE),N'Nữ',CAST('2023-04-25' AS DATE),CAST(0 AS BIT)),
    ('KH107','TKD107',N'Bùi Anh Tuấn','0938100107','demo07@snaplease.test','079201000107',N'TP. Thủ Đức',CAST('1999-10-09' AS DATE),N'Nam',CAST('2022-08-17' AS DATE),CAST(0 AS BIT)),
    ('KH108','TKD108',N'Đỗ Khánh Linh','0938100108','demo08@snaplease.test','079201000108',N'Gò Vấp, TP.HCM',CAST('2001-12-03' AS DATE),N'Nữ',CAST('2023-02-10' AS DATE),CAST(0 AS BIT))
) v(MaKhachThue, MaTaiKhoan, HoTen, SoDienThoai, Email, CCCD, DiaChi, NgaySinh,
    GioiTinh, NgayCap, DaXacNhan)
WHERE EXISTS (SELECT 1 FROM dbo.TaiKhoan t WHERE t.MaTaiKhoan = v.MaTaiKhoan)
  AND NOT EXISTS (
      SELECT 1 FROM dbo.KhachThue x
      WHERE x.MaKhachThue = v.MaKhachThue
         OR x.MaTaiKhoan = v.MaTaiKhoan
         OR x.SoDienThoai = v.SoDienThoai
         OR x.CCCD = v.CCCD
  );

INSERT dbo.GiayToTuyThan
    (MaGiayTo, MaKhachThue, LoaiGiayTo, SoGiayTo, MatTruocUrl, MatSauUrl,
     NgayTaiLen, TrangThaiXacMinh, GhiChu)
SELECT v.MaGiayTo, v.MaKhachThue, 'CCCD', v.SoGiayTo,
       N'/identity/demo/' + LOWER(v.MaKhachThue) + N'-front.jpg',
       N'/identity/demo/' + LOWER(v.MaKhachThue) + N'-back.jpg',
       DATEADD(DAY, -v.NgayCu, @Now), v.TrangThai, v.GhiChu
FROM (VALUES
    ('GTD101','KH101','079201000101',200,'HOP_LE',CAST(NULL AS NVARCHAR(500))),
    ('GTD102','KH102','079201000102',170,'HOP_LE',CAST(NULL AS NVARCHAR(500))),
    ('GTD103','KH103','079201000103',140,'HOP_LE',CAST(NULL AS NVARCHAR(500))),
    ('GTD104','KH104','079201000104',110,'HOP_LE',CAST(NULL AS NVARCHAR(500))),
    ('GTD105','KH105','079201000105', 80,'HOP_LE',CAST(NULL AS NVARCHAR(500))),
    ('GTD106','KH106','079201000106', 50,'CHO_XAC_MINH',N'Đang chờ nhân viên kiểm tra'),
    ('GTD107','KH107','079201000107', 20,'CHO_XAC_MINH',N'Ảnh mặt sau cần đối chiếu'),
    ('GTD108','KH108','079201000108',  8,'TU_CHOI',N'Ảnh giấy tờ bị mờ')
) v(MaGiayTo, MaKhachThue, SoGiayTo, NgayCu, TrangThai, GhiChu)
WHERE EXISTS (SELECT 1 FROM dbo.KhachThue k WHERE k.MaKhachThue = v.MaKhachThue)
  AND NOT EXISTS (
      SELECT 1 FROM dbo.GiayToTuyThan x
      WHERE x.MaGiayTo = v.MaGiayTo OR x.SoGiayTo = v.SoGiayTo
  );

/* -----------------------------------------------------------------
   Kho thiet bi: 24 ban ghi trai rong day du trang thai
----------------------------------------------------------------- */
INSERT dbo.ThietBi
    (MaThietBi, MaDongMay, MaCuaHang, SoSerial, TinhTrang, TrangThai, NgayNhap)
SELECT v.MaThietBi, v.MaDongMay, v.MaCuaHang, v.SoSerial,
       v.TinhTrang, v.TrangThai, DATEADD(DAY, -v.NgayCu, @Today)
FROM (VALUES
    ('TBDEMO101','DONG001','CH001','DEMO-R6-101',N'Mới, đầy đủ pin và nắp',                 'SAN_SANG',240),
    ('TBDEMO102','DONG001','CH001','DEMO-R6-102',N'Tốt, xước rất nhẹ đáy máy',             'SAN_SANG',220),
    ('TBDEMO103','DONG001','CH001','DEMO-R6-103',N'Tốt, cảm biến sạch',                    'DANG_THUE',200),
    ('TBDEMO104','DONG001','CH002','DEMO-R6-104',N'Tốt, đầy đủ phụ kiện',                  'SAN_SANG',180),
    ('TBDEMO105','DONG001','CH002','DEMO-R6-105',N'Đang vệ sinh cảm biến',                 'BAO_TRI',160),
    ('TBDEMO106','DONG002','CH001','DEMO-A7-106',N'Mới, ngoại hình đẹp',                   'SAN_SANG',230),
    ('TBDEMO107','DONG002','CH001','DEMO-A7-107',N'Tốt, pin còn 92%',                      'SAN_SANG',210),
    ('TBDEMO108','DONG002','CH001','DEMO-A7-108',N'Tốt, đầy đủ dây đeo',                   'DANG_GIU',190),
    ('TBDEMO109','DONG002','CH002','DEMO-A7-109',N'Tốt, hoạt động ổn định',                'DANG_THUE',170),
    ('TBDEMO110','DONG002','CH002','DEMO-A7-110',N'Lỗi màn hình lật',                      'HONG',150),
    ('TBDEMO111','DONG003','CH001','DEMO-RF24-111',N'Kính trong, không mốc',               'SAN_SANG',250),
    ('TBDEMO112','DONG003','CH001','DEMO-RF24-112',N'Tốt, vòng zoom mượt',                 'SAN_SANG',225),
    ('TBDEMO113','DONG003','CH001','DEMO-RF24-113',N'Đang cân chỉnh vòng nét',             'BAO_TRI',205),
    ('TBDEMO114','DONG003','CH002','DEMO-RF24-114',N'Kính trong, đầy đủ hai nắp',          'SAN_SANG',185),
    ('TBDEMO115','DONG003','CH002','DEMO-RF24-115',N'Tốt, hoạt động ổn định',              'DANG_THUE',165),
    ('TBDEMO116','DONG004','CH001','DEMO-Z6-116',N'Tốt, pin còn 95%',                      'SAN_SANG',235),
    ('TBDEMO117','DONG004','CH001','DEMO-Z6-117',N'Tốt, cảm biến sạch',                    'SAN_SANG',215),
    ('TBDEMO118','DONG004','CH002','DEMO-Z6-118',N'Tốt, ngoại hình đẹp',                   'SAN_SANG',195),
    ('TBDEMO119','DONG004','CH002','DEMO-Z6-119',N'Tốt, đầy đủ phụ kiện',                  'DANG_THUE',175),
    ('TBDEMO120','DONG004','CH002','DEMO-Z6-120',N'Đang thay cao su tay cầm',              'BAO_TRI',155),
    ('TBDEMO121','DONG005','CH001','DEMO-RP-121',N'Tốt, phù hợp người mới',                'SAN_SANG',140),
    ('TBDEMO122','DONG005','CH001','DEMO-RP-122',N'Tốt, ít sử dụng',                       'SAN_SANG',120),
    ('TBDEMO123','DONG005','CH002','DEMO-RP-123',N'Tốt, đầy đủ pin sạc',                   'SAN_SANG',100),
    ('TBDEMO124','DONG005','CH002','DEMO-RP-124',N'Ngừng kinh doanh để thanh lý',          'NGUNG_KINH_DOANH',80)
) v(MaThietBi, MaDongMay, MaCuaHang, SoSerial, TinhTrang, TrangThai, NgayCu)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.ThietBi x
    WHERE x.MaThietBi = v.MaThietBi OR x.SoSerial = v.SoSerial
);

/* -----------------------------------------------------------------
   Bon gio hang dang chon, moi gio co nhieu dong va chi nhanh
----------------------------------------------------------------- */
INSERT dbo.GioHang (MaGioHang, MaKhachThue, NgayTao, NgayCapNhat, TrangThai)
SELECT v.MaGioHang, v.MaKhachThue, DATEADD(DAY, -v.NgayCu, @Now), @Now, 'DANG_CHON'
FROM (VALUES
    ('GHLARGE101','KH101',3),
    ('GHLARGE102','KH102',2),
    ('GHLARGE103','KH103',1),
    ('GHLARGE104','KH104',0)
) v(MaGioHang, MaKhachThue, NgayCu)
WHERE EXISTS (SELECT 1 FROM dbo.KhachThue k WHERE k.MaKhachThue = v.MaKhachThue)
  AND NOT EXISTS (SELECT 1 FROM dbo.GioHang x WHERE x.MaGioHang = v.MaGioHang);

INSERT dbo.ChiTietGioHang
    (MaChiTietGioHang, MaGioHang, MaCuaHang, NguonTao, MaDongMay,
     SoLuong, NgayBatDau, NgayKetThuc, DonGia, TienCoc, ThanhTien)
SELECT v.MaChiTiet, v.MaGioHang, v.MaCuaHang, 'GIO_HANG', v.MaDongMay, v.SoLuong,
       DATEADD(HOUR, 8, CAST(DATEADD(DAY, v.BatDauSau, @Today) AS DATETIME2)),
       DATEADD(HOUR, 18, CAST(DATEADD(DAY, v.KetThucSau, @Today) AS DATETIME2)),
       v.DonGia, v.TienCoc, v.ThanhTien
FROM (VALUES
    ('CGLARGE101','GHLARGE101','CH001','DONG001',2, 5, 7,CAST(500000 AS DECIMAL(18,2)),CAST(5000000 AS DECIMAL(18,2)),CAST(3000000 AS DECIMAL(18,2))),
    ('CGLARGE102','GHLARGE101','CH001','DONG003',1, 5, 7,300000,3000000,900000),
    ('CGLARGE103','GHLARGE101','CH002','DONG004',1,10,12,470000,4700000,1410000),
    ('CGLARGE104','GHLARGE102','CH001','DONG002',1, 3, 6,427500,4500000,1710000),
    ('CGLARGE105','GHLARGE102','CH002','DONG005',2, 8, 9,350000,3500000,1400000),
    ('CGLARGE106','GHLARGE103','CH002','DONG001',1,14,18,500000,5000000,2500000),
    ('CGLARGE107','GHLARGE103','CH002','DONG003',1,14,18,300000,3000000,1500000),
    ('CGLARGE108','GHLARGE104','CH001','DONG004',1, 2, 2,470000,4700000,470000),
    ('CGLARGE109','GHLARGE104','CH001','DONG002',3,20,23,427500,4500000,5130000),
    ('CGLARGE110','GHLARGE104','CH002','DONG005',1,25,30,350000,3500000,2100000)
) v(MaChiTiet, MaGioHang, MaCuaHang, MaDongMay, SoLuong, BatDauSau, KetThucSau,
    DonGia, TienCoc, ThanhTien)
WHERE EXISTS (SELECT 1 FROM dbo.GioHang g WHERE g.MaGioHang = v.MaGioHang)
  AND NOT EXISTS (SELECT 1 FROM dbo.ChiTietGioHang x WHERE x.MaChiTietGioHang = v.MaChiTiet);

/* Dong CGLARGE108 la thue trong ngay: 08:00 den 18:00 cung ngay. */
UPDATE dbo.ChiTietGioHang
SET NgayKetThuc = DATEADD(HOUR, 18, CAST(DATEADD(DAY, 2, @Today) AS DATETIME2))
WHERE MaChiTietGioHang = 'CGLARGE108';

/* -----------------------------------------------------------------
   Muoi ho so lich su lam nen cho hop dong va bao cao
----------------------------------------------------------------- */
INSERT dbo.GioHang (MaGioHang, MaKhachThue, NgayTao, NgayCapNhat, TrangThai)
SELECT v.MaGioHang, v.MaKhachThue, DATEADD(DAY, v.NgayTao, @Now),
       DATEADD(DAY, v.NgayTao, @Now), 'DA_CHUYEN_HOP_DONG'
FROM (VALUES
    ('GHIST101','KH101',-95),('GHIST102','KH102',-80),
    ('GHIST103','KH103',-65),('GHIST104','KH104',-50),
    ('GHIST105','KH105',-35),('GHIST106','KH106',-20),
    ('GHIST107','KH107', -5),('GHIST108','KH101', -7),
    ('GHIST109','KH102', -2),('GHIST110','KH103', -1)
) v(MaGioHang, MaKhachThue, NgayTao)
WHERE EXISTS (SELECT 1 FROM dbo.KhachThue k WHERE k.MaKhachThue = v.MaKhachThue)
  AND NOT EXISTS (SELECT 1 FROM dbo.GioHang x WHERE x.MaGioHang = v.MaGioHang);

INSERT dbo.ChiTietGioHang
    (MaChiTietGioHang, MaGioHang, MaCuaHang, NguonTao, MaDongMay,
     SoLuong, NgayBatDau, NgayKetThuc, DonGia, TienCoc, ThanhTien)
SELECT v.MaChiTiet, v.MaGioHang, v.MaCuaHang, 'GIO_HANG', v.MaDongMay, 1,
       DATEADD(HOUR, 8, CAST(DATEADD(DAY, v.BatDau, @Today) AS DATETIME2)),
       DATEADD(HOUR, 18, CAST(DATEADD(DAY, v.KetThuc, @Today) AS DATETIME2)),
       v.DonGia, v.TienCoc, v.ThanhTien
FROM (VALUES
    ('CGHIST101','GHIST101','CH001','DONG001',-92,-90,CAST(500000 AS DECIMAL(18,2)),CAST(5000000 AS DECIMAL(18,2)),CAST(1500000 AS DECIMAL(18,2))),
    ('CGHIST102','GHIST102','CH001','DONG002',-77,-75,427500,4500000,1282500),
    ('CGHIST103','GHIST103','CH002','DONG004',-62,-60,470000,4700000,1410000),
    ('CGHIST104','GHIST104','CH001','DONG003',-47,-45,300000,3000000,900000),
    ('CGHIST105','GHIST105','CH002','DONG001',-32,-30,500000,5000000,1500000),
    ('CGHIST106','GHIST106','CH002','DONG005',-17,-15,350000,3500000,1050000),
    ('CGHIST107','GHIST107','CH001','DONG001', -1,  2,500000,5000000,2000000),
    ('CGHIST108','GHIST108','CH002','DONG002', -3, -1,427500,4500000,1282500),
    ('CGHIST109','GHIST109','CH001','DONG004',  2,  5,470000,4700000,1880000),
    ('CGHIST110','GHIST110','CH002','DONG003',  7,  9,300000,3000000,900000)
) v(MaChiTiet, MaGioHang, MaCuaHang, MaDongMay, BatDau, KetThuc,
    DonGia, TienCoc, ThanhTien)
WHERE EXISTS (SELECT 1 FROM dbo.GioHang g WHERE g.MaGioHang = v.MaGioHang)
  AND NOT EXISTS (SELECT 1 FROM dbo.ChiTietGioHang x WHERE x.MaChiTietGioHang = v.MaChiTiet);

INSERT dbo.GiuCho
    (MaGiuCho, MaGioHang, MaKhachThue, MaCuaHang, NgayTao, HetHanLuc, TrangThai)
SELECT v.MaGiuCho, v.MaGioHang, v.MaKhachThue, v.MaCuaHang,
       DATEADD(DAY, v.NgayTao, @Now), DATEADD(MINUTE, 20, DATEADD(DAY, v.NgayTao, @Now)),
       v.TrangThai
FROM (VALUES
    ('GCHIST101','GHIST101','KH101','CH001',-95,'DA_CHUYEN_HOP_DONG'),
    ('GCHIST102','GHIST102','KH102','CH001',-80,'DA_CHUYEN_HOP_DONG'),
    ('GCHIST103','GHIST103','KH103','CH002',-65,'DA_CHUYEN_HOP_DONG'),
    ('GCHIST104','GHIST104','KH104','CH001',-50,'DA_CHUYEN_HOP_DONG'),
    ('GCHIST105','GHIST105','KH105','CH002',-35,'DA_CHUYEN_HOP_DONG'),
    ('GCHIST106','GHIST106','KH106','CH002',-20,'DA_CHUYEN_HOP_DONG'),
    ('GCHIST107','GHIST107','KH107','CH001', -5,'DA_CHUYEN_HOP_DONG'),
    ('GCHIST108','GHIST108','KH101','CH002', -7,'DA_CHUYEN_HOP_DONG'),
    ('GCHIST109','GHIST109','KH102','CH001', -2,'DA_CHUYEN_HOP_DONG'),
    ('GCHIST110','GHIST110','KH103','CH002', -1,'DA_HUY')
) v(MaGiuCho, MaGioHang, MaKhachThue, MaCuaHang, NgayTao, TrangThai)
WHERE EXISTS (SELECT 1 FROM dbo.GioHang g WHERE g.MaGioHang = v.MaGioHang)
  AND NOT EXISTS (SELECT 1 FROM dbo.GiuCho x WHERE x.MaGiuCho = v.MaGiuCho);

INSERT dbo.ChiTietGiuCho
    (MaChiTietGiuCho, MaGiuCho, MaChiTietGioHang, MaDongMay, SoLuong, NgayBatDau, NgayKetThuc)
SELECT v.MaChiTietGiu, v.MaGiuCho, v.MaChiTietGio, v.MaDongMay, 1,
       DATEADD(HOUR, 8, CAST(DATEADD(DAY, v.BatDau, @Today) AS DATETIME2)),
       DATEADD(HOUR, 18, CAST(DATEADD(DAY, v.KetThuc, @Today) AS DATETIME2))
FROM (VALUES
    ('CDHIST101','GCHIST101','CGHIST101','DONG001',-92,-90),
    ('CDHIST102','GCHIST102','CGHIST102','DONG002',-77,-75),
    ('CDHIST103','GCHIST103','CGHIST103','DONG004',-62,-60),
    ('CDHIST104','GCHIST104','CGHIST104','DONG003',-47,-45),
    ('CDHIST105','GCHIST105','CGHIST105','DONG001',-32,-30),
    ('CDHIST106','GCHIST106','CGHIST106','DONG005',-17,-15),
    ('CDHIST107','GCHIST107','CGHIST107','DONG001', -1,  2),
    ('CDHIST108','GCHIST108','CGHIST108','DONG002', -3, -1),
    ('CDHIST109','GCHIST109','CGHIST109','DONG004',  2,  5),
    ('CDHIST110','GCHIST110','CGHIST110','DONG003',  7,  9)
) v(MaChiTietGiu, MaGiuCho, MaChiTietGio, MaDongMay, BatDau, KetThuc)
WHERE EXISTS (SELECT 1 FROM dbo.GiuCho g WHERE g.MaGiuCho = v.MaGiuCho)
  AND NOT EXISTS (SELECT 1 FROM dbo.ChiTietGiuCho x WHERE x.MaChiTietGiuCho = v.MaChiTietGiu);

INSERT dbo.HopDong
    (MaHopDong, MaGioHang, MaGiuCho, MaKhachThue, MaNhanVien, MaCuaHang,
     NgayTaoHopDong, NgayKy, ThoiGianBanGiao, ThoiGianTraDuKien,
     TongTien, TongTienCoc, HinhThucKy, TrangThai, TepHopDongUrl,
     DaDongYDieuKhoan, PhienBanDieuKhoan)
SELECT v.MaHopDong, v.MaGioHang, v.MaGiuCho, v.MaKhachThue, v.MaNhanVien, v.MaCuaHang,
       DATEADD(DAY, v.NgayTao, @Now),
       CASE WHEN v.TrangThai = 'DA_HUY' THEN NULL ELSE DATEADD(HOUR, 1, DATEADD(DAY, v.NgayTao, @Now)) END,
       DATEADD(HOUR, 8, CAST(DATEADD(DAY, v.BatDau, @Today) AS DATETIME2)),
       DATEADD(HOUR, 18, CAST(DATEADD(DAY, v.KetThuc, @Today) AS DATETIME2)),
       v.TongTien, v.TienCoc,
       CASE WHEN v.TrangThai = 'DA_HUY' THEN NULL ELSE v.HinhThucKy END,
       v.TrangThai, N'/contracts/demo/' + LOWER(v.MaHopDong) + N'.pdf',
       CASE WHEN v.TrangThai = 'DA_HUY' THEN 0 ELSE 1 END,
       CASE WHEN v.TrangThai = 'DA_HUY' THEN NULL ELSE '2026.1' END
FROM (VALUES
    ('HDBULK101','GHIST101','GCHIST101','KH101','NV001','CH001',-95,-92,-90,CAST(1500000 AS DECIMAL(18,2)),CAST(5000000 AS DECIMAL(18,2)),'DIEN_TU','HOAN_THANH'),
    ('HDBULK102','GHIST102','GCHIST102','KH102','NV001','CH001',-80,-77,-75,1282500,4500000,'BAN_GIAY','HOAN_THANH'),
    ('HDBULK103','GHIST103','GCHIST103','KH103','NV002','CH002',-65,-62,-60,1410000,4700000,'MAN_HINH','HOAN_THANH'),
    ('HDBULK104','GHIST104','GCHIST104','KH104','NV001','CH001',-50,-47,-45, 900000,3000000,'DIEN_TU','HOAN_THANH'),
    ('HDBULK105','GHIST105','GCHIST105','KH105','NV002','CH002',-35,-32,-30,1500000,5000000,'DIEN_TU','HOAN_THANH'),
    ('HDBULK106','GHIST106','GCHIST106','KH106','NV002','CH002',-20,-17,-15,1050000,3500000,'BAN_GIAY','HOAN_THANH'),
    ('HDBULK107','GHIST107','GCHIST107','KH107','NV001','CH001', -5, -1,  2,2000000,5000000,'DIEN_TU','DANG_THUE'),
    ('HDBULK108','GHIST108','GCHIST108','KH101','NV002','CH002', -7, -3, -1,1282500,4500000,'MAN_HINH','CHO_HOAN_TRA'),
    ('HDBULK109','GHIST109','GCHIST109','KH102','NV001','CH001', -2,  2,  5,1880000,4700000,'DIEN_TU','CHO_BAN_GIAO'),
    ('HDBULK110','GHIST110','GCHIST110','KH103','NV002','CH002', -1,  7,  9, 900000,3000000,'DIEN_TU','DA_HUY')
) v(MaHopDong, MaGioHang, MaGiuCho, MaKhachThue, MaNhanVien, MaCuaHang,
    NgayTao, BatDau, KetThuc, TongTien, TienCoc, HinhThucKy, TrangThai)
WHERE EXISTS (SELECT 1 FROM dbo.GiuCho g WHERE g.MaGiuCho = v.MaGiuCho)
  AND NOT EXISTS (SELECT 1 FROM dbo.HopDong x WHERE x.MaHopDong = v.MaHopDong);

INSERT dbo.ChiTietHopDong
    (MaChiTietHopDong, MaHopDong, MaThietBi, DonGia,
     TinhTrangLucGiao, NgayGiaoThucTe, TinhTrangLucNhan, NgayNhanThucTe, CoHuHong)
SELECT v.MaChiTiet, v.MaHopDong, v.MaThietBi, v.DonGia,
       CASE WHEN v.TrangThai IN ('CHO_BAN_GIAO','DA_HUY') THEN NULL ELSE N'Tốt, đầy đủ phụ kiện' END,
       CASE WHEN v.TrangThai IN ('CHO_BAN_GIAO','DA_HUY') THEN NULL
            ELSE DATEADD(HOUR, 8, CAST(DATEADD(DAY, v.BatDau, @Today) AS DATETIME2)) END,
       CASE WHEN v.TrangThai = 'HOAN_THANH' THEN v.TinhTrangNhan ELSE NULL END,
       CASE WHEN v.TrangThai = 'HOAN_THANH'
            THEN DATEADD(HOUR, 18, CAST(DATEADD(DAY, v.KetThuc, @Today) AS DATETIME2)) END,
       v.CoHuHong
FROM (VALUES
    ('CTBULK101','HDBULK101','TBDEMO101',CAST(500000 AS DECIMAL(18,2)),-92,-90,'HOAN_THANH',N'Tốt, đầy đủ phụ kiện',CAST(0 AS BIT)),
    ('CTBULK102','HDBULK102','TBDEMO106',427500,-77,-75,'HOAN_THANH',N'Tốt, pin còn tốt',0),
    ('CTBULK103','HDBULK103','TBDEMO118',470000,-62,-60,'HOAN_THANH',N'Tốt, xước nhẹ thân máy',1),
    ('CTBULK104','HDBULK104','TBDEMO111',300000,-47,-45,'HOAN_THANH',N'Tốt, đủ hai nắp',0),
    ('CTBULK105','HDBULK105','TBDEMO104',500000,-32,-30,'HOAN_THANH',N'Tốt, đầy đủ phụ kiện',0),
    ('CTBULK106','HDBULK106','TBDEMO123',350000,-17,-15,'HOAN_THANH',N'Tốt, pin còn 88%',0),
    ('CTBULK107','HDBULK107','TBDEMO103',500000, -1,  2,'DANG_THUE',CAST(NULL AS NVARCHAR(500)),0),
    ('CTBULK108','HDBULK108','TBDEMO109',427500, -3, -1,'CHO_HOAN_TRA',CAST(NULL AS NVARCHAR(500)),0),
    ('CTBULK109','HDBULK109','TBDEMO116',470000,  2,  5,'CHO_BAN_GIAO',CAST(NULL AS NVARCHAR(500)),0),
    ('CTBULK110','HDBULK110','TBDEMO114',300000,  7,  9,'DA_HUY',CAST(NULL AS NVARCHAR(500)),0)
) v(MaChiTiet, MaHopDong, MaThietBi, DonGia, BatDau, KetThuc, TrangThai, TinhTrangNhan, CoHuHong)
WHERE EXISTS (SELECT 1 FROM dbo.HopDong h WHERE h.MaHopDong = v.MaHopDong)
  AND NOT EXISTS (SELECT 1 FROM dbo.ChiTietHopDong x WHERE x.MaChiTietHopDong = v.MaChiTiet);

/* -----------------------------------------------------------------
   Thanh toan, phu luc, phieu phat va danh gia
----------------------------------------------------------------- */
INSERT dbo.ThanhToan
    (MaThanhToan, MaHopDong, SoTien, LoaiThanhToan, PhuongThuc,
     MaGiaoDich, ThoiGian, TrangThai, NoiDungChuyenKhoan)
SELECT v.MaThanhToan, v.MaHopDong, v.SoTien, v.Loai, v.PhuongThuc,
       'DEMO-TXN-' + v.MaThanhToan, DATEADD(DAY, v.Ngay, @Now), v.TrangThai,
       N'Dữ liệu kiểm thử ' + v.MaHopDong
FROM (VALUES
    ('TTB101A','HDBULK101',CAST(5000000 AS DECIMAL(18,2)),'TIEN_COC','CHUYEN_KHOAN',-95,'THANH_CONG'),
    ('TTB101B','HDBULK101',1500000,'TIEN_THUE','VI_DIEN_TU',-92,'THANH_CONG'),
    ('TTB102A','HDBULK102',4500000,'TIEN_COC','TIEN_MAT',-80,'THANH_CONG'),
    ('TTB102B','HDBULK102',1282500,'TIEN_THUE','TIEN_MAT',-77,'THANH_CONG'),
    ('TTB103A','HDBULK103',4700000,'TIEN_COC','CHUYEN_KHOAN',-65,'THANH_CONG'),
    ('TTB103B','HDBULK103',1410000,'TIEN_THUE','CHUYEN_KHOAN',-62,'THANH_CONG'),
    ('TTB104A','HDBULK104',3000000,'TIEN_COC','VI_DIEN_TU',-50,'THANH_CONG'),
    ('TTB104B','HDBULK104', 900000,'TIEN_THUE','VI_DIEN_TU',-47,'THANH_CONG'),
    ('TTB105A','HDBULK105',5000000,'TIEN_COC','CHUYEN_KHOAN',-35,'THANH_CONG'),
    ('TTB105B','HDBULK105',1500000,'TIEN_THUE','TIEN_MAT',-32,'THANH_CONG'),
    ('TTB106A','HDBULK106',3500000,'TIEN_COC','TIEN_MAT',-20,'THANH_CONG'),
    ('TTB106B','HDBULK106',1050000,'TIEN_THUE','TIEN_MAT',-17,'THANH_CONG'),
    ('TTB107A','HDBULK107',5000000,'TIEN_COC','CHUYEN_KHOAN', -5,'THANH_CONG'),
    ('TTB107B','HDBULK107',2000000,'TIEN_THUE','CHUYEN_KHOAN', -1,'THANH_CONG'),
    ('TTB108A','HDBULK108',4500000,'TIEN_COC','VI_DIEN_TU', -7,'THANH_CONG'),
    ('TTB108B','HDBULK108',1282500,'TIEN_THUE','VI_DIEN_TU', -3,'THANH_CONG'),
    ('TTB109A','HDBULK109',4700000,'TIEN_COC','CHUYEN_KHOAN', -2,'CHO_THANH_TOAN'),
    ('TTB110A','HDBULK110',3000000,'TIEN_COC','VI_DIEN_TU', -1,'THAT_BAI')
) v(MaThanhToan, MaHopDong, SoTien, Loai, PhuongThuc, Ngay, TrangThai)
WHERE EXISTS (SELECT 1 FROM dbo.HopDong h WHERE h.MaHopDong = v.MaHopDong)
  AND NOT EXISTS (SELECT 1 FROM dbo.ThanhToan x WHERE x.MaThanhToan = v.MaThanhToan);

IF NOT EXISTS (SELECT 1 FROM dbo.PhuLuc WHERE MaPhuLuc = 'PLBULK101')
    INSERT dbo.PhuLuc
        (MaPhuLuc, MaHopDong, NgayLap, ThoiHanTraMoi, ChiPhiPhatSinh,
         TienCocBoSung, GhiChu, LyDoGiaHan, TrangThai)
    VALUES
        ('PLBULK101','HDBULK107',DATEADD(DAY,-1,@Now),DATEADD(HOUR,18,CAST(DATEADD(DAY,3,@Today) AS DATETIME2)),
         500000,0,N'Gia hạn thêm một ngày',N'Khách cần thêm thời gian quay', 'DA_XAC_NHAN');

IF NOT EXISTS (SELECT 1 FROM dbo.PhieuPhat WHERE MaPhieuPhat = 'PPBULK101')
    INSERT dbo.PhieuPhat
        (MaPhieuPhat, MaChiTietHopDong, LoaiViPham, SoTien, MoTa, NgayLap, TrangThai)
    VALUES
        ('PPBULK101','CTBULK103','HU_HONG',350000,N'Xước nhẹ thân máy khi hoàn trả',DATEADD(DAY,-60,@Now),'DA_THANH_TOAN');

IF NOT EXISTS (SELECT 1 FROM dbo.PhieuPhat WHERE MaPhieuPhat = 'PPBULK102')
    INSERT dbo.PhieuPhat
        (MaPhieuPhat, MaChiTietHopDong, LoaiViPham, SoTien, MoTa, NgayLap, TrangThai)
    VALUES
        ('PPBULK102','CTBULK108','TRA_TRE',427500,N'Quá thời gian trả dự kiến một ngày',@Now,'CHO_XAC_NHAN');

INSERT dbo.DanhGia
    (MaDanhGia, MaChiTietHopDong, MaKhachThue, NhanXet, SoSao,
     NgayDanhGia, TrangThaiKiemDuyet, GhiChuKiemDuyet, NgayKiemDuyet)
SELECT v.MaDanhGia, v.MaChiTiet, v.MaKhachThue, v.NhanXet, v.SoSao,
       DATEADD(DAY, v.Ngay, @Now), v.TrangThai, v.GhiChu, DATEADD(DAY, v.Ngay, @Now)
FROM (VALUES
    ('DGBULK101','CTBULK101','KH101',N'Máy rất mới, giao nhận nhanh và nhân viên hỗ trợ nhiệt tình.',CAST(5 AS TINYINT),-89,'DA_DUYET',CAST(NULL AS NVARCHAR(500))),
    ('DGBULK102','CTBULK102','KH102',N'Chất lượng hình ảnh tốt, pin đủ dùng cho cả buổi chụp.',4,-74,'DA_DUYET',CAST(NULL AS NVARCHAR(500))),
    ('DGBULK103','CTBULK103','KH103',N'Máy hoạt động ổn định nhưng ngoại hình có vài vết xước nhẹ.',3,-59,'DA_DUYET',CAST(NULL AS NVARCHAR(500))),
    ('DGBULK104','CTBULK104','KH104',N'Ống kính sắc nét, vòng zoom mượt và đủ phụ kiện.',5,-44,'DA_DUYET',CAST(NULL AS NVARCHAR(500))),
    ('DGBULK105','CTBULK105','KH105',N'Thiết bị dùng được nhưng pin xuống nhanh hơn mong đợi.',2,-29,'DA_DUYET',CAST(NULL AS NVARCHAR(500))),
    ('DGBULK106','CTBULK106','KH106',N'Nội dung đánh giá mẫu đã bị ẩn để kiểm thử chức năng quản trị.',1,-14,'TU_CHOI',N'Ẩn dữ liệu mẫu để kiểm thử')
) v(MaDanhGia, MaChiTiet, MaKhachThue, NhanXet, SoSao, Ngay, TrangThai, GhiChu)
WHERE EXISTS (SELECT 1 FROM dbo.ChiTietHopDong c WHERE c.MaChiTietHopDong = v.MaChiTiet)
  AND NOT EXISTS (
      SELECT 1 FROM dbo.DanhGia x
      WHERE x.MaDanhGia = v.MaDanhGia OR x.MaChiTietHopDong = v.MaChiTiet
  );

INSERT dbo.DanhGiaDiemNoiBat (MaDanhGia, MaDiemNoiBat)
SELECT v.MaDanhGia, v.MaDiem
FROM (VALUES
    ('DGBULK101','CHAT_LUONG_HINH_ANH_TOT'),('DGBULK101','NGOAI_HINH_CON_MOI'),('DGBULK101','PHU_KIEN_DAY_DU'),
    ('DGBULK102','CHAT_LUONG_HINH_ANH_TOT'),('DGBULK102','PIN_SU_DUNG_TOT'),
    ('DGBULK103','THIET_BI_HOAT_DONG_ON_DINH'),('DGBULK103','DE_SU_DUNG'),
    ('DGBULK104','CHAT_LUONG_HINH_ANH_TOT'),('DGBULK104','PHU_KIEN_DAY_DU'),
    ('DGBULK105','DE_SU_DUNG'),('DGBULK106','NGOAI_HINH_CON_MOI')
) v(MaDanhGia, MaDiem)
WHERE EXISTS (SELECT 1 FROM dbo.DanhGia d WHERE d.MaDanhGia = v.MaDanhGia)
  AND NOT EXISTS (
      SELECT 1 FROM dbo.DanhGiaDiemNoiBat x
      WHERE x.MaDanhGia = v.MaDanhGia AND x.MaDiemNoiBat = v.MaDiem
  );

INSERT dbo.AnhDanhGia
    (MaAnhDanhGia, MaDanhGia, DuongDanAnh, PublicId, ThuTu, NgayTao)
SELECT v.MaAnh, v.MaDanhGia,
       N'https://res.cloudinary.com/rqdym8rq/image/upload/reviews/demo/' + LOWER(v.MaAnh) + N'.jpg',
       N'reviews/demo/' + LOWER(v.MaAnh), v.ThuTu, @Now
FROM (VALUES
    ('ADGBULK101','DGBULK101',CAST(1 AS TINYINT)),
    ('ADGBULK102','DGBULK101',CAST(2 AS TINYINT)),
    ('ADGBULK103','DGBULK102',CAST(1 AS TINYINT)),
    ('ADGBULK104','DGBULK104',CAST(1 AS TINYINT))
) v(MaAnh, MaDanhGia, ThuTu)
WHERE EXISTS (SELECT 1 FROM dbo.DanhGia d WHERE d.MaDanhGia = v.MaDanhGia)
  AND NOT EXISTS (
      SELECT 1 FROM dbo.AnhDanhGia x
      WHERE x.MaAnhDanhGia = v.MaAnh
         OR (x.MaDanhGia = v.MaDanhGia AND x.ThuTu = v.ThuTu)
  );

/* -----------------------------------------------------------------
   Thong bao de test loc da doc/chua doc va phan trang
----------------------------------------------------------------- */
INSERT dbo.ThongBao
    (MaThongBao, MaTaiKhoan, Loai, TieuDe, NoiDung, ThoiGianGui, DaDoc)
SELECT v.MaThongBao, v.MaTaiKhoan, v.Loai, v.TieuDe, v.NoiDung,
       DATEADD(HOUR, -v.GioCu, @Now), v.DaDoc
FROM (VALUES
    ('TBBULK101','TKD101','HOP_DONG',N'Hợp đồng hoàn thành',N'Hợp đồng HDBULK101 đã hoàn thành.',720,CAST(1 AS BIT)),
    ('TBBULK102','TKD101','DANH_GIA',N'Cảm ơn bạn đã đánh giá',N'Đánh giá của bạn đã được ghi nhận.',700,1),
    ('TBBULK103','TKD101','THANH_TOAN',N'Thanh toán thành công',N'Tiền thuê đã được thanh toán thành công.',680,1),
    ('TBBULK104','TKD102','HOP_DONG',N'Hợp đồng hoàn thành',N'Hợp đồng HDBULK102 đã hoàn thành.',600,1),
    ('TBBULK105','TKD102','THANH_TOAN',N'Đã nhận tiền cọc',N'Khoản tiền cọc đã được xác nhận.',580,1),
    ('TBBULK106','TKD102','NHAC_TRA',N'Nhắc lịch trả thiết bị',N'Vui lòng trả thiết bị đúng thời gian đã hẹn.',560,0),
    ('TBBULK107','TKD103','HOP_DONG',N'Hợp đồng hoàn thành',N'Hợp đồng HDBULK103 đã hoàn thành.',500,1),
    ('TBBULK108','TKD103','PHI_PHAT',N'Phát sinh phí hư hỏng',N'Biên bản ghi nhận một vết xước nhẹ.',480,0),
    ('TBBULK109','TKD103','THANH_TOAN',N'Phí phạt đã thanh toán',N'Khoản phí phát sinh đã được thanh toán.',460,0),
    ('TBBULK110','TKD104','HOP_DONG',N'Hợp đồng hoàn thành',N'Hợp đồng HDBULK104 đã hoàn thành.',400,1),
    ('TBBULK111','TKD104','DANH_GIA',N'Mời bạn đánh giá',N'Hãy chia sẻ trải nghiệm thuê thiết bị.',380,0),
    ('TBBULK112','TKD104','KHUYEN_MAI',N'Ưu đãi khách hàng cũ',N'Giảm giá cho lần thuê tiếp theo.',360,0),
    ('TBBULK113','TKD105','HOP_DONG',N'Hợp đồng hoàn thành',N'Hợp đồng HDBULK105 đã hoàn thành.',300,1),
    ('TBBULK114','TKD105','DANH_GIA',N'Cảm ơn góp ý của bạn',N'Góp ý giúp cửa hàng cải thiện dịch vụ.',280,0),
    ('TBBULK115','TKD105','THANH_TOAN',N'Hoàn cọc thành công',N'Tiền cọc đã được hoàn trả.',260,0),
    ('TBBULK116','TKD106','HOP_DONG',N'Hợp đồng hoàn thành',N'Hợp đồng HDBULK106 đã hoàn thành.',200,1),
    ('TBBULK117','TKD106','XAC_MINH',N'Đang xác minh giấy tờ',N'Giấy tờ đang được nhân viên kiểm tra.',180,0),
    ('TBBULK118','TKD106','DANH_GIA',N'Đánh giá đã được ẩn',N'Đánh giá vi phạm quy định hiển thị.',160,0),
    ('TBBULK119','TKD107','HOP_DONG',N'Đang thuê thiết bị',N'Hợp đồng HDBULK107 đang có hiệu lực.',48,1),
    ('TBBULK120','TKD107','GIA_HAN',N'Gia hạn thành công',N'Yêu cầu gia hạn đã được xác nhận.',24,0),
    ('TBBULK121','TKD107','NHAC_TRA',N'Sắp đến hạn trả',N'Vui lòng chuẩn bị trả thiết bị.',6,0),
    ('TBBULK122','TKD108','XAC_MINH',N'Giấy tờ chưa hợp lệ',N'Ảnh giấy tờ bị mờ, vui lòng tải lại.',72,1),
    ('TBBULK123','TKD108','TAI_KHOAN',N'Tài khoản tạm khóa',N'Liên hệ quản trị viên để được hỗ trợ.',48,0),
    ('TBBULK124','TKD108','HE_THONG',N'Cập nhật chính sách',N'Điều khoản sử dụng vừa được cập nhật.',12,0)
) v(MaThongBao, MaTaiKhoan, Loai, TieuDe, NoiDung, GioCu, DaDoc)
WHERE EXISTS (SELECT 1 FROM dbo.TaiKhoan t WHERE t.MaTaiKhoan = v.MaTaiKhoan)
  AND NOT EXISTS (SELECT 1 FROM dbo.ThongBao x WHERE x.MaThongBao = v.MaThongBao);

COMMIT TRANSACTION;
GO

/* Tom tat de nguoi chay script nhin thay ngay ket qua. */
SELECT N'Khách hàng demo mở rộng' AS Nhom, COUNT(*) AS SoLuong
FROM dbo.KhachThue WHERE MaKhachThue LIKE 'KH1%'
UNION ALL
SELECT N'Thiết bị demo mở rộng', COUNT(*)
FROM dbo.ThietBi WHERE MaThietBi LIKE 'TBDEMO%'
UNION ALL
SELECT N'Giỏ hàng demo mở rộng', COUNT(*)
FROM dbo.GioHang WHERE MaGioHang LIKE 'GHLARGE%' OR MaGioHang LIKE 'GHIST%'
UNION ALL
SELECT N'Hợp đồng demo mở rộng', COUNT(*)
FROM dbo.HopDong WHERE MaHopDong LIKE 'HDBULK%'
UNION ALL
SELECT N'Thanh toán demo mở rộng', COUNT(*)
FROM dbo.ThanhToan WHERE MaThanhToan LIKE 'TTB%'
UNION ALL
SELECT N'Đánh giá demo mở rộng', COUNT(*)
FROM dbo.DanhGia WHERE MaDanhGia LIKE 'DGBULK%'
UNION ALL
SELECT N'Thông báo demo mở rộng', COUNT(*)
FROM dbo.ThongBao WHERE MaThongBao LIKE 'TBBULK%';
GO
