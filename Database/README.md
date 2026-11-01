# Backend33 database entry point

The official installation is [Schema33/README.md](Schema33/README.md). It includes five SQL files: preflight,33-table schema, synthetic catalog seed, structural postflight and catalog postflight. Financial test SQL is separate under tests/Sql/Schema33.

`13_add_reserve_device_status.sql` is an idempotent forward update for an already installed Schema33 database. It only replaces `CK_ThietBi_TrangThai` so the existing `ThietBi` table accepts `DU_PHONG`; it creates no table and changes no existing device row. Review and back up the target before applying it. It is not an initialization script and is intentionally outside the sealed installation package.

`14_seed_reserve_devices.sql` is the optional, idempotent trial-data follow-up. After script 13, it designates exactly one currently `SAN_SANG` `TR33_` serial per branch/model as `DU_PHONG`. Other device states are preserved, including active holds created by earlier tests. A fresh untouched trial pair therefore has 3 public-ready + 1 reserve + 1 maintenance device. It does not target non-TR33 assets.

[The SQL inventory](../Docs/SCHEMA33_SQL_INVENTORY.md) lists KEEP/ARCHIVE/REVIEW, exact historical hashes and the archive locator. Legacy source citations are provenance, not migration dependencies. Do not run an old migration or reset tool to initialize33.

Three legacy REVIEW SQL files are retained because their data-check/image/workflow coverage has not been fully replaced. They are not part of the default runner and must not be executed against the current database as a setup step.

BUILD PASS is pre-cleanup evidence only. DATABASE NOT_RUN; API SMOKE NOT_RUN; REGRESSION NOT_RUN. No database, Docker, seed, application or build command was run during cleanup.
