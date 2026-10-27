# Backend33 SQL and archive inventory

## Scope of this handoff branch

The cleanup decisions below describe the source trial/history. The independent feature/backend-schema33-handoff branch retains all45 baseline files outside the103-file overlay unchanged, including15 earlier deletion proposals. This prevents inherited references from being broken. They are NOT Schema33 installation prerequisites. Current branch:148 tracked files; ADD49/MODIFY31/DELETE0 expected, with no new file outside the approved list.

Only Database/Schema33/00_preflight.sql,01_schema33.sql,02_seed_catalog.sql,04_verify_schema.sql,05_verify_seed_catalog.sql are default installation stages. Root SQL, inherited Compose, previous sample data, old API5000 tests and old Docker setup guides must not be used for33. Use Docs/SCHEMA33_HANDOFF.md and the sample Schema33Trial configuration. No new Compose was created.

### All45 inherited files, retained unchanged

| Baseline path | Usage for this handoff |
|---|---|
| `.env.example` | Old environment template, not the Schema33Trial configuration procedure. |
| `Database/01_schema.sql` | Legacy SQL for the old database; do not initialize/migrate/seed33 with it. |
| `Database/02_sample_data.sql` | Legacy SQL for the old database; do not initialize/migrate/seed33 with it. |
| `Database/03_update_cloudinary_images.sql` | Legacy SQL for the old database; do not initialize/migrate/seed33 with it. |
| `Database/04_add_home_contract_test_data.sql` | Legacy SQL for the old database; do not initialize/migrate/seed33 with it. |
| `Database/06_add_electronic_signature.sql` | Legacy SQL for the old database; do not initialize/migrate/seed33 with it. |
| `Database/07_add_vnpay_payment.sql` | Legacy SQL for the old database; do not initialize/migrate/seed33 with it. |
| `Database/08_add_firebase_notifications.sql` | Legacy SQL for the old database; do not initialize/migrate/seed33 with it. |
| `Database/08_remove_giohang_unique_hopdong.sql` | Legacy SQL for the old database; do not initialize/migrate/seed33 with it. |
| `Database/09_add_review_details.sql` | Legacy SQL for the old database; do not initialize/migrate/seed33 with it. |
| `Database/09_add_vnpay_attempts.sql` | Legacy SQL for the old database; do not initialize/migrate/seed33 with it. |
| `Database/10_review_publication.sql` | Legacy SQL for the old database; do not initialize/migrate/seed33 with it. |
| `Database/11_mobile_workflows.sql` | Legacy SQL for the old database; do not initialize/migrate/seed33 with it. |
| `Database/12_cart_hold_selection.sql` | Legacy SQL for the old database; do not initialize/migrate/seed33 with it. |
| `Database/migration_thue_ngay_final.sql` | Legacy SQL for the old database; do not initialize/migrate/seed33 with it. |
| `Docs/API_DANH_GIA.md` | Historical/API/REVIEW reference only; current setup/API deltas are in SCHEMA33 guides. |
| `Docs/API_FIGMA_MOBILE.md` | Historical/API/REVIEW reference only; current setup/API deltas are in SCHEMA33 guides. |
| `Docs/API_QUEN_MAT_KHAU.md` | Historical/API/REVIEW reference only; current setup/API deltas are in SCHEMA33 guides. |
| `Docs/API_XAC_THUC.md` | Historical/API/REVIEW reference only; current setup/API deltas are in SCHEMA33 guides. |
| `Docs/FIREBASE_FCM_BACKEND.md` | Historical/API/REVIEW reference only; current setup/API deltas are in SCHEMA33 guides. |
| `Docs/GUI_OTP_KY_HOP_DONG_QUA_EMAIL.md` | Historical/API/REVIEW reference only; current setup/API deltas are in SCHEMA33 guides. |
| `Docs/INTEGRATION_HANDOFF.md` | Historical/API/REVIEW reference only; current setup/API deltas are in SCHEMA33 guides. |
| `Docs/INTEGRATION_PAYMENT_HANDOVER.md` | Historical/API/REVIEW reference only; current setup/API deltas are in SCHEMA33 guides. |
| `Docs/Tai lieu ban giao Backend API Rental Camera.docx` | Historical/API/REVIEW reference only; current setup/API deltas are in SCHEMA33 guides. |
| `Docs/Tai lieu tich hop Backend API Rental Camera.docx` | Historical/API/REVIEW reference only; current setup/API deltas are in SCHEMA33 guides. |
| `Docs/UPLOAD_ANH_BIEN_BAN_CLOUDINARY.md` | Historical/API/REVIEW reference only; current setup/API deltas are in SCHEMA33 guides. |
| `Docs/VNPAY_SANDBOX.md` | Historical/API/REVIEW reference only; current setup/API deltas are in SCHEMA33 guides. |
| `HUONG_DAN_CHAY_DOCKER_CHO_THANH_VIEN.md` | Historical/API/REVIEW reference only; current setup/API deltas are in SCHEMA33 guides. |
| `RentalCamera.Api/.gitignore` | Unchanged baseline support file; no new commit change. |
| `RentalCamera.Api/appsettings.json` | Baseline empty configuration; do not copy live settings. Use the current example in a private runtime. |
| `check_urls.ps1` | Legacy test/helper, not a33 deployment/smoke entry point; not executed. Registration passwords are synthetic fixture inputs where present. |
| `compose.yaml` | DO NOT DEPLOY33: Development environment and retired-table readiness checks. |
| `test_api.ps1` | Legacy test/helper, not a33 deployment/smoke entry point; not executed. Registration passwords are synthetic fixture inputs where present. |
| `test_avail.py` | Legacy test/helper, not a33 deployment/smoke entry point; not executed. Registration passwords are synthetic fixture inputs where present. |
| `test_conc.py` | Legacy test/helper, not a33 deployment/smoke entry point; not executed. Registration passwords are synthetic fixture inputs where present. |
| `test_idempotency.py` | Legacy test/helper, not a33 deployment/smoke entry point; not executed. Registration passwords are synthetic fixture inputs where present. |
| `test_lich.py` | Legacy test/helper, not a33 deployment/smoke entry point; not executed. Registration passwords are synthetic fixture inputs where present. |
| `test_put.py` | Legacy test/helper, not a33 deployment/smoke entry point; not executed. Registration passwords are synthetic fixture inputs where present. |
| `test_rental.py` | Legacy test/helper, not a33 deployment/smoke entry point; not executed. Registration passwords are synthetic fixture inputs where present. |
| `test_rental2.py` | Legacy test/helper, not a33 deployment/smoke entry point; not executed. Registration passwords are synthetic fixture inputs where present. |
| `test_rental_conc.py` | Legacy test/helper, not a33 deployment/smoke entry point; not executed. Registration passwords are synthetic fixture inputs where present. |
| `tests/PaymentDtoRegression/PaymentDtoRegression.csproj` | Inherited regression source retained; not executed or newly claimed compatible with33. |
| `tests/PaymentDtoRegression/Program.cs` | Inherited regression source retained; not executed or newly claimed compatible with33. |
| `tests/VnpayRegression/Program.cs` | Inherited regression source retained; not executed or newly claimed compatible with33. |
| `tests/VnpayRegression/VnpayRegression.csproj` | Inherited regression source retained; not executed or newly claimed compatible with33. |

