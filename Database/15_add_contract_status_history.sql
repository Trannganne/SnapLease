USE RentalCameraDb20;
GO

SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.LichSuTrangThaiHopDong', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LichSuTrangThaiHopDong
    (
        MaLichSu VARCHAR(20) NOT NULL,
        MaHopDong VARCHAR(20) NOT NULL,
        TrangThaiCu VARCHAR(30) NULL,
        TrangThaiMoi VARCHAR(30) NOT NULL,
        NguoiThaoTac VARCHAR(20) NULL,
        VaiTroNguoiThaoTac VARCHAR(20) NOT NULL,
        LyDo NVARCHAR(500) NULL,
        ThoiGian DATETIME2 NOT NULL
            CONSTRAINT DF_LichSuTrangThaiHopDong_ThoiGian DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_LichSuTrangThaiHopDong PRIMARY KEY (MaLichSu),
        CONSTRAINT FK_LichSuTrangThaiHopDong_HopDong
            FOREIGN KEY (MaHopDong) REFERENCES dbo.HopDong(MaHopDong),
        CONSTRAINT CK_LichSuTrangThaiHopDong_VaiTro
            CHECK (VaiTroNguoiThaoTac IN ('KHACH_HANG', 'NHAN_VIEN', 'ADMIN', 'HE_THONG'))
    );

    CREATE INDEX IX_LichSuTrangThaiHopDong_HopDong_ThoiGian
        ON dbo.LichSuTrangThaiHopDong(MaHopDong, ThoiGian DESC);
END;
GO

INSERT INTO dbo.LichSuTrangThaiHopDong
(
    MaLichSu,
    MaHopDong,
    TrangThaiCu,
    TrangThaiMoi,
    NguoiThaoTac,
    VaiTroNguoiThaoTac,
    LyDo,
    ThoiGian
)
SELECT
    CONCAT('LSH', LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 17)),
    hd.MaHopDong,
    NULL,
    hd.TrangThai,
    NULL,
    'HE_THONG',
    N'Khởi tạo lịch sử từ trạng thái hiện có khi nâng cấp dữ liệu.',
    COALESCE(hd.NgayKy, hd.NgayTaoHopDong)
FROM dbo.HopDong hd
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.LichSuTrangThaiHopDong ls
    WHERE ls.MaHopDong = hd.MaHopDong
);
GO
