# Backend integration: deposit payments, VNPAY and current handover APIs

Branch: `integration/rental-signing-payment`, remote `origin`.
This update shares source and isolated tests. It does not deploy containers or change any database.
Keep credentials in your local environment; examples below contain placeholders only.

## What changed

- `POST /api/hop-dong/{contractId}/thanh-toan-coc`: creates a pending deposit, protected
  by a Serializable transaction against duplicate pending/successful deposits. Bank-transfer
  creation requires all receiver configuration fields. The receiver is snapshotted when issued.
- `GET /api/hop-dong/{contractId}/thanh-toan` and `GET /api/thanh-toan/{paymentId}`:
  existing payment fields remain; receiver fields `nganHang`, `maBin`, `soTaiKhoan`,
  `chuTaiKhoan` and optional `thongBao` are added. Receiver fields are null for other methods.
- `POST /api/thanh-toan/{paymentId}/vnpay`: stores an attempt and its reference, reuses
  an active link and blocks a new request while an earlier outcome is unresolved.
- `POST /api/thanh-toan/{paymentId}/vnpay/doi-soat`: authenticated reconciliation using
  QueryDR. Verifies merchant/reference/signature/amount/type before applying a result.
  Gateway calls occur outside the DB transaction; final updates use transaction/locking.
  HTTP 429 rate limit is one request per five minutes for the client-IP/payment key.
- IPN verifies merchant/signature and correlates attempts. Successful parent payments
  are preserved when a late attempt fails; an additional successful attempt is flagged
  `LaThuThua`, not added again to the parent payment amount. Automatic refund is not added.
- Return validates and redirects/returns existing DB status. Browser/deep-link parameters
  do not establish successful payment. QueryDR includes the required User-Agent and uses
  the original issued-link timestamp when available to handle SQL datetime2 losing Kind.
- `Vnpay.BankCode` is optional; the gateway bank choice is no longer forced in service code.

Payment endpoints require access to the contract: its customer, active staff from its store,
or ADMIN. Staff confirmation `/api/thanh-toan/{paymentId}/xac-nhan` remains staff-only.
Pending cash is not a confirmed payment. Payment status and contract status are independent.

### Request/response examples

Create a deposit on an eligible signed contract:

```http
POST /api/hop-dong/{contractId}/thanh-toan-coc
Content-Type: application/json
```

```json
{ "phuongThuc": "CHUYEN_KHOAN", "noiDungChuyenKhoan": "<transfer description>" }
```

Accepted methods are `TIEN_MAT`, `CHUYEN_KHOAN`, `VI_DIEN_TU`; amount comes from Backend.
HTTP 201 includes fields such as:

```json
{
  "maThanhToan": "<paymentId>", "maHopDong": "<contractId>", "soTien": 1000000,
  "loaiThanhToan": "TIEN_COC", "phuongThuc": "CHUYEN_KHOAN",
  "trangThai": "CHO_THANH_TOAN", "nganHang": "<bank>", "maBin": "<bankBin>",
  "soTaiKhoan": "<receiverAccount>", "chuTaiKhoan": "<receiverName>"
}
```

The object has additional existing payment fields; clients should tolerate nullable fields.
GET payment-list returns an array of this DTO. GET contract detail still returns its
`thanhToan` collection through its existing contract response; use the payment endpoints
for the enriched transfer receiver DTO.

`POST /api/thanh-toan/{paymentId}/vnpay` and `/vnpay/doi-soat` have no request body.
Link response includes `paymentUrl`, `reused`, `maThamChieu`, `thoiGianHetHan` and
`phuongThuc: VNPAYQR`; do not log complete payment URLs or callback query strings.
Reconciliation returns `thanhCong`, `trangThai`, `maThanhToan`, optional `maGiaoDich`/
`maPhanHoi`, and `thongBao`. HTTP 409 unresolved can include `chuaXacDinh`, `chiTiet`,
`maPhanHoi`, `trangThaiGiaoDichVnpay`; retain the canonical payment status from a fresh GET.

### Error handling and current limits

- 401/403: authentication/ownership/store scope; 404: missing payment/contract.
- 400: unsupported method or wrong gateway payment type; 409: contract state, duplicate
  deposit, provider conflict, unresolved/expired request or invalid reconciliation outcome.
- 500: missing/incomplete bank receiver configuration; 503: VNPAY not configured;
  429: reconciliation rate limit. Handle non-JSON errors as well as `{loi: ...}`.
- After checking a pending VNPAY payment, GET its canonical status, reconcile only when
  appropriate, then GET again. Never create another charge merely to recover a callback.
- Some definitive failed-attempt responses can still leave the parent payment pending;
  the legacy-link guard can block a subsequent link. This retry path has not been validated
  end-to-end and is not advertised as complete. Do not retry by bypassing the guard.
- IPN URL configuration does not register it with the gateway. Merchant registration and
  real IPN delivery are separate checks. Offline tests do not verify either.

## Schema prerequisites: review before enabling VNPAY on another database

The new code references `dbo.YeuCauThanhToanVnpay`, related to `ThanhToan.MaThanhToan`.
Expected columns: MaYeuCau, MaThanhToan, MaThamChieu, SoTien, TienTe,
DuongDanThanhToan, ThoiGianHetHan, TrangThai, LaThuThua, MaGiaoDich, MaNganHang,
LoaiThe, MaPhanHoi, GhiChu, ThoiGianTao, ThoiGianCapNhat; unique MaThamChieu.
Entity/mapping are shared; schema creation is not automatic at startup.

