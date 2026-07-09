import MapKit
import SwiftUI
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
    }

    private var showsBottomNav: Bool {
        ![.support, .bookingChat, .map, .request].contains(store.screen)
    }

    @ViewBuilder
    private var content: some View {
        switch store.screen {
        case .dashboard:
            DashboardScreen()
        case .request:
            IncomingRequestScreen()
        case .detail:
            OrderDetailScreen()
        case .bookings:
            PartnerBookingsScreen()
        case .earnings:
            EarningsScreen()
        case .map:
            PartnerMapScreen()
        case .notifications:
            PartnerNotificationsScreen()
        case .profile:
            PartnerProfileScreen()
        case .personalInfo:
            PersonalInfoScreen()
        case .documents:
            DocumentsScreen()
        case .myServices:
            MyServicesScreen()
        case .settings:
            PartnerSettingsScreen()
        case .legal:
            PartnerLegalScreen()
        case .support:
            PartnerSupportChatScreen()
        case .bookingChat:
            BookingChatView()
        case .login:
            PartnerLoginView()
        }
    }
}

struct DashboardScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    private var statsColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 104), spacing: 10)]
    }

    var body: some View {
        AndroidPage {
            AndroidCenteredHeader(
                title: "ApnaServo Partner",
                subtitle: "Manage jobs and service updates",
                trailingSystemImage: "bell.fill",
                badgeCount: store.pendingBookings.count + store.notifications.filter { !$0.isRead }.count,
                leadingAction: { store.screen = .profile },
                trailingAction: { store.screen = .notifications }
            )
            onlineCard
            approvalCard
            LazyVGrid(columns: statsColumns, spacing: 10) {
                StatTile(title: "Active Jobs", value: "\(store.activeBookings.count)", systemImage: "briefcase.fill", tint: AppTheme.rose)
                StatTile(title: "Completed", value: "\(store.completedBookings.count)", systemImage: "checkmark.shield.fill", tint: AppTheme.green)
                StatTile(title: "Earnings", value: "Rs \(store.totalEarnings)", systemImage: "wallet.pass.fill", tint: AppTheme.purple)
            }
            SectionHeader(title: "Recent Requests", actionTitle: "Refresh") {
                Task { await store.fetchBookings() }
            }
            recentRequests
            SectionHeader(title: "Live Updates", actionTitle: "Messages") {
                store.screen = .notifications
            }
            notificationsCard
        }
    }

    private var onlineCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(store.profile.online ? AppTheme.green : AppTheme.muted)
                .frame(width: 18, height: 18)
                .padding(12)
                .background(store.profile.online ? AppTheme.greenSoft : AppTheme.line, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(store.profile.online ? "You are Online" : "You are Offline")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                Text(store.profile.online ? "Receiving nearby requests" : "Turn online to receive bookings")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
                    .safeText()
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { store.profile.online },
                set: { _ in store.toggleOnline() }
            ))
            .labelsHidden()
        }
        .androidCard()
    }

    private var approvalCard: some View {
        HStack(spacing: 12) {
            Image(systemName: store.profile.faceVerified ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(store.profile.faceVerified ? AppTheme.green : AppTheme.orange)
                .frame(width: 46, height: 46)
                .background(store.profile.faceVerified ? AppTheme.greenSoft : AppTheme.orangeSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(store.profile.faceVerified ? "Partner verified" : "Verification pending")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                Text(store.profile.skillsLabel.isEmpty ? "Select services and upload documents to receive better matches." : "\(store.profile.skillsLabel) around \(store.profile.serviceArea)")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
                    .safeText()
            }
            Spacer()
            Button("Docs") { store.screen = .documents }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.rose)
        }
        .androidCard()
    }

    private var recentRequests: some View {
        VStack(spacing: 12) {
            if store.pendingBookings.isEmpty {
                emptyRecentRequestCard
            } else {
                ForEach(store.pendingBookings.prefix(8)) { booking in
                    PartnerBookingCard(booking: booking, primaryTitle: "Accept") {
                        store.openBooking(booking)
                    }
                }
            }
        }
    }

    private var emptyRecentRequestCard: some View {
        HStack(spacing: 12) {
            ServiceBadge(title: store.profile.skillsLabel.isEmpty ? "Service" : store.profile.skillsLabel)
            VStack(alignment: .leading, spacing: 5) {
                Text("Waiting for matching requests")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                Text(store.profile.skillsLabel.isEmpty ? "Select services in My Services" : store.profile.skillsLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.rose)
                    .lineLimit(2)
                    .safeText()
                Text(store.profile.online ? "Stay online to get matched with nearby customers." : "Turn online to start receiving customer requests.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.muted)
                    .safeText()
            }
        }
        .androidCard(cornerRadius: 20, padding: 12)
    }

    private var notificationsCard: some View {
        VStack(spacing: 10) {
            let visibleBookings = Array((store.pendingBookings + store.activeBookings).prefix(4))
            if visibleBookings.isEmpty && store.notifications.isEmpty {
                EmptyState(title: "No live messages", subtitle: "Booking requests, chat updates and payout alerts will appear here.")
            } else {
                ForEach(visibleBookings) { booking in
                    NotificationRowView(
                        icon: "bell.fill",
                        title: booking.isPending ? "New request available" : "Booking in progress",
                        message: "\(booking.serviceName) | \(booking.statusLabel)",
                        tint: booking.isPending ? AppTheme.rose : AppTheme.green,
                        bg: booking.isPending ? AppTheme.roseSoft : AppTheme.greenSoft,
                        unread: booking.isPending
                    ) {
                        store.openBooking(booking)
                    }
                }
                ForEach(store.notifications.prefix(4)) { item in
                    NotificationRowView(
                        icon: "bell.fill",
                        title: item.title,
                        message: item.body,
                        tint: item.type == "payment" ? AppTheme.green : AppTheme.rose,
                        bg: item.type == "payment" ? AppTheme.greenSoft : AppTheme.roseSoft,
                        unread: !item.isRead
                    ) {
                        store.markNotificationRead(item)
                        if let booking = store.bookingForNotification(item) {
                            store.openBooking(booking)
                        }
                    }
                }
            }
        }
    }
}

