SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.GiayToTuyThan', N'SelfieUrl') IS NULL
    ALTER TABLE dbo.GiayToTuyThan ADD SelfieUrl nvarchar(500) NULL;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'EkycProvider') IS NULL
    ALTER TABLE dbo.GiayToTuyThan ADD EkycProvider varchar(50) NULL;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'EkycReferenceId') IS NULL
    ALTER TABLE dbo.GiayToTuyThan ADD EkycReferenceId varchar(100) NULL;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'EkycStatus') IS NULL
    ALTER TABLE dbo.GiayToTuyThan ADD EkycStatus varchar(30) NULL;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'OcrConfidence') IS NULL
    ALTER TABLE dbo.GiayToTuyThan ADD OcrConfidence decimal(5,4) NULL;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'FaceMatchScore') IS NULL
    ALTER TABLE dbo.GiayToTuyThan ADD FaceMatchScore decimal(5,4) NULL;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'LivenessScore') IS NULL
    ALTER TABLE dbo.GiayToTuyThan ADD LivenessScore decimal(5,4) NULL;
IF COL_LENGTH(N'dbo.GiayToTuyThan', N'EkycProcessedAtUtc') IS NULL
    ALTER TABLE dbo.GiayToTuyThan ADD EkycProcessedAtUtc datetime2 NULL;

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name=N'CKR_GiayTo_EkycStatus')
    ALTER TABLE dbo.GiayToTuyThan WITH CHECK ADD CONSTRAINT CKR_GiayTo_EkycStatus
        CHECK (EkycStatus IS NULL OR EkycStatus IN ('CHO_XU_LY','CAN_DUYET','DAT','KHONG_DAT','LOI_NHA_CUNG_CAP'));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name=N'CKR_GiayTo_EkycScores')
    ALTER TABLE dbo.GiayToTuyThan WITH CHECK ADD CONSTRAINT CKR_GiayTo_EkycScores
        CHECK ((OcrConfidence IS NULL OR OcrConfidence BETWEEN 0 AND 1)
           AND (FaceMatchScore IS NULL OR FaceMatchScore BETWEEN 0 AND 1)
           AND (LivenessScore IS NULL OR LivenessScore BETWEEN 0 AND 1));

COMMIT TRANSACTION;
