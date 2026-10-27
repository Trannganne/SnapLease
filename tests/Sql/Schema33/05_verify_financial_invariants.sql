-- READ ONLY; execute only after permission to read SQL metadata. No data rows are selected.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() <> N'RentalCameraDb30_Test'
    THROW 53300, 'Only RentalCameraDb30_Test is permitted by this reviewed trial package.', 1;
IF CONVERT(nvarchar(128),SESSION_CONTEXT(N'Schema33.ExpectedDatabase')) IS NULL
 OR CONVERT(nvarchar(128),SESSION_CONTEXT(N'Schema33.ExpectedDatabase')) <> DB_NAME()
    THROW 53301, 'ExpectedDatabase session guard missing or different.', 1;
IF CONVERT(nvarchar(128),SESSION_CONTEXT(N'Schema33.ExpectedServer')) IS NULL
 OR CONVERT(nvarchar(128),SESSION_CONTEXT(N'Schema33.ExpectedServer')) <> CONVERT(nvarchar(128),SERVERPROPERTY('ServerName'))
    THROW 53302, 'ExpectedServer session guard missing or different.', 1;
IF CONVERT(nvarchar(30),SESSION_CONTEXT(N'Schema33.Environment')) IS NULL
 OR CONVERT(nvarchar(30),SESSION_CONTEXT(N'Schema33.Environment')) <> N'Schema33Trial'
    THROW 53303, 'Trial environment session guard missing.', 1;
-- Financial, ownership and history anomalies: returns rows requiring review, never repairs data.
SELECT q.Id IssueEntity,N'FINAL_MONEY_BALANCE' Issue FROM dbo.QuyetToanHopDong q WHERE q.ThuePhiDaThu+q.CocDaThu+q.ConPhaiThuBanDau<>q.TongNghiaVu+q.HoanCocBanDau+q.HoanKhacBanDau;
SELECT p.MaThanhToan IssueEntity,N'REFUND_ACK_WITHOUT_RECORDED_REFUND' Issue FROM dbo.ThanhToan p WHERE p.KhachXacNhanNhanHoanLucUtc IS NOT NULL AND (p.TrangThai<>'DA_HOAN' OR p.XacNhanHoanLucUtc IS NULL);
SELECT p.MaThanhToan IssueEntity,N'ACK_WRONG_OWNER' Issue FROM dbo.ThanhToan p JOIN dbo.HopDong h ON h.MaHopDong=p.MaHopDong JOIN dbo.KhachThue k ON k.MaKhachThue=h.MaKhachThue WHERE p.NguoiXacNhanNhanHoan IS NOT NULL AND p.NguoiXacNhanNhanHoan<>k.MaTaiKhoan;
SELECT q.Id IssueEntity,N'NO_REFUND_ACK_WRONG_OWNER' Issue FROM dbo.QuyetToanHopDong q JOIN dbo.HopDong h ON h.MaHopDong=q.MaHopDong JOIN dbo.KhachThue k ON k.MaKhachThue=h.MaKhachThue WHERE q.NguoiXacNhanHoanTat IS NOT NULL AND q.NguoiXacNhanHoanTat<>k.MaTaiKhoan;
SELECT h.MaHopDong IssueEntity,N'CANCEL_REPLACED_BY_COMPLETION' Issue FROM dbo.HopDong h JOIN dbo.DoiSoatHuyHopDong d ON d.MaHopDong=h.MaHopDong WHERE h.TrangThai<>'DA_HUY';
SELECT p.Id IssueEntity,N'ALLOCATION_OVER_CHARGE' Issue FROM dbo.PhanBoQuyetToan p WHERE p.LoaiDong='NGHIA_VU' AND (SELECT COALESCE(SUM(a.SoTien),0) FROM dbo.PhanBoQuyetToan a WHERE a.MaNghiaVu=p.Id AND a.LoaiDong='PHAN_BO')>p.SoTien;
SELECT t.MaThanhToan IssueEntity,N'ALLOCATION_OVER_PAYMENT' Issue FROM dbo.ThanhToan t WHERE (SELECT COALESCE(SUM(a.SoTien),0) FROM dbo.PhanBoQuyetToan a WHERE a.MaThanhToan=t.MaThanhToan AND a.LoaiDong='PHAN_BO')>t.SoTien;
SELECT p.Id IssueEntity,N'ALLOCATION_WRONG_OBLIGATION_KIND' Issue FROM dbo.PhanBoQuyetToan p JOIN dbo.PhanBoQuyetToan n ON n.Id=p.MaNghiaVu WHERE p.LoaiDong='PHAN_BO' AND (n.LoaiDong<>'NGHIA_VU' OR n.LoaiNghiaVu<>p.LoaiNghiaVu OR n.MaHopDong<>p.MaHopDong);
SELECT c.MaChiTietGiuCho IssueEntity,N'SNAPSHOT_NOT_CONTRACT_CART' Issue FROM dbo.ChiTietGiuCho c JOIN dbo.GiuCho g ON g.MaGiuCho=c.MaGiuCho JOIN dbo.HopDong h ON h.MaGiuCho=g.MaGiuCho LEFT JOIN dbo.ChiTietGioHang s ON s.MaChiTietGioHang=c.MaChiTietGioHangHopDong WHERE c.MaChiTietGioHangHopDong IS NULL OR s.MaGioHang<>h.MaGioHang;
SELECT c.MaChiTietHopDong IssueEntity,N'RECEIPT_CONTRACT_MISMATCH' Issue FROM dbo.ChiTietHopDong c JOIN dbo.BienBanNhanTra b ON b.Id=c.MaBienBanNhanTra WHERE b.MaHopDong<>c.MaHopDong;
SELECT q.Id IssueEntity,N'FINAL_RECEIPT_CONTRACT_MISMATCH' Issue FROM dbo.QuyetToanHopDong q JOIN dbo.BienBanNhanTra b ON b.Id=q.MaBienBan WHERE b.MaHopDong<>q.MaHopDong;
