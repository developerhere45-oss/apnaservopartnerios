import MapKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PartnerAppView: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            content
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsBottomNav {
                PartnerBottomNav()
            }
        }
        .task {
            await store.refreshAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await store.refreshAll() }
        }
    }

    private var showsBottomNav: Bool {
        ![.request, .bookingChat, .map].contains(store.screen)
    }

    @ViewBuilder
    private var content: some View {
        switch store.screen {
        case .dashboard: DashboardScreen()
        case .request: IncomingRequestScreen()
        case .detail: OrderDetailScreen()
        case .bookings: PartnerBookingsScreen()
        case .earnings: EarningsScreen()
        case .map: PartnerMapScreen()
        case .notifications: PartnerNotificationsScreen()
        case .profile: PartnerProfileScreen()
        case .personalInfo: PersonalInfoScreen()
        case .documents: DocumentsScreen()
        case .myServices: MyServicesScreen()
        case .settings: PartnerSettingsScreen()
        case .legal: PartnerLegalScreen()
        case .support: PartnerSupportChatScreen()
        case .bookingChat: BookingChatView()
        case .login: PartnerLoginView()
        }
    }
}

struct DashboardScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ReferencePage {
            HStack(spacing: 10) {
                PlainHeaderButton(systemImage: "line.3.horizontal") { store.screen = .profile }
                Spacer()
                AndroidAssetImage(name: "apna_servo_logo")
                    .frame(width: 148, height: 50)
                Spacer()
                PlainHeaderButton(systemImage: "qrcode.viewfinder") { store.infoMessage = "Partner ID QR opens after backend identity card endpoint is enabled." }
                PlainHeaderButton(systemImage: "bell") { store.screen = .notifications }
                    .overlay(alignment: .topTrailing) {
                        if store.pendingBookings.count + store.notifications.filter({ !$0.isRead }).count > 0 {
                            Circle().fill(AppTheme.hotPink).frame(width: 10, height: 10).offset(x: -7, y: 4)
                        }
                    }
            }
            OnlineStatusCard()
            HomeStatsStrip()
            SectionTitleRow(title: "Recent Requests", actionTitle: "View all") { store.screen = .bookings }
            VisibilityBanner()
            if store.pendingBookings.isEmpty {
                WaitingRequestCard()
            } else {
                ForEach(store.pendingBookings.prefix(4)) { booking in
                    HomeRequestCard(booking: booking) { store.openBooking(booking) }
                }
            }
        }
    }
}

struct PartnerBookingsScreen: View {
    @EnvironmentObject private var store: PartnerAppStore
    @State private var filter: BookingFilter = .all

    var body: some View {
        ReferencePage {
            ReferenceHeader(title: "My Bookings", subtitle: "Manage and track your all bookings", backAction: { store.screen = .dashboard })
            BookingTabs(selection: $filter)
            SectionTitleRow(title: "Upcoming & Ongoing", actionTitle: "View All") { filter = .all }
            if filteredBookings.isEmpty {
                EmptyState(title: "No bookings", subtitle: "Accepted, active and completed jobs will appear here automatically.")
            } else {
                ForEach(filteredBookings) { booking in
                    PremiumBookingCard(booking: booking) {
                        store.callCustomer(booking)
                    } detailsAction: {
                        store.openBooking(booking)
                    }
                }
            }
        }
    }

    private var filteredBookings: [PartnerBooking] {
        switch filter {
        case .all: return store.bookings
        case .ongoing: return store.bookings.filter { $0.isPending || $0.isActive }
        case .completed: return store.completedBookings
        case .cancelled: return store.bookings.filter { ["cancelled", "rejected"].contains($0.status) }
        }
    }
}

struct EarningsScreen: View {
    @EnvironmentObject private var store: PartnerAppStore
    @State private var period: EarningsPeriod = .week

    var body: some View {
        ReferencePage {
            ReferenceHeader(title: "Earnings", subtitle: "Track your income", backAction: { store.screen = .dashboard }, trailingSystemImage: "bell") {
                store.screen = .notifications
            }
            EarningsTabs(selection: $period)
            EarningsHero(period: period)
            EarningsBreakdownCard(period: period)
            TransactionsCard()
            StatementCard()
            RewardsBanner()
        }
    }
}

struct PartnerProfileScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ReferencePage {
            HStack {
                Text("Profile")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity)
            }
            ProfileSummaryCard()
            ProfileActionRow(color: Color(hex: 0xDDF8FF), icon: "person", title: "Personal Information", subtitle: "View and update your personal details") { store.screen = .personalInfo }
            ProfileActionRow(color: Color(hex: 0xEEF0FF), icon: "text.bubble", title: "Documents", subtitle: "Manage your documents and verification") { store.screen = .documents }
            ProfileActionRow(color: AppTheme.roseSoft, icon: "headphones", title: "Support", subtitle: "Help center and support requests") { store.screen = .support }
            ProfileActionRow(color: AppTheme.roseSoft, icon: "shield.checkered", title: "Legal & Information", subtitle: "Privacy, terms and account deletion") { store.screen = .legal }
            ProfileActionRow(color: AppTheme.greenSoft, icon: "wallet.pass", title: "Earnings", subtitle: "View earnings, history and transactions") { store.screen = .earnings }
            ProfileActionRow(color: AppTheme.orangeSoft, icon: "circle.fill", title: "My Services", subtitle: "Manage services and request matching") { store.screen = .myServices }
            ProfileActionRow(color: Color(hex: 0xF3E9FF), icon: "slider.horizontal.3", title: "Settings", subtitle: "Preferences and account setup") { store.screen = .settings }
            Button("Logout") { store.logout() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.hotPink)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(hex: 0xF4B9BE), lineWidth: 1))
                .padding(.horizontal, 18)
                .padding(.top, 10)
        }
    }
}

