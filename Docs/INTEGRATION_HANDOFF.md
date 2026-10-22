# Backend handoff for Web and Mobile

This is the portable product handoff. Local recovery/deployment journals, test
fixtures, credentials and machine-specific execution history are not part of it.
Do not use a fresh checkout to replace an existing runtime or replay migrations
without an operator-reviewed deployment. Preparing these commits did not deploy.

## Configure and start a separate environment

- .NET8 / SQL Server2022 are used by the existing project and Dockerfile.
- Copy `.env.example` to a private `.env`. Set a strong SQL password, database
  name, Firebase project and external service-account file. Firebase Admin is
  required during startup even with push disabled. Never commit that file.
- For email signatures configure `EMAIL_*` and a private
  `ELECTRONIC_SIGNATURE_PEPPER`. Keep OTP response fallback false. Configure
  a valid TLS connection; the committed image has no Avast or other local CA.
  Do not bypass certificate validation when changing machines.
- Cloudinary upload needs the operator's private Cloudinary settings. Bank
  transfer needs all four `BANK_TRANSFER_*` values; there is no personal bank
  fallback. These integrations are not validated merely by starting Swagger.
- Provision/upgrade the database explicitly using [Database/README.md](../Database/README.md).
  Compose's `db-init` is a read-only schema readiness gate, not an initializer or
  a seed/migration executor. Do not run baseline/sample-data SQL on an existing DB.
- In an approved isolated environment, start SQL first, apply the reviewed SQL
  on dedicated connections, then start the API. Select a free `API_PORT` and
  project/container setup; never reuse someone else's API5000/5001 or volumes.
  Default port5000 is a sample mapping, not permission to modify any current API.
- Persist `.keys`, contract PDF files and storage across normal replacement.
  Configure `Cors:AllowedOrigins` for the actual Web origin. Do not copy private
  paths from another machine. `Rental__ProtectedContractIds` is an optional
  comma-separated preservation list; actual local contract IDs are not shipped.

`compose.yaml` and appsettings keep push and background jobs off by default.
There is no real secret, merchant registration, service account or customer data
in the supplied configuration samples. A runnable service still needs those
environment-owned settings and an appropriately provisioned database.

## Consumer API changes requiring Web review

Web source is not in this workspace and has not been built or exercised here.
These are source/API contracts that its owner must integrate and test. Obtain
the exact schemas from `/swagger/v1/swagger.json` on the intended runtime after
deployment; a matching Swagger page alone is not evidence of Web compatibility.

