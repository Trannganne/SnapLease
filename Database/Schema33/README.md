# Schema33 installation package - PREPARED, NOT EXECUTED

This directory contains the reviewed schema definition, fresh33-table installation, synthetic catalog seed, and installation metadata/catalog verification. The exact target is RentalCameraDb30_Test; its name does not change the33-table design.

- 00_preflight.sql: guarded read-only SQL metadata query, not yet executed.
- 01_schema33.sql: guarded one-transaction initialization for an empty schema only. No CREATE DATABASE, DROP, replay, migration history table or auto startup initialization.
- 02_seed_catalog.sql / seed-catalog.json: idempotent professional rental catalog with5 categories,4 brands,6 models,6 featured images and90 devices; also includes16 test accounts and12 fake identity profiles. Never overwrite existing seed IDs or reset modified account passwords.
- 04_verify_schema.sql / expected-metadata.json: exact schema.table,383 columns, keys/indexes/FKs/CHECK trust and definition export. The seven VNPT eKYC result fields remain inside GiayToTuyThan, so the design stays at exactly33 tables.
- 05_verify_seed_catalog.sql: installation/catalog checks only, prepared by the fixture split generator.

Workflow fixtures, capacity scenarios and financial test SQL belong to ../../tests/Sql/Schema33, outside the installation package. Invoke-Schema33Package.ps1 and approval.template.json are included here for independent installation. Their working copies and optional fixture tools remain in trial/tools/schema33-db-package-20261027. The sample configuration is ../../RentalCamera.Api/appsettings.Schema33Trial.example.json; it is NOT loaded or applied automatically.

The mixed draft05_verify_seed_and_finance.sql and duplicate SEED_CAPACITY_EXPECTATIONS.json have been archived outside backend after byte/hash verification. Their catalogue/financial statements and capacity data are retained in the official split files. Historical source citations in schema.json/constraints.json are logical origin paths, not runtime file dependencies; the retained SHA256 registry is in ../../Docs/SCHEMA33_SQL_INVENTORY.md. No archived SQL is part of the default installation or executed by startup.

Before writes: review exact file hashes and manifest, then verify fresh server/database/schema metadata. On 2026-11-03 the .NET8 build passed with zero warnings/errors; Schema33Regression passed EF exact33 tables/383 scalar fields/no shadow properties/restrictive FKs plus62 source-level checks. The package design, expected metadata and SQL definitions now agree on33 tables,383 columns and72 CHECK constraints. The manifest is therefore reviewed and ready for the receiving environment's explicit preflight and install; this is not a claim that the receiver database already passed installation. Stored CHECK/default/filter definitions remain post-install verification requirements. Template approval flags deliberately remain false: the receiver must copy the template to a private file, bind the actual server/data source and enable only the operation being run.

The receiving environment must run Preflight, Schema, VerifySchema, CatalogSeed and VerifyData in order, using a new evidence directory for each stage. After installation, bind the API to that same database and run HTTP smoke tests. Do not reuse another machine's approval file, credentials, evidence directory or database claim.

Keep evidence/logs/checkpoints and private connection configuration outside backend. Startup has no live DB fallback; worker services are disabled in the trial. This configuration is for isolated fake-provider trials; teammates need their own explicit DB/server/storage binding and must not copy this machine's live configuration or Docker database.

## Runner

Run PowerShell from the backend directory:

```powershell
Database/Schema33/Invoke-Schema33Package.ps1 -SchemaPackageDirectory Database/Schema33 -Mode Review
```

Review verifies hashes only and never opens SQL. Before execution, fill a private approval file from the template with the freshly verified server/data source, database and allowed stages. Supply a private connection in process environment `SNAPLEASE33_SQL_CONNECTION`; it is never read from a config fallback or printed. Pass `-ExecuteAfterDbApproval -ApprovalFile <private-file> -ReviewedManifestSha256 <sha256> -EvidenceDirectory <new-private-dir>` for the chosen stage: Preflight, Schema, CatalogSeed, VerifySchema, VerifyData. Each invocation uses a new evidence directory and retains every metadata/count result set. VerifyData maps only to05_verify_seed_catalog.sql. VerifySchema exports definitions; its structural result alone does not prove CHECK/default/filter equivalence.

Use a PowerShell session where the script is allowed by local execution policy/signing. The author's machine denied script execution; its policy was not changed. JSON file hashes can be checked independently, but this does not count as executing the PowerShell runner.

## Recovery boundary

The target must have zero user objects before schema initialization. Save fresh metadata, connection binding (without password), source/package hashes and a trial-only SQL backup/checkpoint before any write. Schema and catalog scripts each own their transaction and roll back on a known failure. After a client timeout or lost connection, the result is UNKNOWN until metadata/counts are read back. Never auto replay; do not drop/recreate, reset data, or restore another database. Keep any completed trial stage as evidence and diagnose the exact next step. No startup EnsureCreated/Migrate is registered and no migration-history table is permitted.
