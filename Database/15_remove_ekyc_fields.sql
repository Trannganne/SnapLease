SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CKR_GiayTo_EkycStatus' AND parent_object_id = OBJECT_ID(N'dbo.GiayToTuyThan'))
    ALTER TABLE dbo.GiayToTuyThan DROP CONSTRAINT CKR_GiayTo_EkycStatus;

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CKR_GiayTo_EkycScores' AND parent_object_id = OBJECT_ID(N'dbo.GiayToTuyThan'))
    ALTER TABLE dbo.GiayToTuyThan DROP CONSTRAINT CKR_GiayTo_EkycScores;

IF COL_LENGTH(N'dbo.GiayToTuyThan', N'EkycProcessedAtUtc') IS NOT NULL
    ALTER TABLE dbo.GiayToTuyThan DROP COLUMN EkycProcessedAtUtc;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'LivenessScore') IS NOT NULL
    ALTER TABLE dbo.GiayToTuyThan DROP COLUMN LivenessScore;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'FaceMatchScore') IS NOT NULL
    ALTER TABLE dbo.GiayToTuyThan DROP COLUMN FaceMatchScore;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'OcrConfidence') IS NOT NULL
    ALTER TABLE dbo.GiayToTuyThan DROP COLUMN OcrConfidence;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'EkycStatus') IS NOT NULL
    ALTER TABLE dbo.GiayToTuyThan DROP COLUMN EkycStatus;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'EkycReferenceId') IS NOT NULL
    ALTER TABLE dbo.GiayToTuyThan DROP COLUMN EkycReferenceId;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'EkycProvider') IS NOT NULL
    ALTER TABLE dbo.GiayToTuyThan DROP COLUMN EkycProvider;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'SelfieUrl') IS NOT NULL
    ALTER TABLE dbo.GiayToTuyThan DROP COLUMN SelfieUrl;

COMMIT TRANSACTION;
