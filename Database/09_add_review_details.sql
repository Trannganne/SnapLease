USE RentalCameraDb20;
GO

SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH('dbo.DanhGia', 'TrangThaiKiemDuyet') IS NULL
BEGIN
    EXEC(N'ALTER TABLE dbo.DanhGia ADD TrangThaiKiemDuyet VARCHAR(20) NULL;');
END;

EXEC(N'UPDATE dbo.DanhGia
       SET TrangThaiKiemDuyet = ''DA_DUYET''
       WHERE TrangThaiKiemDuyet IS NULL;');

EXEC(N'ALTER TABLE dbo.DanhGia
       ALTER COLUMN TrangThaiKiemDuyet VARCHAR(20) NOT NULL;');

IF OBJECT_ID('dbo.DF_DanhGia_TrangThaiKiemDuyet', 'D') IS NULL
BEGIN
    EXEC(N'ALTER TABLE dbo.DanhGia
           ADD CONSTRAINT DF_DanhGia_TrangThaiKiemDuyet
           DEFAULT ''CHO_DUYET'' FOR TrangThaiKiemDuyet;');
END;

IF COL_LENGTH('dbo.DanhGia', 'GhiChuKiemDuyet') IS NULL
    ALTER TABLE dbo.DanhGia ADD GhiChuKiemDuyet NVARCHAR(500) NULL;

IF COL_LENGTH('dbo.DanhGia', 'NgayKiemDuyet') IS NULL
    ALTER TABLE dbo.DanhGia ADD NgayKiemDuyet DATETIME2 NULL;

UPDATE dbo.DanhGia
SET NhanXet = LEFT(NhanXet, 500)
WHERE LEN(NhanXet) > 500;

ALTER TABLE dbo.DanhGia ALTER COLUMN NhanXet NVARCHAR(500) NULL;

IF OBJECT_ID('dbo.CK_DanhGia_TrangThaiKiemDuyet', 'C') IS NULL
BEGIN
    EXEC(N'ALTER TABLE dbo.DanhGia
           ADD CONSTRAINT CK_DanhGia_TrangThaiKiemDuyet
           CHECK (TrangThaiKiemDuyet IN (''CHO_DUYET'', ''DA_DUYET'', ''TU_CHOI''));');
END;

IF OBJECT_ID('dbo.DanhGiaDiemNoiBat', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DanhGiaDiemNoiBat
    (
        MaDanhGia VARCHAR(20) NOT NULL,
        MaDiemNoiBat VARCHAR(50) NOT NULL,

        CONSTRAINT PK_DanhGiaDiemNoiBat
            PRIMARY KEY (MaDanhGia, MaDiemNoiBat),
        CONSTRAINT FK_DanhGiaDiemNoiBat_DanhGia
            FOREIGN KEY (MaDanhGia) REFERENCES dbo.DanhGia(MaDanhGia) ON DELETE CASCADE,
        CONSTRAINT CK_DanhGiaDiemNoiBat_Ma
            CHECK (MaDiemNoiBat IN
            (
                'CHAT_LUONG_HINH_ANH_TOT',
                'THIET_BI_HOAT_DONG_ON_DINH',
                'NGOAI_HINH_CON_MOI',
                'PIN_SU_DUNG_TOT',
                'DE_SU_DUNG',
                'PHU_KIEN_DAY_DU'
            ))
    );
END;

IF OBJECT_ID('dbo.AnhDanhGia', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AnhDanhGia
    (
        MaAnhDanhGia VARCHAR(20) NOT NULL,
        MaDanhGia VARCHAR(20) NOT NULL,
        DuongDanAnh NVARCHAR(500) NOT NULL,
        PublicId NVARCHAR(200) NOT NULL,
        ThuTu TINYINT NOT NULL,
        NgayTao DATETIME2 NOT NULL
            CONSTRAINT DF_AnhDanhGia_NgayTao DEFAULT SYSDATETIME(),

        CONSTRAINT PK_AnhDanhGia PRIMARY KEY (MaAnhDanhGia),
        CONSTRAINT FK_AnhDanhGia_DanhGia
            FOREIGN KEY (MaDanhGia) REFERENCES dbo.DanhGia(MaDanhGia) ON DELETE CASCADE,
        CONSTRAINT UQ_AnhDanhGia_ThuTu UNIQUE (MaDanhGia, ThuTu),
        CONSTRAINT CK_AnhDanhGia_ThuTu CHECK (ThuTu BETWEEN 1 AND 4)
    );
END;

COMMIT TRANSACTION;
GO