| Area | Routes / changes | Required consumer behavior |
|---|---|---|
| Cart | `GET /api/gio-hang`, POST/PUT `/chi-tiet`, DELETE `/chi-tiet/{id}?phienBan=...` under that prefix | Preserve Backend line IDs, GUID `phienBan`, branch, quantity, exact date/time, prices and validation errors. Never replace a server failure with local success. |
| Checkout | `POST /api/gio-hang/checkout` with `Idempotency-Key` and `items:[{id,phienBan}]`; `GET /api/gio-hang/checkout/{key}` | Persist the request key and reconcile uncertain outcomes with GET before any new write. A hold aggregates models but retains selected line versions in the separate selection table. |
| Edit live hold | `PUT /api/gio-hang/giu-cho/{id}` with `maCuaHang,ngayBatDau,ngayKetThuc,items:[{id,phienBan}]` | Existing owner/hold/version checks and transaction protect cart and hold together. Actual successful date/time change resets20 minutes from server time. Branch-only/no-op/read/failed update do not reset TTL. Use `hetHanLuc` plus `thoiGianServer`, including a newly received deadline. |
| Signing / PDF | Existing contract signing routes; `/api/hop-dong/{id}/noi-dung-da-ky`, `/tep-pdf`; signature request returns `emailNhan` | Read masked destination from `emailNhan`, server status and PDF metadata; parse ProblemDetails `title` as well as API error fields. Never regenerate a replacement signed PDF or replay OTP signing after an uncertain acknowledgement. |
| Cash and handover | POST `/api/hop-dong/{id}/thanh-toan-coc` with `phuongThuc:TIEN_MAT`; Staff POST `/api/thanh-toan/{id}/xac-nhan`; PUT `/api/hop-dong/{id}/thiet-bi`; POST `/{id}/ban-giao` | A pending cash request is not money received. Staff confirms the actual Backend amount; serial allocation produces CHO_BAN_GIAO, actual handover produces DANG_THUE. Do not infer either state just because a payment succeeded. |
| Renewal | GET `/api/hop-dong/{id}/du-kien-gia-han?thoiHanTraMoi=...`; POST `/{id}/yeu-cau-gia-han` with `thoiHanTraMoi,lyDoGiaHan,ghiChu`; Staff PUT `/api/gia-han/{id}/xu-ly` with `quyetDinh,ghiChu` | Submit only for eligible DANG_THUE, unreturned equipment and at least24h before effective due. DUYET leads to CHO_KY, not effective renewal. Customer PUTs appendix PDF, POSTs `/{id}/yeu-cau-ky`, then PUTs `/{id}/ky` with the returned confirmation ID, user OTP, content hash and consent. Only committed DA_HIEU_LUC changes effective due. |
| Cancellation | GET/POST `/api/hop-dong/{id}/huy-truoc-ban-giao`; Staff/Admin `/api/yeu-cau-huy/{id}/xu-ly`, reconciliation and evidenced refund confirmation | Distinguish request, approval, deductible, amounts to refund and actually confirmed refund. Only Admin changes cancellation deductions for an evidenced exception. Do not label pending refund as refunded. Existing CHO_KY self-cancel remains. |
| No-show / return correction | `/api/hop-dong/{id}/xac-nhan-khong-den`, `/api/yeu-cau-huy/{id}/de-nghi-ngoai-le`, PUT `/api/chi-tiet-hop-dong/{id}/thoi-gian-nhan` | No automatic cancellation based on time alone. Use evidence, branch/role authorization and reason/audit; actual-received-time correction is not a fee waiver. |
| Reviews | `POST /api/danh-gia`, GET `/bieu-mau/{maChiTietHopDong}`, uploads and own/public lists; Admin PUT `/{id}/kiem-duyet`, GET `/{id}/lich-su-hien-thi` | Newly valid reviews publish as CONG_KHAI. Legacy NULL/DA_DUYET remain public on reads; AN is hidden and unknown statuses must not be inferred public. Staff cannot hide/restore. Handle `REVIEW_ALREADY_EXISTS` and `CONTRACT_NOT_COMPLETED`; one review per contract detail. No review FCM event is added. |
| Notifications | `GET /api/thong-bao` with `daDoc,nhom,trang,kichThuocTrang`, GET `/{id}`, PUT `/{id}/da-doc`; register/delete under `/fcm-token` | `nhom` accepts HOP_DONG or THANH_TOAN. Use `duLieu,tongSo,chuaDoc` and actual `eventCode,targetType,targetId`; enforce ownership on every read/deep link. New event timestamps are UTC; legacy wall-clock rows have no invented offset. |
| VNPAY | Existing create-link, callback/IPN and reconciliation APIs | Stop automatic link POST after ambiguous errors. Verify server-persisted transaction state, signature/reference/amount/status and a valid nonzero numeric transaction number. Redirect UI success alone is not payment proof. Refunds do not use collection endpoints. |

Treat HTTP409/stale versions as a reconciliation requirement, not an invitation
to replay the same write. The concurrency middleware also maps SQL write conflicts
to a response clients must handle. Keep auth/branch/owner checks in the service.
Do not use global pending-appendix GET as a supposedly inert read: it may expire
old records within the caller's scope. Operate on the intended IDs.

## Financial policy and compatibility

- Terms version2026-10-20 is carried by new terms/PDFs; signed historical PDFs and
  unidentified legacy policies are not rewritten. Legacy1.0 appendix terms
  preserve unrelated original clauses, including agreed justified-reason cases.
- Branch schedule defaults to08:00-20:00 every day in Asia/Ho_Chi_Minh. Closed or
  special dates are explicit branch/date records, never inferred holidays.
- Renewal processing deadline is the earlier of4 branch working hours and current
  effective due minus2h. Signing deadline is2 continuous hours after approval,
  capped at current due. Approval alone does not update due or charge the fee.
