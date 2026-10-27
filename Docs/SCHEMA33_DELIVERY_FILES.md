# Danh sách bàn giao Backend33 sau dọn

## Current Git handoff decision (supersedes the cleanup-only deletion proposal)

This independent branch is `feature/backend-schema33-handoff` from baseline `4f4d4af0155b84dd850d16c0b25702d02965bf73`. All103 approved files are included; only their actual ADD/MODIFY changes will be staged in this worktree. The original working tree/index/stash/branch remain untouched. Only the11 documented whitespace errors and handoff documentation were adjusted after copying the trial files.

No tracked legacy file is deleted: the15 previous deletion proposals are NOT APPLIED, and the8 inherited REVIEW guides remain unchanged from baseline. The whitelist limits NEW changes; it does not remove inherited files. The final tree contains148 files:103 core +45 inherited baseline files. All45 are enumerated in SCHEMA33_SQL_INVENTORY.md with their usage restrictions. Do not deploy33 using inherited Compose, root SQL, old sample data/test scripts or old setup guides.

Credential literals in the6 inherited scripts were verified as synthetic registration/login fixture inputs for UUID-named accounts, not runtime-extracted/provider secrets. All148 prospective files and the XML content of2 inherited DOCX were inspected statically; no real secret was identified. No secret was deleted from Git history or treated as removed by a new commit. Archive/evidence/private runtime files are outside the Git worktree and outside the commit.

BUILD PASS is recorded before cleanup (.NET SDK8.0.425). BUILD AFTER CLEANUP NOT_RUN; DATABASE NOT_RUN; API SMOKE NOT_RUN; REGRESSION NOT_RUN. No commit or push is authorized before the owner's final approval.

Backend:193 ->151 files. SQL:33 ->9 (6 KEEP +3 REVIEW). Markdown:41 ->26 (8 KEEP +18 REVIEW). Archived outside backend:42 files =24 SQL +15 MD +3 artifacts. No permanent deletion.

BUILD PASS (.NET SDK8.0.425) is RECORDED BEFORE CLEANUP; build was NOT rerun. DATABASE NOT_RUN; API SMOKE NOT_RUN; REGRESSION NOT_RUN. No commit/merge/push. The original index/stash is preserved; staging is restricted to this independent worktree. The source trial has no .git.

## Current handoff and default push candidates

The103 core files below form the standalone source/setup/API handoff. Git labels compare the trial files to the original repository HEAD; they are proposals only. No files were staged. Source-only cleanup does not establish database/API readiness. Final Git audit corrects the table using the repository clean/text normalization (core.autocrlf=true):49 ADD,31 MODIFY,23 UNCHANGED.17 previous MODIFY labels were line-ending-only differences; byte SHA256 differences do not imply commit changes.