struct PersonalInfoScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ReferencePage {
            ReferenceHeader(title: "Personal Information", subtitle: "", backAction: { store.screen = .profile }, trailingSystemImage: "pencil") {
                store.infoMessage = "Edit fields from registration/profile sync flow. Backend profile update is enabled."
            }
            VStack(spacing: 18) {
                HStack(spacing: 14) {
                    ZStack(alignment: .bottomTrailing) {
                        Circle().fill(AppTheme.roseSoft)
                        Text(initials(store.profile.name))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppTheme.hotPink)
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.hotPink, in: Circle())
                    }
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(Color(hex: 0xFAB8CC), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.partnerDisplayName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                        HStack(spacing: 6) {
                            Text("Verified Partner")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.green)
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.green)
                        }
                        Text("Manage and update your personal details easily.")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.muted)
                            .safeText()
                    }
                    Spacer()
                }
                .padding(.top, 16)
                VStack(spacing: 0) {
                    ProfileInfoRow(icon: "person", label: "Partner Name", value: store.partnerDisplayName)
                    Divider().padding(.leading, 88)
                    ProfileInfoRow(icon: "phone", label: "Phone", value: store.profile.phone.isEmpty ? "Not added" : store.profile.phone)
                    Divider().padding(.leading, 88)
                    ProfileInfoRow(icon: "rectangle.text.magnifyingglass", label: "Partner ID", value: store.partnerCode)
                }
                .androidCard(cornerRadius: 24, padding: 18)
            }
            .androidCard(cornerRadius: 28, padding: 18)
            SecurityNoticeCard(title: "Your information is secure", subtitle: "We use advanced security to keep your data safe and private.")
            Button("Save Changes") {
                store.persistProfile()
                Task { await store.syncPartnerProfile() }
            }
            .primaryButton()
        }
    }
}

struct DocumentsScreen: View {
    @EnvironmentObject private var store: PartnerAppStore
    @State private var importingDocumentType: String?

    var body: some View {
        ReferencePage {
            ReferenceHeader(title: "Documents", subtitle: "Manage your documents and verification", backAction: { store.screen = .profile })
            ForEach(requiredDocuments, id: \.self) { name in
                DocumentUploadRow(title: name, status: status(for: name)) {
                    importingDocumentType = name
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Aadhaar last 4")
                    .font(.system(size: 18, weight: .semibold))
                TextField("1234", text: $store.aadhaarLast4)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                Button("Submit Verification") { store.submitVerification() }
                    .primaryButton()
            }
            .androidCard(cornerRadius: 24)
        }
        .fileImporter(
            isPresented: Binding(get: { importingDocumentType != nil }, set: { if !$0 { importingDocumentType = nil } }),
            allowedContentTypes: [.jpeg, .png, .pdf],
            allowsMultipleSelection: false
        ) { result in
            guard let type = importingDocumentType else { return }
            importingDocumentType = nil
            if case .success(let urls) = result, let url = urls.first {
                store.uploadDocument(documentType: type, fileURL: url)
            }
        }
    }

    private var requiredDocuments: [String] {
        ["Aadhaar Card Front", "Aadhaar Card Back", "PAN Card", "Selfie Verification", "Skill Certificate", "Other Supporting Document"]
    }

    private func status(for type: String) -> String {
        if store.uploadingDocumentType == type { return "Uploading" }
        return store.documentStatuses[type] ?? "Pending"
    }
}

struct MyServicesScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ReferencePage {
            ReferenceHeader(title: "My Services", subtitle: "Manage services and areas", backAction: { store.screen = .profile })
            HStack(spacing: 16) {
                SoftIcon(systemImage: "briefcase.fill", color: AppTheme.hotPink, bg: AppTheme.roseSoft, size: 74, iconSize: 32)
                VStack(alignment: .leading, spacing: 8) {
                    Text("My Services")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text("Manage your services and get better request matching")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.muted)
                        .safeText()
                }
                Spacer()
            }
            .androidCard(cornerRadius: 24, padding: 18)
            VStack(spacing: 0) {
                ServiceSettingRow(icon: "square.stack.3d.up.fill", bg: AppTheme.roseSoft, color: AppTheme.hotPink, title: "Selected Services", value: store.profile.skillsLabel.isEmpty ? "Not selected" : store.profile.skillsLabel) {
                    store.infoMessage = "Use registration service chips to edit selected services. Backend sync is enabled."
                }
                Divider().padding(.leading, 82)
                HStack(spacing: 14) {
                    SoftIcon(systemImage: "wifi", color: AppTheme.green, bg: AppTheme.greenSoft)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Online Status").font(.system(size: 17)).foregroundStyle(AppTheme.muted)
                        Text(store.profile.online ? "Online and receiving requests" : "Offline")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(2)
                            .safeText()
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { store.profile.online }, set: { _ in store.toggleOnline() }))
                        .labelsHidden()
                        .tint(Color(hex: 0x00C853))
                }
                .padding(.vertical, 18)
                Divider().padding(.leading, 82)
                Menu {
                    ForEach([5, 10, 25, 50], id: \.self) { km in
                        Button("\(km) km") { store.profile.serviceRadiusKm = km; store.persistProfile() }
                    }
                } label: {
                    ServiceSettingLabel(icon: "scope", bg: AppTheme.blueSoft, color: Color(hex: 0x4169E1), title: "Service Radius", value: "\(store.profile.serviceRadiusKm) km around \(store.profile.serviceArea)")
                }
                Divider().padding(.leading, 82)
                Menu {
                    ForEach(["Guwahati", "Dispur", "Ganeshguri", "Zoo Road", "Six Mile"], id: \.self) { area in
                        Button(area) { store.profile.serviceArea = area; store.persistProfile() }
                    }
                } label: {
                    ServiceSettingLabel(icon: "mappin.circle", bg: AppTheme.orangeSoft, color: AppTheme.orange, title: "Service Area", value: "\(store.profile.serviceArea), Assam")
                }
            }
            .androidCard(cornerRadius: 24, padding: 18)
            SecurityNoticeCard(title: "Better visibility, more bookings", subtitle: "Keeping your services and area updated helps us match you with the right customer.")
            Button("Save Changes") {
                store.persistProfile()
                Task { await store.syncPartnerProfile() }
            }
            .primaryButton()
        }
    }
}