struct IncomingRequestScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "New Request", subtitle: "Available booking", backAction: { store.screen = .dashboard })
            AndroidPage(showsTopPadding: false) {
                if let booking = store.selectedBooking {
                    requestCard(booking)
                    actionButtons(booking)
                } else {
                    EmptyState(title: "No request selected", subtitle: "Open a pending request from dashboard.")
                }
            }
        }
    }

    private func requestCard(_ booking: PartnerBooking) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available request")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                    Text("Closing this screen keeps the booking in Recent Requests until it is accepted or declined.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.muted)
                        .safeText()
                }
                Spacer()
                StatusPill(text: "Live", tint: AppTheme.green, background: AppTheme.greenSoft)
            }
            .padding(.bottom, 16)

            HStack(spacing: 14) {
                ServiceBadge(title: booking.serviceName)
                VStack(alignment: .leading, spacing: 5) {
                    Text(booking.serviceName)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .safeText()
                    Text(booking.issue.isEmpty ? "Customer requested inspection" : booking.issue)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.muted)
                        .safeText()
                }
                Spacer()
                StatusPill(text: "New", tint: AppTheme.roseDark, background: AppTheme.roseSoft)
            }
            .padding(.bottom, 14)

            detailBlock("Customer", booking.customerName, value2: booking.customerPhone.isEmpty ? "" : "Protected call available", action: booking.customerPhone.isEmpty ? nil : { store.callCustomer(booking) })
            detailBlock("Address", booking.address)
            detailBlock("Issue", booking.issue.isEmpty ? "Customer requested \(booking.serviceName) inspection" : booking.issue)
            detailBlock("Amount", "Partner enters after work")
            detailBlock("Slot", booking.slot)
        }
        .androidCard()
    }

    private func detailBlock(_ label: String, _ value: String, value2: String = "", action: (() -> Void)? = nil) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
                Text(value.isEmpty ? "Not available" : value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .safeText()
                if !value2.isEmpty {
                    Text(value2)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.rose)
                }
            }
            Spacer()
            if let action {
                Button("Call", action: action)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.rose)
                    .frame(width: 54, height: 42)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.rose, lineWidth: 1))
            }
        }
        .padding(.vertical, 12)
        .overlay(Rectangle().fill(AppTheme.line).frame(height: 1), alignment: .bottom)
    }

    private func actionButtons(_ booking: PartnerBooking) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Button("Reject") { store.rejectSelectedBooking() }
                    .outlineButton()
                Button(store.loading ? "Accepting..." : "Accept") { store.acceptSelectedBooking() }
                    .primaryButton()
                    .disabled(store.loading)
                    .opacity(store.loading ? 0.72 : 1)
            }
            VStack(spacing: 10) {
                Button(store.loading ? "Accepting..." : "Accept") { store.acceptSelectedBooking() }
                    .primaryButton()
                    .disabled(store.loading)
                    .opacity(store.loading ? 0.72 : 1)
                Button("Reject") { store.rejectSelectedBooking() }
                    .outlineButton()
            }
        }
    }
}

struct OrderDetailScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                title: "Booking Details",
                subtitle: store.selectedBooking?.displayId ?? "",
                backAction: { store.screen = .dashboard },
                trailingSystemImage: "headphones"
            ) {
                store.openSupport("Booking Support", draft: supportDraft)
            }
            AndroidPage(showsTopPadding: false) {
                if let booking = store.selectedBooking {
                    BookingContactCard(booking: booking)
                    orderDetailCard(booking)
                    BookingProgressStepper(booking: booking)
                    Button {
                        store.openMap(booking)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "location.north.fill")
                                .frame(width: 48, height: 48)
                                .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Start Service")
                                    .font(.system(size: 16, weight: .black))
                                Text("Navigate to customer location")
                                    .font(.system(size: 12))
                            }
                            Spacer()
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 28, weight: .bold))
                        }
                    }
                    .greenButton()
                    acceptedBanner
                    ServiceStatusTimeline(booking: booking)
                    statusActionDock(booking)
                    partnerCancelSupportCard(booking)
                } else {
                    EmptyState(title: "No job selected", subtitle: "Open a booking from dashboard.")
                }
            }
        }
    }

    private var supportDraft: String {
        guard let booking = store.selectedBooking else { return "" }
        return "I need help with booking \(booking.displayId). "
    }

    private func orderDetailCard(_ booking: PartnerBooking) -> some View {
        VStack(spacing: 10) {
            OrderInfoRow(icon: "wrench.and.screwdriver.fill", label: "Service", value: booking.serviceName)
            OrderInfoRow(icon: "doc.text.fill", label: "Issue", value: booking.issue.isEmpty ? "Customer requested \(booking.serviceName) inspection" : booking.issue)
            OrderInfoRow(icon: "mappin.and.ellipse", label: "Address", value: booking.address)
            DateTimeCard(booking: booking)
        }
    }

    private var acceptedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(AppTheme.green)
                .frame(width: 26, height: 26)
                .background(Color.white, in: Circle())
                .overlay(Circle().stroke(AppTheme.green, lineWidth: 1))
            Text("Booking accepted  |  Let's go!")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .safeText()
            Spacer()
        }
        .padding(12)
        .background(AppTheme.greenSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: 0xD9F1E2), lineWidth: 1))
    }

    @ViewBuilder
    private func statusActionDock(_ booking: PartnerBooking) -> some View {
        if let next = StatusStep.next(for: booking.status) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Update Status")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(AppTheme.ink)
                        Text(next.hint)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.muted)
                            .safeText()
                    }
                    Spacer()
                    StatusPill(text: "Live", tint: AppTheme.green, background: AppTheme.greenSoft)
                }
                Button("\(next.label)    >") {
                    store.updateSelectedStatus(next.status)
                }
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(next.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .androidCard(cornerRadius: 24, padding: 14)
        }
    }

    private func partnerCancelSupportCard(_ booking: PartnerBooking) -> some View {
        Button {
            store.openSupport("Booking Cancellation", draft: "I need help cancelling booking \(booking.displayId). ")
        } label: {
            HStack(spacing: 12) {
                Text("!")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(AppTheme.rose)
                    .frame(width: 48, height: 48)
                    .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cancel via Support")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                    Text("Use only if you cannot visit this customer. Support will receive the reason.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.muted)
                        .safeText()
                }
                Spacer()
                Text("Cancel")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.rose)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.rose, lineWidth: 1))
            }
            .androidCard(cornerRadius: 18, padding: 12)
        }
        .buttonStyle(.plain)
    }
}