| File from backend | Proposed Git state |
|---|---|
| `.dockerignore` | ADD |
| `.gitignore` | MODIFY |
| `Database/README.md` | MODIFY |
| `Database/Schema33/00_preflight.sql` | ADD |
| `Database/Schema33/01_schema33.sql` | ADD |
| `Database/Schema33/02_seed_catalog.sql` | ADD |
| `Database/Schema33/04_verify_schema.sql` | ADD |
| `Database/Schema33/05_verify_seed_catalog.sql` | ADD |
| `Database/Schema33/Invoke-Schema33Package.ps1` | ADD |
| `Database/Schema33/README.md` | ADD |
| `Database/Schema33/approval.template.json` | ADD |
| `Database/Schema33/constraints.json` | ADD |
| `Database/Schema33/expected-metadata.json` | ADD |
| `Database/Schema33/package-manifest.json` | ADD |
| `Database/Schema33/schema.json` | ADD |
| `Database/Schema33/seed-catalog.json` | ADD |
| `Docs/SCHEMA33_API_CHANGES.md` | ADD |
| `Docs/SCHEMA33_DELIVERY_FILES.md` | ADD |
| `Docs/SCHEMA33_HANDOFF.md` | ADD |
| `Docs/SCHEMA33_SQL_INVENTORY.md` | ADD |
| `NuGet.Config` | UNCHANGED |
| `README.md` | MODIFY |
| `RentalCamera.Api/Auth/AuthEndpoints.cs` | MODIFY |
| `RentalCamera.Api/Auth/AuthLinkService.cs` | ADD |
| `RentalCamera.Api/Auth/BearerTokenHandler.cs` | MODIFY |
| `RentalCamera.Api/Auth/PasswordPolicy.cs` | UNCHANGED |
| `RentalCamera.Api/Auth/PasswordResetTokenService.cs` | UNCHANGED |
| `RentalCamera.Api/Catalog/CatalogEndpoints.cs` | MODIFY |
| `RentalCamera.Api/Chatbot/ChatContracts.cs` | ADD |
| `RentalCamera.Api/Chatbot/ChatEndpoints.cs` | ADD |
| `RentalCamera.Api/Chatbot/ChatKnowledge.cs` | ADD |
| `RentalCamera.Api/Chatbot/ChatPrivacy.cs` | ADD |
| `RentalCamera.Api/Chatbot/ChatService.cs` | ADD |
| `RentalCamera.Api/Chatbot/EfChatCatalog.cs` | ADD |
| `RentalCamera.Api/Chatbot/GroqChatProvider.cs` | ADD |
| `RentalCamera.Api/Contracts/BranchWorkingHours.cs` | MODIFY |
| `RentalCamera.Api/Contracts/CancellationEndpoints.cs` | MODIFY |
| `RentalCamera.Api/Contracts/ContractFlowEndpoints.cs` | MODIFY |
| `RentalCamera.Api/Contracts/ContractPdfService.cs` | UNCHANGED |
| `RentalCamera.Api/Contracts/ContractSignatureService.cs` | UNCHANGED |
| `RentalCamera.Api/Contracts/LateReturnService.cs` | UNCHANGED |
| `RentalCamera.Api/Contracts/NoShowEndpoints.cs` | MODIFY |
| `RentalCamera.Api/Contracts/RenewalEndpoints.cs` | MODIFY |
| `RentalCamera.Api/Contracts/RentalPolicy.cs` | MODIFY |
| `RentalCamera.Api/Contracts/ReturnTimeCorrectionEndpoints.cs` | MODIFY |
| `RentalCamera.Api/Data/RentalCameraContext.cs` | MODIFY |
| `RentalCamera.Api/Data/RentalModels.cs` | MODIFY |
| `RentalCamera.Api/Data/Schema33Mapping.cs` | ADD |
| `RentalCamera.Api/Data/Schema33WriteGuard.cs` | ADD |
| `RentalCamera.Api/Data/SettlementEntities.cs` | ADD |
| `RentalCamera.Api/Dockerfile` | UNCHANGED |
| `RentalCamera.Api/Email/EmailOptions.cs` | UNCHANGED |
| `RentalCamera.Api/Email/FakeTrialSender.cs` | ADD |
| `RentalCamera.Api/Email/IContractOtpEmailSender.cs` | UNCHANGED |
| `RentalCamera.Api/Email/SmtpContractOtpEmailSender.cs` | UNCHANGED |
| `RentalCamera.Api/Equipment/EquipmentEndpoints.cs` | UNCHANGED |
| `RentalCamera.Api/Handover/HandoverEndpoints.cs` | MODIFY |
| `RentalCamera.Api/Handover/ReturnWorkflow.cs` | ADD |
| `RentalCamera.Api/Identity/IdentityEndpoints.cs` | UNCHANGED |
| `RentalCamera.Api/Infrastructure/ApiAccess.cs` | UNCHANGED |
| `RentalCamera.Api/Infrastructure/ConcurrencyResponse.cs` | UNCHANGED |
| `RentalCamera.Api/Infrastructure/ContractOperation.cs` | ADD |
| `RentalCamera.Api/Infrastructure/Schema33TrialGuard.cs` | ADD |
| `RentalCamera.Api/Infrastructure/TransactionLock.cs` | UNCHANGED |
| `RentalCamera.Api/Knowledge/catalog-evidence.vi.json` | ADD |
| `RentalCamera.Api/Knowledge/faq.vi.json` | ADD |
| `RentalCamera.Api/Media/CloudinaryImageStorage.cs` | MODIFY |
| `RentalCamera.Api/Media/CloudinaryOptions.cs` | UNCHANGED |
| `RentalCamera.Api/Media/TrialMediaStorage.cs` | ADD |
| `RentalCamera.Api/Notifications/FcmTokenEndpoints.cs` | UNCHANGED |
| `RentalCamera.Api/Notifications/FirebaseNotificationSender.cs` | MODIFY |
| `RentalCamera.Api/Notifications/NotificationDeliveryWorker.cs` | UNCHANGED |
| `RentalCamera.Api/Notifications/NotificationEndpoints.cs` | UNCHANGED |
| `RentalCamera.Api/Notifications/NotificationEvents.cs` | UNCHANGED |
| `RentalCamera.Api/Notifications/ReturnReminderWorker.cs` | UNCHANGED |
| `RentalCamera.Api/Notifications/TestPushDeliveryPolicy.cs` | MODIFY |
| `RentalCamera.Api/Payments/RefundWorkflow.cs` | ADD |
| `RentalCamera.Api/Payments/VnpayEndpoints.cs` | MODIFY |
| `RentalCamera.Api/Payments/VnpayOptions.cs` | MODIFY |
| `RentalCamera.Api/Payments/VnpayService.cs` | MODIFY |
| `RentalCamera.Api/Penalties/PenaltyEndpoints.cs` | MODIFY |
| `RentalCamera.Api/Program.cs` | MODIFY |
| `RentalCamera.Api/Rental/AvailabilityService.cs` | MODIFY |
| `RentalCamera.Api/Rental/CartEndpoints.cs` | MODIFY |
| `RentalCamera.Api/Rental/CartHoldEditing.cs` | MODIFY |
| `RentalCamera.Api/Rental/RentalFlowEndpoints.cs` | MODIFY |
| `RentalCamera.Api/Rental/ReservationExpirationService.cs` | UNCHANGED |
| `RentalCamera.Api/RentalCamera.Api.csproj` | MODIFY |
| `RentalCamera.Api/Reports/ReportEndpoints.cs` | UNCHANGED |
| `RentalCamera.Api/Reviews/ReviewEndpoints.cs` | MODIFY |
| `RentalCamera.Api/Settlement/SettlementDocument.cs` | ADD |
| `RentalCamera.Api/Settlement/SettlementEndpoints.cs` | MODIFY |
| `RentalCamera.Api/Settlement/SettlementViewService.cs` | ADD |
| `RentalCamera.Api/Settlement/SettlementWorkflow.cs` | ADD |
| `RentalCamera.Api/appsettings.Schema33Trial.example.json` | ADD |
| `tests/Schema33Regression/EfModelChecks.cs` | ADD |
| `tests/Schema33Regression/Program.cs` | ADD |
| `tests/Schema33Regression/Schema33Regression.csproj` | ADD |
| `tests/Sql/Schema33/03_seed_workflows.json` | ADD |
| `tests/Sql/Schema33/05_verify_financial_invariants.sql` | ADD |
| `tests/Sql/Schema33/README.md` | ADD |
| `tests/Sql/Schema33/capacity-expectations.json` | ADD |
| `tests/Sql/Schema33/fixture-manifest.json` | ADD |

