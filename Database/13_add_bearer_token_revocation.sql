USE RentalCameraDb20;
GO

IF OBJECT_ID('dbo.ThuHoiBearerToken', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ThuHoiBearerToken
    (
        TokenHash CHAR(64) NOT NULL,
        MaTaiKhoan VARCHAR(20) NOT NULL,
        ThuHoiLuc DATETIME2 NOT NULL
            CONSTRAINT DF_ThuHoiBearerToken_ThuHoiLuc DEFAULT SYSUTCDATETIME(),
        HetHanLuc DATETIME2 NOT NULL,

        CONSTRAINT PK_ThuHoiBearerToken PRIMARY KEY (TokenHash),
        CONSTRAINT FK_ThuHoiBearerToken_TaiKhoan
            FOREIGN KEY (MaTaiKhoan) REFERENCES dbo.TaiKhoan(MaTaiKhoan)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_ThuHoiBearerToken_HetHanLuc'
      AND object_id = OBJECT_ID('dbo.ThuHoiBearerToken')
)
BEGIN
    CREATE INDEX IX_ThuHoiBearerToken_HetHanLuc
        ON dbo.ThuHoiBearerToken(HetHanLuc);
END;
GO
