-- Database/08_remove_giohang_unique_hopdong.sql
-- Migration to allow multiple HopDong to share the same MaGioHang
-- but keeping MaGiuCho unique

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ConstraintName NVARCHAR(200);

    -- Find the auto-generated UNIQUE constraint on MaGioHang
    SELECT @ConstraintName = kc.name
    FROM sys.key_constraints kc
    JOIN sys.index_columns ic ON kc.parent_object_id = ic.object_id AND kc.unique_index_id = ic.index_id
    JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE kc.type = 'UQ' 
      AND kc.parent_object_id = OBJECT_ID('HopDong') 
      AND c.name = 'MaGioHang';

    IF @ConstraintName IS NOT NULL
    BEGIN
        PRINT 'Dropping UNIQUE constraint on MaGioHang: ' + @ConstraintName;
        EXEC('ALTER TABLE HopDong DROP CONSTRAINT ' + @ConstraintName);
    END
    ELSE
    BEGIN
        PRINT 'UNIQUE constraint on MaGioHang not found or already dropped.';
    END

    COMMIT TRANSACTION;
    PRINT 'Migration completed successfully.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(50));
    PRINT 'Error Message: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
