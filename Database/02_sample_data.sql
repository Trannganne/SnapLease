/* Du lieu mau cho schema RentCam final 22 bang. */
USE RentalCameraDb20;
GO

INSERT INTO DanhMuc (MaDanhMuc, TenDanhMuc, MoTa) VALUES
('DM001', N'Máy ảnh', N'Máy ảnh DSLR và mirrorless'),
('DM002', N'Ống kính', N'Ống kính rời cho máy ảnh');

INSERT INTO ThuongHieu (MaThuongHieu, TenThuongHieu, QuocGia) VALUES
('TH001', N'Canon', N'Nhật Bản'),
('TH002', N'Sony', N'Nhật Bản'),
('TH003', N'Nikon', N'Nhật Bản');

INSERT INTO DongMay (MaDongMay, MaDanhMuc, MaThuongHieu, TenDongMay, MoTa, GiaThueNgay, TienCoc, PhanTramGiamGia) VALUES
('DONG001','DM001','TH001',N'Canon EOS R6',N'Mirrorless full-frame',500000,5000000,0),
('DONG002','DM001','TH002',N'Sony Alpha A7 III',N'Mirrorless full-frame',450000,4500000,5),
('DONG003','DM002','TH001',N'Canon RF 24-70mm F2.8',N'Ống kính zoom tiêu chuẩn',300000,3000000,0),
('DONG004','DM001','TH003',N'Nikon Z6 II',N'Mirrorless full-frame',470000,4700000,0);

INSERT INTO AnhThietBi (MaAnh, MaDongMay, DuongDanAnh, LaAnhDaiDien, ThuTuHienThi) VALUES
('A001','DONG001',N'/images/canon-r6-1.jpg',1,1),
('A002','DONG001',N'/images/canon-r6-2.jpg',0,2),
('A003','DONG002',N'/images/sony-a7iii.jpg',1,1),
('A004','DONG003',N'/images/canon-rf2470.jpg',1,1),
('A005','DONG004',N'/images/nikon-z6ii.jpg',1,1);

INSERT INTO CuaHang (MaCuaHang, TenCuaHang, DiaChi, SoDienThoai, Email, MoTa) VALUES
('CH001',N'Rental Camera Quận 1',N'01 Nguyễn Huệ, Quận 1, TP.HCM','0901000001','q1@rentalcamera.vn',N'Chi nhánh trung tâm'),
('CH002',N'Rental Camera Thủ Đức',N'20 Võ Văn Ngân, TP. Thủ Đức','0901000002','td@rentalcamera.vn',N'Chi nhánh phía Đông');

INSERT INTO TaiKhoan (MaTaiKhoan, TenDangNhap, MatKhauHash, VaiTro) VALUES
('TK001','admin01','$2a$demo_admin','ADMIN'),
('TK002','nhanvien01','$2a$demo_nv1','NHAN_VIEN'),
('TK003','nhanvien02','$2a$demo_nv2','NHAN_VIEN'),
('TK004','khachhang01','$2a$demo_kh1','KHACH_HANG'),
('TK005','khachhang02','$2a$demo_kh2','KHACH_HANG');

INSERT INTO KhachThue (MaKhachThue, MaTaiKhoan, HoTen, SoDienThoai, Email, CCCD, DiaChi, NgaySinh) VALUES
('KH001','TK004',N'Nguyễn Minh Anh','0911000001','minhanh@example.com','079200000001',N'Bình Thạnh, TP.HCM','2000-04-18'),
('KH002','TK005',N'Trần Gia Huy','0911000002','giahuy@example.com','079200000002',N'Gò Vấp, TP.HCM','1999-11-02');

INSERT INTO GiayToTuyThan (MaGiayTo, MaKhachThue, LoaiGiayTo, SoGiayTo, MatTruocUrl, MatSauUrl, TrangThaiXacMinh) VALUES
('GT001','KH001','CCCD','079200000001',N'/identity/kh001-front.jpg',N'/identity/kh001-back.jpg','HOP_LE'),
('GT002','KH002','CCCD','079200000002',N'/identity/kh002-front.jpg',N'/identity/kh002-back.jpg','HOP_LE');

INSERT INTO NhanVien (MaNhanVien, MaTaiKhoan, MaCuaHang, HoTen, DiaChi, SoDienThoai, ChucVu, Email) VALUES
('NV001','TK002','CH001',N'Lê Hoàng Nam',N'Quận 3, TP.HCM','0922000001',N'Nhân viên vận hành','nam@rentalcamera.vn'),
('NV002','TK003','CH002',N'Phạm Thu Hà',N'TP. Thủ Đức','0922000002',N'Nhân viên cửa hàng','ha@rentalcamera.vn');

