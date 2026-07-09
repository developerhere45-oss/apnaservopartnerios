import Foundation
import SwiftUI
import UIKit

@MainActor
final class PartnerAppStore: ObservableObject {
    @Published var screen: PartnerScreen = .login
    @Published var profile = PartnerProfile()
    @Published var authToken = ""
    @Published var fcmToken = ""
    @Published var bookings: [PartnerBooking] = []
    @Published var selectedBooking: PartnerBooking?
    @Published var notifications: [PartnerNotificationItem] = []
    @Published var messages: [ChatMessage] = []
    @Published var supportMessages: [ChatMessage] = []
    @Published var loading = false
    @Published var errorMessage = ""
    @Published var infoMessage = ""
    @Published var supportType = "Chat"
    @Published var statementFrom = ""
    @Published var statementTo = ""
    @Published var aadhaarLast4 = ""
    @Published var documentStatuses: [String: String] = [:]
    @Published var uploadingDocumentType = ""
    @Published var realtimeConnected = false
    @Published var lastRealtimeSyncAt: Date?
    @Published var phoneVerificationSent = false
    @Published var phoneOTP = ""

    private let api = APIClient()
    private let secureStore = SecureStore()
    private let notificationService = AppNotificationService.shared
    private let firebaseAuth = FirebaseAuthService()
    private let locationService = LocationService()
    private let defaults = UserDefaults.standard
    private let profileKey = "apnaservo_partner_profile"
    private let bookingsKey = "apnaservo_partner_bookings"
    private let tokenKey = "firebase_id_token"
    private var refreshTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var notifiedPendingBookingIds = Set<String>()
    private var realtimeFailureCount = 0
    private var phoneVerificationID = ""
    private var fcmTokenObserver: NSObjectProtocol?

    init() {
        loadLocalState()
        notificationService.configure()
        fcmTokenObserver = NotificationCenter.default.addObserver(forName: .apnaServoFCMTokenUpdated, object: nil, queue: .main) { [weak self] notification in
            guard let token = notification.object as? String else { return }
            Task { @MainActor in
                self?.fcmToken = token
                self?.defaults.set(token, forKey: "partner_fcm_token")
                await self?.saveFCMTokenIfNeeded()
            }
        }
    }

    deinit {
        if let fcmTokenObserver {
            NotificationCenter.default.removeObserver(fcmTokenObserver)
        }
    }

