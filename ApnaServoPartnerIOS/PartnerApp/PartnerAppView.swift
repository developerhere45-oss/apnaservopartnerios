import MapKit
import Foundation
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
                PlainHeaderButton(systemImage: "line.3.horizontal") { store.navigate(to: .profile) }
                Spacer()
                AndroidAssetImage(name: "apna_servo_logo")
                    .frame(width: 148, height: 50)
                Spacer()
                PlainHeaderButton(systemImage: "qrcode.viewfinder") { store.infoMessage = "Partner ID QR opens after backend identity card endpoint is enabled." }
                PlainHeaderButton(systemImage: "bell") { store.navigate(to: .notifications) }
                    .overlay(alignment: .topTrailing) {
                        if store.pendingBookings.count + store.notifications.filter({ !$0.isRead }).count > 0 {
                            Circle().fill(AppTheme.hotPink).frame(width: 10, height: 10).offset(x: -7, y: 4)
                        }
                    }
            }
            OnlineStatusCard()
            HomeStatsStrip()
            SectionTitleRow(title: "Recent Requests", actionTitle: "View all") { store.navigate(to: .bookings) }
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
            ReferenceHeader(title: "My Bookings", subtitle: "Manage and track your all bookings", backAction: { store.goBack(fallback: .dashboard) })
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
            ReferenceHeader(title: "Earnings", subtitle: "Track your income", backAction: { store.goBack(fallback: .dashboard) }, trailingSystemImage: "bell") {
                store.navigate(to: .notifications)
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
            ProfileActionRow(color: Color(hex: 0xDDF8FF), icon: "person", title: "Personal Information", subtitle: "View and update your personal details") { store.navigate(to: .personalInfo) }
            ProfileActionRow(color: Color(hex: 0xEEF0FF), icon: "text.bubble", title: "Documents", subtitle: "Manage your documents and verification") { store.navigate(to: .documents) }
            ProfileActionRow(color: AppTheme.roseSoft, icon: "headphones", title: "Support", subtitle: "Help center and support requests") { store.navigate(to: .support) }
            ProfileActionRow(color: AppTheme.roseSoft, icon: "shield.checkered", title: "Legal & Information", subtitle: "Privacy, terms and account deletion") { store.navigate(to: .legal) }
            ProfileActionRow(color: AppTheme.greenSoft, icon: "wallet.pass", title: "Earnings", subtitle: "View earnings, history and transactions") { store.navigate(to: .earnings) }
            ProfileActionRow(color: AppTheme.orangeSoft, icon: "circle.fill", title: "My Services", subtitle: "Manage services and request matching") { store.navigate(to: .myServices) }
            ProfileActionRow(color: Color(hex: 0xF3E9FF), icon: "slider.horizontal.3", title: "Settings", subtitle: "Preferences and account setup") { store.navigate(to: .settings) }
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
            ReferenceHeader(title: "Personal Information", subtitle: "", backAction: { store.goBack(fallback: .profile) }, trailingSystemImage: "pencil") {
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

    var body: some View {
        ReferencePage {
            ReferenceHeader(title: "Documents", subtitle: "Manage your documents and verification", backAction: { store.goBack(fallback: .profile) })
            VStack(alignment: .leading, spacing: 8) {
                Text("Uploaded Documents")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                Text("Documents are locked after registration. Contact support if anything needs correction.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.muted)
                    .safeText()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)

            if uploadedDocuments.isEmpty {
                EmptyState(title: "No uploaded documents", subtitle: "Aadhaar, selfie and certificates uploaded during registration will appear here.")
            } else {
                VStack(spacing: 0) {
                    ForEach(uploadedDocuments.indices, id: \.self) { index in
                        let item = uploadedDocuments[index]
                        VerificationDocumentRow(title: item.title, status: item.status)
                        if index < uploadedDocuments.count - 1 {
                            Divider().padding(.leading, 72)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
            }
        }
    }

    private var uploadedDocuments: [(title: String, status: String)] {
        documentDisplayOrder.compactMap { type in
            guard let status = store.documentStatuses[type], status == "Uploaded" else { return nil }
            return (type, status)
        }
    }

    private var documentDisplayOrder: [String] {
        ["Aadhaar Card Front", "Aadhaar Card Back", "Selfie Verification", "Skill Certificate"]
    }
}

struct MyServicesScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ReferencePage {
            ReferenceHeader(title: "My Services", subtitle: "Manage services and areas", backAction: { store.goBack(fallback: .profile) })
            VStack(alignment: .leading, spacing: 8) {
                Text("Service setup")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                Text("Keep only the work you can accept. Matching uses your live status, radius and service area.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.muted)
                    .safeText()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Circle()
                        .fill(store.profile.online ? AppTheme.green : AppTheme.muted)
                        .frame(width: 14, height: 14)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.profile.online ? "Online and receiving requests" : "Offline")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(2)
                            .safeText()
                        Text(store.profile.online ? "Customers can match with you now" : "Switch on when you are ready")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { store.profile.online }, set: { _ in store.toggleOnline() }))
                        .labelsHidden()
                        .tint(Color(hex: 0x00C853))
                }
                .padding(.vertical, 16)

                Divider()

                Menu {
                    ForEach([5, 10, 25, 50], id: \.self) { km in
                        Button("\(km) km") {
                            store.profile.serviceRadiusKm = km
                            store.persistProfile()
                        }
                    }
                } label: {
                    ServiceInfoLine(title: "Service Radius", value: "\(store.profile.serviceRadiusKm) km around \(store.profile.serviceArea)", systemImage: "scope")
                }
                .padding(.vertical, 18)

                Divider()

                Menu {
                    ForEach(["Guwahati", "Dispur", "Ganeshguri", "Zoo Road", "Six Mile"], id: \.self) { area in
                        Button(area) {
                            store.profile.serviceArea = area
                            store.profile.workingAreas = area
                            store.persistProfile()
                        }
                    }
                } label: {
                    ServiceInfoLine(title: "Primary Area", value: "\(store.profile.serviceArea), Assam", systemImage: "mappin.circle")
                }
                .padding(.vertical, 18)
            }
            .padding(.horizontal, 18)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.line, lineWidth: 1))

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active service categories")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text("Select at least one service")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    Text("\(store.profile.skills.count) active")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.hotPink)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(AppTheme.roseSoft, in: Capsule())
                }
                LazyVGrid(columns: serviceColumns, alignment: .leading, spacing: 8) {
                    ForEach(PartnerSkill.allCases) { skill in
                        MyServiceSkillChip(skill: skill, selected: store.profile.skills.contains(skill)) {
                            store.setSkill(skill, selected: !store.profile.skills.contains(skill))
                        }
                    }
                }
            }
            .padding(18)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.line, lineWidth: 1))

            HStack(spacing: 12) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.hotPink)
                Text("Changes are synced with backend and used for nearby request matching.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.muted)
                    .safeText()
                Spacer()
            }
            .padding(16)
            .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button("Save Changes") {
                store.persistProfile()
                Task { await store.syncPartnerProfile() }
            }
            .primaryButton()
        }
    }

    private var serviceColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 105), spacing: 8)]
    }
}

