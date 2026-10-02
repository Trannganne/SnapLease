using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;

namespace RentalCamera.Api.Rental;

public sealed class AvailabilityService(RentalCameraContext db)
{
    // Tinh suc chua nho nhat trong TOAN BO khoang yeu cau, khong chi tai thoi diem bat dau.
    // Hold con han va hop dong dang hoat dong deu chiem capacity. Callers ghi du lieu
    // phai goi ham nay trong transaction SERIALIZABLE de tranh overbooking.
    public async Task<int> GetAvailableAsync(
        string storeId,
        string modelId,
        DateTime from,
        DateTime to,
        string? excludeHoldId,
        string? excludeContractId,
        CancellationToken ct)
    {
        const string sql = """
            WITH Capacity AS (
                SELECT COUNT(*) AS TongMay
                FROM ThietBi WITH (UPDLOCK, HOLDLOCK)
                WHERE MaCuaHang = @store
                  AND MaDongMay = @model
                  AND TrangThai IN ('SAN_SANG','DANG_GIU','DANG_THUE')
            ),
            LichChiem AS (
                SELECT ct.NgayBatDau AS BatDau, ct.NgayKetThuc AS KetThuc, ct.SoLuong
                FROM GiuCho gc WITH (UPDLOCK, HOLDLOCK)
                JOIN ChiTietGiuCho ct ON ct.MaGiuCho = gc.MaGiuCho
                WHERE gc.MaCuaHang = @store
                  AND ct.MaDongMay = @model
                  AND gc.TrangThai = 'DANG_GIU'
                  AND gc.HetHanLuc > SYSDATETIME()
                  AND (@excludeHold IS NULL OR gc.MaGiuCho <> @excludeHold)
                  AND ct.NgayBatDau < @toDate
                  AND ct.NgayKetThuc > @fromDate

                UNION ALL

                SELECT
                    ct.NgayBatDau AS BatDau,
                    CASE WHEN pl.ThoiHanGiaHan > hd.ThoiGianTraDuKien
                         THEN pl.ThoiHanGiaHan ELSE hd.ThoiGianTraDuKien END AS KetThuc,
                    ct.SoLuong
                FROM HopDong hd WITH (UPDLOCK, HOLDLOCK)
                JOIN ChiTietGiuCho ct ON ct.MaGiuCho = hd.MaGiuCho
                OUTER APPLY (
                    SELECT MAX(p.ThoiHanTraMoi) AS ThoiHanGiaHan
                    FROM PhuLuc p
                    WHERE p.MaHopDong = hd.MaHopDong AND p.TrangThai = 'DA_XAC_NHAN'
                ) pl
                WHERE hd.MaCuaHang = @store
                  AND ct.MaDongMay = @model
                  AND hd.TrangThai IN ('CHO_KY','DA_KY','CHO_BAN_GIAO','DANG_THUE','CHO_HOAN_TRA')
                  AND (@excludeContract IS NULL OR hd.MaHopDong <> @excludeContract)
                  AND ct.NgayBatDau < @toDate
                  AND (CASE WHEN pl.ThoiHanGiaHan > hd.ThoiGianTraDuKien
                            THEN pl.ThoiHanGiaHan ELSE hd.ThoiGianTraDuKien END) > @fromDate
            ),
            MocThoiGian AS (
                SELECT @fromDate AS ThoiDiem
                UNION
                SELECT BatDau FROM LichChiem
                WHERE BatDau > @fromDate AND BatDau < @toDate
            ),
            SucChuaTaiTungMoc AS (
                SELECT
                    m.ThoiDiem,
                    c.TongMay,
                    COALESCE(SUM(CASE
                        WHEN l.BatDau <= m.ThoiDiem AND l.KetThuc > m.ThoiDiem
                            THEN l.SoLuong ELSE 0 END), 0) AS SoMayBiChiem
                FROM MocThoiGian m
                CROSS JOIN Capacity c
                LEFT JOIN LichChiem l
                    ON l.BatDau <= m.ThoiDiem AND l.KetThuc > m.ThoiDiem
                GROUP BY m.ThoiDiem, c.TongMay
            )
            SELECT CASE
                WHEN MIN(TongMay - SoMayBiChiem) < 0 THEN 0
                ELSE MIN(TongMay - SoMayBiChiem)
            END AS Value
            FROM SucChuaTaiTungMoc
            """;

        var result = await db.Database.SqlQueryRaw<int>(sql,
                new SqlParameter("@store", storeId),
                new SqlParameter("@model", modelId),
                new SqlParameter("@fromDate", from),
                new SqlParameter("@toDate", to),
                new SqlParameter("@excludeHold", (object?)excludeHoldId ?? DBNull.Value),
                new SqlParameter("@excludeContract", (object?)excludeContractId ?? DBNull.Value))
            .ToListAsync(ct);
            
        return result.Single();
    }
}
