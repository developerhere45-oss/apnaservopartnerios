import CoreLocation
import Foundation
import Security
import UIKit
import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum APIError: LocalizedError {
    case missingToken
    case invalidURL
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingToken: return "Firebase ID token missing. Sign in with Firebase Phone OTP."
        case .invalidURL: return "Backend URL invalid."
        case .badResponse(let message): return message
        }
    }
}

struct LocationPayload {
    var lat: Double
    var lng: Double
    var accuracy: Double
    var provider: String
    var isMock: Bool
    var bookingId: String
    var recordedAt: Int64
}

final class APIClient {
    private var activeBaseURL: URL
    private let baseURLs: [URL]
    private let session: URLSession

    init(baseURLs: [URL] = [AppConfig.apiBaseURL], session: URLSession = .shared) {
        self.baseURLs = baseURLs
        self.activeBaseURL = baseURLs[0]
        self.session = session
    }

    func upsertPartnerProfile(_ profile: PartnerProfile, fcmToken: String, token: String) async throws {
        let body: [String: Any] = [
            "name": profile.name,
            "phone": profile.phone,
            "email": profile.email,
            "dob": profile.dob,
            "gender": profile.gender,
            "address": profile.address,
            "city": profile.city,
            "state": profile.state,
            "pinCode": profile.pinCode,
            "emergencyContactNumber": profile.emergencyContactNumber,
            "yearsOfExperience": profile.yearsOfExperience,
            "workingAreas": profile.workingAreas,
            "languages": profile.languages,
            "serviceCategory": profile.skills.map(\.rawValue),
            "isOnline": profile.online,
            "serviceRadiusKm": profile.serviceRadiusKm,
            "serviceArea": profile.serviceArea,
            "lat": profile.lat,
            "lng": profile.lng,
            "fcmToken": fcmToken,
            "photoUrl": profile.photoURL,
            "faceVerified": profile.faceVerified
        ]
        let _: EmptyResponse = try await request(path: "/partners/profile", method: "POST", token: token, body: body)
    }

    func fetchPartnerProfile(current: PartnerProfile, token: String) async throws -> PartnerProfile {
        let envelope: PartnerProfileEnvelope = try await request(path: "/partners/me", token: token)
        return envelope.partner?.toProfile(fallback: current) ?? current
    }

    func saveFCMToken(_ fcmToken: String, token: String) async throws {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "ios-device"
        let androidPathBody: [String: Any] = [
            "token": fcmToken,
            "platform": "ios",
            "deviceId": deviceId,
            "appType": "partner"
        ]
        do {
            let _: EmptyResponse = try await request(path: "/notifications/device-token", method: "POST", token: token, body: androidPathBody)
        } catch {
            let _: EmptyResponse = try await request(path: "/partners/fcm-token", method: "POST", token: token, body: ["fcmToken": fcmToken])
        }
    }

    func requestAccountDeletion(reason: String, token: String) async throws {
        let _: EmptyResponse = try await request(path: "/partners/delete-account-request", method: "POST", token: token, body: ["reason": reason])
    }

    func fetchNotifications(token: String) async throws -> [PartnerNotificationItem] {
        do {
            let envelope: NotificationsEnvelope = try await request(path: "/notifications/my-notifications?role=partner&page=1&limit=25", token: token)
            return envelope.notifications ?? []
        } catch {
            let envelope: NotificationsEnvelope = try await request(path: "/notifications?role=partner&limit=25", token: token)
            return envelope.notifications ?? []
        }
    }

    func markNotificationRead(_ notificationId: String, token: String) async {
        guard !notificationId.isEmpty else { return }
        let _: EmptyResponse? = try? await request(path: "/notifications/\(notificationId)/read?role=partner", method: "PATCH", token: token, body: [:])
    }

    func markAllNotificationsRead(token: String) async {
        let _: EmptyResponse? = try? await request(path: "/notifications/read-all?role=partner", method: "PATCH", token: token, body: [:])
    }

    func setOnline(_ online: Bool, token: String) async throws {
        let _: EmptyResponse = try await request(path: online ? "/partners/online" : "/partners/offline", method: "POST", token: token, body: [:])
    }