struct PartnerBookingsScreen: View {
    @EnvironmentObject private var store: PartnerAppStore
    @State private var filter = BookingFilter.all

    var body: some View {
        AndroidPage {
            AndroidCenteredHeader(
                title: "My Bookings",
                subtitle: "Manage and track your all bookings",
                leadingSystemImage: "line.3.horizontal",
                trailingSystemImage: "arrow.clockwise",
                leadingAction: { store.screen = .profile },
                trailingAction: { Task { await store.fetchBookings() } }
            )
            filterTabs
            SectionHeader(title: "Upcoming & Ongoing", actionTitle: "View All") {
                filter = .all
            }
            if filteredBookings.isEmpty {
                EmptyState(title: "No bookings", subtitle: "Accepted, active and completed jobs will appear here.")
            } else {
                ForEach(filteredBookings) { booking in
                    PartnerBookingCard(
                        booking: booking,
                        primaryTitle: booking.isPending ? "Accept" : "Open",
                        primaryAction: { store.openBooking(booking) },
                        secondaryTitle: booking.isActive ? "Map" : nil,
                        secondaryAction: booking.isActive ? { store.openMap(booking) } : nil
                    )
                }
            }
        }
    }

    private var filteredBookings: [PartnerBooking] {
        switch filter {
        case .all: return store.bookings
        case .new: return store.pendingBookings
        case .active: return store.activeBookings
        case .completed: return store.completedBookings
        }
    }

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BookingFilter.allCases) { item in
                    Button {
                        filter = item
                    } label: {
                        Text(item.title)
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(filter == item ? .white : AppTheme.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(filter == item ? AppTheme.rose : Color.white, in: Capsule())
                            .overlay(Capsule().stroke(filter == item ? Color.clear : AppTheme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct EarningsScreen: View {
    @EnvironmentObject private var store: PartnerAppStore
    @State private var period = "Week"

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 145), spacing: 10)]
    }

    var body: some View {
        AndroidPage {
            AndroidCenteredHeader(
                title: "Earnings",
                subtitle: "Completed jobs and statement",
                leadingSystemImage: "chevron.left",
                leadingAction: { store.screen = .dashboard }
            )
            periodSelector
            VStack(alignment: .leading, spacing: 10) {
                Text("Rs \(store.totalEarnings)")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Total partner earnings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                HStack {
                    Label("\(store.completedBookings.count) completed orders", systemImage: "checkmark.circle.fill")
                    Spacer()
                    Label("Tips Rs 0", systemImage: "gift.fill")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [AppTheme.rose, AppTheme.roseDark], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            LazyVGrid(columns: columns, spacing: 10) {
                StatTile(title: "Today", value: "Rs \(store.todayEarnings)", systemImage: "calendar", tint: AppTheme.rose)
                StatTile(title: "This Month", value: "Rs \(store.monthEarnings)", systemImage: "chart.bar.fill", tint: AppTheme.orange)
                StatTile(title: "Completed Orders", value: "\(store.completedBookings.count)", systemImage: "briefcase.fill", tint: AppTheme.blue)
                StatTile(title: "Tips", value: "Rs 0", systemImage: "gift.fill", tint: AppTheme.green)
            }
            statementCard
            SectionHeader(title: "Transactions")
            if store.completedBookings.isEmpty {
                EmptyState(title: "No completed jobs", subtitle: "Completed orders will show as transactions.")
            } else {
                ForEach(store.completedBookings) { booking in
                    PartnerBookingCard(booking: booking, primaryTitle: "Open") {
                        store.openBooking(booking)
                    }
                }
            }
        }
    }

    private var periodSelector: some View {
        HStack(spacing: 8) {
            ForEach(["Week", "Month", "All"], id: \.self) { item in
                Button {
                    period = item
                } label: {
                    Text(item)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(period == item ? .white : AppTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(period == item ? AppTheme.rose : Color.white, in: Capsule())
                        .overlay(Capsule().stroke(period == item ? Color.clear : AppTheme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var statementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Job Statement")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(AppTheme.ink)
            HStack(spacing: 10) {
                TextField("From yyyy-mm-dd", text: $store.statementFrom)
                    .textFieldStyle(.roundedBorder)
                TextField("To yyyy-mm-dd", text: $store.statementTo)
                    .textFieldStyle(.roundedBorder)
            }
            Button("Download PDF") {
                store.downloadStatement()
            }
            .primaryButton()
        }
        .androidCard()
    }
}

struct PartnerMapScreen: View {
    @EnvironmentObject private var store: PartnerAppStore
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: AppConfig.defaultLatitude, longitude: AppConfig.defaultLongitude),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Service Route", subtitle: store.selectedBooking?.address ?? "", backAction: { store.screen = .detail })
            if let booking = store.selectedBooking {
                Map(coordinateRegion: $region, annotationItems: [booking]) { item in
                    MapMarker(coordinate: CLLocationCoordinate2D(latitude: item.lat, longitude: item.lng), tint: .red)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    region.center = CLLocationCoordinate2D(latitude: booking.lat, longitude: booking.lng)
                }
                .overlay(alignment: .bottom) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            MapCustomerCard(booking: booking)
                            ServiceStatusTimeline(booking: booking)
                            mapActions(booking)
                        }
                        .padding(16)
                    }
                    .frame(maxHeight: 430)
                    .background(.ultraThinMaterial)
                }
            } else {
                EmptyState(title: "No map target", subtitle: "Open a booking first.")
                    .padding(18)
            }
        }
        .background(AppTheme.bg)
    }

    private func mapActions(_ booking: PartnerBooking) -> some View {
        VStack(spacing: 10) {
            Button("Navigate") {
                store.openAppleMaps(booking)
            }
            .greenButton()
            if booking.isActive {
                Button("Customer No Response") {
                    store.reportNoResponse(reason: "Customer did not respond")
                }
                .outlineButton()
            }
        }
        .androidCard()
    }
}

struct PartnerNotificationsScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                title: "Messages",
                subtitle: "All your notifications and messages",
                backAction: { store.screen = .dashboard },
                trailingSystemImage: "checkmark.circle"
            ) {
                store.markAllNotificationsRead()
            }
            AndroidPage(showsTopPadding: false) {
                if store.notifications.isEmpty && store.pendingBookings.isEmpty && store.activeBookings.isEmpty {
                    EmptyState(title: "No notifications", subtitle: "Booking requests, chat updates, service status and payout alerts will appear here.")
                } else {
                    ForEach(store.pendingBookings) { booking in
                        NotificationRowView(
                            icon: "bell.fill",
                            title: "New request available",
                            message: "\(booking.serviceName) | \(booking.slot)",
                            tint: AppTheme.rose,
                            bg: AppTheme.roseSoft,
                            unread: true
                        ) {
                            store.openBooking(booking)
                        }
                    }
                    ForEach(store.activeBookings) { booking in
                        NotificationRowView(
                            icon: "briefcase.fill",
                            title: "Booking in progress",
                            message: "\(booking.serviceName) | \(booking.statusLabel)",
                            tint: AppTheme.green,
                            bg: AppTheme.greenSoft,
                            unread: false
                        ) {
                            store.openBooking(booking)
                        }
                    }
                    ForEach(store.notifications) { item in
                        NotificationRowView(
                            icon: "bell.fill",
                            title: item.title,
                            message: item.body,
                            tint: item.type == "payment" ? AppTheme.green : AppTheme.rose,
                            bg: item.type == "payment" ? AppTheme.greenSoft : AppTheme.roseSoft,
                            unread: !item.isRead
                        ) {
                            store.markNotificationRead(item)
                            if let booking = store.bookingForNotification(item) {
                                store.openBooking(booking)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct PartnerProfileScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        AndroidPage {
            profileUnifiedCard
            quickActions
            profileAction("Personal Information", "Name, phone and profile", "person.fill") { store.screen = .personalInfo }
            profileAction("Documents", "ID proof and skill certificate", "folder.fill") { store.screen = .documents }
            profileAction("My Services", "Manage services and request matching", "slider.horizontal.3") { store.screen = .myServices }
            profileAction("Support", "Chat, complaint, track issue", "headphones") { store.openSupport("Chat") }
            profileAction("Settings", "Notifications and account", "gearshape.fill") { store.screen = .settings }
            Button("Logout") { store.logout() }
                .outlineButton()
        }
    }

    private var profileUnifiedCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [AppTheme.roseDark, AppTheme.rose], startPoint: .topLeading, endPoint: .bottomTrailing))
                    if store.profile.photoURL.isEmpty {
                        Text(initials(store.profile.name))
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(.white)
                    } else {
                        AsyncImage(url: URL(string: store.profile.photoURL)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Text(initials(store.profile.name))
                                .font(.system(size: 24, weight: .black))
                                .foregroundStyle(.white)
                        }
                        .clipShape(Circle())
                    }
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 5) {
                    Text(store.profile.name.isEmpty ? "Partner" : store.profile.name)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .safeText()
                    Text(store.profile.phone.isEmpty ? "Mobile number pending" : store.profile.phone)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.muted)
                    StatusPill(
                        text: store.profile.faceVerified ? "Face verified" : "Verification pending",
                        tint: store.profile.faceVerified ? AppTheme.green : AppTheme.orange,
                        background: store.profile.faceVerified ? AppTheme.greenSoft : AppTheme.orangeSoft
                    )
                }
                Spacer()
            }

            HStack(spacing: 10) {
                profileMiniStat("Services", store.profile.skills.count.description)
                profileMiniStat("Radius", "\(store.profile.serviceRadiusKm) km")
                profileMiniStat("Area", store.profile.serviceArea)
            }
        }
        .androidCard(cornerRadius: 22)
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            quickAction("Bookings", "briefcase.fill") { store.screen = .bookings }
            quickAction("Earnings", "wallet.pass.fill") { store.screen = .earnings }
            quickAction("Messages", "bell.fill") { store.screen = .notifications }
        }
    }

    private func profileMiniStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(AppTheme.bgLight, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func quickAction(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.rose)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.roseSoft, in: Circle())
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .androidCard(cornerRadius: 16, padding: 10)
        }
        .buttonStyle(.plain)
    }

    private func profileAction(_ title: String, _ subtitle: String, _ image: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: image)
                    .foregroundStyle(AppTheme.rose)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 14, weight: .black)).foregroundStyle(AppTheme.ink)
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(AppTheme.muted).safeText()
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.rose)
            }
            .androidCard(cornerRadius: 18, padding: 12)
        }
        .buttonStyle(.plain)
    }
}