struct PartnerSettingsScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ReferencePage {
            ReferenceHeader(title: "Settings", subtitle: "Manage your notification and route preferences", backAction: { store.screen = .profile })
            VStack(spacing: 0) {
                SettingPreferenceRow(icon: "bell", bg: AppTheme.roseSoft, color: AppTheme.hotPink, title: "Notifications", subtitle: "Manage your notification and route preferences", chip: "Enabled")
                Divider().padding(.leading, 76)
                SettingPreferenceRow(icon: "bell.badge", bg: AppTheme.orangeSoft, color: AppTheme.orange, title: "Booking Alerts", subtitle: "Get notified for new bookings and updates", chip: "Ring + Vibration")
                Divider().padding(.leading, 76)
                SettingPreferenceRow(icon: "mappin.circle", bg: AppTheme.blueSoft, color: AppTheme.blue, title: "Map Mode", subtitle: "Choose how map should show your route", chip: "In-app live route")
            }
            .androidCard(cornerRadius: 24, padding: 18)
            HStack(spacing: 20) {
                SoftIcon(systemImage: "shield.checkered", color: AppTheme.hotPink, bg: AppTheme.roseSoft)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your preferences are secure")
                        .font(.system(size: 18, weight: .semibold))
                    Text("We only use these settings to improve your app experience.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.muted)
                        .safeText()
                }
                Spacer()
                SoftIcon(systemImage: "slider.horizontal.3", color: AppTheme.hotPink, bg: AppTheme.roseSoft)
            }
            .androidCard(cornerRadius: 24, padding: 20)
            Button("Save Changes") {
                Task {
                    _ = await AppNotificationService.shared.requestPermission()
                    await store.sendLocationHeartbeat()
                }
            }
            .primaryButton()
        }
    }
}

struct PartnerLegalScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ReferencePage {
            ReferenceHeader(title: "Legal & Information", subtitle: "Privacy, terms and account deletion", backAction: { store.screen = .profile })
            LegalCard(title: "Privacy Policy", detail: "ApnaServo stores only partner profile, service area, verification, booking and payment records required to operate the platform.")
            LegalCard(title: "Partner Terms", detail: "Accept only genuine jobs, keep customer communication inside ApnaServo, and update every service status honestly.")
            LegalCard(title: "Account Deletion", detail: "Deletion requests are sent to backend for review. Legal, statement and compliance records may be retained as required.")
        }
    }
}

struct PartnerSupportChatScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ReferencePage {
            ReferenceHeader(title: "Support", subtitle: "We're here to help you 24/7", backAction: { store.screen = .profile })
            VStack(alignment: .leading, spacing: 0) {
                Text("How can we help you today?")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .padding(.bottom, 18)
                SupportOptionRow(icon: "headphones", bg: AppTheme.roseSoft, color: AppTheme.hotPink, title: "Chat with us", subtitle: "Talk to our support team for any help") {
                    store.sendSupportMessage("I need help from support.")
                }
                Divider().padding(.leading, 110)
                SupportOptionRow(icon: "doc.badge.arrow.up", bg: AppTheme.orangeSoft, color: AppTheme.orange, title: "Raise a Complaint", subtitle: "Report booking, payment or service issues") {
                    store.openSupport("Complaint", draft: "I want to raise a complaint about ")
                }
                Divider().padding(.leading, 110)
                SupportOptionRow(icon: "bell.badge", bg: AppTheme.roseSoft, color: AppTheme.hotPink, title: "Cancel Active Booking", subtitle: "Request cancellation with a clear reason") {
                    store.openSupport("Booking Cancellation", draft: "I need help cancelling my active booking. ")
                }
                Divider().padding(.leading, 110)
                SupportOptionRow(icon: "bell", bg: Color(hex: 0xF3D8FF), color: AppTheme.purple, title: "Track your Issue", subtitle: "Check status of your submitted requests") {
                    store.infoMessage = "Support ticket tracking will show backend ticket status."
                }
                Divider().padding(.leading, 110)
                SupportOptionRow(icon: "shield.checkered", bg: AppTheme.greenSoft, color: AppTheme.green, title: "Help Center", subtitle: "Find answers to common questions") {
                    store.infoMessage = "Help center content is loaded from backend knowledge base."
                }
            }
            .androidCard(cornerRadius: 28, padding: 24)
            HStack(spacing: 18) {
                SoftIcon(systemImage: "headphones", color: AppTheme.hotPink, bg: AppTheme.roseSoft)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("AI Assistant")
                            .font(.system(size: 22, weight: .semibold))
                        Text("Beta")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.hotPink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AppTheme.roseSoft, in: Capsule())
                    }
                    Text("Get quick answers to common questions with our AI assistant")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.muted)
                        .safeText()
                }
                Spacer()
                Button("Ask AI") { store.infoMessage = "AI Assistant requires backend AI endpoint before release." }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.hotPink)
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .background(Color.white, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.hotPink, lineWidth: 1.2))
            }
            .androidCard(cornerRadius: 24, padding: 20)
        }
    }
}

