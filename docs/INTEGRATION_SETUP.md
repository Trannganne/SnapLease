# Mobile product handoff

Use the existing Flutter project, its `pubspec.yaml` and committed `pubspec.lock`.
The Backend contract/configuration handoff is `Docs/INTEGRATION_HANDOFF.md` in the
Backend repository. No API/DB migration, APK installation or service send happens
as part of preparing this commit.

## Environment-owned setup

1. Install a Flutter SDK compatible with the existing Dart SDK constraint. Run
   `flutter pub get` to restore the locked packages; do not upgrade dependencies
   merely to run this handoff. Firebase core/messaging and Android Google Services
   integration are required; minimum Android SDK is24.
2. Obtain the Android configuration for your Firebase project and the existing
   `vn.rentcam.rentcam` application ID. Put it at
   `android/app/google-services.json` locally. That real file is excluded from Git.
   `google-services.json.example` documents its shape only; its placeholders are
   not a working Firebase registration. Backend service-account/project settings
   must agree with the operator's Firebase setup. No server credentials belong
   in Flutter. iOS Firebase provisioning has not been prepared by this handoff.
3. Use an explicit API endpoint, for example:

       flutter run -d <your-device> -t lib/main.dart --dart-define=BASE_URL=http://127.0.0.1:5001

   With a USB Android device first map the selected test API port:

       adb -s <your-device> reverse tcp:5001 tcp:5001

   For an emulator use `http://10.0.2.2:<port>`; for LAN use the reachable host
   address via BASE_URL. Never commit a private machine IP. Choose the actual
   Backend deployment/port and configure its allowed origins when testing Web.
4. Product routing in the committed tree starts at login. The local test-start
   route, review/notification preview routes, fixtures and mock reset hook are
   intentionally not part of the shipped changes. Their working copies are
   preserved for their owner; do not depend on them in a product build.
5. The existing font files in `assets/fonts` and image directory declared in
   pubspec are required by contract/appendix PDFs and the UI. Restore them from
   Git along with the source. Unreferenced draft banner images are not required.

Machine-specific Gradle memory, worker and cross-drive Kotlin troubleshooting
changes are not included. Keep necessary local overrides on the operator's own
machine; do not copy another machine's SDK paths, caches, private keys or CA.

## Implemented product paths

- Real repository-backed cart, selection/version-aware checkout, hold editing,
  exact pickup/return time selection and server-synchronized countdown. Successful
  actual period changes reset20 minutes; branch-only/no-op/read/error do not.
- Backend-driven contract list/detail, signed-document access, signature email
  destination/error mapping, contract terms/PDF and appendix signing UI.
- Cash deposit request and server-authoritative payment status. Pending request
  does not mean the store received money. Timeout handling reconciles with reads
  and does not automatically POST/open another VNPAY link.
- Review submission/detail/publication mapping, actual eligible contract-detail
  IDs and immediate-public/hidden/legacy visibility states.
- FCM registration/logout integration, inbox grouping/unread state and navigation
  to the actual authorized notification/contract target.
- Shared loading, skeleton and notice components reused across product pages.

Staff actions belong to the Backend/Web APIs, not fake customer-side state changes.
Approval is not effective renewal: only a successfully signed/committed appendix
may change effective due. Flutter must display Backend prices/statuses. This
handoff does not introduce new business policy or a new review push event.

## Validation and remaining issues

Reuse earlier focused source/regression results for unchanged files. The commit
preparation separately checks the shipped dependency graph after excluding local
preview/mock/config pieces; it does not claim an APK build or install.

The user has confirmed real-device checkout/TTL/edit flows, actual email OTP
contract signing, signed PDF after a refreshed detail page, simulated cash deposit,
Android notification, correct-contract navigation and matching paid/awaiting-
handover state. This is evidence for that observed case, not every foreground,
background or cold-start path, nor proof that an arbitrary Firebase deployment works.

Known issues are intentionally not fixed by a commit-only handoff:

- Immediately after OTP signing, the payment screen can retain old PDF metadata
  and say no signed document. Reopen and refresh the actual contract detail before
  viewing its Backend PDF. Do not request another OTP or manufacture a replacement PDF.
- Recorded cash-request dialog title has insufficient contrast on white.
- A previous cold-start notification flow required login; persistence remains a
  limitation. There is no Customer confirmation UI/API for receiving a refunded deposit.
- Effective appendix signing/updated due and the complete return/settlement/refund
  path still need real-device testing; approval alone is not PASS.
- VNPAY Sandbox callback/tunnel/merchant readiness is pending and outside the
  current cash/renewal mobile test. Do not use real money/cards or fake callbacks.

If a write times out or fails ambiguously, stop and reconcile the actual server
record before proposing another attempt. Never fake dates, states or successful
payments in the app. Existing security cooldown/expiry/rate limits still apply.
