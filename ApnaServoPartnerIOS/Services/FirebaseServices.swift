import Foundation
import UIKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

enum FirebaseServiceError: LocalizedError {
    case missingGoogleServicePlist
    case authUnavailable
    case currentUserMissing
    case invalidPhone
    case otpRequired

    var errorDescription: String? {
        switch self {
        case .missingGoogleServicePlist:
            return "GoogleService-Info.plist missing hai. Firebase Console se iOS app plist add karo."
        case .authUnavailable:
            return "Firebase Auth SDK unavailable hai. Xcode package resolve karke dobara build karo."
        case .currentUserMissing:
            return "Firebase user session missing hai. Phone OTP se login karo."
        case .invalidPhone:
            return "Valid 10 digit Indian mobile number required hai."
        case .otpRequired:
            return "Firebase OTP enter karo, phir continue dabao."
        }
    }
}

final class FirebaseAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureFirebaseIfPossible()
        AppNotificationService.shared.configure()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        AppNotificationService.shared.setAPNSToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    private func configureFirebaseIfPossible() {
        #if canImport(FirebaseCore)
        guard FirebaseApp.app() == nil else { return }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print(FirebaseServiceError.missingGoogleServicePlist.localizedDescription)
            return
        }
        FirebaseApp.configure()
        #endif
    }
}

final class FirebaseAuthService {
    func currentIDToken(forceRefresh: Bool = false) async throws -> String? {
        #if canImport(FirebaseAuth)
        guard FirebaseApp.app() != nil else { throw FirebaseServiceError.missingGoogleServicePlist }
        guard let user = Auth.auth().currentUser else { return nil }
        let token: String? = try await withCheckedThrowingContinuation { continuation in
            user.getIDTokenForcingRefresh(forceRefresh) { token, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: token)
                }
            }
        }
        return token
        #else
        throw FirebaseServiceError.authUnavailable
        #endif
    }

    func startPhoneVerification(phoneNumber: String) async throws -> String {
        #if canImport(FirebaseAuth)
        guard FirebaseApp.app() != nil else { throw FirebaseServiceError.missingGoogleServicePlist }
        let verificationID: String = try await withCheckedThrowingContinuation { continuation in
            PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let verificationID {
                    continuation.resume(returning: verificationID)
                } else {
                    continuation.resume(throwing: FirebaseServiceError.currentUserMissing)
                }
            }
        }
        return verificationID
        #else
        throw FirebaseServiceError.authUnavailable
        #endif
    }

    func confirmPhoneOTP(verificationID: String, code: String) async throws -> String {
        #if canImport(FirebaseAuth)
        guard FirebaseApp.app() != nil else { throw FirebaseServiceError.missingGoogleServicePlist }
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: code)
        let result: AuthDataResult = try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(with: credential) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: FirebaseServiceError.currentUserMissing)
                }
            }
        }
        let token: String = try await withCheckedThrowingContinuation { continuation in
            result.user.getIDTokenForcingRefresh(true) { token, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: FirebaseServiceError.currentUserMissing)
                }
            }
        }
        return token
        #else
        throw FirebaseServiceError.authUnavailable
        #endif
    }

    func signOut() {
        #if canImport(FirebaseAuth)
        try? Auth.auth().signOut()
        #endif
    }
}
