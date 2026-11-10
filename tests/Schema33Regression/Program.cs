using RentalCamera.Api.Contracts;
using RentalCamera.Api.Data;
using RentalCamera.Api.Rental;
using RentalCamera.Api.Payments;
using RentalCamera.Api.Equipment;
using RentalCamera.Api.Identity;
using RentalCamera.Api.Handover;
using RentalCamera.Api.Admin;
using Microsoft.Extensions.Configuration;

#if !DIRECT_OFFLINE
if (args.Length == 1 && args[0] == "--registration-email-checks")
{
    await IdentityChecks.RunRegistrationAsync();
    return;
}
if (args.Length == 1 && args[0] == "--auth-email-checks")
{
    await ContractSmtpDemoChecks.RunAuthAsync();
    return;
}

if (args.Length == 1 && args[0] == "--identity-checks")
{
    await IdentityChecks.RunAsync();
    return;
}
if (args.Length == 1 && args[0] == "--contract-smtp-checks")
{
    await ContractSmtpDemoChecks.RunAsync();
    return;
}
if (args.Length == 2 && args[0] == "--model-output")
{
    Schema33EfChecks.Run(args[1]);
    return;
}
#endif

var count=0;
void Check(bool ok,string name){if(!ok)throw new Exception(name);count++;}
await ChatbotChecks.RunAsync();
Check(EmployeeEndpoints.IsContractInProgress("CHO_KY") &&
      EmployeeEndpoints.IsContractInProgress("DA_KY") &&
      EmployeeEndpoints.IsContractInProgress("CHO_BAN_GIAO") &&
      EmployeeEndpoints.IsContractInProgress("DANG_THUE") &&
      EmployeeEndpoints.IsContractInProgress("CHO_HOAN_TRA") &&
      !EmployeeEndpoints.IsContractInProgress("DA_HUY") &&
      !EmployeeEndpoints.IsContractInProgress("HOAN_THANH"),
    "Employee cannot leave while assigned contract work remains in progress");
var noPromotion = RentalPromotionPolicy.Evaluate(2, false);
Check(noPromotion.Percent == 0 && noPromotion.Codes.Length == 0, "Existing customer below three devices has no promotion");
var bulkPromotion = RentalPromotionPolicy.Evaluate(3, false);
Check(bulkPromotion.Percent == 10 && bulkPromotion.HasThreeOrMoreDevices && bulkPromotion.Apply(100_000) == 90_000,
    "Three-device rental receives ten percent promotion");
var newCustomerPromotion = RentalPromotionPolicy.Evaluate(1, true);
Check(newCustomerPromotion.Percent == 10 && newCustomerPromotion.IsNewCustomer,
    "New customer receives ten percent promotion");
var combinedPromotion = RentalPromotionPolicy.Evaluate(3, true);
Check(combinedPromotion.Percent == 10 && combinedPromotion.Codes.Length == 2 && combinedPromotion.Apply(100_000) == 90_000,
    "New-customer and three-device promotions do not stack above ten percent");
var contractLinePrice=ContractPricePresentation.ForLine(125_000m,100_000m,90_000m,2,3m);
Check(contractLinePrice.GiaGoc==125_000m &&
      contractLinePrice.PhanTramKhuyenMaiDaApDung==10m &&
      contractLinePrice.SoTienKhuyenMaiDaApDung==60_000m,
    "Contract detail exposes original price and the promotion captured at checkout");
var contractPromotion=ContractPricePresentation.ForContract(600_000m,540_000m);
Check(contractPromotion.PhanTramKhuyenMaiDaApDung==10m &&
      contractPromotion.SoTienKhuyenMaiDaApDung==60_000m,
    "Contract promotion summary uses immutable checkout totals");
var promotionStart = new DateTime(2026,11,6,8,0,0,DateTimeKind.Utc);
var promotionEnd = promotionStart.AddDays(2);
var timedModel = new DongMay
{
    MaDongMay="PROMO_MODEL", MaDanhMuc="DM", MaThuongHieu="TH", TenDongMay="Timed promotion",
    GiaThueNgay=1_000_000m, TienCoc=1_000_000m, PhanTramGiamGia=10m,
    TGBatDau=promotionStart, TGKetThuc=promotionEnd
};
Check(RentalPromotionPolicy.EffectiveCatalogPercent(timedModel,promotionStart.AddTicks(-1))==0m,
    "Timed catalog promotion is inactive before its start");
Check(RentalPromotionPolicy.EffectiveCatalogPercent(timedModel,promotionStart)==10m &&
      RentalPromotionPolicy.EffectiveCatalogPrice(timedModel,promotionStart)==900_000m,
    "Timed catalog promotion starts inclusively and computes the discounted price");
Check(RentalPromotionPolicy.EffectiveCatalogPercent(timedModel,promotionEnd.AddTicks(-1))==10m,
    "Timed catalog promotion remains active immediately before its end");