struct PartnerNotificationsScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ReferencePage {
            ReferenceHeader(title: "Messages", subtitle: "All your notifications and messages", backAction: { store.screen = .dashboard }, trailingSystemImage: "checkmark.circle") {
                store.markAllNotificationsRead()
            }
            if store.notifications.isEmpty && store.pendingBookings.isEmpty {
                EmptyState(title: "No notifications", subtitle: "Booking requests, status updates and payout alerts will appear here.")
            } else {
                ForEach(store.pendingBookings) { booking in
                    NotificationRowView(icon: "bell", title: "New request available", detail: "\(booking.serviceName) - \(booking.slot)", unread: true) {
                        store.openBooking(booking)
                    }
                }
                ForEach(store.notifications) { item in
                    NotificationRowView(icon: "bell", title: item.title, detail: item.body, unread: !item.isRead) {
                        store.markNotificationRead(item)
                    }
                }
            }
        }
    }
}

struct IncomingRequestScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ReferencePage {
            ReferenceHeader(title: "New Request", subtitle: "Available booking", backAction: { store.screen = .dashboard })
            if let booking = store.selectedBooking {
                PremiumBookingCard(booking: booking) {
                    store.callCustomer(booking)
                } detailsAction: {
                    store.screen = .detail
                }
                VStack(spacing: 12) {
                    Button(store.loading ? "Accepting..." : "Accept Booking") { store.acceptSelectedBooking() }
                        .primaryButton()
                        .disabled(store.loading)
                    Button("Reject") { store.rejectSelectedBooking() }
                        .outlineButton()
                }
            } else {
                EmptyState(title: "No request selected", subtitle: "Open a pending request from dashboard.")
            }
        }
    }
}

struct OrderDetailScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ReferencePage {
            ReferenceHeader(title: "Booking Details", subtitle: store.selectedBooking?.displayId ?? "", backAction: { store.screen = .bookings }, trailingSystemImage: "headphones") {
                store.screen = .support
            }
            if let booking = store.selectedBooking {
                PremiumBookingCard(booking: booking) {
                    store.callCustomer(booking)
                } detailsAction: {
                    store.openMap(booking)
                }
                ServiceTimelineCard(booking: booking)
                if let next = StatusStep.next(for: booking.status) {
                    Button(next.label) { store.updateSelectedStatus(next.status) }
                        .primaryButton()
                }
                Button("Customer No Response") { store.reportNoResponse(reason: "Customer did not respond") }
                    .outlineButton()
                Button("Chat with Customer") { store.openBookingChat(booking) }
                    .outlineButton()
            } else {
                EmptyState(title: "No job selected", subtitle: "Open a booking from dashboard.")
            }
        }
    }
}

struct PartnerMapScreen: View {
    @EnvironmentObject private var store: PartnerAppStore
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: AppConfig.defaultLatitude, longitude: AppConfig.defaultLongitude), span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Live Route", subtitle: store.selectedBooking?.address ?? "", backAction: { store.screen = .detail })
            if let booking = store.selectedBooking {
                Map(coordinateRegion: $region, annotationItems: [booking]) { item in
                    MapMarker(coordinate: CLLocationCoordinate2D(latitude: item.lat, longitude: item.lng), tint: .red)
                }
                .onAppear {
                    region.center = CLLocationCoordinate2D(latitude: booking.lat, longitude: booking.lng)
                }
                VStack(spacing: 10) {
                    Button("Navigate") { store.openAppleMaps(booking) }.greenButton()
                    Button("Back to Booking") { store.screen = .detail }.outlineButton()
                }
                .padding(18)
                .background(Color.white)
            } else {
                EmptyState(title: "No map target", subtitle: "Open a booking first.")
                    .padding(18)
            }
        }
    }
}

private struct ReferencePage<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = proxy.size.width < 360 ? 12 : 16
            let verticalSpacing: CGFloat = proxy.size.width < 360 ? 12 : 16
            ScrollView(showsIndicators: false) {
                VStack(spacing: verticalSpacing) {
                    content
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .dynamicTypeSize(.small ... .medium)
        }
    }
}

private struct ReferenceHeader: View {
    let title: String
    var subtitle: String
    var backAction: (() -> Void)?
    var trailingSystemImage: String?
    var trailingAction: (() -> Void)?

    init(title: String, subtitle: String, backAction: (() -> Void)? = nil, trailingSystemImage: String? = nil, trailingAction: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.backAction = backAction
        self.trailingSystemImage = trailingSystemImage
        self.trailingAction = trailingAction
    }

    var body: some View {
        ZStack {
            HStack {
                if let backAction {
                    PlainHeaderButton(systemImage: "chevron.left", action: backAction)
                } else {
                    PlainHeaderButton(systemImage: "line.3.horizontal") {}
                }
                Spacer()
                if let trailingSystemImage, let trailingAction {
                    PlainHeaderButton(systemImage: trailingSystemImage, action: trailingAction)
                } else {
                    Color.clear.frame(width: 48, height: 48)
                }
            }
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 50)
        }
        .frame(minHeight: 52)
    }
}

private struct PlainHeaderButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(systemImage == "chevron.left" ? AppTheme.hotPink : AppTheme.ink)
                .frame(width: 44, height: 44)
                .background(systemImage == "chevron.left" ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: systemImage == "chevron.left" ? Color.black.opacity(0.06) : .clear, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

private struct OnlineStatusCard: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(AppTheme.green.opacity(0.12))
                Circle().stroke(AppTheme.green.opacity(0.16), lineWidth: 2).padding(9)
                Circle().fill(Color(hex: 0x00C853)).frame(width: 20, height: 20)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 5) {
                Text(store.profile.online ? "You are Online" : "You are Offline")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(store.profile.online ? "Receiving requests now" : "Switch on to receive requests")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(store.profile.online ? "Switch off anytime" : "You can switch on anytime")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { store.profile.online }, set: { _ in store.toggleOnline() }))
                .labelsHidden()
                .tint(Color(hex: 0x00C853))
                .scaleEffect(0.86)
        }
        .androidCard(cornerRadius: 22, padding: 14)
    }
}