    func updateLocation(_ location: LocationPayload, token: String) async throws {
        let body: [String: Any] = [
            "lat": location.lat,
            "lng": location.lng,
            "accuracy": location.accuracy,
            "provider": location.provider,
            "isMock": location.isMock,
            "bookingId": location.bookingId,
            "recordedAt": location.recordedAt
        ]
        let _: EmptyResponse = try await request(path: "/partners/location", method: "PATCH", token: token, body: body)
    }

    func fetchPartnerBookings(token: String) async throws -> [PartnerBooking] {
        let envelope: BookingEnvelope = try await request(path: "/bookings/partner", token: token)
        return envelope.bookings ?? []
    }

    func acceptBooking(_ bookingId: String, token: String) async throws -> PartnerBooking {
        let body: [String: Any] = [
            "arrivalEstimateMinutes": 30,
            "arrivalEstimateLabel": "30 minutes"
        ]
        let envelope: BookingEnvelope = try await request(path: "/bookings/\(bookingId)/accept", method: "POST", token: token, body: body)
        return envelope.booking ?? PartnerBooking(id: bookingId, serviceName: "Service", issue: "Accepted", customerName: "Customer", address: "Address", slot: "Slot", status: "accepted")
    }

    func rejectBooking(_ bookingId: String, token: String) async throws {
        let _: EmptyResponse = try await request(path: "/bookings/\(bookingId)/reject", method: "POST", token: token, body: [:])
    }

    func updateBookingStatus(_ bookingId: String, status: String, finalAmount: Int, location: LocationPayload?, token: String) async throws -> PartnerBooking {
        var body: [String: Any] = ["status": status, "finalAmount": finalAmount]
        if let location {
            body["lat"] = location.lat
            body["lng"] = location.lng
            body["accuracy"] = location.accuracy
            body["provider"] = location.provider
            body["isMock"] = location.isMock
            body["recordedAt"] = location.recordedAt
        }
        let envelope: BookingEnvelope = try await request(path: "/bookings/\(bookingId)/status", method: "PATCH", token: token, body: body)
        return envelope.booking ?? PartnerBooking(id: bookingId, serviceName: "Service", issue: "", customerName: "Customer", address: "", slot: "", finalAmount: finalAmount, status: status)
    }

    func createCallLog(bookingId: String, action: String, reason: String, token: String) async {
        let body: [String: Any] = ["action": action, "reason": reason]
        let _: EmptyResponse? = try? await request(path: "/bookings/\(bookingId)/calls", method: "POST", token: token, body: body)
    }

    func reportNoResponse(bookingId: String, reason: String, location: LocationPayload?, token: String) async throws {
        var body: [String: Any] = ["reason": reason, "evidenceUrl": ""]
        if let location {
            body["lat"] = location.lat
            body["lng"] = location.lng
            body["accuracy"] = location.accuracy
            body["provider"] = location.provider
            body["isMock"] = location.isMock
            body["recordedAt"] = location.recordedAt
        }
        let _: EmptyResponse = try await request(path: "/bookings/\(bookingId)/no-response-report", method: "POST", token: token, body: body)
    }

    func submitVerification(aadhaarLast4: String, selfieURL: String, faceVerified: Bool, selfieVerified: Bool, token: String) async throws {
        var body: [String: Any] = [
            "selfieUrl": selfieURL,
            "faceVerified": faceVerified,
            "selfieVerified": selfieVerified,
            "livenessChecks": [:]
        ]
        if !aadhaarLast4.isEmpty {
            body["aadhaarLast4"] = aadhaarLast4
        }
        if selfieURL.isEmpty {
            body.removeValue(forKey: "selfieUrl")
        }
        let _: EmptyResponse = try await request(path: "/partners/verification", method: "POST", token: token, body: body)
    }

    func createPartnerSupportTicket(
        category: String,
        message: String,
        clientMessageId: String,
        attachmentURL: String,
        priority: String = "high",
        roleContext: String = "partner",
        bookingId: String = "",
        metadata: [String: String] = [:],
        token: String
    ) async throws {
        let body: [String: Any] = [
            "category": category,
            "message": message,
            "clientMessageId": clientMessageId,
            "attachmentUrl": attachmentURL,
            "priority": priority,
            "roleContext": roleContext,
            "bookingId": bookingId,
            "metadata": metadata
        ]
        let _: EmptyResponse = try await request(path: "/partners/support-tickets", method: "POST", token: token, body: body)
    }