struct PartnerSettingsScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ReferencePage {
            ReferenceHeader(title: "Settings", subtitle: "Manage your notification and route preferences", backAction: { store.goBack(fallback: .profile) })
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
            ReferenceHeader(title: "Legal & Information", subtitle: "Privacy, terms and account deletion", backAction: { store.goBack(fallback: .profile) })
            LegalCard(title: "Privacy Policy", detail: "ApnaServo stores only partner profile, service area, verification, booking and payment records required to operate the platform.")
            LegalCard(title: "Partner Terms", detail: "Accept only genuine jobs, keep customer communication inside ApnaServo, and update every service status honestly.")
            LegalCard(title: "Account Deletion", detail: "Deletion requests are sent to backend for review. Legal, statement and compliance records may be retained as required.")
        }
    }
}

struct PartnerSupportChatScreen: View {
    @EnvironmentObject private var store: PartnerAppStore
    @State private var selectedCategory: PartnerSupportCategory = .booking
    @State private var selectedPriority: SupportPriority = .high
    @State private var selectedBookingId = ""
    @State private var draft = ""

    var body: some View {
        ReferencePage {
            ReferenceHeader(title: "Partner Support", subtitle: "Dedicated operations helpdesk", backAction: { store.goBack(fallback: .profile) })
            SupportHeroCard(openTickets: partnerTicketCount, activeJobs: store.activeBookings.count)

            VStack(alignment: .leading, spacing: 12) {
                SectionTitleRow(title: "Choose issue type")
                LazyVGrid(columns: supportColumns, spacing: 10) {
                    ForEach(PartnerSupportCategory.allCases) { category in
                        SupportCategoryCard(category: category, selected: selectedCategory == category) {
                            selectedCategory = category
                            if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                draft = category.template(booking: selectedBooking)
                            }
                        }
                    }
                }
            }
            .supportPanel()

            VStack(alignment: .leading, spacing: 14) {
                Text("Priority")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                HStack(spacing: 8) {
                    ForEach(SupportPriority.allCases) { priority in
                        Button {
                            selectedPriority = priority
                        } label: {
                            Text(priority.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(selectedPriority == priority ? .white : priority.tint)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(selectedPriority == priority ? priority.tint : priority.background, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(selectedPriority.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.muted)
                    .safeText()
            }
            .supportPanel()

            if !contextBookings.isEmpty {
                Menu {
                    Button("No booking context") { selectedBookingId = "" }
                    ForEach(contextBookings) { booking in
                        Button("\(booking.displayId) - \(booking.serviceName)") {
                            selectedBookingId = booking.id
                            if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                draft = selectedCategory.template(booking: booking)
                            }
                        }
                    }
                } label: {
                    SupportContextRow(booking: selectedBooking)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Partner message")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text("Write operational details. Customer-facing wording is not used here.")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    Text(selectedCategory.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.hotPink)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(AppTheme.roseSoft, in: Capsule())
                }
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $draft)
                        .font(.system(size: 14))
                        .frame(minHeight: 118)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(Color(hex: 0xFFF9FA), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
                    if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(selectedCategory.template(booking: selectedBooking))
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.muted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                Button("Submit partner support ticket") {
                    let message = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selectedCategory.template(booking: selectedBooking) : draft
                    store.sendSupportMessage(message, category: selectedCategory.title, priority: selectedPriority.apiValue, booking: selectedBooking)
                    draft = ""
                }
                .primaryButton()
            }
            .supportPanel()

            VStack(alignment: .leading, spacing: 14) {
                SectionTitleRow(title: "Ticket timeline", actionTitle: "Refresh") {
                    store.infoMessage = "Ticket refresh will sync with backend support status endpoint when enabled."
                }
                ForEach(store.supportMessages.suffix(6)) { message in
                    SupportTimelineRow(message: message)
                }
            }
            .supportPanel()

            VStack(alignment: .leading, spacing: 14) {
                Text("Partner playbooks")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                SupportPlaybookRow(title: "Booking escalation", detail: "Use when customer is unreachable, address is wrong, or visit timing changes.", icon: "calendar.badge.exclamationmark")
                SupportPlaybookRow(title: "Payment and payout", detail: "Use for unpaid job, wallet mismatch, commission or settlement queries.", icon: "wallet.pass")
                SupportPlaybookRow(title: "Verification and documents", detail: "Use for Aadhaar, selfie, skill certificate or profile approval issues.", icon: "checkmark.shield")
            }
            .supportPanel()
        }
        .onAppear {
            if draft.isEmpty {
                draft = selectedCategory.template(booking: selectedBooking)
            }
        }
    }

    private var supportColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 142), spacing: 10)]
    }

    private var contextBookings: [PartnerBooking] {
        Array((store.pendingBookings + store.activeBookings).prefix(8))
    }

    private var selectedBooking: PartnerBooking? {
        guard !selectedBookingId.isEmpty else { return nil }
        return store.bookings.first { $0.id == selectedBookingId }
    }

    private var partnerTicketCount: Int {
        store.supportMessages.filter { $0.senderRole == "partner" }.count
    }
}

