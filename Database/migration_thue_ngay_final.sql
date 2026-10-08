-- MIGRATION SCRIPT CHO LUỒNG THUÊ NGAY VÀ NHIỀU CHI NHÁNH
-- Tương thích hoàn toàn với việc chạy 1 batch duy nhất không có GO bên trong TRY/CATCH.

SET XACT_ABORT ON;
GO

BEGIN TRY
    IF DB_NAME() <> 'RentalCameraDb20'
    BEGIN
        THROW 50001, 'Lỗi: Script này chỉ được chạy trên database RentalCameraDb20.', 1;
    END

    BEGIN TRANSACTION;

    -- 1. BẢO TOÀN DỮ LIỆU CŨ VÀ RÀNG BUỘC (KIỂM TRA TRƯỚC)
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'GioHang')
    BEGIN
        THROW 50001, 'Schema không đúng kỳ vọng: Không tìm thấy bảng dbo.GioHang', 1;
    END

    -- 2. KHACH THUE (IDENTITY)
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'KhachThue' AND COLUMN_NAME = 'GioiTinh')
    BEGIN
        EXEC('ALTER TABLE dbo.KhachThue ADD GioiTinh NVARCHAR(10) NULL;');
    END
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'KhachThue' AND COLUMN_NAME = 'QuocTich')
    BEGIN
        EXEC('ALTER TABLE dbo.KhachThue ADD QuocTich NVARCHAR(100) NULL;');
    END
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'KhachThue' AND COLUMN_NAME = 'NgayCap')
    BEGIN
        EXEC('ALTER TABLE dbo.KhachThue ADD NgayCap DATE NULL;');
    END
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'KhachThue' AND COLUMN_NAME = 'NoiCap')
    BEGIN
        EXEC('ALTER TABLE dbo.KhachThue ADD NoiCap NVARCHAR(200) NULL;');
    END
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'KhachThue' AND COLUMN_NAME = 'DaXacNhanThongTin')
    BEGIN
        EXEC('ALTER TABLE dbo.KhachThue ADD DaXacNhanThongTin BIT NOT NULL DEFAULT 0;');
    END

    -- 3. CHI TIET GIO HANG
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'ChiTietGioHang' AND COLUMN_NAME = 'MaCuaHang')
    BEGIN
        EXEC('ALTER TABLE dbo.ChiTietGioHang ADD MaCuaHang VARCHAR(20) NULL;');
    END
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'ChiTietGioHang' AND COLUMN_NAME = 'NguonTao')
    BEGIN
        EXEC('ALTER TABLE dbo.ChiTietGioHang ADD NguonTao VARCHAR(20) NOT NULL DEFAULT ''GIO_HANG'';');
    END
    
    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_ChiTietGioHang_NguonTao')
    BEGIN
        EXEC('ALTER TABLE dbo.ChiTietGioHang ADD CONSTRAINT CK_ChiTietGioHang_NguonTao CHECK (NguonTao IN (''GIO_HANG'', ''THUE_NGAY''));');
    END
    
    -- Check if MaCuaHang is nullable, meaning it was just added or backfill failed previously
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'ChiTietGioHang' AND COLUMN_NAME = 'MaCuaHang' AND IS_NULLABLE = 'YES')
    BEGIN
        -- Neu can backfill ma GioHang.MaCuaHang khong con thi phai dung lai bao loi
        IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'GioHang' AND COLUMN_NAME = 'MaCuaHang')
        BEGIN
            -- Kiem tra xem thuc te co dong nao NULL khong
            DECLARE @needsBackfill INT = 0;
            EXEC sp_executesql N'SELECT @cnt = COUNT(*) FROM dbo.ChiTietGioHang WHERE MaCuaHang IS NULL', N'@cnt INT OUTPUT', @needsBackfill OUTPUT;
            IF @needsBackfill > 0
            BEGIN
                THROW 50001, 'Khong the backfill ChiTietGioHang vi GioHang.MaCuaHang da bi xoa. Khong the suy doan chi nhanh.', 1;
            END
        END
        ELSE
        BEGIN
            -- Backfill dữ liệu bằng Dynamic SQL để tránh compile error
            EXEC('
            UPDATE c SET c.MaCuaHang = g.MaCuaHang
            FROM dbo.ChiTietGioHang c INNER JOIN dbo.GioHang g ON c.MaGioHang = g.MaGioHang
            WHERE c.MaCuaHang IS NULL;
            ');
        END

        -- Dùng biến đếm thay vì SELECT trực tiếp để kiểm tra nếu backfill xót
        DECLARE @missing INT;
        EXEC sp_executesql N'SELECT @cnt = COUNT(*) FROM dbo.ChiTietGioHang WHERE MaCuaHang IS NULL', N'@cnt INT OUTPUT', @missing OUTPUT;
        
        IF @missing > 0
        BEGIN
            DECLARE @msg NVARCHAR(200) = FORMATMESSAGE('Backfill thất bại: Có %d ChiTietGioHang thiếu MaCuaHang', @missing);
            THROW 50001, @msg, 1;
        END

        EXEC('ALTER TABLE dbo.ChiTietGioHang ALTER COLUMN MaCuaHang VARCHAR(20) NOT NULL;');
    END

    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ChiTietGioHang_CuaHang')
    BEGIN
        EXEC('ALTER TABLE dbo.ChiTietGioHang ADD CONSTRAINT FK_ChiTietGioHang_CuaHang FOREIGN KEY (MaCuaHang) REFERENCES dbo.CuaHang(MaCuaHang);');
    END

    -- 4. GỠ RÀNG BUỘC CŨ CỦA GIO HANG
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_HopDong_GioHang_Khach_CuaHang')
    BEGIN
        ALTER TABLE dbo.HopDong DROP CONSTRAINT FK_HopDong_GioHang_Khach_CuaHang;
    END
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_GiuCho_GioHang_Khach_CuaHang')
    BEGIN
        ALTER TABLE dbo.GiuCho DROP CONSTRAINT FK_GiuCho_GioHang_Khach_CuaHang;
    END
    IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_GioHang_MaGioHang_Khach_CuaHang')
    BEGIN
        ALTER TABLE dbo.GioHang DROP CONSTRAINT UQ_GioHang_MaGioHang_Khach_CuaHang;
    END
    IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_GioHang_MaGioHang_MaCuaHang')
    BEGIN
        ALTER TABLE dbo.GioHang DROP CONSTRAINT UQ_GioHang_MaGioHang_MaCuaHang;
    END
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_GioHang_CuaHang')
    BEGIN
        ALTER TABLE dbo.GioHang DROP CONSTRAINT FK_GioHang_CuaHang;
    END
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'GioHang' AND COLUMN_NAME = 'MaCuaHang')
    BEGIN
        EXEC('ALTER TABLE dbo.GioHang DROP COLUMN MaCuaHang;');
    END
    
    IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_ChiTietGioHang')
    BEGIN
        ALTER TABLE dbo.ChiTietGioHang DROP CONSTRAINT UQ_ChiTietGioHang;
    END

    -- 5. BẢO TOÀN RÀNG BUỘC GIỎ - KHÁCH 
    IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_GioHang_MaGioHang_KhachThue')
    BEGIN
        ALTER TABLE dbo.GioHang ADD CONSTRAINT UQ_GioHang_MaGioHang_KhachThue UNIQUE (MaGioHang, MaKhachThue);
    END
    
    -- Gỡ FK cũ trước khi tạo mới để tránh lỗi nếu đang trỏ trực tiếp
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_GiuCho_GioHang')
    BEGIN
        ALTER TABLE dbo.GiuCho DROP CONSTRAINT FK_GiuCho_GioHang;
    END
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_HopDong_GioHang')
    BEGIN
        ALTER TABLE dbo.HopDong DROP CONSTRAINT FK_HopDong_GioHang;
    END

    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_GiuCho_GioHang_KhachThue')
    BEGIN
        ALTER TABLE dbo.GiuCho ADD CONSTRAINT FK_GiuCho_GioHang_KhachThue 
            FOREIGN KEY (MaGioHang, MaKhachThue) REFERENCES dbo.GioHang(MaGioHang, MaKhachThue);
    END
    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_HopDong_GioHang_KhachThue')
    BEGIN
        ALTER TABLE dbo.HopDong ADD CONSTRAINT FK_HopDong_GioHang_KhachThue 
            FOREIGN KEY (MaGioHang, MaKhachThue) REFERENCES dbo.GioHang(MaGioHang, MaKhachThue);
    END

    -- 6. LIÊN KẾT CHÍNH XÁC CHI TIẾT GIỎ VỚI GIỮ CHỖ
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'ChiTietGiuCho' AND COLUMN_NAME = 'MaChiTietGioHang')
    BEGIN
        EXEC('ALTER TABLE dbo.ChiTietGiuCho ADD MaChiTietGioHang VARCHAR(20) NULL;');
    END
    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ChiTietGiuCho_ChiTietGioHang')
    BEGIN
        -- ON DELETE SET NULL để khi xóa dòng tạm, lịch sử ChiTietGiuCho không bị ảnh hưởng
        EXEC('ALTER TABLE dbo.ChiTietGiuCho ADD CONSTRAINT FK_ChiTietGiuCho_ChiTietGioHang 
            FOREIGN KEY (MaChiTietGioHang) REFERENCES dbo.ChiTietGioHang(MaChiTietGioHang) ON DELETE SET NULL;');
    END

    -- 7. BẢNG IDEMPOTENCY KEY
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'IdempotencyKey')
    BEGIN
        EXEC('CREATE TABLE dbo.IdempotencyKey (
            IdempotencyKey VARCHAR(100) NOT NULL,
            MaKhachThue VARCHAR(20) NOT NULL,
            LoaiThaoTac VARCHAR(50) NOT NULL,
            PayloadHash VARCHAR(64) NOT NULL,
            MaThucThe VARCHAR(50) NOT NULL,
            NgayTao DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
            
            CONSTRAINT PK_IdempotencyKey PRIMARY KEY (IdempotencyKey, MaKhachThue, LoaiThaoTac),
            CONSTRAINT FK_Idempotency_KhachThue FOREIGN KEY (MaKhachThue) REFERENCES dbo.KhachThue(MaKhachThue)
        );');
    END

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