## KEEP / ARCHIVE / REVIEW for all Markdown

KEEP denotes current entry points. REVIEW documents retain unique detailed API/business/provider guidance; they are not default33 deployment instructions and must not be auto-published/staged. Only headers and links were maintained; original business text remains. Archived originals and exact hashes are listed in [the registry](SCHEMA33_SQL_INVENTORY.md).

| Markdown from backend | Decision | Basis |
|---|---|---|
| `Database/README.md` | KEEP | Current33 entry point/installation/API/fixture guide. |
| `Database/Schema33/README.md` | KEEP | Current33 entry point/installation/API/fixture guide. |
| `Docs/API5001_AUTOMATIC_FCM.md` | ARCHIVE | Historical recipient/runtime deployment instructions; general FCM contract remains in FIREBASE_FCM_BACKEND and INTEGRATION_HANDOFF. |
| `Docs/API5001_CONTINUOUS_DEMO.md` | ARCHIVE | Bound API5001 demo run, not a33 deployment guide; detailed API guides retained. |
| `Docs/API5001_DEPLOYMENT_PLAN.md` | ARCHIVE | Historical approved manifests/deployments for DB20/API5001; no33 startup dependency. |
| `Docs/API_CART_HOLD_EDIT.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `Docs/API_DANH_GIA.md` | ARCHIVE | Obsolete chip/CHO_DUYET/Staff moderation contract replaced by current review source and retained API_REVIEW_PUBLICATION plus SCHEMA33_API_CHANGES. |
| `Docs/API_FIGMA_MOBILE.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `Docs/API_QUEN_MAT_KHAU.md` | ARCHIVE | Obsolete phone/reset-token-response procedure replaced by verified-email flow in current AuthEndpoints and SCHEMA33_API_CHANGES. |
| `Docs/API_RETURN_SETTLEMENT.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `Docs/API_REVIEW_PUBLICATION.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `Docs/API_XAC_THUC.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `Docs/BACKEND_CHANGELOG_MOBILE_INTEGRATION.md` | ARCHIVE | Historical implementation/deployment checkpoints; API/biz detail retained in current and REVIEW guides. |
| `Docs/BUSINESS_RULES_AND_CONTRACT_VERSION.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `Docs/CHATBOT_MAPBOX_HANDOFF.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `Docs/CHECKLIST_BAN_GIAO_DIEN_THOAI.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `Docs/CHECKOUT_REPAIR_REVIEW.md` | ARCHIVE | Historical fix uses removed selection table; original/version/snapshot33 mapping and API_CART_HOLD_EDIT retained. |
| `Docs/DEVICE_OTP_FCM_TEST_PLAN.md` | ARCHIVE | Past bounded device test/deployment plan, not a33 API contract; FCM/signature guides retained. |
| `Docs/E2E_TEST_CHECKLIST.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `Docs/FAQ_CHATBOT_DRAFT.md` | ARCHIVE | All5 answers and8 terms match Knowledge/faq.vi.json and RentalPolicy.Terms exactly; gate/config notes remain in CHATBOT_MAPBOX_HANDOFF. |
| `Docs/FIREBASE_FCM_BACKEND.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `Docs/GUI_OTP_KY_HOP_DONG_QUA_EMAIL.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `Docs/HANDOFF_REVIEW_PUBLICATION.md` | ARCHIVE | Old implementation checkpoint superseded by current review source and retained publication guide. |
| `Docs/INTEGRATION_HANDOFF.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `Docs/INTEGRATION_PAYMENT_HANDOVER.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `Docs/MOBILE_CASH_RENEWAL_RUNBOOK.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `Docs/RESTORE_GUIDE.md` | ARCHIVE | Recovery guide for earlier API5001 images/DB20 backups; current trial recovery boundary is in Schema33 README. |
| `Docs/SCHEMA33_API_CHANGES.md` | KEEP | Current33 entry point/installation/API/fixture guide. |
| `Docs/SCHEMA33_DELIVERY_FILES.md` | KEEP | Current33 entry point/installation/API/fixture guide. |
| `Docs/SCHEMA33_HANDOFF.md` | KEEP | Current33 entry point/installation/API/fixture guide. |
| `Docs/SCHEMA33_SQL_INVENTORY.md` | KEEP | Current33 entry point/installation/API/fixture guide. |
| `Docs/SQL_POLICY_REVIEW_20261021.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `Docs/STAGING_ALIGNMENT_MATRIX.md` | ARCHIVE | Previous staging/DB20 runtime comparison, superseded for trial setup by SCHEMA33 handoff; original copy untouched. |
| `Docs/TICH_HOP_BAN_GIAO_MOBILE_SWAGGER.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `Docs/UPLOAD_ANH_BIEN_BAN_CLOUDINARY.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `Docs/VNPAY_SANDBOX.md` | REVIEW | Contains detailed business/API/provider/testing guidance not fully transferred/validated for33; retained, not a default deployment guide. |
| `HANDOFF_BAN_GIAO.md` | ARCHIVE | Old device/runtime checkpoint; handover API detail remains in TICH_HOP_BAN_GIAO_MOBILE_SWAGGER and INTEGRATION_PAYMENT_HANDOVER. |
| `HANDOFF_VNPAY.md` | ARCHIVE | Specific historical payment/hostname recovery with private run identifiers; VNPAY contract remains in VNPAY_SANDBOX and code. |
| `HUONG_DAN_CHAY_DOCKER_CHO_THANH_VIEN.md` | ARCHIVE | Old Compose bootstrap/reset procedure replaced by SCHEMA33_HANDOFF and installation README. |
| `README.md` | KEEP | Current33 entry point/installation/API/fixture guide. |
| `tests/Sql/Schema33/README.md` | KEEP | Current33 entry point/installation/API/fixture guide. |

## Historical tracked-removal proposal - NOT APPLIED on this handoff branch

These files were removed only from the cleaned source trial and have verified archive copies. The current handoff deliberately retains their HEAD-baseline copies unchanged, as requested. No delete or legacy-doc maintenance outside the103-file whitelist is included. The table below is historical context, not the current commit plan.

| Path | Proposal |
|---|---|
| `Database/01_schema.sql` | RETAINED BASELINE; no deletion |
| `Database/02_sample_data.sql` | RETAINED BASELINE; no deletion |
| `Database/06_add_electronic_signature.sql` | RETAINED BASELINE; no deletion |
| `Database/07_add_vnpay_payment.sql` | RETAINED BASELINE; no deletion |
| `Database/08_add_firebase_notifications.sql` | RETAINED BASELINE; no deletion |
| `Database/08_remove_giohang_unique_hopdong.sql` | RETAINED BASELINE; no deletion |
| `Database/09_add_review_details.sql` | RETAINED BASELINE; no deletion |
| `Database/09_add_vnpay_attempts.sql` | RETAINED BASELINE; no deletion |
| `Database/10_review_publication.sql` | RETAINED BASELINE; no deletion |
| `Database/11_mobile_workflows.sql` | RETAINED BASELINE; no deletion |
| `Database/12_cart_hold_selection.sql` | RETAINED BASELINE; no deletion |
| `Database/migration_thue_ngay_final.sql` | RETAINED BASELINE; no deletion |
| `Docs/API_DANH_GIA.md` | RETAINED BASELINE; no deletion |
| `Docs/API_QUEN_MAT_KHAU.md` | RETAINED BASELINE; no deletion |
| `HUONG_DAN_CHAY_DOCKER_CHO_THANH_VIEN.md` | RETAINED BASELINE; no deletion |

Archived files that were not in the original HEAD should simply stay out of the new handoff; they are not Git deletion hunks. The archive registry lists every removed trial file and its hash.

## REVIEW and exclusions from automatic push

All REVIEW files stay in the trial. Keep them outside the103-file automatic whitelist until their older contract/runtime/private context is reviewed. This includes2 DOCX and3 legacy SQL, in addition to18 Markdown. Do not delete them merely to reduce the count.

| Retained path | Push disposition |
|---|---|
| `Database/00_mobile_preflight.test.sql` | REVIEW; not auto-stage/publish |
| `Database/03_update_cloudinary_images.sql` | REVIEW; not auto-stage/publish |
| `Database/04_add_home_contract_test_data.sql` | REVIEW; not auto-stage/publish |
| `Docs/API_CART_HOLD_EDIT.md` | REVIEW; not auto-stage/publish |
| `Docs/API_FIGMA_MOBILE.md` | REVIEW; not auto-stage/publish |
| `Docs/API_RETURN_SETTLEMENT.md` | REVIEW; not auto-stage/publish |
| `Docs/API_REVIEW_PUBLICATION.md` | REVIEW; not auto-stage/publish |
| `Docs/API_XAC_THUC.md` | REVIEW; not auto-stage/publish |
| `Docs/BUSINESS_RULES_AND_CONTRACT_VERSION.md` | REVIEW; not auto-stage/publish |
| `Docs/CHATBOT_MAPBOX_HANDOFF.md` | REVIEW; not auto-stage/publish |
| `Docs/CHECKLIST_BAN_GIAO_DIEN_THOAI.md` | REVIEW; not auto-stage/publish |
| `Docs/E2E_TEST_CHECKLIST.md` | REVIEW; not auto-stage/publish |
| `Docs/FIREBASE_FCM_BACKEND.md` | REVIEW; not auto-stage/publish |
| `Docs/GUI_OTP_KY_HOP_DONG_QUA_EMAIL.md` | REVIEW; not auto-stage/publish |
| `Docs/INTEGRATION_HANDOFF.md` | REVIEW; not auto-stage/publish |
| `Docs/INTEGRATION_PAYMENT_HANDOVER.md` | REVIEW; not auto-stage/publish |
| `Docs/MOBILE_CASH_RENEWAL_RUNBOOK.md` | REVIEW; not auto-stage/publish |
| `Docs/SQL_POLICY_REVIEW_20261021.md` | REVIEW; not auto-stage/publish |
| `Docs/TICH_HOP_BAN_GIAO_MOBILE_SWAGGER.md` | REVIEW; not auto-stage/publish |
| `Docs/Tai lieu ban giao Backend API Rental Camera.docx` | REVIEW; not auto-stage/publish |
| `Docs/Tai lieu tich hop Backend API Rental Camera.docx` | REVIEW; not auto-stage/publish |
| `Docs/UPLOAD_ANH_BIEN_BAN_CLOUDINARY.md` | REVIEW; not auto-stage/publish |
| `Docs/VNPAY_SANDBOX.md` | REVIEW; not auto-stage/publish |

Final audit disposition for the8 tracked REVIEW documents below: none is required by the standalone103-file source/setup/API package. Keep their business content in the trial/original and exclude them from the proposed handoff payload. They are already tracked in the current HEAD, so omitting them from a staging list does NOT remove them from the target branch. Their disposition is now explicit: retain the baseline copies unchanged as legacy references, outside the103-file current setup contract. This supersedes the earlier cleanup audit blocker. If a later integration retains them, their historical setup references must be reviewed with the deletion plan; no automatic deletion or whole-document staging is authorized here:

- `Docs/API_FIGMA_MOBILE.md`
- `Docs/API_XAC_THUC.md`
- `Docs/FIREBASE_FCM_BACKEND.md`
- `Docs/GUI_OTP_KY_HOP_DONG_QUA_EMAIL.md`
- `Docs/INTEGRATION_HANDOFF.md`
- `Docs/INTEGRATION_PAYMENT_HANDOVER.md`
- `Docs/UPLOAD_ANH_BIEN_BAN_CLOUDINARY.md`
- `Docs/VNPAY_SANDBOX.md`

Never push archive/before-edit backups, cleanup evidence/diffs, .env, live/private appsettings, SQL connections, signing/DataProtection keys, service-account files, real business data/media, runtime directories, bin/obj, test output or author-machine build/generator scripts. The obsolete Roslyn DLL/generated obj source were archived. There are no live credentials/configuration files in the core whitelist; its synthetic fixture values are explicitly labelled.

## Optional fixture companion (outside cleanup scope)

The prior3 companion files under tools/schema33-db-package-20261027 remain unchanged, optional and uncompiled/unexecuted. They are not required for building/installing the core. No tools file was changed by this cleanup. Fixture manifest paths preserve the relative backend/tools layout.

The detailed audit, archive/source hashes, Git snapshot, changes and dependency edges are stored once in evidence/backend33-cleanup-20261027/cleanup-manifest.json outside backend. SQL decisions and historical hash lookup are in [SCHEMA33_SQL_INVENTORY.md](SCHEMA33_SQL_INVENTORY.md).
