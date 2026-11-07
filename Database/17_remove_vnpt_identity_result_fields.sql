SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CKR_GiayTo_KetQuaXacMinhTuDong' AND parent_object_id = OBJECT_ID(N'dbo.GiayToTuyThan'))
    ALTER TABLE dbo.GiayToTuyThan DROP CONSTRAINT CKR_GiayTo_KetQuaXacMinhTuDong;

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CKR_GiayTo_DiemXacMinhTuDong' AND parent_object_id = OBJECT_ID(N'dbo.GiayToTuyThan'))
    ALTER TABLE dbo.GiayToTuyThan DROP CONSTRAINT CKR_GiayTo_DiemXacMinhTuDong;

IF COL_LENGTH(N'dbo.GiayToTuyThan', N'NhaCungCapXacMinh') IS NOT NULL
    ALTER TABLE dbo.GiayToTuyThan DROP COLUMN NhaCungCapXacMinh;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'MaThamChieuXacMinh') IS NOT NULL
    ALTER TABLE dbo.GiayToTuyThan DROP COLUMN MaThamChieuXacMinh;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'KetQuaXacMinhTuDong') IS NOT NULL
    ALTER TABLE dbo.GiayToTuyThan DROP COLUMN KetQuaXacMinhTuDong;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'DoTinCayOcr') IS NOT NULL
    ALTER TABLE dbo.GiayToTuyThan DROP COLUMN DoTinCayOcr;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'DiemSoKhuonMat') IS NOT NULL
    ALTER TABLE dbo.GiayToTuyThan DROP COLUMN DiemSoKhuonMat;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'DiemSoSong') IS NOT NULL
    ALTER TABLE dbo.GiayToTuyThan DROP COLUMN DiemSoSong;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'XacMinhTuDongLucUtc') IS NOT NULL
    ALTER TABLE dbo.GiayToTuyThan DROP COLUMN XacMinhTuDongLucUtc;

COMMIT TRANSACTION;
