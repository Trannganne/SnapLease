using System.Security.Claims;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using RentalCamera.Api.Data;
using RentalCamera.Api.Infrastructure;

namespace RentalCamera.Api.Contracts;

public sealed class BranchWorkingHours(RentalCameraContext db)
{
    public async Task<DateTime?> AddWorkingHoursUtcAsync(string store,DateTime fromUtc,int hours,CancellationToken ct)
    {
        var intervals=await IntervalsAsync(store,fromUtc,ct);
        return AddHours(intervals,fromUtc,TimeSpan.FromHours(hours));
    }
    public static DateTime? AddHours(IEnumerable<(DateTime Start,DateTime End)> intervals,DateTime from,TimeSpan remaining)
    {
        foreach(var (opening,closing) in intervals.OrderBy(x=>x.Start)){
            var start=opening>from?opening:from;if(start>=closing)continue;
            if(closing-start>=remaining)return start.Add(remaining);
            remaining-=closing-start;
        }
        return null;
    }
    public async Task<bool> IsOpenAsync(string store,DateTime utc,CancellationToken ct)=>
        (await IntervalsAsync(store,utc,ct)).Any(x=>x.Start<=utc&&utc<x.End);
    public async Task<DateTime?> NextOpeningAsync(string store,DateTime utc,CancellationToken ct)
    {
        foreach(var (start,end) in await IntervalsAsync(store,utc,ct))if(end>utc)return start>utc?start:utc;
        return null;
    }
    private async Task<List<(DateTime Start,DateTime End)>> IntervalsAsync(string store,DateTime from,CancellationToken ct)
    {
        var first=DateOnly.FromDateTime(from.AddHours(7));var last=first.AddDays(370);
        var weekly=await db.LichLamViec.AsNoTracking().Where(x=>x.MaCuaHang==store||x.MaCuaHang=="*").ToListAsync(ct);
        var special=await db.LichLamViecDacBiet.AsNoTracking().Where(x=>x.MaCuaHang==store&&x.Ngay>=first&&x.Ngay<=last).ToDictionaryAsync(x=>x.Ngay,ct);
        var result=new List<(DateTime,DateTime)>();
        for(var day=first;day<=last;day=day.AddDays(1)){
            TimeOnly? open,close;
            if(special.TryGetValue(day,out var exception)){open=exception.GioMoCua;close=exception.GioDongCua;}
            else {var row=weekly.Where(x=>x.NgayTrongTuan==(int)day.DayOfWeek).OrderBy(x=>x.MaCuaHang==store?0:1).FirstOrDefault();open=row?.GioMoCua;close=row?.GioDongCua;}
            if(open is null||close is null)continue;
            result.Add((RentalPolicy.Utc(day.ToDateTime(open.Value)),RentalPolicy.Utc(day.ToDateTime(close.Value))));
        }
        return result;
    }
    public static void MapWorkingHoursEndpoints(IEndpointRouteBuilder app)
    {
        app.MapGet("/api/cua-hang/{id}/lich-lam-viec",async(string id,RentalCameraContext db,CancellationToken ct)=>Results.Ok(new{
            muiGio="Asia/Ho_Chi_Minh",tuan=await db.LichLamViec.AsNoTracking().Where(x=>x.MaCuaHang==id||x.MaCuaHang=="*").ToListAsync(ct),
            ngoaiLe=await db.LichLamViecDacBiet.AsNoTracking().Where(x=>x.MaCuaHang==id).ToListAsync(ct)}));
        app.MapPut("/api/cua-hang/{id}/lich-lam-viec/{ngay}",async(string id,DateOnly ngay,WorkingHoursException request,ClaimsPrincipal principal,RentalCameraContext db,CancellationToken ct)=>{
            if(string.IsNullOrWhiteSpace(request.LyDo)||request.LyDo.Length>500||request.GioMoCua.HasValue!=request.GioDongCua.HasValue || request.GioDongCua<=request.GioMoCua)return Results.BadRequest();
            if(!await db.CuaHang.AnyAsync(x=>x.MaCuaHang==id,ct))return Results.NotFound();
            await using var tx=await db.Database.BeginTransactionAsync(ct);await TransactionLock.AcquireAsync(db,"schedule:"+id,ct);
            var row=await db.LichLamViecDacBiet.SingleOrDefaultAsync(x=>x.MaCuaHang==id&&x.Ngay==ngay,ct);
            var before=row is null?null:JsonSerializer.Serialize(row);
            if(row is null){row=new(){MaCuaHang=id,Ngay=ngay};db.LichLamViecDacBiet.Add(row);}
            row.GioMoCua=request.GioMoCua;row.GioDongCua=request.GioDongCua;row.LyDo=request.LyDo.Trim();
            db.NhatKyNghiepVu.Add(new(){Id=ApiAccess.NewId("AU"),HanhDong="BRANCH_SCHEDULE",DoiTuongId=id,MaTaiKhoan=ApiAccess.AccountId(principal)!,
                ThoiGianUtc=DateTime.UtcNow,LyDo=row.LyDo,DuLieuJson=JsonSerializer.Serialize(new{before,after=row})});
            await db.SaveChangesAsync(ct);await tx.CommitAsync(ct);return Results.Ok(row);
        }).RequireAuthorization("Admin");
    }
}
public sealed record WorkingHoursException(TimeOnly? GioMoCua,TimeOnly? GioDongCua,string LyDo);
