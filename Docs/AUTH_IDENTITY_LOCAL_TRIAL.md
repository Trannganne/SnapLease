# Auth email and identity: local Schema33 trial

The API remains `http://127.0.0.1:5003`, bound only to the Windows loopback interface.
No SQL/schema/seed/manifest changes, public tunnel or VNPay request are required.
Offline tests are preparation evidence. Real email delivery, Android link opening and
real CCCD capture require the operator's own test; do not claim those steps passed from a fake test.

## Implementation and configuration

The old backend's forgot-password code issued a token and optionally returned it;
it did not contain an auth SMTP sender. This trial keeps Schema33 `AuthLinkService`
(purpose, expiry, account security epoch and password fingerprint), verified-email
requirements and the existing DTOs. Auth and signing reuse the same existing
`SmtpContractOtpEmailSender` SMTP/TLS transport. Auth has a separate opt-in and uses
the already approved signing recipient allowlist; it never substitutes the recipient.
Global provider mode stays `Fake`; signing's keyed SMTP provider remains enabled.

The secret-free defaults are in `appsettings.Schema33Trial.example.json`:

```json
"AuthEmail": {
  "Mode": "Fake",
  "SmtpApproved": false,
  "LinkBaseUrl": "http://127.0.0.1:5003/auth-link"
}
```

Only for the approved private local trial, prepare using the existing launcher:

```powershell
.\runtime\schema33-phone\Start-SmtpDemo.ps1 -Action Prepare -EnableAuthEmail `
  -AuthLinkBaseUrl 'http://127.0.0.1:5003/auth-link'
```

This sets only private `AuthEmail` configuration and makes a private rollback copy.
It requires existing DPAPI SMTP/Pepper and approved signing SMTP. No secret is
created, rotated, embedded in source or printed. Tokens/OTP must never be returned
to Flutter as a fake fallback. The real recipient currently allowed on the operator's
machine is `trngan0708@gmail.com`; another address needs explicit approval.

`/auth-link` is a static, no-store local page with no third-party resources or analytics.
The token is in the URL fragment, not the HTTP query. The page clears its URL and
opens `rentalcamera://auth-link/verify-email` or `/reset-password` only when the user
presses **Mở SnapLease**. Android receives only these exact host/path filters.
Flutter removes the fragment from navigation, keeps the token in memory, and waits
for the user's explicit verify/reset button. Opening an email/link never mutates auth state.

## Operator: real email test

1. Keep the trial API/SQL healthy and connect the Android phone by USB. Use
   `adb -s R5GL66JBAEA reverse tcp:5003 tcp:5003`; preserve other mappings.
2. Log in as the customer who owns the allowlisted mailbox. Account shows the email
   actually returned by the server. Do not change another account or impersonate it.
   If no email exists, the owner may use existing Swagger `PUT /api/auth/email`
   with `{ "email": "<their approved email>" }`, then log in again. This is a user action.
3. Account → **Xác minh email** → **Gửi liên kết xác minh**. Open the received email
   on the connected phone → **Mở SnapLease** → **Xác minh email**. Log in again.
   An already verified address does not receive another verification link. A mailbox
   already verified on a different account is a blocker; do not clear its verification in SQL.
4. Login → **Quên mật khẩu**. Enter that verified email. `202` is deliberately generic;
   it is not proof that an eligible account exists or that SMTP delivered mail.
5. Open the reset email on the phone, choose **Mở SnapLease**, enter/confirm a new
   password (8–128 characters, uppercase/lowercase/digit/special), and submit once.
   Only `204` is success. Old sessions become invalid; log in yourself with the new password.
6. Missing/expired links and used reset tokens require a new link. An already verified
   email may return idempotent `204` without another state write. Respect server `429`/`Retry-After`.
   On reset/verification timeout, the result is unknown; check by logging in or request
   a new link manually. Never edit SQL flags or retry mutations automatically.

No agent should send email, verify a link, reset a real password or record a test pass
on the user's behalf. Keep auth tokens/passwords out of screenshots, chat and logs.

## Operator: real CCCD capture and approval