The6 registration-script literals were verified by static AST/dataflow: UUID account creation followed by the same credential login. No real credential was identified, no provider/runtime contacted, and no ancestry rewrite performed. Two inherited DOCX contain no media/embedded objects/macros; their XML was included in the prospective-tree scan.


Cleanup scope: backend trial only. No Docker, SQL, build, application or provider call. BUILD PASS (.NET SDK8.0.425) is historical pre-cleanup evidence; DATABASE NOT_RUN, API SMOKE NOT_RUN, REGRESSION NOT_RUN.

## Official installation

The installation manifest selects exactly5 SQL under Database/Schema33. The financial verifier in tests/Sql/Schema33 is retained separately; it is not installation SQL. No legacy migration or reset utility is a default deployment step.

| SQL path from backend | Decision | Replacement / retention basis |
|---|---|---|
| `Database/00_mobile_preflight.test.sql` | REVIEW | Legacy data/duplicate/state checks are not fully replaced by the new metadata preflight; keep for review only. |
| `Database/01_schema.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/02_sample_data.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/03_update_cloudinary_images.sql` | REVIEW | Updates old Cloudinary sample rows; no validated equivalent TR33 image seed. |
| `Database/04_add_home_contract_test_data.sql` | REVIEW | Contains workflow/catalog scenarios not fully covered by executed33 fixtures. |
| `Database/06_add_electronic_signature.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/06_test.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/07_add_vnpay_payment.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/07_test.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/07_test2.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/08_add_firebase_notifications.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/08_remove_giohang_unique_hopdong.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/09_add_review_details.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/09_add_vnpay_attempts.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/09_add_yeu_cau_thanh_toan_vnpay.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/10_review_publication.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/10_review_publication.test.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/11_mobile_workflows.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/11_mobile_workflows.test.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/12_cart_hold_selection.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/12_cart_hold_selection.test.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/13_return_settlement.proposed.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/14_branch_coordinates.proposed.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/Schema33/00_preflight.sql` | KEEP | Official33 installation or retained33 financial test. |
| `Database/Schema33/01_schema33.sql` | KEEP | Official33 installation or retained33 financial test. |
| `Database/Schema33/02_seed_catalog.sql` | KEEP | Official33 installation or retained33 financial test. |
| `Database/Schema33/04_verify_schema.sql` | KEEP | Official33 installation or retained33 financial test. |
| `Database/Schema33/05_verify_seed_and_finance.sql` | ARCHIVE | All catalog and financial statements are retained in the split official catalog verifier and financial test. |
| `Database/Schema33/05_verify_seed_catalog.sql` | KEEP | Official33 installation or retained33 financial test. |
| `Database/migration_thue_ngay.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/migration_thue_ngay_final.sql` | ARCHIVE | Fresh33 structure is defined in Schema33/01_schema33.sql plus schema.json/constraints.json; old-schema upgrade variants are not part of this33-only workflow. This is source-scope coverage, not proof of a DB migration. |
| `Database/recreate_test_db.sql` | ARCHIVE | Destructive DB20 DROP/recreate utility has no trial caller and is explicitly outside the new empty33 installation/reset-free workflow. |
| `tests/Sql/Schema33/05_verify_financial_invariants.sql` | KEEP | Official33 installation or retained33 financial test. |

