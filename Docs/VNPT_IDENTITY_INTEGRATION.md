# VNPT identity verification integration status

## Completed foundation

- The physical table set remains exactly 33 tables.
- `GiayToTuyThan` has seven nullable, provider-result fields added by
  `Database/16_add_vnpt_identity_result_fields.sql`.
- No selfie, raw provider payload or API credential is stored in the database.
- `TrangThaiXacMinh` remains the staff's final decision; an automatic result cannot
  approve a customer by itself.
- Existing CCCD front/back upload and branch-scoped staff review remain unchanged.

## External call is intentionally not enabled yet

VNPT advertises OCR, Face ID and liveness APIs, but the public product pages do not
publish the trial tenant's exact endpoints, authentication headers or response schema.
Do not guess those contracts or enable outbound traffic before receiving the official
trial documentation and credentials.

Before implementing the VNPT adapter, obtain and review:

1. OCR, face comparison and liveness endpoint documentation.
2. Required authentication headers and test base URL.
3. A redacted success response and representative failure responses.
4. Quota rules for the free trial and whether liveness is included.
5. Image retention/deletion requirements and request identifiers used for support.

Secrets must be supplied only through the local environment or deployment secret
store. Never commit them, send them in chat, return them from an API or write them to
logs.
