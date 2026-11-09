# Backend chatbot handoff

This document covers only the .NET Backend chatbot. Flutter UI, local chat
history and mobile widget/integration tests are owned by the Mobile team.

## API contract

Both routes require a valid Bearer token for a `KHACH_HANG` account.

### `GET /api/tro-ly/trang-thai`

Response `200`:

```json
{
  "enabled": false,
  "reason": "Trợ lý AI chưa được bật.",
  "model": "",
  "currentKnowledgeSha256": "..."
}
```

`currentKnowledgeSha256` is not a secret. It identifies the exact FAQ,
catalog evidence and rental terms loaded by the Backend. An operator must review
those sources and copy this exact value into `Chatbot__ApprovedKnowledgeSha256`
before enabling the provider.

### `POST /api/tro-ly/tin-nhan`

Request body:

```json
{
  "message": "Tôi cần máy chụp chân dung khoảng 500k/ngày",
  "history": [
    { "role": "user", "text": "Tôi đã có kinh nghiệm" }
  ]
}
```

`message` is required and is limited to 1,200 characters. `history` is optional,
contains at most six turns, accepts only `user` and `assistant`, and each turn is
limited to 1,200 characters. The Mobile client may send fewer turns.

Response `200`:

```json
{
  "text": "...",
  "products": [
    {
      "maDongMay": "...",
      "tenDongMay": "...",
      "anhDaiDien": "https://...",
      "giaThueNgay": 500000,
      "phanTramGiamGia": 0,
      "tenDanhMuc": "Máy ảnh",
      "reason": "..."
    }
  ],
  "sources": ["..."],
  "observedAtUtc": "2026-11-09T00:00:00Z"
}
```

The response does not prove physical availability. Consumers must use the
existing availability API with a branch and rental interval before displaying an
availability conclusion.

Expected failures:

| HTTP | `code` | Meaning |
|---|---|---|
| 400 | `CHAT_INPUT` | Invalid length, history count or role |
| 400 | `CHAT_PRIVATE` | Message/history contains sensitive data |
| 429 | `AI_QUOTA` or no body code | Provider quota or Backend rate limit |
| 503 | `CHAT_DISABLED` | Configuration or knowledge approval gate is closed |
| 503 | `AI_UNAVAILABLE`, `AI_NETWORK`, `AI_INVALID`, `AI_EMPTY` | Provider cannot produce a safe response |
| 504 | `AI_TIMEOUT` | Provider exceeded the 20-second Backend timeout |

The message route permits three requests per minute per authenticated account
and does not queue or automatically retry a provider request.

## Safe configuration

Committed settings remain disabled and contain no real secret. Supply private
values through environment configuration. Docker Compose maps the corresponding
`.env` names shown on the right:

```text
Chatbot__Enabled=true                         CHATBOT_ENABLED=true
Chatbot__LiveApiApproved=true                 CHATBOT_LIVE_API_APPROVED=true
Chatbot__FreePlanConfirmed=true               CHATBOT_FREE_PLAN_CONFIRMED=true
Chatbot__ApiKey=<private-provider-key>         CHATBOT_API_KEY=<private-provider-key>
Chatbot__Model=<approved-live-model-id>        CHATBOT_MODEL=<approved-live-model-id>
Chatbot__ApprovedKnowledgeSha256=<hash>        CHATBOT_APPROVED_KNOWLEDGE_SHA256=<hash>
```

Recommended activation sequence:

1. Start with `Chatbot__Enabled=false`.
2. Authenticate as a customer and read `/api/tro-ly/trang-thai`.
3. Review `RentalCamera.Api/Knowledge/faq.vi.json`,
   `catalog-evidence.vi.json` and the current `RentalPolicy.Terms`.
4. Set the returned hash as `Chatbot__ApprovedKnowledgeSha256`, configure the
   approved model/key and confirm the provider plan.
5. Enable the feature and restart the Backend.
6. Re-read status, then send one bounded smoke request. Never put the key in
   source, JSON committed to Git, logs, screenshots or a mobile build.

`Schema33Trial` always requires chatbot disabled and blocks the external
provider. `Schema33Sandbox` permits it only when all six settings above
are complete and the explicit live-API approval is true. Missing or inconsistent
approval prevents startup; it never falls back to an unrestricted HTTP client.

## Backend safety boundary

- Raw messages and history never leave the Backend. The provider receives only
  controlled need labels, a numeric budget, allowlisted FAQ/catalog identifiers
  and approved catalog evidence.
- CCCD/CMND, OTP, phone numbers, email addresses, passwords, API keys and tokens
  are rejected before the catalog or provider call.
- Provider output is only a selector. Product and FAQ identifiers are checked
  again against Backend catalog/evidence before a response is built.
- The chatbot cannot create rentals, sign, pay, extend, return equipment, settle
  money or confirm availability.
- The provider URL is fixed, redirects are disabled and responses are bounded by
  time and size.

## Backend verification

Run from the repository root:

```text
dotnet build RentalCamera.Api/RentalCamera.Api.csproj --configuration Release
dotnet run --project tests/Schema33Regression/Schema33Regression.csproj
```

`ChatbotChecks` exercises the configuration gate, privacy filter, normalized
provider input, allowlisted product/FAQ output, evidence sources and disabled
no-call behavior. It makes no database, mobile runtime or real provider call.
The separately approved environment still needs one authenticated API smoke test
with the intended database and provider credentials before release.
