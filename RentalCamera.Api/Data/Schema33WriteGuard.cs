using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;

namespace RentalCamera.Api.Data;

// Application guard complements transaction/role checks. SQL verification is still required.
public static class Schema33WriteGuard
{
    public static void Validate(ChangeTracker tracker)
    {
        tracker.DetectChanges();
        foreach (var e in tracker.Entries())
        {
            if (e.Entity is QuyetToanHopDong && e.State is EntityState.Modified or EntityState.Deleted)
            {
                if (e.State == EntityState.Deleted || e.Properties.Any(p => p.IsModified &&
                    p.Metadata.Name is not (nameof(QuyetToanHopDong.HoanThanhLucUtc) or
                        nameof(QuyetToanHopDong.KhachXacNhanHoanTatLucUtc) or nameof(QuyetToanHopDong.NguoiXacNhanHoanTat))))
                    throw new InvalidOperationException("Bản quyết toán cuối bất biến.");
                FirstWriteOnly(e, nameof(QuyetToanHopDong.HoanThanhLucUtc));
                FirstWriteOnly(e, nameof(QuyetToanHopDong.KhachXacNhanHoanTatLucUtc));
                FirstWriteOnly(e, nameof(QuyetToanHopDong.NguoiXacNhanHoanTat));
            }
            if (e.Entity is PhanBoQuyetToan && e.State is EntityState.Modified or EntityState.Deleted)
                throw new InvalidOperationException("Nghĩa vụ/phân bổ đã ghi không được sửa hoặc xóa.");
            if (e.Entity is ThanhToan && e.State == EntityState.Modified)
            {
                foreach (var name in new[] { nameof(ThanhToan.NguoiXacNhanHoan), nameof(ThanhToan.XacNhanHoanLucUtc),
                    nameof(ThanhToan.NguoiXacNhanNhanHoan), nameof(ThanhToan.KhachXacNhanNhanHoanLucUtc) }) FirstWriteOnly(e, name);
                if (e.Property(nameof(ThanhToan.XacNhanHoanLucUtc)).OriginalValue != null && e.Properties.Any(p => p.IsModified &&
                    p.Metadata.Name is not (nameof(ThanhToan.NguoiXacNhanNhanHoan) or nameof(ThanhToan.KhachXacNhanNhanHoanLucUtc))))
                    throw new InvalidOperationException("Khoản đã hoàn không được thay tiền hoặc ngữ cảnh.");
            }
            if (e.Entity is DoiSoatHuyHopDong && e.State is EntityState.Modified or EntityState.Deleted)
            {
                if (e.State == EntityState.Deleted || e.Properties.Any(p => p.IsModified &&
                    !p.Metadata.Name.StartsWith("Tien", StringComparison.Ordinal) && p.Metadata.Name != nameof(DoiSoatHuyHopDong.DoiSoatHuyLucUtc)))
                    throw new InvalidOperationException("Không thay nguyên nhân/thời điểm/tỷ lệ hủy đã ghi.");
            }
        }
    }
    private static void FirstWriteOnly(EntityEntry entry, string name)
    {
        var p = entry.Property(name);
        if (p.IsModified && p.OriginalValue != null && !Equals(p.CurrentValue, p.OriginalValue))
            throw new InvalidOperationException("Mốc xác nhận đầu không được ghi đè.");
    }
}
