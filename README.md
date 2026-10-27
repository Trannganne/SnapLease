# SNAPLEASE Backend33

This is the source-only `feature/backend-schema33-handoff` branch, based on `4f4d4af0155b84dd850d16c0b25702d02965bf73`. The handoff overlays only the103 approved files;45 baseline files remain unchanged,148 tracked files in total. No legacy deletion is part of this handoff. See the retained-file ledger in Docs/SCHEMA33_SQL_INVENTORY.md.

Use the .NET8/manual setup and sample Schema33Trial configuration below. Do NOT use inherited compose.yaml, old database migrations/sample data, old test scripts or old Docker setup guides to deploy33. No new Compose was created. Baseline appsettings.json contains no live connection/provider credential; configure a separate private runtime from the current example as documented.

Start with [the independent setup and handoff](Docs/SCHEMA33_HANDOFF.md).

- [Installation schema, seed and guarded runner](Database/Schema33/README.md)
- [API changes for Backend/Web/Mobile](Docs/SCHEMA33_API_CHANGES.md)
- [SQL KEEP / ARCHIVE / REVIEW and provenance](Docs/SCHEMA33_SQL_INVENTORY.md)
- [Delivery files, Markdown classification and proposed Git changes](Docs/SCHEMA33_DELIVERY_FILES.md)

The target is a separate RentalCameraDb30_Test with33 application tables. This package uses Schema33Trial and fake providers. The old Compose/bootstrap/reset workflow is not an installation entry point.

BUILD PASS (.NET SDK8.0.425) was recorded before cleanup; no build was rerun afterward. DATABASE NOT_RUN; API SMOKE NOT_RUN; REGRESSION NOT_RUN. Port5003 is planned, not a verified running URL.

Never commit private configuration, keys, media, backup, runtime, bin/obj or evidence. Review-marked historical guides remain for business/API comparison and are not default deployment instructions. No commit/merge/push was performed.
