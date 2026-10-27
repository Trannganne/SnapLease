using RentalCamera.Api.Contracts;
using RentalCamera.Api.Data;
using RentalCamera.Api.Rental;
using RentalCamera.Api.Payments;

#if !DIRECT_OFFLINE
if (args.Length == 2 && args[0] == "--model-output")
{
    Schema33EfChecks.Run(args[1]);
    return;
}
#endif

var count=0;
void Check(bool ok,string name){if(!ok)throw new Exception(name);count++;}
var now=new DateTime(2026,10,27,1,0,0,DateTimeKind.Utc);
var start=new DateTime(2026,11,10,8,0,0);
var end=start.AddDays(2);
var va=Guid.Parse("11111111-1111-1111-1111-111111111111");
var vb=Guid.Parse("22222222-2222-2222-2222-222222222222");
var a=new ChiTietGioHang{MaChiTietGioHang="CG_ORIG_A",MaGioHang="GH_ORIG",MaCuaHang="S1",MaDongMay="M1",SoLuong=2,PhienBan=va,NguonTao="GIO_HANG",NgayBatDau=start,NgayKetThuc=end};
var b=new ChiTietGioHang{MaChiTietGioHang="CG_ORIG_B",MaGioHang="GH_ORIG",MaCuaHang="S1",MaDongMay="M1",SoLuong=1,PhienBan=vb,NguonTao="GIO_HANG",NgayBatDau=start,NgayKetThuc=end};
var hold=new GiuCho{MaGiuCho="H1",MaGioHang="GH_ORIG",MaCuaHang="S1",TrangThai="DANG_GIU",HetHanLuc=now.AddMinutes(4)};
hold.ChiTiet.Add(new(){MaChiTietGiuCho="L1",MaGiuCho="H1",MaChiTietGioHang=a.MaChiTietGioHang,MaDongMay="M1",SoLuong=2,PhienBanGioHang=va,NgayBatDau=start,NgayKetThuc=end});
hold.ChiTiet.Add(new(){MaChiTietGiuCho="L2",MaGiuCho="H1",MaChiTietGioHang=b.MaChiTietGioHang,MaDongMay="M1",SoLuong=1,PhienBanGioHang=vb,NgayBatDau=start,NgayKetThuc=end});
Check(CartHoldEditing.ExpiryAfterEdit(hold,start,end,now)==hold.HetHanLuc,"No-op/branch-only retains TTL");
Check(CartHoldEditing.ExpiryAfterEdit(hold,start.AddHours(1),end.AddHours(1),now)==now.AddMinutes(20),"Real interval edit gets20m");
Check(CartHoldEditing.CanEdit(hold,now),"Active hold editable");
Check(!CartHoldEditing.CanEdit(hold,hold.HetHanLuc),"Exact expiry cannot revive");
hold.TrangThai="HET_HAN";Check(!CartHoldEditing.CanEdit(hold,now),"Expired state cannot revive");hold.TrangThai="DANG_GIU";
CartCheckoutItem[] requested=[new(a.MaChiTietGioHang,va),new(b.MaChiTietGioHang,vb)];
var selected=hold.ChiTiet.ToArray();
Check(CartHoldEditing.MatchesSnapshot(hold,selected,[a,b],requested),"Separate selections same model preserved");
Check(!CartHoldEditing.MatchesSnapshot(hold,selected,[a,b],[requested[0]]),"Subset rejected");
Check(!CartHoldEditing.MatchesSnapshot(hold,selected,[a,b],[requested[0],requested[0]]),"Duplicate selection rejected");
a.PhienBan=Guid.NewGuid();Check(!CartHoldEditing.MatchesSnapshot(hold,selected,[a,b],requested),"Stale version rejected");a.PhienBan=va;
a.DaChuyenHopDong=true;Check(!CartHoldEditing.MatchesSnapshot(hold,selected,[a,b],requested),"Converted original cannot reuse");a.DaChuyenHopDong=false;
a.MaCuaHang="S2";Check(!CartHoldEditing.MatchesSnapshot(hold,selected,[a,b],requested),"Branch mismatch rejected");a.MaCuaHang="S1";
Check(hold.ChiTiet.Sum(x=>x.SoLuong)==3,"Selection quantity counted once");
Check(RentalPolicy.CancellationRate(start,start.AddHours(-48))==0,"48h boundary");
Check(RentalPolicy.CancellationRate(start,start.AddHours(-48).AddTicks(1))==.30m,"Below48h");
Check(RentalPolicy.CancellationRate(start,start.AddHours(-24))==.30m,"24h boundary");
Check(RentalPolicy.CancellationRate(start,start.AddHours(-24).AddTicks(1))==1m,"Below24h");
Check(RentalPolicy.CancellationRate(start,start.AddHours(2))==1m,"After appointment before delivery");
Check(CancellationEndpoints.Amounts(3_000_000,1_000_000,500_000,.30m,false)==(900_000m,2_100_000m,1_000_000m,500_000m),"Deduct deposit only; rent/excess separate");
Check(CancellationEndpoints.Amounts(3_000_000,1_000_000,500_000,1m,true)==(0m,3_000_000m,1_000_000m,500_000m),"Approved exception refunds actual money");
Check(CancellationEndpoints.Amounts(0,0,0,1m,false)==(0m,0m,0m,0m),"Never invent uncollected deposit");
var due=new DateTime(2026,11,12,20,0,0);
var cutoff=RentalPolicy.Utc(due).AddHours(-24);
Check(RentalPolicy.CanRequestExtension(new("DANG_THUE",due,false),cutoff),"Extension exact24h allowed");
Check(!RentalPolicy.CanRequestExtension(new("DANG_THUE",due,false),cutoff.AddTicks(1)),"Less than24h rejected");
Check(!RentalPolicy.CanRequestExtension(new("DA_HUY",due,false),cutoff),"Canceled cannot extend");
Check(!RentalPolicy.CanRequestExtension(new("DANG_THUE",due,true),cutoff),"Returned cannot extend");
Check(RentalPolicy.SigningDeadline(now,due)==now.AddHours(2),"Extension signing2h not20m");
Check(RentalPolicy.SigningDeadline(RentalPolicy.Utc(due).AddHours(-1),due)==RentalPolicy.Utc(due),"Signing bounded by return");
var day=DateOnly.FromDateTime(start);
var intervals=Enumerable.Range(0,3).Select(i=>(RentalPolicy.Utc(day.AddDays(i).ToDateTime(new TimeOnly(8,0))),RentalPolicy.Utc(day.AddDays(i).ToDateTime(new TimeOnly(20,0)))));
Check(BranchWorkingHours.AddHours(intervals,RentalPolicy.Utc(day.ToDateTime(new TimeOnly(18,30))),TimeSpan.FromHours(4))==RentalPolicy.Utc(day.AddDays(1).ToDateTime(new TimeOnly(10,30))),"Working4h crosses night");
Check(RentalPolicy.LateDays(due,due.AddHours(23.999))==0,"Late below24h zero");
Check(RentalPolicy.LateDays(due,due.AddHours(24))==1,"Late exact24h one");
Check(RentalPolicy.LateDays(due,due.AddHours(24).AddMinutes(1))==2,"Late24h1m two");
var verify=new XacMinhKhachKhongDen{MaHopDong="HD1",NguoiXacMinh="STAFF",XacMinhLucUtc=now,LienHeLucUtc=now.AddMinutes(-1),GioHenKhiXacMinhKhongDen=start,KenhLienHe="PHONE",KetQuaLienHe="No answer",GhiChuKhongDen="Synthetic"};
var v=NoShowEndpoints.Version(verify);
verify.XacMinhLucUtc=DateTime.SpecifyKind(verify.XacMinhLucUtc,DateTimeKind.Unspecified);
verify.LienHeLucUtc=DateTime.SpecifyKind(verify.LienHeLucUtc,DateTimeKind.Unspecified);
Check(NoShowEndpoints.Version(verify)==v,"Version stable after datetime2 kind loss");
verify.CoTranhChapKhongDen=true;Check(NoShowEndpoints.Version(verify)!=v,"Changed facts invalidate version");
var payment=new ThanhToan{MaThanhToan="REF1",MaHopDong="HD1",LoaiThanhToan="HOAN_THU_THUA",SoTien=500_000};
var hash=RefundWorkflow.Hash(payment);payment.SoTien=500_001;
Check(hash!=RefundWorkflow.Hash(payment),"Refund acknowledgement binds exact amount");
Check(RefundWorkflow.IsRefund("HOAN_THU_THUA")&&!RefundWorkflow.IsRefund("THU_QUYET_TOAN"),"Refund distinct from collection");
#if DIRECT_OFFLINE
Console.WriteLine("NOT_RUN: EF mapping and exact33 schema.table checks skipped by DIRECT_OFFLINE.");
#else
Schema33EfChecks.Run();
#endif
Console.WriteLine($"PASS {count} source-level Schema33 checks; no database, app runtime or provider calls.");
