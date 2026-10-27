# Schema33 workflow fixtures and test SQL - PREPARED, NOT EXECUTED

Installation DDL and catalog seed live in ../../../Database/Schema33. This directory contains workflow fixtures and financial/capacity test inputs only; none are part of the default schema installation.

- The fixture executable source lives in trial/tools/schema33-db-package-20261027/FixtureSeed, not this SQL fixture directory. It is never started by preparing or compiling it. It requires a separately approved exact fixture-manifest SHA, explicit backend/tools source roots, private target connection/server binding and fresh installed33-table/catalog90 verification before writes.
  In this source handoff it is an optional companion with its relative tools/backend layout preserved, not an installation dependency. It has not been compiled/executed. The installation runner is included directly in Database/Schema33, so normal setup does not need external trial tools.
- 03_seed_workflows.json: cases, retained-step/idempotency behavior and limitations.
- capacity-expectations.json: expected counts by all18 branch/model pairs and interval scenarios, not measured database results.
- 05_verify_financial_invariants.sql: read-only anomaly queries for the approved trial DB. No repair, DROP, rollback or data cleanup.

Expected baseline:3 branches,6 models at every branch,5 physical devices per pair (4SAN_SANG/1BAO_TRI),90 total. SAN_SANG does not prove availability: live holds and contracts occupy half-open intervals. The runner prepares empty/partial/full/expired/other-branch/overlap/adjacent/bulk4 and extension success/conflict scenarios, then receipt/multiple images/final/refund/customer-ACK/no-refund/debt/excess fixtures through source endpoints. It does not insert or backdate contracts directly.

The only deliberate time fixture changes a synthetic hold's Created/Expires together to a past20-minute interval. Live handover cases run only during08:00-19:50 Vietnam local time; no source clock is changed. Do not resume an unknown pending write automatically. Keep fixture-state, logs, PDFs, keys and checkpoints in a new private runtime/evidence directory OUTSIDE backend; publish/run the fixture binary there after separate approval so fake media also stays outside backend.

No payment URLs are requested. Fake OTP is read from the in-memory sender only; signed synthetic callbacks have no external gateway transport. FCM/jobs remain disabled. In-process role-policy/source handler checks are not publicHTTP/device/Web/rate-limiter or SQL concurrency evidence. Real rendering, uploads, provider behavior and integration invariants remain unrun.

Do not run the tool project/test SQL now. It is not covered by schema-file approval alone. Do not use old40-table integration executors or migration fixtures against Schema33. Preserve all prior scripts/evidence.