struct PersonalInfoScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Personal Information", subtitle: "Partner details", backAction: { store.screen = .profile })
            AndroidPage(showsTopPadding: false) {
                VStack(spacing: 12) {
                    TextField("Partner name", text: $store.profile.name)
                        .textFieldStyle(.roundedBorder)
                    TextField("Phone", text: $store.profile.phone)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.roundedBorder)
                    TextField("Email", text: $store.profile.email)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)
                    TextField("DD/MM/YYYY", text: $store.profile.dob)
                        .textFieldStyle(.roundedBorder)
                    TextField("Gender", text: $store.profile.gender)
                        .textFieldStyle(.roundedBorder)
                    TextField("Full address", text: $store.profile.address)
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 10) {
                        TextField("City", text: $store.profile.city)
                            .textFieldStyle(.roundedBorder)
                        TextField("State", text: $store.profile.state)
                            .textFieldStyle(.roundedBorder)
                    }
                    TextField("PIN Code", text: $store.profile.pinCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    TextField("Emergency phone", text: $store.profile.emergencyContactNumber)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.roundedBorder)
                    Stepper("Years of Experience: \(store.profile.yearsOfExperience)", value: $store.profile.yearsOfExperience, in: 0...80)
                    TextField("Service Area / Work", text: $store.profile.workingAreas)
                        .textFieldStyle(.roundedBorder)
                    TextField("Languages Known", text: $store.profile.languages)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") {
                        store.persistProfile()
                        Task { await store.syncPartnerProfile() }
                    }
                    .primaryButton()
                }
                .androidCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Backend Auth")
                        .font(.system(size: 16, weight: .black))
                    SecureField("Firebase ID token for API calls", text: $store.authToken)
                        .textFieldStyle(.roundedBorder)
                    Button("Save Token") {
                        store.saveAuthToken()
                    }
                    .outlineButton()
                    Text("In production, Firebase Auth will set this token automatically.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.muted)
                }
                .androidCard()
            }
        }
    }
}

