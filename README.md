# ApnaServoPartnerIOS

Native SwiftUI Partner App recreated from the Android Partner App.

## Open

Open `ApnaServoPartnerIOS.xcodeproj` on macOS in Xcode, select the `ApnaServoPartnerIOS` target, set signing, then run on an iPhone simulator/device.

## Included

- Partner login/register profile flow
- Dashboard with online toggle, stats, new/active bookings
- Request accept/reject and job lifecycle updates
- Partner GPS heartbeat and Apple Maps navigation
- Bookings, earnings, statement PDF download
- Notifications, profile tools, documents, verification, services/radius/area
- Protected call/no-response reporting
- Booking chat and partner support chat
- URLSession API calls matching Android endpoints
- UserDefaults + Keychain-style storage
- Imported Android raster assets bundled in `ImportedAndroidAssets`

## Xcode Setup

- Add `GoogleService-Info.plist` before enabling Firebase Auth/Messaging.
- Add Firebase iOS packages if push notifications and automatic Firebase ID tokens are required.
- Paste and save a Firebase ID token on login/register until automatic Firebase sign-in is wired.
- Enable APNs/push notification capability for production booking alerts.
- Set the signing team on the `ApnaServoPartnerIOS` target.
- Backend base URL is in `ApnaServoPartnerIOS/App/AppConfig.swift`.

This Windows workspace cannot run `xcodebuild`; open the project on macOS and build from Xcode.
