# eKYC integration handoff

## Scope and safety boundary

The eKYC extension reuses `GiayToTuyThan`; the physical table count remains 33. Apply `Database/15_add_ekyc_fields.sql` before deploying the matching API build. The database stores only the selfie URL, provider/reference identifiers, decision status, three normalized scores and processing time. It does not store the provider's raw response.

Images remain under the authenticated `GET /api/giay-to/anh/{fileName}` endpoint. Customers can read only their own images; staff retain the existing branch scope. Never write document images, Base64 payloads, API keys or provider responses to logs.

## API flow

1. The customer uploads both sides of a CCCD with `POST /api/giay-to`.
2. The customer calls `POST /api/giay-to/{id}/ekyc` with:

```json
{ "selfieBase64": "data:image/jpeg;base64,..." }
```

3. The API sends the two stored CCCD images and the selfie to the configured private gateway.
4. It checks document validity, normalized document-number equality, OCR confidence, face match and liveness.
5. A passing result records `EkycStatus=DAT`. `TrangThaiXacMinh` intentionally remains `CHO_XAC_MINH`; staff still perform the final `PUT /api/giay-to/{id}/xac-minh` decision.

The endpoint is customer-only and limited to five attempts per account per hour. A completed `DAT` result cannot be submitted again.

## Provider-neutral gateway contract

The backend uses an HTTPS JSON gateway so vendor-specific SDKs and credentials are isolated. Request fields are `documentType`, `expectedDocumentNumber`, `frontImage`, `backImage`, and `selfieImage`. Images are data URIs.

The gateway response must have this shape:

```json
{
  "referenceId": "provider-reference",
  "documentNumber": "001234567890",
  "documentValid": true,
  "faceMatched": true,
  "livenessPassed": true,
  "ocrConfidence": 0.96,
  "faceMatchScore": 0.91,
  "livenessScore": 0.93
}
```

Scores must be between 0 and 1. The backend sends `Authorization: Bearer <Ekyc__ApiKey>` when a key is configured. Redirects are disabled.

## Configuration

Keep eKYC disabled until an approved provider gateway is available. Configure secrets only through local environment variables or the deployment secret store:

```text
EKYC_ENABLED=true
EKYC_PROVIDER=ApprovedGateway
EKYC_VERIFICATION_URL=https://gateway.example/verify
EKYC_API_KEY=<secret>
EKYC_MINIMUM_OCR_CONFIDENCE=0.85
EKYC_MINIMUM_FACE_MATCH_SCORE=0.80
EKYC_MINIMUM_LIVENESS_SCORE=0.80
```

No real vendor call is covered by the offline regression suite. Before production, separately verify the approved vendor's consent, retention, deletion, data-location, retry and incident-handling requirements.
