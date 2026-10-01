/*
Cap nhat URL anh Cloudinary cho database da duoc khoi tao truoc do.
Script chi thay doi 5 ban ghi anh mau A001-A005, khong tao lai database.
*/

USE RentalCameraDb20;
GO

SET XACT_ABORT ON;
BEGIN TRANSACTION;

UPDATE AnhThietBi
SET DuongDanAnh = N'https://res.cloudinary.com/rqdym8rq/image/upload/canon-r6-1.jpg',
    LaAnhDaiDien = 1,
    ThuTuHienThi = 1
WHERE MaAnh = 'A001' AND MaDongMay = 'DONG001';

UPDATE AnhThietBi
SET DuongDanAnh = N'https://res.cloudinary.com/rqdym8rq/image/upload/canon-r6-2.jpg',
    LaAnhDaiDien = 0,
    ThuTuHienThi = 2
WHERE MaAnh = 'A002' AND MaDongMay = 'DONG001';

UPDATE AnhThietBi
SET DuongDanAnh = N'https://res.cloudinary.com/rqdym8rq/image/upload/sony-a7iii.jpg',
    LaAnhDaiDien = 1,
    ThuTuHienThi = 1
WHERE MaAnh = 'A003' AND MaDongMay = 'DONG002';

UPDATE AnhThietBi
SET DuongDanAnh = N'https://res.cloudinary.com/rqdym8rq/image/upload/canon-rf2470.jpg',
    LaAnhDaiDien = 1,
    ThuTuHienThi = 1
WHERE MaAnh = 'A004' AND MaDongMay = 'DONG003';

UPDATE AnhThietBi
SET DuongDanAnh = N'https://res.cloudinary.com/rqdym8rq/image/upload/nikon-z6ii.jpg',
    LaAnhDaiDien = 1,
    ThuTuHienThi = 1
WHERE MaAnh = 'A005' AND MaDongMay = 'DONG004';

COMMIT TRANSACTION;
GO

SELECT MaAnh, MaDongMay, DuongDanAnh, LaAnhDaiDien, ThuTuHienThi
FROM AnhThietBi
WHERE MaAnh IN ('A001','A002','A003','A004','A005')
ORDER BY MaDongMay, ThuTuHienThi;
GO