INSERT INTO ThietBi (MaThietBi, MaDongMay, MaCuaHang, SoSerial, TinhTrang, TrangThai, NgayNhap) VALUES
('TB001','DONG001','CH001','CR6-0001',N'Tốt, đủ nắp và pin','SAN_SANG','2026-01-10'),
('TB002','DONG001','CH001','CR6-0002',N'Xước nhẹ thân máy','BAO_TRI','2026-02-01'),
('TB003','DONG002','CH001','SA7-0001',N'Tốt','SAN_SANG','2026-02-15'),
('TB004','DONG003','CH001','RF2470-001',N'Tốt','SAN_SANG','2026-03-01'),
('TB005','DONG004','CH002','NZ6-0001',N'Tốt','DANG_THUE','2026-03-20');

INSERT INTO GioHang (MaGioHang, MaKhachThue, MaCuaHang, NgayTao, NgayCapNhat, TrangThai) VALUES
('GH001','KH001','CH001','2026-08-01T09:00:00','2026-08-01T09:15:00','DA_CHUYEN_HOP_DONG'),
('GH002','KH002','CH002','2026-09-10T10:00:00','2026-09-10T10:10:00','DA_CHUYEN_HOP_DONG'),
('GH003','KH001','CH001',SYSDATETIME(),SYSDATETIME(),'DANG_CHON');

INSERT INTO ChiTietGioHang (MaChiTietGioHang, MaGioHang, MaDongMay, SoLuong, NgayBatDau, NgayKetThuc, DonGia, TienCoc, ThanhTien) VALUES
('CTGH001','GH001','DONG001',1,'2026-08-05T08:00:00','2026-08-07T18:00:00',500000,5000000,1500000),
('CTGH002','GH001','DONG003',1,'2026-08-05T08:00:00','2026-08-07T18:00:00',300000,3000000,900000),
('CTGH003','GH002','DONG004',1,'2026-09-12T08:00:00','2026-09-14T18:00:00',470000,4700000,1410000),
('CTGH004','GH003','DONG001',1,'2026-10-10T08:00:00','2026-10-12T18:00:00',500000,5000000,1500000);

INSERT INTO GiuCho (MaGiuCho, MaGioHang, MaKhachThue, MaCuaHang, NgayTao, HetHanLuc, TrangThai) VALUES
('GC001','GH001','KH001','CH001','2026-08-01T09:15:00','2026-08-01T09:35:00','DA_CHUYEN_HOP_DONG'),
('GC002','GH002','KH002','CH002','2026-09-10T10:10:00','2026-09-10T10:30:00','DA_CHUYEN_HOP_DONG'),
('GC003','GH003','KH001','CH001',SYSDATETIME(),DATEADD(MINUTE,20,SYSDATETIME()),'DANG_GIU');

INSERT INTO ChiTietGiuCho (MaChiTietGiuCho, MaGiuCho, MaDongMay, SoLuong, NgayBatDau, NgayKetThuc) VALUES
('CTGC001','GC001','DONG001',1,'2026-08-05T08:00:00','2026-08-07T18:00:00'),
('CTGC002','GC001','DONG003',1,'2026-08-05T08:00:00','2026-08-07T18:00:00'),
('CTGC003','GC002','DONG004',1,'2026-09-12T08:00:00','2026-09-14T18:00:00'),
('CTGC004','GC003','DONG001',1,'2026-10-10T08:00:00','2026-10-12T18:00:00');

INSERT INTO HopDong (MaHopDong, MaGioHang, MaGiuCho, MaKhachThue, MaNhanVien, MaCuaHang,
    NgayTaoHopDong, NgayKy, ThoiGianBanGiao, ThoiGianTraDuKien,
    TongTien, TongTienCoc, HinhThucKy, TrangThai, TepHopDongUrl) VALUES
('HD001','GH001','GC001','KH001','NV001','CH001','2026-08-01T09:16:00','2026-08-01T09:20:00',
 '2026-08-05T08:00:00','2026-08-07T18:00:00',2400000,8000000,'DIEN_TU','HOAN_THANH',N'/contracts/hd001.pdf'),