private struct HomeStatsStrip: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                HomeStat(icon: "briefcase", tint: AppTheme.hotPink, bg: AppTheme.roseSoft, title: "Active Jobs", value: "\(store.activeBookings.count)", footer: "In Progress")
                StatDivider()
                HomeStat(icon: "calendar", tint: AppTheme.orange, bg: AppTheme.orangeSoft, title: "Completed Jobs", value: "\(store.completedBookings.count)", footer: "All Time")
                StatDivider()
                HomeStat(icon: "shield.checkered", tint: AppTheme.blue, bg: AppTheme.blueSoft, title: "Response Rate", value: "55%", footer: "Excellent", footerTint: AppTheme.green)
                StatDivider()
                HomeStat(icon: "star", tint: AppTheme.purple, bg: Color(hex: 0xF9E8FF), title: "Total Earnings", value: "Rs \(store.monthEarnings)", footer: "This Month")
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                HomeStat(icon: "briefcase", tint: AppTheme.hotPink, bg: AppTheme.roseSoft, title: "Active Jobs", value: "\(store.activeBookings.count)", footer: "In Progress")
                HomeStat(icon: "calendar", tint: AppTheme.orange, bg: AppTheme.orangeSoft, title: "Completed Jobs", value: "\(store.completedBookings.count)", footer: "All Time")
                HomeStat(icon: "shield.checkered", tint: AppTheme.blue, bg: AppTheme.blueSoft, title: "Response Rate", value: "55%", footer: "Excellent", footerTint: AppTheme.green)
                HomeStat(icon: "star", tint: AppTheme.purple, bg: Color(hex: 0xF9E8FF), title: "Total Earnings", value: "Rs \(store.monthEarnings)", footer: "This Month")
            }
        }
        .androidCard(cornerRadius: 22, padding: 10)
    }
}

private struct HomeStat: View {
    let icon: String
    let tint: Color
    let bg: Color
    let title: String
    let value: String
    let footer: String
    var footerTint: Color = AppTheme.muted

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(bg, in: Circle())
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Text(footer)
                .font(.system(size: 11))
                .foregroundStyle(footerTint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StatDivider: View {
    var body: some View {
        Rectangle().fill(Color(hex: 0xF4DCE2)).frame(width: 1, height: 78)
    }
}

private struct SectionTitleRow: View {
    let title: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Spacer()
            Button(actionTitle, action: action)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.hotPink)
        }
        .padding(.horizontal, 4)
    }
}

private struct VisibilityBanner: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        HStack(spacing: 12) {
            Text(store.profile.online ? "ON" : "OFF")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(store.profile.online ? AppTheme.green : AppTheme.muted)
                .frame(width: 64, height: 34)
                .background(store.profile.online ? AppTheme.greenSoft : Color(hex: 0xF3F3F3), in: Capsule())
            Text(statusText)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(2)
                .safeText()
            Spacer()
        }
        .androidCard(cornerRadius: 16, padding: 12)
    }

    private var statusText: String {
        if !store.profile.online {
            return "You are hidden from customer matching"
        }
        return store.realtimeConnected
            ? "You are visible to customers and receiving new requests"
            : "Connecting to secure realtime request queue"
    }
}

private struct WaitingRequestCard: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        HStack(spacing: 12) {
            ServiceBadge(title: store.profile.skillsLabel.isEmpty ? "Service" : store.profile.skillsLabel, size: 62)
            VStack(alignment: .leading, spacing: 7) {
                Text("Waiting for matching requests")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                    .safeText()
                Text(store.profile.skillsLabel.isEmpty ? "Select services" : store.profile.skillsLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.hotPink)
                    .lineLimit(2)
                    .safeText()
                Text("Stay online to get matched with nearby customers.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.muted)
                    .safeText()
            }
            Spacer()
        }
        .androidCard(cornerRadius: 20, padding: 14)
    }
}

private struct HomeRequestCard: View {
    let booking: PartnerBooking
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ServiceBadge(title: booking.serviceName, size: 62)
                VStack(alignment: .leading, spacing: 7) {
                    Text(booking.serviceName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)
                        .safeText()
                    Text(booking.issue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.hotPink)
                        .lineLimit(2)
                        .safeText()
                    Text("\(booking.city) - \(booking.slot)")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)
                }
                Spacer()
                StatusPill(text: booking.statusLabel, tint: AppTheme.orange, background: AppTheme.orangeSoft)
            }
            .androidCard(cornerRadius: 20, padding: 14)
        }
        .buttonStyle(.plain)
    }
}

private struct BookingTabs: View {
    @Binding var selection: BookingFilter

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BookingFilter.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    Text(tab.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selection == tab ? AppTheme.hotPink : AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(selection == tab ? AppTheme.roseSoft : .clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 7, x: 0, y: 3)
    }
}

