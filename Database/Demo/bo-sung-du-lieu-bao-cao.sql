SET NOCOUNT ON;
SET XACT_ABORT ON;

USE [RentalCameraDb30_Test];
GO

IF DB_NAME() <> N'RentalCameraDb30_Test'
    THROW 51000, N'Chi duoc chay tren RentalCameraDb30_Test.', 1;

/*
    Bổ sung dữ liệu đánh giá phục vụ trình diễn/báo cáo.
    - Không tạo bảng hoặc thay đổi cấu trúc Schema33.
    - Chỉ lấy hợp đồng đã hoàn thành và chưa được đánh giá.
    - Có thể chạy lại an toàn; mỗi chi tiết hợp đồng chỉ có một đánh giá.
*/

BEGIN TRANSACTION;

;WITH UngVien AS
(
    SELECT TOP (6)
        ct.MaChiTietHopDong,
        h.MaKhachThue,
        ROW_NUMBER() OVER
        (
            ORDER BY h.NgayTaoHopDong DESC, ct.MaChiTietHopDong
        ) AS STT
    FROM dbo.HopDong AS h
    INNER JOIN dbo.ChiTietHopDong AS ct
        ON ct.MaHopDong = h.MaHopDong
    LEFT JOIN dbo.DanhGia AS dg
        ON dg.MaChiTietHopDong = ct.MaChiTietHopDong
    WHERE h.TrangThai = 'HOAN_THANH'
      AND dg.MaDanhGia IS NULL
)
INSERT dbo.DanhGia
(
    MaDanhGia,
    MaChiTietHopDong,
    MaKhachThue,
    NhanXet,
    SoSao,
    NgayDanhGia,
    TrangThaiKiemDuyet,
    GhiChuKiemDuyet,
    NgayKiemDuyet,
    NguoiCapNhatHienThi,
    TraLoi,
    NguoiTraLoi,
    TraLoiLucUtc,
    SuaTraLoiLucUtc
)
SELECT
    CONCAT('DGDEMO', RIGHT(CONCAT('00', STT), 3)),
    MaChiTietHopDong,
    MaKhachThue,
    CASE STT
        WHEN 1 THEN N'Thiết bị hoạt động ổn định, quy trình nhận và trả máy nhanh.'
        WHEN 2 THEN N'Nhân viên tư vấn rõ ràng, máy sạch và đúng mô tả.'
        WHEN 3 THEN N'Chất lượng ảnh tốt, phụ kiện được bàn giao đầy đủ.'
        WHEN 4 THEN N'Trải nghiệm thuê thuận tiện, sẽ tiếp tục sử dụng dịch vụ.'
        WHEN 5 THEN N'Máy tốt, thời gian xử lý hợp đồng hợp lý.'
        ELSE N'Dịch vụ ổn, thiết bị đáp ứng đúng nhu cầu sử dụng.'
    END,
    CASE STT WHEN 3 THEN 4 WHEN 5 THEN 4 ELSE 5 END,
    DATEADD(MINUTE, -STT, SYSUTCDATETIME()),
    'CONG_KHAI',
    N'Dữ liệu mẫu phục vụ trình diễn và báo cáo.',
    SYSUTCDATETIME(),
    NULL,
    CASE WHEN STT IN (1, 2)
         THEN N'Cảm ơn bạn đã sử dụng dịch vụ của SnapLease.'
         ELSE NULL
    END,
    NULL,
    CASE WHEN STT IN (1, 2) THEN SYSUTCDATETIME() ELSE NULL END,
    NULL
FROM UngVien
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.DanhGia AS daCo
    WHERE daCo.MaChiTietHopDong = UngVien.MaChiTietHopDong
       OR daCo.MaDanhGia = CONCAT('DGDEMO', RIGHT(CONCAT('00', STT), 3))
);

DECLARE @SoDanhGiaDaThem int = @@ROWCOUNT;

COMMIT TRANSACTION;

SELECT
    @SoDanhGiaDaThem AS SoDanhGiaDaThem,
    (SELECT COUNT(*) FROM dbo.DanhGia) AS TongDanhGiaHienTai;