('HD002','GH002','GC002','KH002','NV002','CH002','2026-09-10T10:11:00','2026-09-10T10:15:00',
 '2026-09-12T08:00:00','2026-09-14T18:00:00',1410000,4700000,'BAN_GIAY','DANG_THUE',N'/contracts/hd002.pdf');

INSERT INTO ChiTietHopDong (MaChiTietHopDong, MaHopDong, MaThietBi, DonGia,
    TinhTrangLucGiao, NgayGiaoThucTe, TinhTrangLucNhan, NgayNhanThucTe, CoHuHong) VALUES
('CTHD001','HD001','TB002',500000,N'Tốt, đủ pin và nắp','2026-08-05T08:05:00',N'Xước nhẹ thân máy','2026-08-07T18:20:00',1),
('CTHD002','HD001','TB004',300000,N'Tốt, đủ hai nắp','2026-08-05T08:05:00',N'Tốt, đủ hai nắp','2026-08-07T18:20:00',0),
('CTHD003','HD002','TB005',470000,N'Tốt, đủ pin và nắp','2026-09-12T08:10:00',NULL,NULL,0);

INSERT INTO ThanhToan (MaThanhToan, MaHopDong, SoTien, LoaiThanhToan, PhuongThuc, MaGiaoDich, ThoiGian, TrangThai, NoiDungChuyenKhoan) VALUES
('TT001','HD001',8000000,'TIEN_COC','CHUYEN_KHOAN','TXN-001','2026-08-01T09:30:00','THANH_CONG',N'Cọc HD001'),
('TT002','HD001',2400000,'TIEN_THUE','VI_DIEN_TU','TXN-002','2026-08-05T08:00:00','THANH_CONG',N'Tiền thuê HD001'),
('TT003','HD002',4700000,'TIEN_COC','CHUYEN_KHOAN','TXN-003','2026-09-10T10:20:00','THANH_CONG',N'Cọc HD002'),
('TT004','HD002',1410000,'TIEN_THUE','TIEN_MAT',NULL,'2026-09-12T08:00:00','THANH_CONG',N'Tiền thuê HD002');

INSERT INTO PhuLuc (MaPhuLuc, MaHopDong, NgayLap, ThoiHanTraMoi, ChiPhiPhatSinh, TienCocBoSung, LyDoGiaHan, TrangThai) VALUES
('PL001','HD002','2026-09-14T09:00:00','2026-09-15T18:00:00',470000,0,N'Khách cần thêm một ngày chụp','DA_XAC_NHAN');

INSERT INTO PhieuPhat (MaPhieuPhat, MaChiTietHopDong, LoaiViPham, SoTien, MoTa, NgayLap, TrangThai) VALUES
('PP001','CTHD001','HU_HONG',600000,N'Xước thân máy phát sinh sau khi nhận lại','2026-08-07T18:30:00','DA_XAC_NHAN');

INSERT INTO AnhBienBan (MaAnhBienBan, MaChiTietHopDong, Loai, DuongDanAnh, MoTa, ThoiGianChup) VALUES
('ABB001','CTHD001','BAN_GIAO',N'/handover/hd001-tb002-giao.jpg',N'Ảnh trước khi giao','2026-08-05T08:04:00'),
('ABB002','CTHD001','HU_HONG',N'/handover/hd001-tb002-xuoc.jpg',N'Ảnh vết xước khi nhận lại','2026-08-07T18:19:00'),
('ABB003','CTHD002','NHAN_LAI',N'/handover/hd001-tb004-nhan.jpg',N'Ảnh nhận lại ống kính','2026-08-07T18:20:00');

INSERT INTO DanhGia (MaDanhGia, MaChiTietHopDong, MaKhachThue, NhanXet, SoSao, NgayDanhGia) VALUES
('DG001','CTHD001','KH001',N'Thiết bị tốt, giao nhận nhanh',5,'2026-08-08T09:00:00');

INSERT INTO ThongBao (MaThongBao, MaTaiKhoan, Loai, TieuDe, NoiDung, ThoiGianGui, DaDoc) VALUES
('TBao001','TK004','HOP_DONG',N'Hợp đồng đã hoàn thành',N'Hợp đồng HD001 đã hoàn thành','2026-08-07T19:00:00',1),
('TBao002','TK005','GIA_HAN',N'Gia hạn được xác nhận',N'Phụ lục PL001 đã được xác nhận','2026-09-14T09:05:00',0),
('TBao003','TK004','GIU_CHO',N'Đang giữ chỗ',N'Giữ chỗ GC003 có hiệu lực trong 20 phút',SYSDATETIME(),0);
GO