- Extension price uses original contract-detail daily prices. The current flow
  settles extension charges at return; there is no separate pre-sign cash receipt
  step to mark paid. Do not collect or duplicate charges without a supported API.
- Cancellation deducts0% at>=48h before pickup,30% at24-48h,100% below24h, based on
  server request receipt and valid actually collected deposit. Overcollection is
  refunded fully, and prepaid rent/refund confirmation are tracked separately.
- New-policy late charge is per actually late serial: below24h zero days;
  otherwise `ceil(total late hours/24) * original daily price`. Thus24h=1day,
  24h1m=2days,48h=2days,49h=3days. Do not subtract24h first or multiply quantity
  twice. Before actual receipt it is an estimate. No discretionary late-fee waiver.
- Legacy extension requests missing the new signing/deadline evidence are not
  fabricated or auto-migrated. Admin may close the old workflow with reason/audit;
  a new Customer request must independently satisfy the24h condition.

## Automatic FCM and background work

Business SaveChanges creates the inbox/outbox transactionally for existing
contract/payment/renewal events. NotificationDeliveryWorker runs independently
of `Rental:BackgroundJobsEnabled`. Push=false leaves inbox records available and
does not itself replay pending records.

`Rental:BackgroundJobsEnabled` gates both ReservationExpirationService (holds
and pending-signature expiry) and ReturnReminderWorker (appendix expiry and
24h/2h/overdue/repeated return reminders). Leave it false when an environment has
unreviewed old records. It is not a switch for FCM alone.

For an explicitly scoped continuous test recipient use the existing
`Notifications:TestDelivery` guard, not an unrestricted worker:

- `Enabled=true`, `Mode=Continuous`, matching `AccountId`/`Notifications:TestAccountId`,
  intended `CustomerId`, verified `DeviceRegistrationId`, `DeviceTokenHash`, fixed
  `CutoverUtc` in round-trip UTC format, and the exact `EventCodes` allowlist in
  `TestPushDeliveryPolicy.cs`. Obtain identity/binding from the actual environment;
  no sample user, device or token is supplied. Invalid scope fails closed.
- Cutover is chosen once from reviewed server state before enabling; earlier
  pending notices/inbox/history remain unchanged and are not replayed by this
  scoped worker. Do not move it on restart or reset historical counters.
- Keep jobs=false and OTP fallback=false for this scope. Set PushEnabled=true
  only after reviewing the intended recipient/backlog; defaults stay false.
- Logout/rebind deactivates or pauses the corresponding association; sender checks
  current account/device before sending. A changed token/registration requires
  fresh binding confirmation. Never put registration tokens in logs or source.
- Scope retries explicit transient rejections with backoff; uncertain transport
  outcomes are not replayed automatically. Do not claim exactly-once delivery.
  The legacy unrestricted drain has different lease/retry behavior; enabling it
  requires its own pending/recipient review. No review event was invented.

## What has and has not been verified

Previous focused offline builds/regressions and isolated hold-edit API tests
exist for the implemented source. On the real Android device the user has
confirmed hold TTL/edit behavior, real email OTP contract signing, signed-PDF
view after refreshing detail, simulated cash deposit recording, Android FCM
receipt/deep link and matching awaiting-handover state. This does not prove Web
integration, every app-visibility case, a newly provisioned environment, or a full
signed renewal/return/refund flow.

Open issues retained for the next authorized development scope:

1. Direct successful signing -> PaymentPage may retain stale signed-PDF availability.
   Refresh the contract detail before opening its real signed PDF; do not re-sign.
2. Cash-request recorded-dialog title has low contrast on its white background.
3. A previous cold-start notification path required login; persistence is not
   claimed resolved. Customer refund-receipt confirmation has no dedicated API/UI.
4. Real-device effective appendix/renewal and final return/settlement remain unverified.
5. VNPAY Sandbox tunnel/IPN merchant registration and end-to-end payment remain
   pending; no fake callbacks or DB success flags form verification.

Local recipient IDs/preservation arrays, CA images, test/regression files and
deployment scripts remain local. The portable configuration replaces those data
values without modifying the running test image or the existing pending contract.