Check(RentalPromotionPolicy.EffectiveCatalogPercent(timedModel,promotionEnd)==0m &&
      RentalPromotionPolicy.EffectiveCatalogPrice(timedModel,promotionEnd)==1_000_000m,
    "Expired catalog promotion returns rental and renewal quotes to the original price");
timedModel.TGBatDau=null;
timedModel.TGKetThuc=null;
Check(RentalPromotionPolicy.EffectiveCatalogPercent(timedModel,promotionEnd)==10m,
    "Legacy catalog discount without a time window remains active");
timedModel.TGBatDau=promotionStart;
Check(RentalPromotionPolicy.EffectiveCatalogPercent(timedModel,promotionStart)==0m,
    "Incomplete catalog promotion window fails closed");
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
var directVersion=Guid.NewGuid();
var direct=new ChiTietGioHang{MaChiTietGioHang="CG_DIRECT",MaGioHang="GH_DIRECT",MaCuaHang="S1",MaDongMay="M1",SoLuong=1,PhienBan=directVersion,NguonTao="THUE_NGAY",NgayBatDau=start,NgayKetThuc=end};
var directHold=new GiuCho{MaGiuCho="H_DIRECT",MaGioHang="GH_DIRECT",MaCuaHang="S1",TrangThai="DANG_GIU",HetHanLuc=now.AddMinutes(10)};
directHold.ChiTiet.Add(new(){MaChiTietGiuCho="L_DIRECT",MaGiuCho="H_DIRECT",MaChiTietGioHang=direct.MaChiTietGioHang,MaDongMay="M1",SoLuong=1,PhienBanGioHang=directVersion,NgayBatDau=start,NgayKetThuc=end});
CartCheckoutItem[] directRequest=[new(direct.MaChiTietGioHang,directVersion)];
Check(CartHoldEditing.MatchesSnapshot(directHold,directHold.ChiTiet.ToArray(),[direct],directRequest),"Direct-rental hold can use the existing versioned edit workflow");
direct.NguonTao="UNKNOWN";
Check(!CartHoldEditing.MatchesSnapshot(directHold,directHold.ChiTiet.ToArray(),[direct],directRequest),"Unknown selection source cannot edit hold");
direct.NguonTao="THUE_NGAY";direct.DaChuyenHopDong=true;
Check(!CartHoldEditing.MatchesSnapshot(directHold,directHold.ChiTiet.ToArray(),[direct],directRequest),"Converted direct-rental selection cannot edit hold");
direct.DaChuyenHopDong=false;direct.PhienBan=Guid.NewGuid();
Check(!CartHoldEditing.MatchesSnapshot(directHold,directHold.ChiTiet.ToArray(),[direct],directRequest),"Stale direct-rental version is rejected");
var riskConfig = new ConfigurationManager();
riskConfig["Rental:BufferMinutes"] = "120";
riskConfig["Rental:StandardMaxQuantity"] = "10";
riskConfig["Rental:HighValueMaxQuantity"] = "3";
riskConfig["Rental:HighValueDepositThreshold"] = "10000000";
riskConfig["Rental:ReserveMinimumPerModel"] = "1";
Check(RentalRiskPolicy.BufferMinutes(riskConfig)==120,"Rental availability buffer is configurable at two hours");
Check(RentalRiskPolicy.Evaluate([(20_000_000m,2),(10_000_000m,1)],riskConfig).Allowed,
    "Three high-value devices across separate cart lines are allowed");
var tooManyHighValue=RentalRiskPolicy.Evaluate([(20_000_000m,2),(10_000_000m,2)],riskConfig);
Check(!tooManyHighValue.Allowed&&tooManyHighValue.HighValueQuantity==4,
    "High-value limit is aggregate across models and rejects the fourth device");
Check(RentalRiskPolicy.Evaluate([(9_999_999m,10)],riskConfig).Allowed,
    "Deposit below the configured threshold keeps the standard quantity limit");
Check(!RentalRiskPolicy.Evaluate([(1_000_000m,11)],riskConfig).Allowed,
    "Standard devices still respect the configured maximum quantity");
var scheduledReturn=new DateTime(2026,11,11,7,0,0);
Check(RentalRiskPolicy.OccupiedUntil(scheduledReturn,null,"DANG_THUE",scheduledReturn.AddHours(-1),riskConfig)==scheduledReturn.AddHours(2),
    "On-time rental reserves the configured two-hour turnaround buffer");
Check(RentalRiskPolicy.OccupiedUntil(scheduledReturn,null,"DANG_THUE",scheduledReturn,riskConfig)==DateTime.MaxValue,
    "Overdue unreturned rental stays unavailable without a guessed end time");
