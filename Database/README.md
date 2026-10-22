# Database deployment for the shared Backend / Web / Mobile API

Use an explicitly selected SQL Server database and back it up before reviewing any upgrade.
No script was executed as part of preparing this commit. Never run bootstrap or sample data on an existing database.

## New empty database

1. Review `01_schema.sql` from the committed tree: it is the original baseline, not the local test-workflow snapshot.
2. Apply the baseline only to a new disposable/approved database. Its `CREATE DATABASE`/`USE` targets are fixed to `RentalCameraDb20`; review those targets explicitly when provisioning a differently named database.
3. Apply `06_add_electronic_signature.sql`, `07_add_vnpay_payment.sql`, `08_add_firebase_notifications.sql` after reviewing their fixed database context.
4. On a dedicated connection to the intended database, apply the sequence below with `-d` and `TargetDatabase` agreeing.
5. Provision application accounts using the supported application/admin procedures. Sample data and test fixtures are not required migrations and are not run by Compose.

## Existing baseline database / remaining sequence

Inspect tables, column types, constraints, indexes and legacy statuses first. Do not replay a migration just because a file exists. Use a fresh sqlcmd connection per file, `-I -b`, `-d <database>` and `-v TargetDatabase=<same database>`:

1. `08_remove_giohang_unique_hopdong.sql`: permits multiple contracts per customer cart, retaining hold uniqueness.
2. `09_add_vnpay_attempts.sql`: payment-attempt records, references, indexes and overcollection flag.
3. `10_review_publication.sql`: public-by-default reviews, legacy NULL read compatibility, Admin visibility audit. Stop for unsupported legacy statuses; no guessed mapping or fabricated approval.
4. `11_mobile_workflows.sql`: cart versions, device/outbox records, branch calendars, signed renewals, cancellation/refund/audit. Adds the agreed wildcard08:00-20:00 schedule only where missing; does not invent holidays or change existing branch exceptions.
5. `12_cart_hold_selection.sql`: preserves each selected cart line/version while aggregating the reservation by model.

Example command shape (operator supplies the real server and database):

    sqlcmd -S <server> -U <operator> -I -b -d <database> -v TargetDatabase=<database> -i Database/10_review_publication.sql

Supply authentication securely outside shell history; no passwords belong in this example. Never concatenate all files into one batch: each file owns its transaction and schema prerequisites.

Do not apply the old `09_add_review_details.sql` pending-review backfill as part of this sequence. Do not run the `.test.sql`, recreate, ad-hoc or fixture scripts from a local working tree as a deployment plan. The portable09/10/11/12 files preserve the reviewed statement bodies, replacing only the selected DB guard/header; they still require an operator-reviewed upgrade and legacy report.10 and12 intentionally stop when their completed structures already exist.

The original baseline plus migration10 avoids the local modified baseline's duplicate review audit table. Compose now checks schema readiness only; it neither seeds nor automatically upgrades existing databases. See [integration handoff](../Docs/INTEGRATION_HANDOFF.md) for service configuration and consumer changes.