Registration and `PUT /api/auth/email` now reject another account's mailbox even
when it is unverified (`409`, `EMAIL_ALREADY_USED`). Both paths normalize and lock
the mailbox within their existing SQL transaction machinery. Existing accounts
sharing an email are retained. Keeping the same normalized email does not reset
verification. Forgot/reset still select the verified mailbox/account and retain
the existing token, purpose, expiration and security-epoch checks. Offline handler
tests use scripted transactions; they do not establish SQL Server concurrency safety.

The old implementation is two-sided CCCD capture → on-device OCR/QR → customer
reviews/consents → authenticated image upload/profile confirmation → staff approval.
There is no selfie, face matching or liveness provider. OCR success is not identity approval.
Schema33 reuses `KhachThue` and `GiayToTuyThan`; no extra table/column is used.

1. Customer: Account → **Thông tin cá nhân & Giấy tờ**. Allow camera access, capture
   front/back, or cancel/retake. Review all extracted fields before confirming.
   Camera denied: enable Camera in Android Settings and retry. Unreadable photos/OCR
   must be retaken; never enter a fabricated successful result.
   This screen first reads the server profile/documents. An already confirmed
   profile is displayed immediately, including when its document is still pending;
   opening it does not upload again. A previously uploaded pending document with
   the same number can finish profile confirmation using its existing ID/images;
   the review explicitly states that its stored images are retained. There is no
   image replacement endpoint, and no silent replacement of approved documents.
2. On confirmation, server creates an owned `CHO_XAC_MINH` document and stores
   images in the existing private Storage with authenticated owner/Admin/branch access.
   Customer-confirmed fields do not turn that document into `HOP_LE`.
   The rental confirmation can be revisited with the same live matching hold,
   selection and quote; creating the contract still requires staff-approved
   `HOP_LE`. An expired/mismatched/syncing hold blocks continuation. No hold is
   extended or created by identity confirmation. Unknown upload outcomes trigger
   GET readback and block blind retries; a matching number alone is not upload proof.
3. Staff/Admin logs into local Swagger using the published trial fixture
   `trial33.admin` / `TrialOnly!2026a` (standard login/Authorize, no role changes).
   `GET /api/giay-to/cho-xac-minh` lists permitted pending documents. Select the correct
   customer's document, inspect both images and the actual information yourself.
   View each image through Swagger `GET /api/giay-to/anh/{fileName}` with Authorize;
   opening a bare image URL in a new browser tab does not attach its Bearer token.
4. Only the operator sends `PUT /api/giay-to/{maGiayTo}/xac-minh` with
   `{ "ketQua": "HOP_LE", "ghiChu": "<actual inspection note>" }`, or `TU_CHOI` with
   the actual reason. Staff needs the existing customer/cart branch scope; Admin
   may review customers with no branch/cart. Never approve blindly.
5. Return to Account or pull to refresh. Its latest-document status must come from
   server. Avatar remains the uppercase first grapheme of username.

Image/number mismatches, foreign documents and duplicate uploads are rejected.
After an uncertain upload, read the existing profile/documents before resubmitting;
do not create another document blindly. The schema's unique document number remains
enforced; rejected-document resubmission must not bypass that history/constraint.

## Another machine and rollback

- Keep its own approved Schema33 DB/container/image identities, SQL volume, private
  storage/PDF directories and Data Protection keys. Do not point this launcher at a
  public/backend-old DB or copy backend-old secrets. This machine's container IDs
  and DPAPI files are not portable installation credentials.
- Start from the secret-free example; provision private SMTP/SQL credentials with
  hidden input under the owning Windows user. DPAPI files cannot simply be copied
  between machines/users. Preserve the existing Pepper/keys when retaining signed
  data; do not generate replacement keys to make guards pass.
- Set `AuthEmail:LinkBaseUrl` for that approved local trial. Services do not hardcode
  localhost globally. This opt-in guard accepts only the approved loopback bridge;
  another public/web deployment requires its own approved URL/link association.
  Existing Flutter web auth routes remain usable; this USB bridge targets Android,
  not an unverified web host. No additional package or Android autoVerify domain is assumed.
- Run launcher as its actual owner using `-ExpectedWindowsIdentity 'MACHINE\USER'`.
  First bind/review that machine's trial container IDs/volumes with the existing
  preparation procedure; mismatched guards must block deployment, not be removed.