struct DocumentsScreen: View {
    @EnvironmentObject private var store: PartnerAppStore
    @State private var importingDocumentType: String?

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Documents", subtitle: "Verification", backAction: { store.screen = .profile })
            AndroidPage(showsTopPadding: false) {
                documentRow("Aadhaar Card Front", "Upload clear Aadhaar image", required: true)
                documentRow("Aadhaar Card Back", "Upload clear Aadhaar image", required: true)
                documentRow("PAN Card", "Upload PAN card image", required: true)
                documentRow("Selfie Verification", "Upload clear face photo", required: true)
                documentRow("Skill Certificate", "Upload skill certificate", required: false)
                documentRow("Training Certificate", "Upload training certificate", required: false)
                documentRow("Government License", "Upload license if applicable", required: false)
                documentRow("Trade License", "Upload optional trade license", required: false)
                documentRow("Other Supporting Document", "Upload any supporting proof", required: false)
                verificationCard
            }
        }
        .fileImporter(
            isPresented: Binding(
                get: { importingDocumentType != nil },
                set: { if !$0 { importingDocumentType = nil } }
            ),
            allowedContentTypes: [.jpeg, .png, .pdf],
            allowsMultipleSelection: false
        ) { result in
            guard let documentType = importingDocumentType else { return }
            importingDocumentType = nil
            if case .success(let urls) = result, let url = urls.first {
                store.uploadDocument(documentType: documentType, fileURL: url)
            }
        }
    }

    private func status(for documentType: String) -> String {
        if store.uploadingDocumentType == documentType { return "Uploading" }
        return store.documentStatuses[documentType] ?? (documentType == "Skill Certificate" ? "Required" : "Pending")
    }

    private func documentRow(_ title: String, _ subtitle: String, required: Bool) -> some View {
        Button {
            importingDocumentType = title
        } label: {
            HStack(spacing: 12) {
                let current = status(for: title)
                Image(systemName: current == "Uploaded" ? "checkmark.seal.fill" : "doc.fill")
                    .foregroundStyle(current == "Uploaded" ? AppTheme.green : AppTheme.rose)
                    .frame(width: 44, height: 44)
                    .background(current == "Uploaded" ? AppTheme.greenSoft : AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.muted)
                        .safeText()
                }
                Spacer()
                StatusPill(
                    text: current,
                    tint: current == "Uploaded" ? AppTheme.green : required ? AppTheme.orange : AppTheme.muted,
                    background: current == "Uploaded" ? AppTheme.greenSoft : required ? AppTheme.orangeSoft : Color(hex: 0xF6F6F6)
                )
            }
            .androidCard(cornerRadius: 18, padding: 12)
        }
        .buttonStyle(.plain)
    }

    private var verificationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aadhaar last 4")
                .font(.system(size: 16, weight: .black))
            TextField("1234", text: $store.aadhaarLast4)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
            Button("Submit Verification") {
                store.submitVerification()
            }
            .primaryButton()
            Text("Upload clear and valid verification documents. These files are used only for verification.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.muted)
                .safeText()
        }
        .androidCard()
    }
}

