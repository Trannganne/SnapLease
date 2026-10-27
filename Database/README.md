# Backend33 database entry point

The official installation is [Schema33/README.md](Schema33/README.md). It includes five SQL files: preflight,33-table schema, synthetic catalog seed, structural postflight and catalog postflight. Financial test SQL is separate under tests/Sql/Schema33.

[The SQL inventory](../Docs/SCHEMA33_SQL_INVENTORY.md) lists KEEP/ARCHIVE/REVIEW, exact historical hashes and the archive locator. Legacy source citations are provenance, not migration dependencies. Do not run an old migration or reset tool to initialize33.

Three legacy REVIEW SQL files are retained because their data-check/image/workflow coverage has not been fully replaced. They are not part of the default runner and must not be executed against the current database as a setup step.

BUILD PASS is pre-cleanup evidence only. DATABASE NOT_RUN; API SMOKE NOT_RUN; REGRESSION NOT_RUN. No database, Docker, seed, application or build command was run during cleanup.