- Offline restore/build/tests must pass. Publish to a new empty directory, check every
  exit code, and compare the published API DLL hash with the tested DLL. If callback
  proxy is stopped, validate its config with a one-shot `nginx -t`, no ports/tunnel.
- Deployment keeps the previous API container for rollback and existing SQL/storage/
  PDF/keys mounts. Restore the old API container and private auth-config backup if needed;
  do not delete volumes, uninstall the app or clear app data. Install updates with `adb install -r`.

## Recorded preparation on 2026-10-30

- API deployed on the approved local port; a real read of `/api/cua-hang` succeeded
  against `RentalCameraDb30_Test`. SQL container/volume identity was retained.
- All seven publish gates passed; runtime DLL hash matches the tested/published DLL.
- 93 Flutter checks passed; targeted analyze is clean. Backend: 19 identity checks,
  15 auth/crypto/provider checks, 47 signing/appendix SMTP checks, plus the existing
  Schema33 and settlement regression checks passed offline. They are not real-mail/
  real-document/SQL transaction validation.
- STARTTLS with the existing CA bundle passed and a wrong hostname was rejected.
  This probe used no SMTP AUTH or mail commands; actual delivery still needs the user.
- APK installed on `R5GL66JBAEA` with `adb install -r`. Installed APK hash matches
  the build; reverse 5003 is present, other observed mappings were preserved.
  Exact auth intent paths are registered and an unrelated auth path is not.
- Credentials, Pepper, Data Protection keys, CA, non-auth configuration, SQL/seed/
  manifest hashes and callback routing were retained. VNPay proxy/tunnel stayed stopped.
- Read-only account metadata found `trial33.customer01` active, with the allowlisted
  email **not yet verified** and one existing identity document. Its published fixture
  password is `TrialOnly!2026a` if the owner has not changed it. An existing document/
  verification label is not evidence that the new real-CCCD capture flow passed.
  Use an appropriate empty customer profile for an independent identity test when
  the existing customer's profile/history must remain untouched; account creation is
  the user's action, and document-number/verified-email uniqueness still applies.
- No agent email request, email confirmation, password reset, photo capture/upload
  or staff identity approval was sent. The app was not launched by the installer.

Evidence is in `evidence/auth-identity-live-20261030`: `publish-verified.json`,
`deployment.json`, `runtime-readiness.json`, `phone-install.json`, `smtp-tls.json`,
and the passing test/analyze/build logs. Original pre-feature rollback container:
`schema33-phone-api-before-20261030114227`; the immediately previous auth build is
`schema33-phone-api-before-20261030115459`. Private auth-config rollback copies remain
under the protected runtime directory, never in Git.

Changed code responsibilities:

| Area | Files |
| --- | --- |
| Auth API/link page | `RentalCamera.Api/Auth/AuthEndpoints.cs` |
| Shared SMTP and auth adapter | `RentalCamera.Api/Email/SmtpContractOtpEmailSender.cs`, `RestrictedContractOtpEmailSender.cs` |
| Opt-in/DI/example | `RentalCamera.Api/Infrastructure/Schema33TrialGuard.cs`, `Program.cs`, `appsettings.Schema33Trial.example.json` |
| Identity ownership/validation | Existing pending changes in `RentalCamera.Api/Identity/IdentityEndpoints.cs`, now included in the tested deployment |
| Backend offline harness | `tests/Schema33Regression/IdentityChecks.cs`, `ContractSmtpDemoChecks.cs`, `Program.cs` |
| Flutter auth/link/session UI | Existing `features/auth/data/auth_repository.dart`, `password_recovery` Cubit/page, `app/router/app_router.dart`, Android manifest |
| Account/CCCD | Existing account page, identity Bloc/repository/scanner/camera/QR page; the username avatar and server-owned status remain in use |
| Flutter checks | `test/password_recovery_test.dart`, `test/account_identity_test.dart` |
| Runtime | Existing `Start-SmtpDemo.ps1`, `Publish-VnpaySandbox.ps1`, `Build-CashPhone.ps1`; isolated verification/publish runners under the current artifact directory |

No new SMTP transport, OCR cloud provider, parallel identity module or package was added.