    var hasBackendSession: Bool { !authToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var loggedIn: Bool { profile.isValid && hasBackendSession }
    var pendingBookings: [PartnerBooking] { bookings.filter(\.isPending) }
    var activeBookings: [PartnerBooking] { bookings.filter(\.isActive) }
    var completedBookings: [PartnerBooking] { bookings.filter { $0.status == "completed" } }
    var totalEarnings: Int { completedBookings.reduce(0) { $0 + $1.amount } }
    var todayEarnings: Int {
        let calendar = Calendar.current
        return completedBookings
            .filter { calendar.isDate(Date(milliseconds: $0.completedAtMillis), inSameDayAs: Date()) }
            .reduce(0) { $0 + $1.amount }
    }
    var monthEarnings: Int {
        let calendar = Calendar.current
        let now = Date()
        return completedBookings
            .filter { calendar.isDate(Date(milliseconds: $0.completedAtMillis), equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    func loadLocalState() {
        if let data = defaults.data(forKey: profileKey),
           let saved = try? JSONDecoder().decode(PartnerProfile.self, from: data) {
            profile = saved
            screen = .login
        }
        if let data = defaults.data(forKey: bookingsKey),
           let saved = try? JSONDecoder().decode([PartnerBooking].self, from: data) {
            bookings = saved
            notifiedPendingBookingIds = Set(saved.filter(\.isPending).map(\.id))
        }
        fcmToken = defaults.string(forKey: "partner_fcm_token") ?? ""
        supportMessages = [
            ChatMessage(id: "support-welcome", bookingId: "support", bookingCode: "", senderRole: "support", senderName: "Partner Support", message: "Welcome to partner support. How can we help?", clientMessageId: "", deliveryStatus: "sent", createdAtMillis: Int64(Date().timeIntervalSince1970 * 1000))
        ]
        if loggedIn {
            startRealtimePolling()
            startLocationHeartbeat()
        }
    }

    func persistProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: profileKey)
        }
    }

    func persistBookings() {
        if let data = try? JSONEncoder().encode(bookings) {
            defaults.set(data, forKey: bookingsKey)
        }
    }

    @discardableResult
    private func refreshBackendToken(forceRefresh: Bool = false) async -> Bool {
        do {
            if let token = try await firebaseAuth.currentIDToken(forceRefresh: forceRefresh) {
                authToken = token
                secureStore.set(token, for: tokenKey)
                return true
            }
        } catch {
            if forceRefresh {
                errorMessage = error.localizedDescription
            }
        }
        return false
    }

    private func usableAuthToken(forceRefresh: Bool = false) async throws -> String {
        guard await refreshBackendToken(forceRefresh: forceRefresh) else {
            throw APIError.missingToken
        }
        return authToken
    }

    private func normalizedPhoneNumber() throws -> String {
        let raw = profile.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("+") {
            let digits = raw.dropFirst().filter(\.isNumber)
            guard digits.count >= 10 else { throw FirebaseServiceError.invalidPhone }
            return "+\(digits)"
        }
        let digits = raw.filter(\.isNumber)
        guard digits.count == 10 else { throw FirebaseServiceError.invalidPhone }
        return "+91\(digits)"
    }

    private func maskedPhoneNumber() -> String {
        let digits = profile.phone.filter(\.isNumber)
        guard digits.count >= 4 else { return profile.phone }
        return "******\(digits.suffix(4))"
    }

    func saveAuthToken() {
        authToken = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !authToken.isEmpty else {
            errorMessage = "Firebase ID token blank hai. Valid backend token paste karo."
            return
        }
        secureStore.set(authToken, for: tokenKey)
        infoMessage = "Backend token saved."
    }

    func completeLogin() {
        Task { await completeLoginWithFirebase() }
    }

    func restoreFirebaseSession() async {
        guard profile.isValid, !hasBackendSession else { return }
        do {
            guard let token = try await firebaseAuth.currentIDToken(forceRefresh: false) else { return }
            await finishAuthenticatedLogin(token: token, requestNotifications: false)
        } catch {
            authToken = ""
            secureStore.set("", for: tokenKey)
            screen = .login
        }
    }

    private func completeLoginWithFirebase() async {
        guard profile.isValid else {
            errorMessage = "Name, 10 digit phone, aur at least one service required hai."
            return
        }
        loading = true
        defer { loading = false }
        do {
            if let token = try await firebaseAuth.currentIDToken(forceRefresh: true) {
                await finishAuthenticatedLogin(token: token, requestNotifications: true)
                return
            }
            if phoneVerificationSent {
                let code = phoneOTP.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !phoneVerificationID.isEmpty, !code.isEmpty else {
                    errorMessage = FirebaseServiceError.otpRequired.localizedDescription
                    return
                }
                let token = try await firebaseAuth.confirmPhoneOTP(verificationID: phoneVerificationID, code: code)
                phoneVerificationSent = false
                phoneVerificationID = ""
                phoneOTP = ""
                await finishAuthenticatedLogin(token: token, requestNotifications: true)
                return
            }
            phoneVerificationID = try await firebaseAuth.startPhoneVerification(phoneNumber: normalizedPhoneNumber())
            phoneVerificationSent = true
            infoMessage = "Firebase OTP sent to \(maskedPhoneNumber()). OTP enter karke Continue dabao."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishAuthenticatedLogin(token: String, requestNotifications: Bool) async {
        authToken = token
        secureStore.set(token, for: tokenKey)
        persistProfile()
        screen = .dashboard
        if requestNotifications {
            _ = await notificationService.requestPermission()
        }
        fcmToken = await notificationService.refreshFCMToken()
        defaults.set(fcmToken, forKey: "partner_fcm_token")
        await saveFCMTokenIfNeeded()
        await syncPartnerProfile()
        await refreshAll()
        startRealtimePolling()
        startLocationHeartbeat()
    }

    func logout() {
        refreshTask?.cancel()
        heartbeatTask?.cancel()
        profile = PartnerProfile()
        authToken = ""
        fcmToken = ""
        bookings = []
        selectedBooking = nil
        realtimeConnected = false
        lastRealtimeSyncAt = nil
        phoneVerificationSent = false
        phoneVerificationID = ""
        phoneOTP = ""
        firebaseAuth.signOut()
        secureStore.set("", for: tokenKey)
        defaults.removeObject(forKey: profileKey)
        defaults.removeObject(forKey: bookingsKey)
        defaults.removeObject(forKey: "partner_fcm_token")
        screen = .login
    }

    func syncPartnerProfile() async {
        guard profile.isValid else { return }
        do {
            let token = try await usableAuthToken()
            try await api.upsertPartnerProfile(profile, fcmToken: fcmToken, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveFCMTokenIfNeeded() async {
        if fcmToken.isEmpty {
            fcmToken = await notificationService.refreshFCMToken()
            defaults.set(fcmToken, forKey: "partner_fcm_token")
        }
        guard !fcmToken.isEmpty, hasBackendSession else { return }
        do {
            let token = try await usableAuthToken()
            try await api.saveFCMToken(fcmToken, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchRemoteProfile() async {
        do {
            let token = try await usableAuthToken()
            profile = try await api.fetchPartnerProfile(current: profile, token: token)
            persistProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleOnline() {
        profile.online.toggle()
        persistProfile()
        Task {
            do {
                let token = try await usableAuthToken()
                try await api.setOnline(profile.online, token: token)
                await syncPartnerProfile()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func refreshAll(silent: Bool = false) async {
        guard await refreshBackendToken() else {
            realtimeConnected = false
            return
        }
        let bookingsOK = await fetchBookings(surfaceErrors: !silent)
        let notificationsOK = await fetchNotifications(surfaceErrors: !silent)
        if bookingsOK || notificationsOK {
            realtimeConnected = true
            realtimeFailureCount = 0
            lastRealtimeSyncAt = Date()
        } else if !authToken.isEmpty {
            realtimeConnected = false
            realtimeFailureCount = min(realtimeFailureCount + 1, 8)
        }
    }

    @discardableResult
    func fetchBookings(surfaceErrors: Bool = true) async -> Bool {
        guard await refreshBackendToken() else {
            realtimeConnected = false
            return false
        }
        do {
            let live = try await api.fetchPartnerBookings(token: authToken)
            mergeBookings(live)
            return true
        } catch {
            if surfaceErrors { errorMessage = error.localizedDescription }
            return false
        }
    }

    @discardableResult
    func fetchNotifications(surfaceErrors: Bool = true) async -> Bool {
        guard await refreshBackendToken() else {
            realtimeConnected = false
            return false
        }
        do {
            notifications = try await api.fetchNotifications(token: authToken)
            return true
        } catch {
            if surfaceErrors { errorMessage = error.localizedDescription }
            return false
        }
    }

    func markNotificationRead(_ item: PartnerNotificationItem) {
        Task {
            let token = (try? await usableAuthToken()) ?? authToken
            await api.markNotificationRead(item.id, token: token)
            if let index = notifications.firstIndex(where: { $0.id == item.id }) {
                notifications[index].isRead = true
            }
        }
    }

    func markAllNotificationsRead() {
        Task {
            let token = (try? await usableAuthToken()) ?? authToken
            await api.markAllNotificationsRead(token: token)
            for index in notifications.indices {
                notifications[index].isRead = true
            }
            infoMessage = "Messages marked as read."
        }
    }

    func openBooking(_ booking: PartnerBooking) {
        selectedBooking = booking
        screen = booking.isPending ? .request : .detail
    }

    func acceptSelectedBooking() {
        guard let booking = selectedBooking else { return }
        loading = true
        Task {
            do {
                let token = try await usableAuthToken()
                let accepted = try await api.acceptBooking(booking.id, token: token)
                upsertBooking(accepted)
                selectedBooking = accepted
                screen = .detail
                infoMessage = "Booking accepted."
            } catch {
                errorMessage = error.localizedDescription
            }
            loading = false
        }
    }

    func rejectSelectedBooking() {
        guard let booking = selectedBooking else { return }
        loading = true
        Task {
            do {
                let token = try await usableAuthToken()
                try await api.rejectBooking(booking.id, token: token)
                var rejected = booking
                rejected.status = "rejected"
                upsertBooking(rejected)
                selectedBooking = nil
                screen = .dashboard
                infoMessage = "Booking rejected."
            } catch {
                errorMessage = error.localizedDescription
            }
            loading = false
        }
    }

    func updateSelectedStatus(_ status: String) {
        guard var booking = selectedBooking else { return }
        loading = true
        Task {
            let location = await makeLocationPayload(bookingId: booking.id)
            do {
                let token = try await usableAuthToken()
                let updated = try await api.updateBookingStatus(booking.id, status: status, finalAmount: booking.amount, location: location, token: token)
                booking = updated
                upsertBooking(updated)
                selectedBooking = booking
                if status == "completed" {
                    screen = .bookings
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            loading = false
        }
    }

    func reportNoResponse(reason: String) {
        guard let booking = selectedBooking else { return }
        Task {
            let location = await makeLocationPayload(bookingId: booking.id)
            do {
                let token = try await usableAuthToken()
                try await api.reportNoResponse(bookingId: booking.id, reason: reason, location: location, token: token)
                infoMessage = "No-response report submitted."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func openMap(_ booking: PartnerBooking) {
        selectedBooking = booking
        screen = .map
    }

    func openAppleMaps(_ booking: PartnerBooking) {
        let url = URL(string: "http://maps.apple.com/?daddr=\(booking.lat),\(booking.lng)&dirflg=d")!
        openExternalURL(url)
    }

    func callCustomer(_ booking: PartnerBooking) {
        let digits = booking.customerPhone.filter(\.isNumber)
        guard !digits.isEmpty, let url = URL(string: "tel://\(digits)") else {
            errorMessage = "Customer phone hidden or unavailable."
            return
        }
        Task {
            let token = (try? await usableAuthToken()) ?? authToken
            await api.createCallLog(bookingId: booking.id, action: "start", reason: "", token: token)
        }
        openExternalURL(url)
    }

    func openBookingChat(_ booking: PartnerBooking) {
        selectedBooking = booking
        screen = .bookingChat
        Task { await loadBookingChat() }
    }

    func loadBookingChat() async {
        guard let booking = selectedBooking else { return }
        do {
            let token = try await usableAuthToken()
            messages = try await api.fetchBookingChatMessages(bookingId: booking.id, token: token)
            await api.markBookingChatSeen(bookingId: booking.id, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendBookingChatMessage(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let booking = selectedBooking, !clean.isEmpty else { return }
        let local = ChatMessage.local(text: clean, booking: booking)
        messages.append(local)
        Task {
            do {
                let token = try await usableAuthToken()
                let sent = try await api.sendBookingChatMessage(bookingId: booking.id, message: clean, token: token)
                if let index = messages.firstIndex(where: { $0.id == local.id }) {
                    messages[index] = sent
                }
                await api.monitorBookingChat(bookingId: booking.id, message: clean, clientMessageId: sent.clientMessageId, token: token)
            } catch {
                if let index = messages.firstIndex(where: { $0.id == local.id }) {
                    messages[index].deliveryStatus = "failed"
                }
                errorMessage = error.localizedDescription
            }
        }
    }

    func openSupport(_ type: String, draft: String = "") {
        supportType = type
        if !draft.isEmpty {
            supportMessages.append(ChatMessage(id: UUID().uuidString, bookingId: "support", bookingCode: "", senderRole: "partner", senderName: "You", message: draft, clientMessageId: "", deliveryStatus: "draft", createdAtMillis: Int64(Date().timeIntervalSince1970 * 1000)))
        }
        screen = .support
    }

    func sendSupportMessage(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let clientMessageId = "IOSSUPPORT\(Int(Date().timeIntervalSince1970 * 1000))"
        let local = ChatMessage(id: clientMessageId, bookingId: "support", bookingCode: "", senderRole: "partner", senderName: "You", message: clean, clientMessageId: clientMessageId, deliveryStatus: "queued", createdAtMillis: Int64(Date().timeIntervalSince1970 * 1000))
        supportMessages.append(local)
        Task {
            do {
                let token = try await usableAuthToken()
                try await api.createPartnerSupportTicket(category: supportType, message: clean, clientMessageId: clientMessageId, attachmentURL: "", token: token)
                if let index = supportMessages.firstIndex(where: { $0.id == clientMessageId }) {
                    supportMessages[index].deliveryStatus = "sent"
                }
                infoMessage = "Support request submitted."
            } catch {
                if let index = supportMessages.firstIndex(where: { $0.id == clientMessageId }) {
                    supportMessages[index].deliveryStatus = "failed"
                }
                errorMessage = error.localizedDescription
            }
        }
    }

    func submitVerification() {
        guard aadhaarLast4.isEmpty || aadhaarLast4.range(of: #"^\d{4}$"#, options: .regularExpression) != nil else {
            errorMessage = "Enter the last 4 digits of Aadhaar."
            return
        }
        Task {
            do {
                let token = try await usableAuthToken()
                try await api.submitVerification(aadhaarLast4: aadhaarLast4, selfieURL: profile.photoURL, faceVerified: false, selfieVerified: false, token: token)
                persistProfile()
                infoMessage = "Verification submitted for review."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func uploadDocument(documentType: String, fileURL: URL) {
        Task {
            let scoped = fileURL.startAccessingSecurityScopedResource()
            defer {
                if scoped { fileURL.stopAccessingSecurityScopedResource() }
            }
            do {
                let allowedExtensions = ["jpg", "jpeg", "png", "pdf"]
                guard allowedExtensions.contains(fileURL.pathExtension.lowercased()) else {
                    errorMessage = "Only JPG, PNG or PDF documents are allowed."
                    return
                }
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
                guard size <= AppConfig.maxDocumentBytes else {
                    errorMessage = "Document must be under 5 MB."
                    return
                }
                uploadingDocumentType = documentType
                documentStatuses[documentType] = "Uploading"
                let token = try await usableAuthToken()
                try await api.uploadDocument(documentType: documentType, fileURL: fileURL, aadhaarLast4: aadhaarLast4, token: token)
                documentStatuses[documentType] = "Uploaded"
                infoMessage = "\(documentType) uploaded for verification."
            } catch {
                documentStatuses[documentType] = "Failed"
                errorMessage = error.localizedDescription
            }
            uploadingDocumentType = ""
        }
    }

    func requestAccountDeletion(reason: String = "Partner requested account deletion from iOS app") {
        Task {
            do {
                let token = try await usableAuthToken()
                try await api.requestAccountDeletion(reason: reason, token: token)
                logout()
                infoMessage = "Account deletion request submitted."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func downloadStatement() {
        Task {
            do {
                let token = try await usableAuthToken()
                let data = try await api.downloadStatement(from: statementFrom, to: statementTo, token: token)
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("apnaservo-job-statement.pdf")
                try data.write(to: url)
                openExternalURL(url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func startRealtimePolling() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshAll(silent: true)
                let delay = await self?.realtimeDelayNanoseconds() ?? AppConfig.refreshSeconds
                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }

    func startLocationHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sendLocationHeartbeat()
                try? await Task.sleep(nanoseconds: AppConfig.locationHeartbeatSeconds)
            }
        }
    }

    func sendLocationHeartbeat() async {
        guard profile.online else { return }
        let payload = await makeLocationPayload(bookingId: activeBookings.first?.id ?? "")
        do {
            let token = try await usableAuthToken()
            try await api.updateLocation(payload, token: token)
            profile.lat = payload.lat
            profile.lng = payload.lng
            persistProfile()
        } catch {
        }
    }

    func setSkill(_ skill: PartnerSkill, selected: Bool) {
        if selected {
            profile.skills.insert(skill)
        } else if profile.skills.count > 1 {
            profile.skills.remove(skill)
        }
        persistProfile()
    }

    private func makeLocationPayload(bookingId: String) async -> LocationPayload {
        let location = await locationService.currentLocation()
        return LocationPayload(
            lat: location.coordinate.latitude,
            lng: location.coordinate.longitude,
            accuracy: max(location.horizontalAccuracy, 0),
            provider: "ios-corelocation",
            isMock: false,
            bookingId: bookingId,
            recordedAt: Int64(Date().timeIntervalSince1970 * 1000)
        )
    }

    private func mergeBookings(_ live: [PartnerBooking]) {
        let existingIds = Set(bookings.map(\.id))
        for booking in live {
            upsertBooking(booking, persist: false)
            if booking.isPending,
               !existingIds.contains(booking.id),
               !notifiedPendingBookingIds.contains(booking.id) {
                notifiedPendingBookingIds.insert(booking.id)
                notificationService.showBookingRequestNotification(booking)
                notifications.insert(
                    PartnerNotificationItem(
                        id: "local-\(booking.id)",
                        title: "New request available",
                        body: "\(booking.serviceName) | \(booking.slot)",
                        type: "booking_request",
                        bookingId: booking.id,
                        isRead: false
                    ),
                    at: 0
                )
            }
        }
        persistBookings()
        if let selected = selectedBooking,
           let updated = bookings.first(where: { $0.id == selected.id }) {
            selectedBooking = updated
        }
    }

    private func upsertBooking(_ booking: PartnerBooking, persist: Bool = true) {
        if let index = bookings.firstIndex(where: { $0.id == booking.id || (!$0.bookingCode.isEmpty && $0.bookingCode == booking.bookingCode) }) {
            bookings[index] = booking
        } else {
            bookings.insert(booking, at: 0)
        }
        if persist { persistBookings() }
    }

    private func openExternalURL(_ url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func realtimeDelayNanoseconds() -> UInt64 {
        if realtimeFailureCount == 0 {
            return AppConfig.refreshSeconds
        }
        let seconds = min(30, 4 + realtimeFailureCount * 3)
        return UInt64(seconds) * 1_000_000_000
    }

}

private extension Date {
    init(milliseconds: Int64) {
        if milliseconds > 0 {
            self.init(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
        } else {
            self.init(timeIntervalSince1970: 0)
        }
    }
}
