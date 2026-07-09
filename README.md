# ApnaServoPartnerIOS

Native SwiftUI Partner App recreated from the Android Partner App.

## Open

Open `ApnaServoPartnerIOS.xcodeproj` on macOS in Xcode, select the `ApnaServoPartnerIOS` target, set signing, then run on an iPhone simulator/device.

## Included

- Partner login/register profile flow
- Firebase Phone Auth with automatic backend ID token refresh
- Firebase Cloud Messaging/APNs registration for booking alerts
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

- Add your Firebase iOS app with bundle ID `com.apnaservo.partnerios`.
- Download `GoogleService-Info.plist` from Firebase Console and add it to the `ApnaServoPartnerIOS` target.
- Enable Firebase Authentication Phone provider.
- Upload your Apple APNs auth key/certificate in Firebase Cloud Messaging settings.
- Enable Push Notifications capability and set the signing team on the `ApnaServoPartnerIOS` target.
- Backend base URL is in `ApnaServoPartnerIOS/App/AppConfig.swift`.

This Windows workspace cannot run `xcodebuild`; open the project on macOS and build from Xcode.