private enum PartnerSupportCategory: String, CaseIterable, Identifiable {
    case booking
    case payout
    case verification
    case customerDispute
    case appIssue
    case safety

    var id: String { rawValue }

    var title: String {
        switch self {
        case .booking: return "Booking Operations"
        case .payout: return "Payment & Payout"
        case .verification: return "Verification"
        case .customerDispute: return "Customer Dispute"
        case .appIssue: return "App Issue"
        case .safety: return "Safety"
        }
    }

    var subtitle: String {
        switch self {
        case .booking: return "Job, schedule, location"
        case .payout: return "Wallet, commission"
        case .verification: return "Docs, selfie, approval"
        case .customerDispute: return "Customer behavior"
        case .appIssue: return "Login, notification, map"
        case .safety: return "Urgent field support"
        }
    }

    var icon: String {
        switch self {
        case .booking: return "calendar.badge.clock"
        case .payout: return "wallet.pass"
        case .verification: return "checkmark.shield"
        case .customerDispute: return "person.2.slash"
        case .appIssue: return "iphone.gen3"
        case .safety: return "exclamationmark.shield"
        }
    }

    var tint: Color {
        switch self {
        case .booking, .verification: return AppTheme.hotPink
        case .payout: return AppTheme.green
        case .customerDispute, .safety: return AppTheme.orange
        case .appIssue: return AppTheme.blue
        }
    }

    var background: Color {
        switch self {
        case .booking, .verification: return AppTheme.roseSoft
        case .payout: return AppTheme.greenSoft
        case .customerDispute, .safety: return AppTheme.orangeSoft
        case .appIssue: return AppTheme.blueSoft
        }
    }

    func template(booking: PartnerBooking?) -> String {
        let bookingLine = booking.map { "Booking: \($0.displayId), \($0.serviceName), status \($0.statusLabel). " } ?? ""
        switch self {
        case .booking:
            return "\(bookingLine)I need partner operations help with schedule, location, customer contact or job status."
        case .payout:
            return "\(bookingLine)I need help with payout, wallet balance, commission, incentive or payment confirmation."
        case .verification:
            return "I need help with partner verification, Aadhaar, selfie, skill certificate or profile approval."
        case .customerDispute:
            return "\(bookingLine)I need help handling a customer dispute or service disagreement."
        case .appIssue:
            return "I am facing an app issue with login, notifications, map, booking sync or chat."
        case .safety:
            return "\(bookingLine)I need urgent field safety support. Please review immediately."
        }
    }
}

private enum SupportPriority: String, CaseIterable, Identifiable {
    case normal
    case high
    case urgent

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var apiValue: String { rawValue }

    var subtitle: String {
        switch self {
        case .normal: return "Use for general questions and non-blocking profile queries."
        case .high: return "Use when a booking, payment, verification, or app workflow is blocked."
        case .urgent: return "Use only for active job risk, safety, or customer escalation."
        }
    }