    func uploadDocument(documentType: String, fileURL: URL, aadhaarLast4: String, token: String) async throws {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: try makeURL(baseURL: activeBaseURL, path: "/partners/documents"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try multipartBody(boundary: boundary, documentType: documentType, fileURL: fileURL, aadhaarLast4: aadhaarLast4)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badResponse("Document upload failed: \(String(data: data, encoding: .utf8) ?? "")")
        }
    }

    func downloadStatement(from: String, to: String, token: String) async throws -> Data {
        var query: [String] = []
        if !from.isEmpty { query.append("from=\(from)") }
        if !to.isEmpty { query.append("to=\(to)") }
        let path = query.isEmpty ? "/partner/get-statement" : "/partner/get-statement?\(query.joined(separator: "&"))"
        return try await dataRequest(path: path, token: token)
    }

    func fetchBookingChatMessages(bookingId: String, token: String) async throws -> [ChatMessage] {
        let envelope: ChatEnvelope = try await request(path: "/bookings/\(bookingId)/chat/messages", token: token)
        return envelope.messages
    }

    func sendBookingChatMessage(bookingId: String, message: String, token: String) async throws -> ChatMessage {
        let clientMessageId = "IOSPARTNER\(Int(Date().timeIntervalSince1970 * 1000))"
        let envelope: SendChatEnvelope = try await request(
            path: "/bookings/\(bookingId)/chat/messages",
            method: "POST",
            token: token,
            body: ["message": message, "clientMessageId": clientMessageId]
        )
        return envelope.message ?? ChatMessage(id: clientMessageId, bookingId: bookingId, bookingCode: "", senderRole: "partner", senderName: "You", message: message, clientMessageId: clientMessageId, deliveryStatus: "sent", createdAtMillis: Int64(Date().timeIntervalSince1970 * 1000))
    }

    func monitorBookingChat(bookingId: String, message: String, clientMessageId: String, token: String) async {
        let body: [String: Any] = ["message": message, "clientMessageId": clientMessageId, "source": "partner_support_chat"]
        let _: EmptyResponse? = try? await request(path: "/bookings/\(bookingId)/chat/monitor", method: "POST", token: token, body: body)
    }

    func markBookingChatSeen(bookingId: String, token: String) async {
        let _: EmptyResponse? = try? await request(path: "/bookings/\(bookingId)/chat/seen", method: "PATCH", token: token, body: [:])
    }