var actualReturn=scheduledReturn.AddMinutes(30);
Check(RentalRiskPolicy.OccupiedUntil(scheduledReturn,actualReturn,"CHO_HOAN_TRA",actualReturn,riskConfig)==actualReturn.AddHours(2),
    "Actual return restarts the turnaround buffer from receipt time");
Check(RentalRiskPolicy.ReserveMinimumPerModel(riskConfig)==1,
    "Reserve minimum per branch/model is configurable");
Check(ReserveDevicePolicy.CanSwap("CHO_BAN_GIAO",null),
    "Reserve swap is allowed before physical handover");
Check(!ReserveDevicePolicy.CanSwap("DANG_THUE",null)&&!ReserveDevicePolicy.CanSwap("CHO_BAN_GIAO",now),
    "Reserve swap cannot rewrite a renting or delivered contract");
Check(ReserveDevicePolicy.IsIncidentState("BAO_TRI")&&ReserveDevicePolicy.IsIncidentState("HONG")&&
    !ReserveDevicePolicy.IsIncidentState("DANG_THUE"),
    "Reserve swap accepts only maintenance or damaged disposition for the old serial");
Check(ReserveDevicePolicy.IsBelowMinimum(0,1)&&!ReserveDevicePolicy.IsBelowMinimum(1,1),
    "Reserve alert fires only below the configured safe minimum");
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
Check(RentalPolicy.LateDays(due,due.AddHours(-1))==0,"Early return zero");
Check(RentalPolicy.LateDays(due,due.AddHours(2))==0,"Late exact2h free");
Check(RentalPolicy.LateDays(due,due.AddHours(2).AddMinutes(1))==1,"Late2h1m one day");
Check(RentalPolicy.LateDays(due,due.AddHours(24))==1,"Late exact24h one");
Check(RentalPolicy.LateDays(due,due.AddHours(24).AddMinutes(1))==2,"Late24h1m two");
Check(RentalPolicy.UsesCurrentLateReturnPolicy(RentalPolicy.TermsVersion,true),"Current accepted terms use new late policy");
Check(!RentalPolicy.UsesCurrentLateReturnPolicy(RentalPolicy.PreviousTermsVersion,true),"Previous signed terms are not migrated");
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
var historyPayments = new[]
{
    new ThanhToan { MaThanhToan="PAY_DEPOSIT", MaHopDong="HD1", LoaiThanhToan="TIEN_COC", TrangThai="THANH_CONG", SoTien=1_250_000m },
    new ThanhToan { MaThanhToan="PAY_RENT", MaHopDong="HD1", LoaiThanhToan="TIEN_THUE", TrangThai="THANH_CONG", SoTien=250_000m },
    new ThanhToan { MaThanhToan="PAY_EXTENSION", MaHopDong="HD1", LoaiThanhToan="PHI_GIA_HAN", TrangThai="THANH_CONG", SoTien=125_000m },
    new ThanhToan { MaThanhToan="PAY_FAILED", MaHopDong="HD1", LoaiThanhToan="PHI_PHAT", TrangThai="THAT_BAI", SoTien=500_000m },
    new ThanhToan { MaThanhToan="REFUND", MaHopDong="HD1", LoaiThanhToan="HOAN_COC", TrangThai="THANH_CONG", SoTien=1_250_000m }
};
Check(RentalHistoryPolicy.TotalPaid(historyPayments)==1_625_000m,
    "Rental history totals only successful collected payments and excludes failed/refund rows");
var identity=new GiayToTuyThan{TrangThaiXacMinh="HOP_LE"};
Check(ContractEndpoints.IsIdentityVerifiedForRental(identity),"Verified identity can create rental contract");
identity.TrangThaiXacMinh="CHO_XAC_MINH";
Check(!ContractEndpoints.IsIdentityVerifiedForRental(identity),"Pending identity cannot create rental contract");
identity.TrangThaiXacMinh="TU_CHOI";
Check(!ContractEndpoints.IsIdentityVerifiedForRental(identity),"Rejected identity cannot create rental contract");
Check(HandoverEndpoints.CanCustomerConfirm("DANG_THUE", 1, 0)
      && !HandoverEndpoints.CanCustomerConfirm("CHO_BAN_GIAO", 1, 0)
      && !HandoverEndpoints.CanCustomerConfirm("DANG_THUE", 0, 0)
      && !HandoverEndpoints.CanCustomerConfirm("DANG_THUE", 1, 1),
    "Customer handover confirmation requires a renting contract and complete physical handover");
#if DIRECT_OFFLINE
Console.WriteLine("NOT_RUN: EF mapping and exact33 schema.table checks skipped by DIRECT_OFFLINE.");
#else
await SettlementLifecycleChecks.RunAsync();
Schema33EfChecks.Run();
#endif
Console.WriteLine($"PASS {count} source-level Schema33 checks; no database, app runtime or provider calls.");