    var tint: Color {
        switch self {
        case .normal: return AppTheme.blue
        case .high: return AppTheme.hotPink
        case .urgent: return AppTheme.orange
        }
    }

    var background: Color {
        switch self {
        case .normal: return AppTheme.blueSoft
        case .high: return AppTheme.roseSoft
        case .urgent: return AppTheme.orangeSoft
        }
    }
}

private struct SupportHeroCard: View {
    let openTickets: Int
    let activeJobs: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                SoftIcon(systemImage: "headphones", color: AppTheme.hotPink, bg: AppTheme.roseSoft)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Partner Support Desk")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text("Separate queue for partner operations, bookings, payouts and verification.")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.muted)
                        .safeText()
                }
                Spacer()
            }
            HStack(spacing: 10) {
                SupportMetricPill(value: "\(openTickets)", label: "Tickets")
                SupportMetricPill(value: "\(activeJobs)", label: "Active jobs")
                SupportMetricPill(value: "24/7", label: "Desk")
            }
        }
        .supportPanel()
    }
}

private struct SupportMetricPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.hotPink)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(AppTheme.bgLight, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct SupportCategoryCard: View {
    let category: PartnerSupportCategory
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(selected ? .white : category.tint)
                        .frame(width: 36, height: 36)
                        .background(selected ? category.tint : category.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(category.tint)
                    }
                }
                Text(category.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                    .safeText()
                Text(category.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
                    .safeText()
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(selected ? category.tint.opacity(0.65) : AppTheme.line, lineWidth: selected ? 1.4 : 1))
        }
        .buttonStyle(.plain)
    }
}

private struct SupportContextRow: View {
    let booking: PartnerBooking?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "link")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.hotPink)
                .frame(width: 40, height: 40)
                .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("Booking context")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.muted)
                Text(booking.map { "\($0.displayId) - \($0.serviceName)" } ?? "No booking selected")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                    .safeText()
            }
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.hotPink)
        }
        .supportPanel()
    }
}

private struct SupportTimelineRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: message.senderRole == "partner" ? "person.crop.circle.fill" : "headphones.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(message.senderRole == "partner" ? AppTheme.hotPink : AppTheme.green)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(message.senderName.isEmpty ? (message.senderRole == "partner" ? "You" : "Support") : message.senderName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    if !message.deliveryStatus.isEmpty {
                        Text(message.deliveryStatus.capitalized)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(message.deliveryStatus == "failed" ? AppTheme.orange : AppTheme.green)
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(message.deliveryStatus == "failed" ? AppTheme.orangeSoft : AppTheme.greenSoft, in: Capsule())
                    }
                }
                Text(message.message)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.ink)
                    .safeText()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

private struct SupportPlaybookRow: View {
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.hotPink)
                .frame(width: 40, height: 40)
                .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.muted)
                    .safeText()
            }
            Spacer()
        }
    }
}

private extension View {
    func supportPanel() -> some View {
        self
            .padding(16)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
    }
}

