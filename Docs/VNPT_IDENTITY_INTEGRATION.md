# VNPT identity verification integration status

## Completed foundation

- The physical table set remains exactly 33 tables.
- `GiayToTuyThan` has seven nullable, provider-result fields added by
  `Database/16_add_vnpt_identity_result_fields.sql`.
- No selfie, raw provider payload or API credential is stored in the database.
- `TrangThaiXacMinh` remains the staff's final decision; an automatic result cannot
  approve a customer by itself.
- Existing CCCD front/back upload and branch-scoped staff review remain unchanged.

## Implemented provider adapter

The reviewed VNPT trial documentation specifies `https://api.idg.vnpt.vn/` and three
required secrets: Token ID, Token Key and Access Token. The adapter performs exactly:

1. three uploads (`file-service/v1/addFile`) for front, back and the transient selfie;
2. one combined two-sided OCR request (`ai/v1/ocr/id`); and
3. one face comparison (`ai/v1/face/compare`).

Handoff status: provider uploads have succeeded in the local trial, but the combined OCR
request is still rejected by VNPT with HTTP 400. End-to-end VNPT verification is therefore
not approved yet; keep the Schema33 manifest pending and do not mark this integration PASS
until the OCR request contract has been confirmed against the assigned VNPT trial tenant.

The selfie is held only in request memory and is never written to application storage or
the database. Raw VNPT responses and provider image hashes are not persisted or logged.
APIs for adding, searching or verifying faces against VNPT's retained face collection are
deliberately not used.

The supplied documentation does not define a delete-file endpoint or provider retention
period. Enabling the live gate therefore means the operator has accepted that the three
uploaded images are transmitted to VNPT under its trial terms; the application must not
claim immediate provider-side deletion.

VNPT's input standard warns that static-image liveness endpoints are not recommended
without its capture SDK. Therefore this backend does not claim or synthesize liveness:
`DiemSoSong` remains null and the endpoint returns `liveness = SDK_REQUIRED`. A future
Flutter/Web SDK integration needs a separately reviewed, tamper-resistant result contract.

The customer-only endpoint is:

`POST /api/giay-to/{id}/vnpt-xac-minh`

with `{ "selfieBase64": "data:image/jpeg;base64,..." }`. It accepts only a customer's
own two-sided CCCD and refuses a second provider call after any result was recorded, which
protects the 100-request trial quota. A provider success can only produce `CAN_DUYET` or
`KHONG_DAT`; it never changes the staff-controlled `TrangThaiXacMinh` to `HOP_LE`.

## Image gate

- JPEG or PNG only; maximum 5 MB per image.
- Minimum dimensions are 600 x 900 in either portrait/landscape orientation.
- The mobile/web client remains responsible for framing, glare, blur, one-person and
  document-area checks that cannot be proven from file metadata alone.

## Private runtime configuration

The adapter fails closed unless both gates and all secrets are present:

```text
VnptEkyc__Enabled=true
VnptEkyc__LiveApiApproved=true
VnptEkyc__BaseUrl=https://api.idg.vnpt.vn/
VnptEkyc__TokenId=<private>
VnptEkyc__TokenKey=<private>
VnptEkyc__AccessToken=<private>
VnptEkyc__MacAddress=TEST1
```

For Compose, map the corresponding `VNPT_EKYC_*` values from the private `.env` into
these .NET configuration names. Never commit them, send them in chat, return them from an
API, include them in screenshots or write them to logs.

`tests/VnptEkycRegression` uses only a synthetic in-memory provider. It verifies the
headers, exact provider-call count, score normalization, mismatch behavior and the
pre-quota image gate without contacting VNPT.