private struct PremiumBookingCard: View {
    let booking: PartnerBooking
    let callAction: () -> Void
    let detailsAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ViewThatFits(in: .horizontal) {
                bookingHeader(axis: .horizontal)
                bookingHeader(axis: .vertical)
            }
            ViewThatFits(in: .horizontal) {
                actionButtons(axis: .horizontal)
                actionButtons(axis: .vertical)
            }
        }
        .androidCard(cornerRadius: 22, padding: 14)
    }

    @ViewBuilder
    private func bookingHeader(axis: Axis) -> some View {
        if axis == .horizontal {
            HStack(alignment: .top, spacing: 12) {
                ServiceBadge(title: booking.serviceName, size: 70)
                bookingInfo(showTitle: true)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ServiceBadge(title: booking.serviceName, size: 56)
                    Text(booking.serviceName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)
                        .safeText()
                }
                bookingInfo(showTitle: false)
            }
        }
    }

    @ViewBuilder
    private func bookingInfo(showTitle: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("#\(booking.displayId)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.roseDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                Spacer()
                StatusPill(text: booking.statusLabel == "Accepted" ? "Ongoing" : booking.statusLabel, tint: AppTheme.orange, background: AppTheme.orangeSoft)
            }
            if showTitle {
                Text(booking.serviceName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                    .safeText()
            }
            BookingMetaRow(mark: "D", value: bookingDateLabel(booking))
            BookingMetaRow(mark: "T", value: booking.slot)
            BookingMetaRow(mark: "L", value: booking.city)
            Text("Note: \(booking.issue.isEmpty ? "Customer requested \(booking.serviceName)" : booking.issue)")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.roseDark)
                .lineLimit(2)
                .safeText()
        }
    }

    @ViewBuilder
    private func actionButtons(axis: Axis) -> some View {
        if axis == .horizontal {
            HStack(spacing: 10) {
                Button("Call", action: callAction)
                    .bookingOutlineButton()
                Button("View Details", action: detailsAction)
                    .bookingFilledButton()
            }
        } else {
            VStack(spacing: 8) {
                Button("Call", action: callAction)
                    .bookingOutlineButton()
                Button("View Details", action: detailsAction)
                    .bookingFilledButton()
            }
        }
    }
}

private struct BookingMetaRow: View {
    let mark: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(mark)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.muted)
                .frame(width: 16)
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

private struct EarningsTabs: View {
    @Binding var selection: EarningsPeriod

    var body: some View {
        HStack(spacing: 0) {
            ForEach(EarningsPeriod.allCases) { item in
                Button {
                    selection = item
                } label: {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selection == item ? .white : AppTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(selection == item ? AppTheme.hotPink : .clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 7, x: 0, y: 3)
    }
}

private struct EarningsHero: View {
    @EnvironmentObject private var store: PartnerAppStore
    let period: EarningsPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Wallet - \(period.title)ly Earnings")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("Rs \(amount)")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(jobs) completed jobs in this period")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(2)
                        .safeText()
                }
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "wallet.pass")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 62, height: 58)
                        .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    Button("View Wallet") {}
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 82, height: 36)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.72), lineWidth: 1.5))
                }
            }
            Sparkline()
                .frame(height: 52)
                .padding(.top, 4)
        }
        .padding(16)
        .background(LinearGradient(colors: [Color(hex: 0xD90069), AppTheme.hotPink], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 4)
    }

    private var amount: Int {
        switch period {
        case .today: return store.todayEarnings
        case .week, .month: return store.monthEarnings
        }
    }

    private var jobs: Int {
        store.completedBookings.count
    }
}

private struct Sparkline: View {
    var body: some View {
        GeometryReader { proxy in
            let points: [CGPoint] = [
                CGPoint(x: 0.02, y: 0.78), CGPoint(x: 0.20, y: 0.48), CGPoint(x: 0.30, y: 0.58),
                CGPoint(x: 0.40, y: 0.36), CGPoint(x: 0.58, y: 0.46), CGPoint(x: 0.68, y: 0.22),
                CGPoint(x: 0.86, y: 0.30), CGPoint(x: 0.95, y: 0.10)
            ].map { CGPoint(x: $0.x * proxy.size.width, y: $0.y * proxy.size.height) }
            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x, y: proxy.size.height))
                    points.forEach { path.addLine(to: $0) }
                    if let last = points.last {
                        path.addLine(to: CGPoint(x: last.x, y: proxy.size.height))
                    }
                    path.closeSubpath()
                }
                .fill(Color.white.opacity(0.16))
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    points.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(Color.white.opacity(0.92), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                ForEach(points.indices, id: \.self) { index in
                    Circle().fill(Color.white).frame(width: 6, height: 6).position(points[index])
                }
            }
        }
    }
}

private struct EarningsBreakdownCard: View {
    @EnvironmentObject private var store: PartnerAppStore
    let period: EarningsPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                SoftIcon(systemImage: "chart.bar", color: AppTheme.hotPink, bg: AppTheme.roseSoft)
                Text("Earnings Breakdown")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            BreakdownRow(icon: "calendar", bg: AppTheme.blueSoft, color: AppTheme.blue, title: "Completed Orders", value: "Rs \(store.totalEarnings)")
            BreakdownRow(icon: "star", bg: Color(hex: 0xFFFBE7), color: Color(hex: 0xDCA000), title: "Incentives", value: "Rs 0")
            BreakdownRow(icon: "wifi", bg: AppTheme.greenSoft, color: AppTheme.green, title: "Tips", value: "Rs 0")
            HStack {
                Text("Total").font(.system(size: 20, weight: .semibold))
                Spacer()
                Text("Rs \(store.totalEarnings)").font(.system(size: 20, weight: .semibold)).foregroundStyle(AppTheme.hotPink)
            }
        }
        .androidCard(cornerRadius: 24, padding: 18)
    }
}

private struct BreakdownRow: View {
    let icon: String
    let bg: Color
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            SoftIcon(systemImage: icon, color: color, bg: bg, size: 46, iconSize: 20)
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(2)
                .safeText()
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
    }
}