struct PartnerNotificationsScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ReferencePage {
            ReferenceHeader(title: "Messages", subtitle: "All your notifications and messages", backAction: { store.goBack(fallback: .dashboard) }, trailingSystemImage: "checkmark.circle") {
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
            ReferenceHeader(title: "New Request", subtitle: "Available booking", backAction: { store.goBack(fallback: .dashboard) })
            if let booking = store.selectedBooking {
                PremiumBookingCard(booking: booking) {
                    store.callCustomer(booking)
                } detailsAction: {
                    store.navigate(to: .detail)
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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                BookingDetailCloneHeader(
                    backAction: { store.goBack(fallback: .bookings) },
                    supportAction: { store.navigate(to: .support) }
                )

                if let booking = store.selectedBooking {
                    BookingDetailCloneCard(
                        booking: booking,
                        chatAction: { store.openBookingChat(booking) },
                        callAction: { store.callCustomer(booking) },
                        startAction: { store.openMap(booking) }
                    )
                    BookingDetailCloneAcceptedBanner()
                } else {
                    EmptyState(title: "No job selected", subtitle: "Open a booking from dashboard.")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 22)
        }
        .background(AppTheme.bg.ignoresSafeArea())
    }
}

private struct BookingDetailCloneHeader: View {
    let backAction: () -> Void
    let supportAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button(action: backAction) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 52, height: 52)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            VStack(spacing: 10) {
                Text("Booking Details")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 16) {
                    Capsule()
                        .fill(AppTheme.rose)
                        .frame(width: 48, height: 6)
                    Circle()
                        .fill(AppTheme.rose)
                        .frame(width: 7, height: 7)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            Button(action: supportAction) {
                HStack(spacing: 6) {
                    Image(systemName: "headphones")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Support")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(AppTheme.rose)
                .frame(width: 108, height: 52)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 88)
    }
}

private struct BookingDetailCloneCard: View {
    let booking: PartnerBooking
    let chatAction: () -> Void
    let callAction: () -> Void
    let startAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            customerBlock
                .padding(.bottom, 18)
            BookingDetailCloneDivider()
            BookingDetailCloneInfoRow(icon: "wrench.fill", title: "Service", value: booking.serviceName)
            BookingDetailCloneDivider()
            BookingDetailCloneInfoRow(icon: "doc.text.fill", title: "Issue", value: issueText)
            BookingDetailCloneDivider()
            BookingDetailCloneInfoRow(icon: "mappin", title: "Address", value: booking.address.isEmpty ? booking.city : booking.address)
            BookingDetailCloneDivider()
            dateTimeRow
                .padding(.vertical, 18)
            startButton
        }
        .padding(18)
        .background(
            ZStack(alignment: .topTrailing) {
                Color.white
                Circle()
                    .fill(AppTheme.roseSoft.opacity(0.7))
                    .frame(width: 190, height: 190)
                    .offset(x: 76, y: 12)
                    .blur(radius: 1)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color(hex: 0xF1E5E7), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.09), radius: 18, x: 0, y: 10)
    }

    private var customerBlock: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(bookingInitials)
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(AppTheme.rose)
                .frame(width: 76, height: 76)
                .background(
                    Circle()
                        .fill(Color(hex: 0xFFE7EE))
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 5) {
                Text(customerName)
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(shortPhone)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text(maskedPhone)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: "shield")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x14AEB8))
                    Text("Protected calling")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.rose)
                        .lineLimit(1)
                }
                Text("Only you can call this customer")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button(action: chatAction) {
                    Label("Chat", systemImage: "message")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.rose)
                        .frame(width: 74, height: 50)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(AppTheme.rose, lineWidth: 1.2))
                }
                .buttonStyle(.plain)

                Button(action: callAction) {
                    Label("Call", systemImage: "phone.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 78, height: 50)
                        .background(
                            LinearGradient(colors: [AppTheme.rose, Color(hex: 0xDE235A)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                        )
                        .shadow(color: AppTheme.rose.opacity(0.28), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var dateTimeRow: some View {
        HStack(spacing: 14) {
            BookingDetailCloneDateCell(icon: "calendar", title: "Booking Date", value: bookingDateTitle, subvalue: bookingDayTitle)
            Rectangle()
                .fill(Color(hex: 0xEADFE2))
                .frame(width: 1, height: 70)
            BookingDetailCloneDateCell(icon: "clock", title: "Time", value: bookingTimeTitle, subvalue: bookingDurationTitle)
        }
    }

    private var startButton: some View {
        Button(action: startAction) {
            HStack(spacing: 16) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Color.white.opacity(0.16)))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Start Service")
                        .font(.system(size: 25, weight: .black))
                    Text("Navigate to customer location")
                        .font(.system(size: 17, weight: .medium))
                }
                .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .frame(height: 76)
            .background(
                LinearGradient(colors: [Color(hex: 0x0DB85B), Color(hex: 0x008A36)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(hex: 0x008B38), lineWidth: 1))
            .shadow(color: Color(hex: 0x008A36).opacity(0.26), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
    }

    private var customerName: String {
        booking.customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Customer" : booking.customerName
    }

    private var bookingInitials: String {
        let words = customerName.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first }.map { String($0).uppercased() }.joined()
        return letters.isEmpty ? "C" : letters
    }

    private var digitsOnlyPhone: String {
        booking.customerPhone.filter(\.isNumber)
    }

    private var shortPhone: String {
        guard digitsOnlyPhone.count >= 4 else { return "+----" }
        return "+" + String(digitsOnlyPhone.suffix(4))
    }

    private var maskedPhone: String {
        guard digitsOnlyPhone.count >= 4 else { return "******----" }
        return "******" + String(digitsOnlyPhone.suffix(4))
    }

    private var issueText: String {
        booking.issue.isEmpty ? "Customer requested \(booking.serviceName) inspection" : booking.issue
    }

    private var bookingDateTitle: String {
        let extracted = Self.extractDate(from: booking.slot)
        guard !extracted.isEmpty else { return "Today" }
        return Self.isToday(extracted) ? "Today" : extracted
    }

    private var bookingDayTitle: String {
        let extracted = Self.extractDate(from: booking.slot)
        if let date = Self.parseDate(extracted) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
        return "Friday"
    }

    private var bookingTimeTitle: String {
        booking.slot.isEmpty ? "Time not set" : booking.slot
    }

    private var bookingDurationTitle: String {
        let slot = booking.slot
        let pattern = #"(\d{1,2}):(\d{2})\s*([AP]M)\s*-\s*(\d{1,2}):(\d{2})\s*([AP]M)"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: slot, range: NSRange(slot.startIndex..., in: slot)),
            let startHourRange = Range(match.range(at: 1), in: slot),
            let startMinuteRange = Range(match.range(at: 2), in: slot),
            let startMeridiemRange = Range(match.range(at: 3), in: slot),
            let endHourRange = Range(match.range(at: 4), in: slot),
            let endMinuteRange = Range(match.range(at: 5), in: slot),
            let endMeridiemRange = Range(match.range(at: 6), in: slot),
            let startMinutes = Self.minutes(hour: String(slot[startHourRange]), minute: String(slot[startMinuteRange]), meridiem: String(slot[startMeridiemRange])),
            let endMinutes = Self.minutes(hour: String(slot[endHourRange]), minute: String(slot[endMinuteRange]), meridiem: String(slot[endMeridiemRange]))
        else {
            return "2 hrs"
        }
        let minutes = max(0, endMinutes - startMinutes)
        if minutes >= 60, minutes % 60 == 0 { return "\(minutes / 60) hrs" }
        if minutes >= 60 { return "\(minutes / 60) hr \(minutes % 60) min" }
        return "\(minutes) min"
    }

    private static func extractDate(from slot: String) -> String {
        let pattern = #"\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4}"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: slot, range: NSRange(slot.startIndex..., in: slot)),
            let range = Range(match.range, in: slot)
        else { return "" }
        return String(slot[range])
    }

    private static func parseDate(_ text: String) -> Date? {
        guard !text.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["d MMM yyyy", "dd MMM yyyy", "d MMMM yyyy", "dd MMMM yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    private static func isToday(_ text: String) -> Bool {
        guard let date = parseDate(text) else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private static func minutes(hour: String, minute: String, meridiem: String) -> Int? {
        guard var h = Int(hour), let m = Int(minute) else { return nil }
        let upper = meridiem.uppercased()
        if upper == "PM", h < 12 { h += 12 }
        if upper == "AM", h == 12 { h = 0 }
        return h * 60 + m
    }
}

private struct BookingDetailCloneInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppTheme.rose)
                .frame(width: 60, height: 60)
                .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: 0xF7D9E1), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 5)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(AppTheme.muted)
                Text(value.isEmpty ? "-" : value)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 18)
    }
}