struct MyServicesScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "My Services", subtitle: "Manage services and areas", backAction: { store.screen = .profile })
            AndroidPage(showsTopPadding: false) {
                myServicesHero
                myServicesRows
                serviceVisibilityCard
                SkillPickerGrid()
                    .androidCard()
                Button("Save Changes") {
                    store.persistProfile()
                    Task { await store.syncPartnerProfile() }
                }
                .primaryButton()
            }
        }
    }

    private var myServicesHero: some View {
        HStack(spacing: 16) {
            AndroidAssetImage(name: "partner_mascot")
                .frame(width: 78, height: 78)
                .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text("My Services")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                Text("Manage your services and get better request matching")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
                    .safeText()
            }
            Spacer()
        }
        .androidCard(cornerRadius: 22, padding: 16)
    }

    private var myServicesRows: some View {
        VStack(spacing: 0) {
            serviceDetailRow(icon: "square.stack.3d.up.fill", bg: AppTheme.roseSoft, accent: AppTheme.rose, title: "Selected Services", value: store.profile.skillsLabel, actionLabel: "Edit", action: {})
            Divider().background(AppTheme.line)
            serviceDetailRow(icon: "wifi", bg: AppTheme.greenSoft, accent: AppTheme.green, title: "Online Status", value: store.profile.online ? "Online and receiving requests" : "Offline", actionLabel: "", action: { store.toggleOnline() }, showToggle: true)
            Divider().background(AppTheme.line)
            serviceDetailRow(icon: "target", bg: AppTheme.blueSoft, accent: AppTheme.blue, title: "Service Radius", value: "\(store.profile.serviceRadiusKm) km around \(store.profile.serviceArea)", actionLabel: "Edit", action: {})
            radiusPicker
            Divider().background(AppTheme.line)
            serviceDetailRow(icon: "location.fill", bg: AppTheme.orangeSoft, accent: AppTheme.orange, title: "Service Area", value: "\(store.profile.serviceArea), Assam", actionLabel: "Edit", action: {})
            areaPicker
        }
        .androidCard(cornerRadius: 20, padding: 14)
    }

    private func serviceDetailRow(icon: String, bg: Color, accent: Color, title: String, value: String, actionLabel: String, action: @escaping () -> Void, showToggle: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(accent)
                .frame(width: 50, height: 50)
                .background(bg, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
                Text(value.isEmpty ? "Not selected" : value)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                    .safeText()
            }
            Spacer()
            if showToggle {
                Toggle("", isOn: Binding(
                    get: { store.profile.online },
                    set: { _ in store.toggleOnline() }
                ))
                .labelsHidden()
            } else if !actionLabel.isEmpty {
                Button(actionLabel, action: action)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(AppTheme.rose)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(AppTheme.roseSoft, in: Capsule())
            }
        }
        .padding(.vertical, 12)
    }

    private var radiusPicker: some View {
        Picker("Radius", selection: $store.profile.serviceRadiusKm) {
            ForEach([5, 10, 25, 50], id: \.self) { km in
                Text("\(km) km").tag(km)
            }
        }
        .pickerStyle(.segmented)
        .padding(.bottom, 8)
    }

    private var areaPicker: some View {
        Picker("Area", selection: $store.profile.serviceArea) {
            ForEach(["Guwahati", "Dispur", "Ganeshguri", "Zoo Road", "Six Mile"], id: \.self) { area in
                Text(area).tag(area)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var serviceVisibilityCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "shield.fill")
                .foregroundStyle(AppTheme.rose)
                .frame(width: 58, height: 58)
                .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text("Better visibility, more bookings")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                Text("Keeping your services and area updated helps us match you with the right customer.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.muted)
                    .safeText()
            }
            Spacer()
        }
        .androidCard(cornerRadius: 18, padding: 14)
    }
}

struct PartnerSettingsScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Settings", subtitle: "Account and notifications", backAction: { store.screen = .profile })
            AndroidPage(showsTopPadding: false) {
                setting("Notifications", "Booking requests, cancellations and updates use APNs plus Firebase Messaging.", "bell.fill") {
                    Task { _ = await AppNotificationService().requestPermission() }
                }
                setting("Map & Location", "Location heartbeat updates /partners/location while online.", "location.fill") {
                    Task { await store.sendLocationHeartbeat() }
                }
                setting("Legal Information", "Privacy, partner terms and account deletion.", "shield.fill") {
                    store.screen = .legal
                }
                Button("Delete Account Request") {
                    store.requestAccountDeletion()
                }
                .outlineButton()
            }
        }
    }

    private func setting(_ title: String, _ subtitle: String, _ image: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: image)
                    .foregroundStyle(AppTheme.rose)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 14, weight: .black)).foregroundStyle(AppTheme.ink)
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(AppTheme.muted).safeText()
                }
                Spacer()
            }
            .androidCard(cornerRadius: 18, padding: 12)
        }
        .buttonStyle(.plain)
    }
}