    private func request<T: Decodable>(path: String, method: String = "GET", token: String, body: [String: Any]? = nil) async throws -> T {
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw APIError.missingToken }
        var lastError: Error?
        let ordered = [activeBaseURL] + baseURLs.filter { $0 != activeBaseURL }
        for baseURL in ordered {
            do {
                let value: T = try await execute(baseURL: baseURL, path: path, method: method, token: token, body: body)
                activeBaseURL = baseURL
                return value
            } catch {
                lastError = error
            }
        }
        throw lastError ?? APIError.badResponse("Backend not reachable.")
    }

    private func execute<T: Decodable>(baseURL: URL, path: String, method: String, token: String, body: [String: Any]?) async throws -> T {
        var request = URLRequest(url: try makeURL(baseURL: baseURL, path: path))
        request.httpMethod = method
        request.timeoutInterval = 14
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.badResponse("Backend response invalid.") }
        guard (200..<300).contains(http.statusCode) else { throw APIError.badResponse(httpError(code: http.statusCode, data: data)) }
        if data.isEmpty {
            if T.self == EmptyResponse.self { return EmptyResponse() as! T }
            throw APIError.badResponse("Backend returned empty response.")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func dataRequest(path: String, token: String) async throws -> Data {
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw APIError.missingToken }
        var request = URLRequest(url: try makeURL(baseURL: activeBaseURL, path: path))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.badResponse("PDF generation failed.")
        }
        return data
    }

    private func makeURL(baseURL: URL, path: String) throws -> URL {
        let parts = path.split(separator: "?", maxSplits: 1).map(String.init)
        let cleanPath = parts[0].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var url = baseURL
        for component in cleanPath.split(separator: "/") {
            url.appendPathComponent(String(component))
        }
        if parts.count > 1 {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.percentEncodedQuery = parts[1]
            guard let finalURL = components?.url else { throw APIError.invalidURL }
            return finalURL
        }
        return url
    }

    private func httpError(code: Int, data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = object["message"] as? String,
           !message.isEmpty {
            return "HTTP \(code): \(message)"
        }
        switch code {
        case 401, 403: return "Unauthorized. Please login again."
        case 409: return "Request conflicts with latest booking state."
        case 413: return "File too large."
        case 415: return "Unsupported file type."
        case 500...599: return "Server temporarily unavailable."
        default: return "Request failed."
        }
    }

    private func multipartBody(boundary: String, documentType: String, fileURL: URL, aadhaarLast4: String) throws -> Data {
        var data = Data()
        func addField(_ name: String, _ value: String) {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            data.append("\(value)\r\n".data(using: .utf8)!)
        }
        addField("documentType", documentType)
        addField("compressedByClient", "false")
        if !aadhaarLast4.isEmpty { addField("aadhaarLast4", aadhaarLast4) }
        let fileData = try Data(contentsOf: fileURL)
        addField("originalSizeBytes", "\(fileData.count)")
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"document\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(mimeType(for: fileURL))\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        return data
    }

    private func mimeType(for fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "png": return "image/png"
        case "pdf": return "application/pdf"
        default: return "image/jpeg"
        }
    }
}

final class SecureStore {
    private let service = "com.apnaservo.partnerios.secure"

    func string(for key: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func set(_ value: String, for key: String) {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        guard let data = value.data(using: .utf8) else { return }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}

extension Notification.Name {
    static let apnaServoFCMTokenUpdated = Notification.Name("apnaServoFCMTokenUpdated")
}

final class AppNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationService()
    private(set) var fcmToken = ""

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        #if canImport(FirebaseMessaging)
        guard FirebaseApp.app() != nil else { return }
        Messaging.messaging().delegate = self
        if let token = Messaging.messaging().fcmToken {
            updateFCMToken(token)
        }
        #endif
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            return false
        }
    }

    func setAPNSToken(_ deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        guard FirebaseApp.app() != nil else { return }
        Messaging.messaging().apnsToken = deviceToken
        #endif
    }

    func refreshFCMToken() async -> String {
        #if canImport(FirebaseMessaging)
        guard FirebaseApp.app() != nil else { return fcmToken }
        let token: String = await withCheckedContinuation { continuation in
            Messaging.messaging().token { token, _ in
                if let token {
                    self.updateFCMToken(token)
                }
                continuation.resume(returning: self.fcmToken)
            }
        }
        return token
        #else
        return fcmToken
        #endif
    }

    private func updateFCMToken(_ token: String) {
        fcmToken = token
        NotificationCenter.default.post(name: .apnaServoFCMTokenUpdated, object: token)
    }

    func showBookingRequestNotification(_ booking: PartnerBooking) {
        let content = UNMutableNotificationContent()
        content.title = "New \(booking.serviceName) booking"
        content.body = "\(booking.customerName) | \(booking.city) | \(booking.slot)"
        content.sound = .default
        content.categoryIdentifier = "booking_request"
        content.userInfo = ["bookingId": booking.id, "bookingCode": booking.bookingCode]
        let request = UNNotificationRequest(identifier: "booking-\(booking.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

#if canImport(FirebaseMessaging)
extension AppNotificationService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        updateFCMToken(fcmToken ?? "")
    }
}
#endif

final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func currentLocation() async -> CLLocation {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            if manager.authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            }
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let fallback = CLLocation(latitude: AppConfig.defaultLatitude, longitude: AppConfig.defaultLongitude)
        continuation?.resume(returning: locations.last ?? fallback)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: CLLocation(latitude: AppConfig.defaultLatitude, longitude: AppConfig.defaultLongitude))
        continuation = nil
    }
}