private struct BookingDetailCloneDateCell: View {
    let icon: String
    let title: String
    let value: String
    let subvalue: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.rose)
                .frame(width: 58, height: 58)
                .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color(hex: 0xF7D9E1), lineWidth: 1))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.muted)
                Text(value)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
                Text(subvalue)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BookingDetailCloneDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: 0xEFE3E6))
            .frame(height: 1)
    }
}

private struct BookingDetailCloneAcceptedBanner: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color(hex: 0x008D3E))
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(Color(hex: 0x008D3E), lineWidth: 2))

            Text("Booking accepted")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color(hex: 0x008D3E))
            Text("\u{2022}")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.ink)
            Text("Let's go!")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(AppTheme.muted)
            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(Color(hex: 0xF4FFF9), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(hex: 0xCFEEDD), lineWidth: 1))
    }
}

struct PartnerMapScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                ServiceStatusCloneHeader(
                    backAction: { store.goBack(fallback: .detail) },
                    supportAction: { store.navigate(to: .support) }
                )

            if let booking = store.selectedBooking {
                    ServiceStatusCloneCustomerCard(
                        booking: booking,
                        chatAction: { store.openBookingChat(booking) },
                        callAction: { store.callCustomer(booking) }
                    )
                    ServiceStatusCloneServiceProblemRow(booking: booking)
                    ServiceStatusCloneTimeline(booking: booking)
                    ServiceStatusCloneLocationRow(booking: booking) {
                        store.openAppleMaps(booking)
                    }
                    if let next = ServiceStatusCloneStep.next(for: booking.status) {
                        ServiceStatusCloneActionPanel(step: next, loading: store.loading) {
                            store.updateSelectedStatus(next.status)
                        }
                    }
            } else {
                EmptyState(title: "No map target", subtitle: "Open a booking first.")
            }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(AppTheme.bg.ignoresSafeArea())
    }
}

