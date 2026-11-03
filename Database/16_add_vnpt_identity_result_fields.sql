SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.GiayToTuyThan', N'NhaCungCapXacMinh') IS NULL
    ALTER TABLE dbo.GiayToTuyThan ADD NhaCungCapXacMinh varchar(30) NULL;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'MaThamChieuXacMinh') IS NULL
    ALTER TABLE dbo.GiayToTuyThan ADD MaThamChieuXacMinh varchar(100) NULL;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'KetQuaXacMinhTuDong') IS NULL
    ALTER TABLE dbo.GiayToTuyThan ADD KetQuaXacMinhTuDong varchar(30) NULL;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'DoTinCayOcr') IS NULL
    ALTER TABLE dbo.GiayToTuyThan ADD DoTinCayOcr decimal(5,4) NULL;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'DiemSoKhuonMat') IS NULL
    ALTER TABLE dbo.GiayToTuyThan ADD DiemSoKhuonMat decimal(5,4) NULL;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'DiemSoSong') IS NULL
    ALTER TABLE dbo.GiayToTuyThan ADD DiemSoSong decimal(5,4) NULL;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'XacMinhTuDongLucUtc') IS NULL
    ALTER TABLE dbo.GiayToTuyThan ADD XacMinhTuDongLucUtc datetime2 NULL;

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CKR_GiayTo_KetQuaXacMinhTuDong')
    ALTER TABLE dbo.GiayToTuyThan WITH CHECK ADD CONSTRAINT CKR_GiayTo_KetQuaXacMinhTuDong
        CHECK (KetQuaXacMinhTuDong IS NULL OR KetQuaXacMinhTuDong IN ('CHO_XU_LY','CAN_DUYET','DAT','KHONG_DAT','LOI_NHA_CUNG_CAP'));

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CKR_GiayTo_DiemXacMinhTuDong')
    ALTER TABLE dbo.GiayToTuyThan WITH CHECK ADD CONSTRAINT CKR_GiayTo_DiemXacMinhTuDong
        CHECK ((DoTinCayOcr IS NULL OR DoTinCayOcr BETWEEN 0 AND 1)
           AND (DiemSoKhuonMat IS NULL OR DiemSoKhuonMat BETWEEN 0 AND 1)
           AND (DiemSoSong IS NULL OR DiemSoSong BETWEEN 0 AND 1));

COMMIT TRANSACTION;