The local test DB previously verified this table. Script 09 is test-DB-specific and is
excluded from this source delivery because approval for other environments is not established.
An absent table will break VNPAY attempt/reconciliation paths. Have the Backend/DB owner
approve a target-specific migration before enabling those paths; do not reset/seed the DB.
No migration command is prescribed here and no migration was run in this task.
The earlier local commits also contain schema 07 (payment columns) and 08 (multiple contracts
per cart). Their presence in Git is not proof they have been approved/applied on your DB.

## Configuration without secrets

Supply local environment values for `BankTransfer__NganHang`, `BankTransfer__MaBin`,
`BankTransfer__SoTaiKhoan`, `BankTransfer__ChuTaiKhoan`; shared defaults do not contain
receiver details. Compose uses the corresponding `BANK_TRANSFER_*` environment variables.
Set `Vnpay__Enabled`, `Vnpay__TmnCode`, `Vnpay__HashSecret`, `Vnpay__ReturnUrl`,
`Vnpay__IpnUrl`, `Vnpay__MobileCallbackUrl` locally. Optional `Vnpay__BankCode` and
`Vnpay__QueryDrUrl` use your approved gateway setup. No session Quick Tunnel domain is shared.
Provide connection strings/passwords, JWT/signature/SMTP credentials locally; do not commit them.
The existing `.env.example` in published history contains a SQL password value used locally;
this update removes the value from the template. It does not remove old history or rotate
the actual runtime credential. Credential rotation requires separate coordination.

## Handover: existing behavior, no implementation changes in this update

`PUT /api/hop-dong/{contractId}/thiet-bi`, staff/admin and store scope:

```json
{ "maThietBi": ["<deviceId1>", "<deviceId2>"] }
```

Requires DA_KY, no prior details, ready devices from the correct store/models, exact quantities
and no conflicting assigned schedule. Returns 200/CHO_BAN_GIAO, devices DANG_GIU.

`POST /api/hop-dong/{contractId}/ban-giao`, staff/admin and store scope:

```json
{ "thietBi": [
  { "maChiTietHopDong": "<detailId1>", "tinhTrang": "<observed condition and items supplied>" },
  { "maChiTietHopDong": "<detailId2>", "tinhTrang": "<observed condition and items supplied>" }
] }
```

Current source requires CHO_BAN_GIAO, at least one successful deposit and a condition item
for each detail. Returns 200/DANG_THUE, changes devices, records actual dates. It does NOT yet
ensure enough deposit/rent, minimum photos, timing policy, exact-set input validation, audit
of the actual operator or safe concurrency over the final read/check/write sequence.
Those improvements and any required handover schema are not implemented by this delivery.
Do not interpret a successful current response as proof the new policies were enforced.

Read `GET /api/hop-dong/{contractId}` for all booked models/quantities and assigned details
(serial, condition, actual dates, `anhBienBan`). `GET .../ban-giao` has handover details but
does not aggregate images. Both use contract ownership/store access. Contract pickup time
is scheduled; `chiTiet[].ngayGiaoThucTe` is actual. Preserve the agreed due date.
Photo registration exists at `POST /api/chi-tiet-hop-dong/{detailId}/anh-bien-ban`:

```json
{ "loai": "BAN_GIAO", "duongDanAnh": "<existing real image URL>", "moTa": "<description>" }
```

It registers a URL, not a multipart upload. No customer handover confirmation endpoint/button
is added. Mobile displays the Backend result after staff handover.

## Build/test and teammate update

Use .NET SDK 8. Isolated tests: `dotnet run --project tests/VnpayRegression` and
`dotnet run --project tests/PaymentDtoRegression`. They use synthetic fixtures, no DB/gateway.
The older API scripts on this branch may write test data or target another port; do not run
them against a shared database as part of updating source.

Before updating, inspect/save your own local changes and select the correct integration branch:

```sh
git status
git fetch origin
git switch integration/rental-signing-payment
git pull --ff-only origin integration/rental-signing-payment
```

If the branch is absent locally, use `git switch --track origin/integration/rental-signing-payment`
after saving local work. If fast-forward fails, stop and coordinate; do not reset/force overwrite.
Source pushed, the author's running API, and your own running API are separate states.
Updating Git does not rebuild/restart your container, apply schema or configure credentials.

### Validation for this delivery

The exact staged source/configuration was exported to an ignored review directory and built
with the existing .NET SDK 8 Docker image. Restore used NuGet/cache with unchanged package
versions; dependency advisory audit was disabled for this compilation check. API build:
0 errors and 0 compiler warnings. VnpayRegression: 9 passed; PaymentDtoRegression: 6 passed.
No API service was started, no migration/shared-DB test or real gateway call was performed.
Staged diff --check passed; staged-content scan found no matching local credentials/receiver
values, JWT literals, personal contract/payment IDs, session tunnel URLs or build artifacts.
This is not an end-to-end/gateway or deployment validation.

The branch also had six existing local commits ahead of its upstream before this delivery:

| Commit | Existing change |
|---|---|
| f2590d5 | Multiple contracts per cart and hold-to-contract concurrency |
| b707196 | SMTP OTP delivery and signature hashing |
| 3bca856 | Contract-list store/device/quantity fields |
| 8c14fe8 | QUOTED_IDENTIFIER for the VNPAY filtered index |
| 0913672 | API integration-test scripts using generated test fixtures |
| 2d10425 | Required ElectronicSignature:Pepper; removed public fallback |

Those earlier integration scripts were reviewed but not executed against a shared DB.