The3 REVIEW SQL remain physically present and are NOT in package-manifest.json or the default runner. Their old target/rows/data-check purpose has no fully verified equivalent: do not execute them as33 setup. The5 official SQL and financial test are unchanged.

## Dependency checks

- Application C#/csproj, JSON/config, runner, tests and deployment scripts were scanned. No retained executable reads an archived filename. Project references and declared content files remain present. Startup does not run SQL/EnsureCreated/Migrate.
- Trial has no Compose or legacy run_sql_scripts.py. The original repository has its own Compose/script references to its own legacy copies; those original files and Git state were not changed.
- Generic legacy SQL harnesses accept user-supplied SQL paths; they are not33 installation entry points. Tests and their source were retained. No test was run.
-20 links in retained Markdown were redirected to this in-package registry. Four more historical links disappeared only when the two obsolete entry-point bodies were replaced with current33 routing. No business text in REVIEW guides was removed; they received a scope banner and link-target maintenance.
-1,177 schema.json/constraints.json source citations identify logical ORIGINAL source paths/line numbers. These JSON files remain byte-identical. They do not read SQL files at runtime. Resolve historical copies using the hashes/registry below; the archive is optional history, not a build/install dependency.
- Preparation generators outside backend are historical, not shipped setup entry points; they were not modified or invoked. Optional FixtureSeed does not use archived SQL.
- Destructive SQL was inspected statically. recreate_test_db.sql contains SINGLE_USER/DROP DATABASE for DB20_Test. It was archived. Other archived scripts contain DROP CONSTRAINT. No retained default installation SQL contains a database reset, row DELETE or TRUNCATE.