struct PartnerLegalScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Legal & Information", subtitle: "Partner terms", backAction: { store.screen = .settings })
            AndroidPage(showsTopPadding: false) {
                legalCard("Privacy Policy", "ApnaServo stores profile, service area, verification, booking and payment information to operate the platform and send job updates.")
                legalCard("Partner Terms & Conditions", "Partners must accept only genuine jobs, keep booking chat and service updates clear, provide verified service and avoid off-app misuse. Fraud, fake documents or unsafe service can restrict the account.")
                legalCard("Payment Information", "ApnaServo currently connects customers with independent service professionals. Pricing, payment methods and service details should be confirmed inside the booking flow.")
                legalCard("Account Deletion", "Deletion request is sent to backend for review. Pending bookings, statements and compliance records may be retained as required.")
            }
        }
    }

    private func legalCard(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 16, weight: .black)).foregroundStyle(AppTheme.ink)
            Text(content).font(.system(size: 13)).foregroundStyle(AppTheme.muted).safeText()
        }
        .androidCard()
    }
}

struct PartnerSupportChatScreen: View {
    @EnvironmentObject private var store: PartnerAppStore
    @State private var text = ""

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: store.supportType, subtitle: "Partner Support", backAction: { store.screen = .profile })
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.supportMessages) { message in
                            ChatBubble(message: message, isMe: message.senderRole == "partner")
                                .id(message.id)
                        }
                    }
                    .padding(18)
                }
                .background(AppTheme.bg)
                .onChange(of: store.supportMessages.count) { _ in
                    if let last = store.supportMessages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            HStack(spacing: 10) {
                TextField("Type message", text: $text)
                    .textFieldStyle(.roundedBorder)
                Button {
                    store.sendSupportMessage(text)
                    text = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.rose, in: Circle())
                }
            }
            .padding(12)
            .background(Color.white)
        }
    }
}

private struct BookingContactCard: View {
    @EnvironmentObject private var store: PartnerAppStore
    let booking: PartnerBooking

    var body: some View {
        HStack(spacing: 12) {
            Text(initials(booking.customerName))
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(AppTheme.rose)
                .frame(width: 54, height: 54)
                .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(booking.customerName)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .safeText()
                Text("Protected Call")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.rose)
                Text("Only you can call this customer")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.muted)
            }

            Spacer()

            VStack(spacing: 8) {
                Button("Chat") { store.openBookingChat(booking) }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.rose)
                    .frame(width: 74, height: 38)
                    .background(Color.white, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.rose, lineWidth: 1))
                Button("Call") { store.callCustomer(booking) }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 74, height: 38)
                    .background(LinearGradient(colors: [AppTheme.rose, AppTheme.roseDark], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
            }
        }
        .androidCard(cornerRadius: 16, padding: 12)
    }
}

private struct OrderInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.rose)
                .frame(width: 46, height: 46)
                .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
                Text(value.isEmpty ? "Not available" : value)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(3)
                    .safeText()
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.rose)
        }
        .androidCard(cornerRadius: 14, padding: 12)
    }
}

private struct DateTimeCard: View {
    let booking: PartnerBooking

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                dateColumn(icon: "calendar", label: "Booking Date", value: bookingDate, sub: "Assigned")
                Rectangle().fill(AppTheme.line).frame(width: 1, height: 52)
                dateColumn(icon: "clock.fill", label: "Time", value: booking.slot, sub: "2 hrs")
            }
            VStack(spacing: 8) {
                dateColumn(icon: "calendar", label: "Booking Date", value: bookingDate, sub: "Assigned")
                dateColumn(icon: "clock.fill", label: "Time", value: booking.slot, sub: "2 hrs")
            }
        }
        .androidCard(cornerRadius: 16, padding: 14)
    }

    private var bookingDate: String {
        formatMillis(booking.createdAtMillis)
    }

    private func dateColumn(icon: String, label: String, value: String, sub: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.rose)
                .frame(width: 42, height: 42)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.muted)
                Text(value)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BookingProgressStepper: View {
    let booking: PartnerBooking

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(booking.statusRank > 0 ? "Assigned" : "New request")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(AppTheme.rose)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.roseSoft, in: Capsule())
                .frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: 0) {
                step("A", "Accept", active: booking.statusRank >= 1)
                step("W", "On the Way", active: booking.statusRank >= 2)
                step("R", "Arrived", active: booking.statusRank >= 3)
                step("C", "Complete", active: booking.statusRank >= 5)
            }
        }
        .androidCard(cornerRadius: 18, padding: 14)
    }

    private func step(_ icon: String, _ label: String, active: Bool) -> some View {
        VStack(spacing: 6) {
            Text(active ? "OK" : icon)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(active ? .white : AppTheme.muted)
                .frame(width: 42, height: 42)
                .background(active ? AppTheme.rose : Color(hex: 0xF3F1F1), in: Circle())
                .overlay(Circle().stroke(active ? Color.white : AppTheme.line, lineWidth: 1))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(active ? AppTheme.ink : AppTheme.muted)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.74)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ServiceStatusTimeline: View {
    let booking: PartnerBooking

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineRow(rank: 1, icon: "checkmark", title: "Booking Accepted", subtitle: formatMillis(booking.createdAtMillis), hasNext: true)
            timelineRow(rank: 2, icon: "car.fill", title: "On The Way", subtitle: booking.statusRank >= 2 ? "ETA: 10 min" : "Pending", hasNext: true)
            timelineRow(rank: 3, icon: "mappin", title: "Arrived", subtitle: booking.statusRank >= 3 ? "Customer location reached" : "Pending", hasNext: true)
            timelineRow(rank: 4, icon: "play.fill", title: "Service Started", subtitle: booking.statusRank >= 4 ? "Work is active" : "Pending", hasNext: true)
            timelineRow(rank: 6, icon: "checkmark", title: "Completed", subtitle: booking.statusRank >= 6 ? "Done" : amountPendingLabel, hasNext: false)
        }
        .androidCard(cornerRadius: 20, padding: 18)
    }

    private var amountPendingLabel: String {
        booking.status == "amount_pending" ? "Waiting for customer payment" : "Pending"
    }

    private func timelineRow(rank: Int, icon: String, title: String, subtitle: String, hasNext: Bool) -> some View {
        let completed = rank == 1 || booking.statusRank >= rank
        let current = !completed && booking.statusRank + 1 == rank
        let tint = timelineColor(rank: rank, current: current, completed: completed)

        return HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Image(systemName: completed ? "checkmark" : icon)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle((completed || current) ? .white : AppTheme.muted)
                    .frame(width: 44, height: 44)
                    .background(tint, in: Circle())
                if hasNext {
                    Rectangle()
                        .fill(completed ? AppTheme.greenSoft : AppTheme.line)
                        .frame(width: 3, height: 34)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(completed ? AppTheme.green : current ? tint : AppTheme.muted)
                    .safeText()
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(completed || current ? AppTheme.ink : AppTheme.muted)
                    .safeText()
            }
            Spacer()
            StatusPill(
                text: completed ? "Completed" : current ? "In Progress" : "Pending",
                tint: completed ? AppTheme.green : current ? tint : AppTheme.muted,
                background: completed ? AppTheme.greenSoft : current ? tint.opacity(0.14) : Color(hex: 0xF6F6F6)
            )
        }
    }

    private func timelineColor(rank: Int, current: Bool, completed: Bool) -> Color {
        if completed { return AppTheme.green }
        if !current { return Color(hex: 0xEEEEEE) }
        if rank == 3 { return AppTheme.blue }
        if rank == 4 { return AppTheme.orange }
        if rank >= 6 { return AppTheme.green }
        return AppTheme.rose
    }
}