private struct TransactionsCard: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                SoftIcon(systemImage: "scope", color: AppTheme.hotPink, bg: AppTheme.roseSoft)
                Text("Transactions")
                    .font(.system(size: 22, weight: .semibold))
            }
            if store.completedBookings.isEmpty {
                Text("No verified transaction yet. Completed jobs will appear here automatically.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
            } else {
                ForEach(store.completedBookings.prefix(5)) { booking in
                    HStack {
                        Text(booking.serviceName).font(.system(size: 16, weight: .bold))
                        Spacer()
                        Text("Rs \(booking.amount)").font(.system(size: 16, weight: .semibold))
                    }
                }
            }
        }
        .androidCard(cornerRadius: 24, padding: 18)
    }
}

private struct StatementCard: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                SoftIcon(systemImage: "doc.text", color: Color(hex: 0x4169E1), bg: AppTheme.blueSoft)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Job Statement PDF")
                        .font(.system(size: 22, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text("Download completed jobs, commission and payout summary.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.muted)
                        .safeText()
                }
            }
            Button("Download Job Statement") { store.downloadStatement() }
                .primaryButton()
        }
        .androidCard(cornerRadius: 24, padding: 18)
    }
}

private struct RewardsBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Keep up the great work!")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(AppTheme.roseDark)
                Text("Complete more orders and earn exciting rewards.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.ink)
                    .safeText()
                Button("View Rewards") {}
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.hotPink)
                    .frame(width: 108, height: 38)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(hex: 0xF4B9BE), lineWidth: 1))
            }
            Spacer()
            Image(systemName: "gift.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(AppTheme.hotPink)
                .frame(width: 58, height: 56)
        }
        .androidCard(cornerRadius: 24, padding: 18)
        .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct ProfileSummaryCard: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 16) {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0xD90069), AppTheme.hotPink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 76, height: 76)
                    .shadow(color: AppTheme.hotPink.opacity(0.16), radius: 6, x: 0, y: 3)
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.partnerDisplayName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                    Text("Star 4.7 (4 reviews)")
                        .font(.system(size: 15))
                    Text("ID: \(store.partnerCode)")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.muted)
                    Text("OK  Verified Partner")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.green)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.greenSoft, in: Capsule())
                }
                Spacer()
            }
            HStack(spacing: 0) {
                ProfileMetric(icon: "calendar", tint: AppTheme.orange, bg: AppTheme.orangeSoft, value: "\(store.completedBookings.count)", label: "Jobs Done")
                ProfileMetric(icon: "star", tint: Color(hex: 0xDCA000), bg: Color(hex: 0xFFFBE7), value: "4.7", label: "Rating")
                ProfileMetric(icon: "shield.checkered", tint: AppTheme.blue, bg: AppTheme.blueSoft, value: "55%", label: "Response")
                ProfileMetric(icon: "briefcase", tint: AppTheme.hotPink, bg: AppTheme.roseSoft, value: "\(store.activeBookings.count)", label: "Active Jobs")
            }
        }
        .androidCard(cornerRadius: 24, padding: 18)
    }
}

private struct ProfileMetric: View {
    let icon: String
    let tint: Color
    let bg: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 34, height: 34)
                .background(bg, in: Circle())
            Text(value).font(.system(size: 17, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
            Text(label).font(.system(size: 11)).foregroundStyle(AppTheme.muted).multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileActionRow: View {
    let color: Color
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                SoftIcon(systemImage: icon, color: icon == "circle.fill" ? AppTheme.orange : AppTheme.hotPink, bg: color, size: 50, iconSize: 21)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(AppTheme.ink).lineLimit(1).minimumScaleFactor(0.78)
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(AppTheme.muted).safeText()
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            SoftIcon(systemImage: icon, color: AppTheme.hotPink, bg: AppTheme.roseSoft)
            VStack(alignment: .leading, spacing: 5) {
                Text(label).font(.system(size: 15)).foregroundStyle(AppTheme.muted)
                Text(value).font(.system(size: 18, weight: .semibold)).foregroundStyle(AppTheme.ink).lineLimit(2).safeText()
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }
}

private struct SecurityNoticeCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            SoftIcon(systemImage: "shield.checkered", color: AppTheme.hotPink, bg: AppTheme.roseSoft)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 18, weight: .semibold)).foregroundStyle(AppTheme.ink)
                Text(subtitle).font(.system(size: 14)).foregroundStyle(AppTheme.muted).safeText()
            }
            Spacer()
        }
        .androidCard(cornerRadius: 22, padding: 16)
    }
}

private struct DocumentUploadRow: View {
    let title: String
    let status: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                SoftIcon(systemImage: status == "Uploaded" ? "checkmark.seal" : "doc", color: status == "Uploaded" ? AppTheme.green : AppTheme.hotPink, bg: status == "Uploaded" ? AppTheme.greenSoft : AppTheme.roseSoft)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(AppTheme.ink).lineLimit(1).minimumScaleFactor(0.78)
                    Text("JPG, PNG or PDF under 5 MB").font(.system(size: 13)).foregroundStyle(AppTheme.muted)
                }
                Spacer()
                StatusPill(text: status, tint: status == "Uploaded" ? AppTheme.green : AppTheme.orange, background: status == "Uploaded" ? AppTheme.greenSoft : AppTheme.orangeSoft)
            }
            .androidCard(cornerRadius: 22, padding: 14)
        }
        .buttonStyle(.plain)
    }
}

private struct ServiceSettingRow: View {
    let icon: String
    let bg: Color
    let color: Color
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ServiceSettingLabel(icon: icon, bg: bg, color: color, title: title, value: value)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 10)
    }
}