private struct ServiceStatusCloneHeader: View {
    let backAction: () -> Void
    let supportAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button(action: backAction) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(AppTheme.rose)
                    .frame(width: 54, height: 54)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            VStack(spacing: 8) {
                Text("Service Status")
                    .font(.system(size: 27, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text("Live updates about your service")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 12) {
                    Capsule().fill(AppTheme.rose).frame(width: 48, height: 6)
                    Capsule().fill(AppTheme.rose).frame(width: 12, height: 6)
                }
                .padding(.top, 2)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            Button(action: supportAction) {
                HStack(spacing: 7) {
                    Image(systemName: "headphones")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Support")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(AppTheme.rose)
                .frame(width: 110, height: 52)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 104)
    }
}

private struct ServiceStatusCloneCustomerCard: View {
    let booking: PartnerBooking
    let chatAction: () -> Void
    let callAction: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
        .padding(.top, 12)
    }

    private var horizontalLayout: some View {
        HStack(alignment: .center, spacing: 18) {
            avatar
            customerCopy
            Spacer(minLength: 8)
            actionButtons
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                avatar
                customerCopy
            }
            actionButtons
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(initials)
                .font(.system(size: 35, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 94, height: 94)
                .background(
                    Circle()
                        .fill(LinearGradient(colors: [AppTheme.roseDark, AppTheme.rose], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(Circle().stroke(AppTheme.roseSoft, lineWidth: 8))
                )
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(AppTheme.rose, in: Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 3))
        }
    }

    private var customerCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.system(size: 25, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Label("Protected calling only", systemImage: "shield.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.rose)
            Label(maskedPhone, systemImage: "phone.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.ink)
            Label(addressText, systemImage: "mappin")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button(action: chatAction) {
                Label("Chat", systemImage: "message")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.rose)
                    .frame(width: 78, height: 50)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.rose, lineWidth: 1.3))
            }
            .buttonStyle(.plain)

            Button(action: callAction) {
                Label("Call", systemImage: "phone.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 78, height: 50)
                    .background(
                        LinearGradient(colors: [AppTheme.rose, Color(hex: 0xC9004D)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(color: AppTheme.rose.opacity(0.25), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
        }
    }

    private var name: String {
        booking.customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Customer" : booking.customerName
    }

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
        return letters.isEmpty ? "C" : letters
    }

    private var maskedPhone: String {
        let digits = booking.customerPhone.filter(\.isNumber)
        guard digits.count >= 4 else { return "**** **** ----" }
        return "**** **** \(digits.suffix(4))"
    }

    private var addressText: String {
        booking.address.isEmpty ? booking.city : booking.address
    }
}

private struct ServiceStatusCloneServiceProblemRow: View {
    let booking: PartnerBooking

    var body: some View {
        VStack(spacing: 22) {
            Rectangle()
                .fill(Color(hex: 0xF4CBD4))
                .frame(height: 1)

            HStack(spacing: 18) {
                ServiceStatusCloneMiniInfo(icon: "wrench.fill", title: "Service", value: booking.serviceName)
                Rectangle()
                    .fill(Color(hex: 0xF4CBD4))
                    .frame(width: 1, height: 72)
                ServiceStatusCloneMiniInfo(icon: "doc.text.fill", title: "Problem", value: booking.issue.isEmpty ? "Customer requested \(booking.serviceName)" : booking.issue)
            }
        }
    }
}

private struct ServiceStatusCloneMiniInfo: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.rose)
                .frame(width: 58, height: 58)
                .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.muted)
                Text(value)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ServiceStatusCloneTimeline: View {
    let booking: PartnerBooking

    var body: some View {
        VStack(spacing: 0) {
            ForEach(ServiceStatusCloneStage.allCases) { stage in
                ServiceStatusCloneTimelineRow(
                    stage: stage,
                    currentRank: booking.serviceCloneRank,
                    acceptedTime: booking.acceptedCloneTime,
                    hasNext: stage != ServiceStatusCloneStage.allCases.last
                )
            }
        }
        .padding(.vertical, 6)
    }
}

private struct ServiceStatusCloneTimelineRow: View {
    let stage: ServiceStatusCloneStage
    let currentRank: Int
    let acceptedTime: String
    let hasNext: Bool

    private var completed: Bool { currentRank > stage.rank || currentRank >= 6 || stage.rank == 1 }
    private var current: Bool { currentRank == stage.rank && currentRank < 6 && stage.rank > 1 }
    private var circleColor: Color { completed ? AppTheme.green : current ? AppTheme.rose : Color(hex: 0xF1F1F1) }
    private var lineColor: Color { completed ? AppTheme.green.opacity(0.45) : current ? AppTheme.rose.opacity(0.65) : Color(hex: 0xE5E5E5) }
    private var textColor: Color { current ? AppTheme.rose : completed ? AppTheme.ink : AppTheme.muted }
    private var statusText: String { completed ? "Completed" : current ? "In Progress" : "Pending" }
    private var statusColor: Color { completed ? AppTheme.green : current ? AppTheme.rose : AppTheme.muted }
    private var statusBg: Color { completed ? AppTheme.greenSoft : current ? AppTheme.roseSoft : Color(hex: 0xF5F5F5) }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack(alignment: .top) {
                if hasNext {
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: 3, height: 78)
                        .offset(y: 42)
                }
                ZStack {
                    Circle()
                        .fill(circleColor)
                        .frame(width: 54, height: 54)
                    Image(systemName: completed ? "checkmark" : stage.icon)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(completed || current ? .white : AppTheme.muted)
                }
            }
            .frame(width: 58, height: hasNext ? 98 : 62)

            VStack(alignment: .leading, spacing: 5) {
                Text(stage.title)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(textColor)
                Text(stage.rank == 1 ? acceptedTime : current ? acceptedTime : "Pending")
                    .font(.system(size: 15))
                    .foregroundStyle(current || completed ? AppTheme.ink : AppTheme.muted)
            }
            .padding(.top, 7)

            Spacer()

            Text(statusText)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(statusBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 8)
        }
    }
}

private struct ServiceStatusCloneLocationRow: View {
    let booking: PartnerBooking
    let navigateAction: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "mappin")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.rose)
                .frame(width: 58, height: 58)
                .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text("Customer Location")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                Text(booking.address.isEmpty ? booking.city : booking.address)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(3)
            }
            Spacer()
            Button(action: navigateAction) {
                Label("Navigate", systemImage: "paperplane.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.rose)
                    .frame(width: 118, height: 50)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.rose.opacity(0.45), lineWidth: 1.2))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }
}