private struct MapCustomerCard: View {
    @EnvironmentObject private var store: PartnerAppStore
    let booking: PartnerBooking

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(initials(booking.customerName))
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(LinearGradient(colors: [AppTheme.roseDark, AppTheme.rose], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.customerName)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                    Text(booking.address)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(3)
                        .safeText()
                }
                Spacer()
                Button("Call") { store.callCustomer(booking) }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.rose)
                    .frame(width: 76, height: 40)
                    .background(Color.white, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.rose, lineWidth: 1))
            }
            Divider().background(AppTheme.line)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    statusMiniInfo(icon: "wrench.and.screwdriver.fill", label: "Service", value: booking.serviceName)
                    Rectangle().fill(AppTheme.line).frame(width: 1, height: 52)
                    statusMiniInfo(icon: "doc.text.fill", label: "Problem", value: booking.issue.isEmpty ? "Inspection" : booking.issue)
                }
                VStack(spacing: 8) {
                    statusMiniInfo(icon: "wrench.and.screwdriver.fill", label: "Service", value: booking.serviceName)
                    statusMiniInfo(icon: "doc.text.fill", label: "Problem", value: booking.issue.isEmpty ? "Inspection" : booking.issue)
                }
            }
        }
        .androidCard()
    }

    private func statusMiniInfo(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.rose)
                .frame(width: 44, height: 44)
                .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.muted)
                Text(value)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(3)
                    .safeText()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NotificationRowView: View {
    let icon: String
    let title: String
    let message: String
    let tint: Color
    let bg: Color
    let unread: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .frame(width: 46, height: 46)
                    .background(bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .safeText()
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.muted)
                        .safeText()
                }
                Spacer()
                if unread {
                    Circle().fill(AppTheme.rose).frame(width: 10, height: 10)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.rose)
            }
            .androidCard(cornerRadius: 18, padding: 12)
        }
        .buttonStyle(.plain)
    }
}

private enum BookingFilter: String, CaseIterable, Identifiable {
    case all
    case new
    case active
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .new: return "New"
        case .active: return "Active"
        case .completed: return "Completed"
        }
    }
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

    var hint: String {
        switch self {
        case .complete:
            return "Complete the job and send the final amount."
        case .confirmPayment:
            return "Confirm only after receiving customer payment."
        default:
            return "Tap once. The customer will be notified instantly."
        }
    }

    var gradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .arrived:
            colors = [AppTheme.blue, Color(hex: 0x1454C9)]
        case .started:
            colors = [AppTheme.orange, Color(hex: 0xE0690F)]
        case .complete, .confirmPayment:
            colors = [Color(hex: 0x00A44E), Color(hex: 0x007C3E)]
        default:
            colors = [AppTheme.rose, AppTheme.roseDark]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

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
    func bookingForNotification(_ item: PartnerNotificationItem) -> PartnerBooking? {
        bookings.first { booking in
            booking.id == item.bookingId ||
            booking.bookingCode == item.bookingId ||
            booking.id == item.bookingCode ||
            booking.bookingCode == item.bookingCode
        }
    }
}

private func initials(_ name: String) -> String {
    let parts = name
        .split(separator: " ")
        .prefix(2)
        .compactMap { $0.first }
    let value = String(parts).uppercased()
    return value.isEmpty ? "AS" : value
}

private func formatMillis(_ value: Int64) -> String {
    guard value > 0 else { return "Today" }
    let date = Date(timeIntervalSince1970: TimeInterval(value) / 1000)
    let formatter = DateFormatter()
    formatter.dateFormat = "dd MMM, h:mm a"
    return formatter.string(from: date)
}