## Archive locator and exact hashes

Owner archive: `evidence/backend33-cleanup-20261027/archive/backend/` relative to the trial root. Audit/journal: `evidence/backend33-cleanup-20261027/cleanup-manifest.json`. These are outside backend and must not be pushed. Current runtime/build/setup does not need them.

Every archive copy was read back and SHA256/bytes checked before removing only its matching trial file. The original source repositories retain their own copies. Modified document versions were separately preserved under `before-edit/backend/`; those are edit backups, not extra removed-file counts.

| Logical original path from backend | Type | SHA-256 |
|---|---|---|
| <a id="archive-database-01-schema-sql"></a>`Database/01_schema.sql` | SQL | `5b9dd8935f893c9912df02127c27003117c13ebf4b1b91f4d1bb44c78f414015` |
| <a id="archive-database-02-sample-data-sql"></a>`Database/02_sample_data.sql` | SQL | `d5f922b06fec0e5661ec8cd99cc7da7fcab086812c56a4065df9841be453af1e` |
| <a id="archive-database-06-add-electronic-signature-sql"></a>`Database/06_add_electronic_signature.sql` | SQL | `c8b94773275ff8e4b5a0b6b26442425385488f94b92d12b394446d3c3e3ae436` |
| <a id="archive-database-06-test-sql"></a>`Database/06_test.sql` | SQL | `1a4fe4e3e467016b2a5bdb71d7b376a34fb34df8f23abf2c342677ecdc08b246` |
| <a id="archive-database-07-add-vnpay-payment-sql"></a>`Database/07_add_vnpay_payment.sql` | SQL | `21fb791ccd097a7aea991978df6036a8dab125ab25c046d1f84f2eae92856107` |
| <a id="archive-database-07-test-sql"></a>`Database/07_test.sql` | SQL | `accb9a9ebe16b9b87f0662358d661bd5e4355c68bc711eb553241ebae4042a27` |
| <a id="archive-database-07-test2-sql"></a>`Database/07_test2.sql` | SQL | `c012fa82afeb12326689c95de53098cdae9386e5db492f8e57cef2283f38ff31` |
| <a id="archive-database-08-add-firebase-notifications-sql"></a>`Database/08_add_firebase_notifications.sql` | SQL | `7055e7852e98c65c454b57c86fd29679c9f6e0ebc72fbce7e8385489479efbca` |
| <a id="archive-database-08-remove-giohang-unique-hopdong-sql"></a>`Database/08_remove_giohang_unique_hopdong.sql` | SQL | `f90259392048426e68adb81e34fd3aa1a4918e4c40a11669a94ff05e8815fa84` |
| <a id="archive-database-09-add-review-details-sql"></a>`Database/09_add_review_details.sql` | SQL | `2eb673fded0d56970c6627883af04e034accc6fd67e298b4ecff8acdc5e1dc68` |
| <a id="archive-database-09-add-vnpay-attempts-sql"></a>`Database/09_add_vnpay_attempts.sql` | SQL | `c8de6f7da93d9f60c328215d8816860bce3331e1176d408ca7be7ef0d3ec2f92` |
| <a id="archive-database-09-add-yeu-cau-thanh-toan-vnpay-sql"></a>`Database/09_add_yeu_cau_thanh_toan_vnpay.sql` | SQL | `310ac512e5e4b5de80388fa6a5c5778cf5b58fea6abdcdff7822d70a750b0707` |
| <a id="archive-database-10-review-publication-sql"></a>`Database/10_review_publication.sql` | SQL | `15ab26de1f33bdb0eebf7ec68df9c099b18521696325022589fe04b8fcb3f9b3` |
| <a id="archive-database-10-review-publication-test-sql"></a>`Database/10_review_publication.test.sql` | SQL | `63b6c7822d7f24e06b261a1fb25c1c770fcb098deffe4c3fca1b519d6aee70bb` |
| <a id="archive-database-11-mobile-workflows-sql"></a>`Database/11_mobile_workflows.sql` | SQL | `7b4b13a7cdb49714abbdd8ab87ef01402445f77346e44dfb84594820aa18db86` |
| <a id="archive-database-11-mobile-workflows-test-sql"></a>`Database/11_mobile_workflows.test.sql` | SQL | `c9312c10a56ac27821aaea8052f733297aca73d507c0552c5ff8d739c6a98345` |
| <a id="archive-database-12-cart-hold-selection-sql"></a>`Database/12_cart_hold_selection.sql` | SQL | `fe15b365715bceb293a9df2c37341a2ca23c498dabbae82fb818e0c1cbbec495` |
| <a id="archive-database-12-cart-hold-selection-test-sql"></a>`Database/12_cart_hold_selection.test.sql` | SQL | `6810ce2b1e5d4de1ce66ec8333592a557caa1ffc3aff1847f9270e8e60ce33a7` |
| <a id="archive-database-13-return-settlement-proposed-sql"></a>`Database/13_return_settlement.proposed.sql` | SQL | `874a2cc607f690c297a37cf5ab1ec8376fd870bcc4801cc7bf2a21c85fd2f871` |
| <a id="archive-database-14-branch-coordinates-proposed-sql"></a>`Database/14_branch_coordinates.proposed.sql` | SQL | `e283cd49b3b5d749c3e695d009a81d1a9e2a54203304ead21756e402d58f4b04` |
| <a id="archive-database-schema33-05-verify-seed-and-finance-sql"></a>`Database/Schema33/05_verify_seed_and_finance.sql` | SQL | `9c05c3aee737bdceeec00f66273e6c4bb1320200f111c52d46fdb4b1d045743c` |
| <a id="archive-database-schema33-seed-capacity-expectations-json"></a>`Database/Schema33/SEED_CAPACITY_EXPECTATIONS.json` | ARTIFACT | `64252e87d32fe94e09d8cd177f3be45c4a668757f60dc5b24ba79513d445eb51` |
| <a id="archive-database-migration-thue-ngay-sql"></a>`Database/migration_thue_ngay.sql` | SQL | `fc142360c6c54d70e72b606c5baafe70a622e06b6b2b5ab96c87d84ae07a42ce` |
| <a id="archive-database-migration-thue-ngay-final-sql"></a>`Database/migration_thue_ngay_final.sql` | SQL | `03da79010506ef1f4a3dcb9dbf5bf6bf40721229391baf842a76c03bf23b5064` |
| <a id="archive-database-recreate-test-db-sql"></a>`Database/recreate_test_db.sql` | SQL | `67b82add69d06b8f86dc327843ae727c238910e3752d10d5bd19a599a7a8c4b6` |
| <a id="archive-docs-api5001-automatic-fcm-md"></a>`Docs/API5001_AUTOMATIC_FCM.md` | MD | `01d7a2084f5147188f5489814275a15ba2081c0bf1beb47fe1fb1de60ddc8751` |
| <a id="archive-docs-api5001-continuous-demo-md"></a>`Docs/API5001_CONTINUOUS_DEMO.md` | MD | `1d90ec22157e3e0a1b8c32e2e59dbff1ed55974d007daaface603ca3c1ea9ac3` |
| <a id="archive-docs-api5001-deployment-plan-md"></a>`Docs/API5001_DEPLOYMENT_PLAN.md` | MD | `5bab61bc998e86f94a7dcba848332edb702207c53fcbeec6cefc409943459248` |
| <a id="archive-docs-api-danh-gia-md"></a>`Docs/API_DANH_GIA.md` | MD | `f89d7bc08a31a8da0c6b665cf39c2fdcde77c27dea7c43feb0f46dfc795d0285` |
| <a id="archive-docs-api-quen-mat-khau-md"></a>`Docs/API_QUEN_MAT_KHAU.md` | MD | `b82c355ce33cb790b5a3f3d2458a19a7a97ed40cc2328f951c35d2ed3bbb6663` |
| <a id="archive-docs-backend-changelog-mobile-integration-md"></a>`Docs/BACKEND_CHANGELOG_MOBILE_INTEGRATION.md` | MD | `a0bb9b315ad1a8a6bbdedf034b71a134d60bf2d87da0ecac1d6217b67fd85096` |
| <a id="archive-docs-checkout-repair-review-md"></a>`Docs/CHECKOUT_REPAIR_REVIEW.md` | MD | `b28c5331e6a8cd9737ab3d11e2b2723ebe46ebd674b516ad6657c40c7ddb2ead` |
| <a id="archive-docs-device-otp-fcm-test-plan-md"></a>`Docs/DEVICE_OTP_FCM_TEST_PLAN.md` | MD | `3e074654e285446d19ed01385c725cd912d4b83eba3a135408ed86442a786c50` |
| <a id="archive-docs-faq-chatbot-draft-md"></a>`Docs/FAQ_CHATBOT_DRAFT.md` | MD | `fe0b6b70739a6b10b3f085f5207ead26465365460192f90ba59574c598ec5dc5` |
| <a id="archive-docs-handoff-review-publication-md"></a>`Docs/HANDOFF_REVIEW_PUBLICATION.md` | MD | `0a567a99745bd288c414e8e2e40dfb46644641b3cd286a19d4f03c8db67c4b88` |
| <a id="archive-docs-restore-guide-md"></a>`Docs/RESTORE_GUIDE.md` | MD | `d1ed7b71cbc013e1df3cadbc399ef4094454a1f92b723cedad320ef6cd3885ce` |
| <a id="archive-docs-staging-alignment-matrix-md"></a>`Docs/STAGING_ALIGNMENT_MATRIX.md` | MD | `25520a498ee78e59bb5a174515bfcab585c6ee867725e6f72cca00a387ea476b` |
| <a id="archive-handoff-ban-giao-md"></a>`HANDOFF_BAN_GIAO.md` | MD | `35d5558035e262e6a32c66c6e2a7c7f7df644d8dcf6cfe5be60c102ed54d3ab4` |
| <a id="archive-handoff-vnpay-md"></a>`HANDOFF_VNPAY.md` | MD | `a1afc92458a9d34573e6de023ac3976ab56cab6b2db75cd70d8db9be811c104d` |
| <a id="archive-huong-dan-chay-docker-cho-thanh-vien-md"></a>`HUONG_DAN_CHAY_DOCKER_CHO_THANH_VIEN.md` | MD | `6a556846aedbb532b17cf0645be276aba657066c2a0baf8a6d4d73490aca3269` |
| <a id="archive-rentalcamera-api-obj-schema33offlinecompile-globalusings-g-cs"></a>`RentalCamera.Api/obj/Schema33OfflineCompile/GlobalUsings.g.cs` | ARTIFACT | `1c0f5bfd46911c0510dc8253b9fb7daa44f4593c42313cb10a4c01ccb8f3e436` |
| <a id="archive-rentalcamera-api-obj-schema33offlinecompile-rentalcamera-api-dll"></a>`RentalCamera.Api/obj/Schema33OfflineCompile/RentalCamera.Api.dll` | ARTIFACT | `c3710c7ae7eac1299c8c2efb825c78691afe7b45adc54703bc5ec70d07ed246e` |

## Remaining limits

Database, EF runtime, API smoke, regression and post-cleanup build were not run. Replacement decisions apply only to the approved fresh33 source package; they do not authorize migration/reset of an existing database. REVIEW material retains detailed older business/API assumptions that still need a teammate to reconcile with SCHEMA33_API_CHANGES and actual source/Swagger. Pre-existing historical evidence links outside the package are recorded separately in the audit, not reconstructed or treated as current evidence.
