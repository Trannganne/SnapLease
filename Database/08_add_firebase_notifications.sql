USE RentalCameraDb20;
GO

SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID('dbo.FcmDeviceToken', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.FcmDeviceToken
    (
        Id VARCHAR(36) NOT NULL,
        MaTaiKhoan VARCHAR(20) NOT NULL,
        Token NVARCHAR(2048) NOT NULL,
        TokenHash CHAR(64) NOT NULL,
        Platform VARCHAR(20) NOT NULL,
        DeviceId NVARCHAR(200) NULL,
        IsActive BIT NOT NULL
            CONSTRAINT DF_FcmDeviceToken_IsActive DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL
            CONSTRAINT DF_FcmDeviceToken_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt DATETIME2 NOT NULL
            CONSTRAINT DF_FcmDeviceToken_UpdatedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_FcmDeviceToken PRIMARY KEY (Id),
        CONSTRAINT FK_FcmDeviceToken_TaiKhoan
            FOREIGN KEY (MaTaiKhoan)
            REFERENCES dbo.TaiKhoan(MaTaiKhoan)
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'UX_FcmDeviceToken_TokenHash'
      AND object_id = OBJECT_ID('dbo.FcmDeviceToken')
)
BEGIN
    CREATE UNIQUE INDEX UX_FcmDeviceToken_TokenHash
        ON dbo.FcmDeviceToken(TokenHash);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_FcmDeviceToken_MaTaiKhoan_IsActive'
      AND object_id = OBJECT_ID('dbo.FcmDeviceToken')
)
BEGIN
    CREATE INDEX IX_FcmDeviceToken_MaTaiKhoan_IsActive
        ON dbo.FcmDeviceToken(MaTaiKhoan, IsActive);
END;

IF COL_LENGTH('dbo.ThongBao', 'EventCode') IS NULL
    ALTER TABLE dbo.ThongBao ADD EventCode VARCHAR(50) NULL;

IF COL_LENGTH('dbo.ThongBao', 'TargetType') IS NULL
    ALTER TABLE dbo.ThongBao ADD TargetType VARCHAR(30) NULL;

IF COL_LENGTH('dbo.ThongBao', 'TargetId') IS NULL
    ALTER TABLE dbo.ThongBao ADD TargetId VARCHAR(50) NULL;

COMMIT TRANSACTION;
GO