private struct ServiceSettingLabel: View {
    let icon: String
    let bg: Color
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            SoftIcon(systemImage: icon, color: color, bg: bg)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 17)).foregroundStyle(AppTheme.muted)
                Text(value).font(.system(size: 18, weight: .semibold)).foregroundStyle(AppTheme.ink).lineLimit(2).safeText()
            }
            Spacer()
            Text("Edit")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.hotPink)
                .frame(width: 70, height: 38)
                .background(AppTheme.roseSoft, in: Capsule())
        }
        .padding(.vertical, 14)
    }
}

private struct SettingPreferenceRow: View {
    let icon: String
    let bg: Color
    let color: Color
    let title: String
    let subtitle: String
    let chip: String

    var body: some View {
        HStack(spacing: 14) {
            SoftIcon(systemImage: icon, color: color, bg: bg, size: 50, iconSize: 21)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(AppTheme.ink).lineLimit(1).minimumScaleFactor(0.78)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(AppTheme.muted).safeText()
            }
            Spacer()
            Text(chip)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(bg, in: Capsule())
        }
        .padding(.vertical, 14)
    }
}

private struct SupportOptionRow: View {
    let icon: String
    let bg: Color
    let color: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                SoftIcon(systemImage: icon, color: color, bg: bg, size: 50, iconSize: 21)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(AppTheme.ink).lineLimit(1).minimumScaleFactor(0.78)
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(AppTheme.muted).safeText()
                }
                Spacer()
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

private struct LegalCard: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 20, weight: .semibold)).foregroundStyle(AppTheme.ink)
            Text(detail).font(.system(size: 15)).foregroundStyle(AppTheme.muted).safeText()
        }
        .androidCard(cornerRadius: 24)
    }
}

private struct NotificationRowView: View {
    let icon: String
    let title: String
    let detail: String
    let unread: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                SoftIcon(systemImage: icon, color: AppTheme.hotPink, bg: AppTheme.roseSoft)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(AppTheme.ink).lineLimit(1).minimumScaleFactor(0.78)
                    Text(detail).font(.system(size: 14)).foregroundStyle(AppTheme.muted).safeText()
                }
                Spacer()
                if unread { Circle().fill(AppTheme.hotPink).frame(width: 10, height: 10) }
            }
            .androidCard(cornerRadius: 22, padding: 14)
        }
        .buttonStyle(.plain)
    }
}

private struct ServiceTimelineCard: View {
    let booking: PartnerBooking

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Service Status")
                .font(.system(size: 20, weight: .semibold))
            ForEach(StatusStep.timeline, id: \.status) { step in
                HStack(spacing: 14) {
                    Image(systemName: booking.statusRank >= step.rank ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(booking.statusRank >= step.rank ? AppTheme.green : AppTheme.muted)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.label).font(.system(size: 17, weight: .semibold))
                        Text(booking.statusRank >= step.rank ? "Completed" : "Pending").font(.system(size: 13)).foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                }
            }
        }
        .androidCard(cornerRadius: 24)
    }
}

private struct SoftIcon: View {
    let systemImage: String
    let color: Color
    let bg: Color
    var size: CGFloat = 54
    var iconSize: CGFloat = 23

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: iconSize, weight: .bold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(bg, in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

private enum BookingFilter: String, CaseIterable, Identifiable {
    case all
    case ongoing
    case completed
    case cancelled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .ongoing: return "Ongoing"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

private enum EarningsPeriod: String, CaseIterable, Identifiable {
    case today
    case week
    case month

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

private enum StatusStep {
    case onTheWay
    case arrived
    case started
    case complete
    case confirmPayment

    var status: String {
        switch self {
        case .onTheWay: return "on_the_way"
        case .arrived: return "arrived"
        case .started: return "started"
        case .complete: return "amount_pending"
        case .confirmPayment: return "completed"
        }
    }

    var label: String {
        switch self {
        case .onTheWay: return "Mark as On The Way"
        case .arrived: return "Mark as Arrived"
        case .started: return "Start Service"
        case .complete: return "Complete Service"
        case .confirmPayment: return "Confirm Payment Received"
        }
    }

    var rank: Int {
        switch self {
        case .onTheWay: return 2
        case .arrived: return 3
        case .started: return 4
        case .complete: return 5
        case .confirmPayment: return 6
        }
    }

    static var timeline: [StatusStep] { [.onTheWay, .arrived, .started, .complete, .confirmPayment] }

    static func next(for status: String) -> StatusStep? {
        switch status {
        case "accepted": return .onTheWay
        case "on_the_way": return .arrived
        case "arrived": return .started
        case "started": return .complete
        case "amount_pending": return .confirmPayment
        default: return nil
        }
    }
}

private extension PartnerBooking {
    var statusRank: Int {
        switch status {
        case "accepted": return 1
        case "on_the_way": return 2
        case "arrived": return 3
        case "started": return 4
        case "amount_pending": return 5
        case "completed": return 6
        default: return isPending ? 0 : 1
        }
    }
}

private extension PartnerAppStore {
    var partnerDisplayName: String {
        profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Partner" : profile.name
    }

    var partnerCode: String {
        let digits = profile.phone.filter(\.isNumber)
        return "ASP\(digits.suffix(4).isEmpty ? "1470" : String(digits.suffix(4)))"
    }
}

private func initials(_ name: String) -> String {
    let parts = name.split(separator: " ").prefix(2).compactMap(\.first)
    let value = String(parts).uppercased()
    return value.isEmpty ? "P" : value
}

private func bookingDateLabel(_ booking: PartnerBooking) -> String {
    let calendar = Calendar.current
    let date = Date(timeIntervalSince1970: TimeInterval(booking.createdAtMillis) / 1000)
    if calendar.isDateInToday(date) { return "Today" }
    let formatter = DateFormatter()
    formatter.dateFormat = "dd MMM yyyy"
    return formatter.string(from: date)
}