private struct ServiceStatusCloneActionPanel: View {
    let step: ServiceStatusCloneStep
    let loading: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Rectangle()
                .fill(Color(hex: 0xF4CBD4))
                .frame(height: 1)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Update Status")
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                    Text(step.hint)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                HStack(spacing: 8) {
                    Circle().fill(Color(hex: 0x008D3E)).frame(width: 9, height: 9)
                    Text("Live")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: 0x008D3E))
                }
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(AppTheme.greenSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: step.icon)
                        .font(.system(size: 20, weight: .black))
                    Text(loading ? "Updating..." : step.label)
                        .font(.system(size: 18, weight: .black))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .black))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(step.gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: step.color.opacity(0.28), radius: 14, x: 0, y: 8)
            }
            .disabled(loading)
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
    }
}

private enum ServiceStatusCloneStage: CaseIterable, Identifiable {
    case accepted
    case onTheWay
    case arrived
    case started
    case completed

    var id: String { title }

    var rank: Int {
        switch self {
        case .accepted: return 1
        case .onTheWay: return 2
        case .arrived: return 3
        case .started: return 4
        case .completed: return 5
        }
    }

    var title: String {
        switch self {
        case .accepted: return "Booking Accepted"
        case .onTheWay: return "On The Way"
        case .arrived: return "Arrived"
        case .started: return "Service Started"
        case .completed: return "Completed"
        }
    }

    var icon: String {
        switch self {
        case .accepted: return "checkmark"
        case .onTheWay: return "car.fill"
        case .arrived: return "mappin"
        case .started: return "play.fill"
        case .completed: return "checkmark"
        }
    }
}

private enum ServiceStatusCloneStep {
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

    var icon: String {
        switch self {
        case .onTheWay: return "car.fill"
        case .arrived: return "mappin"
        case .started: return "play.fill"
        case .complete, .confirmPayment: return "checkmark"
        }
    }

    var color: Color {
        switch self {
        case .onTheWay: return AppTheme.rose
        case .arrived: return AppTheme.blue
        case .started: return AppTheme.orange
        case .complete, .confirmPayment: return AppTheme.green
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .onTheWay:
            return LinearGradient(colors: [AppTheme.rose, Color(hex: 0xC9004D)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .arrived:
            return LinearGradient(colors: [AppTheme.blue, Color(hex: 0x1454C9)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .started:
            return LinearGradient(colors: [AppTheme.orange, Color(hex: 0xE0690F)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .complete, .confirmPayment:
            return LinearGradient(colors: [Color(hex: 0x0DB85B), Color(hex: 0x008A36)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var hint: String {
        switch self {
        case .complete:
            return "Complete the job and enter the final amount."
        case .confirmPayment:
            return "Confirm only after receiving customer payment."
        default:
            return "Tap once. The customer will be notified instantly."
        }
    }

    static func next(for status: String) -> ServiceStatusCloneStep? {
        switch status {
        case "accepted", "pending": return .onTheWay
        case "on_the_way": return .arrived
        case "arrived": return .started
        case "started": return .complete
        case "amount_pending": return .confirmPayment
        default: return nil
        }
    }
}

private extension PartnerBooking {
    var serviceCloneRank: Int {
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

    var acceptedCloneTime: String {
        let date = Date(timeIntervalSince1970: TimeInterval(createdAtMillis) / 1000)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM yyyy h:mm a"
        return formatter.string(from: date)
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
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.hotPink)
            }
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

private struct VerificationDocumentRow: View {
    let title: String
    let status: String

    var body: some View {
        HStack(spacing: 14) {
            SoftIcon(systemImage: status == "Uploaded" ? "checkmark.seal" : "doc.text", color: documentTint, bg: documentBackground, size: 48, iconSize: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(status == "Uploaded" ? "Submitted for verification" : "Registration upload status")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            StatusPill(text: status, tint: documentTint, background: documentBackground)
        }
        .padding(.vertical, 12)
    }

    private var documentTint: Color {
        status == "Uploaded" ? AppTheme.green : AppTheme.orange
    }

    private var documentBackground: Color {
        status == "Uploaded" ? AppTheme.greenSoft : AppTheme.orangeSoft
    }
}

private struct ServiceInfoLine: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.hotPink)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.muted)
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                    .safeText()
            }
            Spacer()
            Text("Change")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.hotPink)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.hotPink)
        }
        .contentShape(Rectangle())
    }
}

private struct MyServiceSkillChip: View {
    let skill: PartnerSkill
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(skill.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? .white : AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, minHeight: 38)
                .padding(.horizontal, 10)
                .background(
                    selected
                        ? LinearGradient(colors: [AppTheme.hotPink, AppTheme.rose], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white, Color.white], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Capsule()
                )
                .overlay(Capsule().stroke(selected ? Color.clear : AppTheme.line, lineWidth: 1))
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
