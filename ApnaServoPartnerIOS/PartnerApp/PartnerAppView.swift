import MapKit
import SwiftUI
import UniformTypeIdentifiers

struct PartnerAppView: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            content
            if showsBottomNav {
                PartnerBottomNav()
            }
        }
        .background(AppTheme.bg)
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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                onlineCard
                HStack(spacing: 10) {
                    StatTile(title: "Active Jobs", value: "\(store.activeBookings.count)", systemImage: "briefcase.fill", tint: AppTheme.rose)
                    StatTile(title: "Completed", value: "\(store.completedBookings.count)", systemImage: "checkmark.shield.fill", tint: AppTheme.green)
                    StatTile(title: "Earnings", value: "Rs \(store.totalEarnings)", systemImage: "wallet.pass.fill", tint: AppTheme.purple)
                }
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "New Requests", actionTitle: "Refresh") {
                        Task { await store.fetchBookings() }
                    }
                    if store.pendingBookings.isEmpty {
                        EmptyState(title: "No new requests", subtitle: "Keep Online ON. Matching bookings will appear here.")
                    } else {
                        ForEach(store.pendingBookings) { booking in
                            PartnerBookingCard(booking: booking, primaryTitle: "View") {
                                store.openBooking(booking)
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Active Jobs")
                    if store.activeBookings.isEmpty {
                        EmptyState(title: "No active jobs", subtitle: "Accepted jobs will be tracked here.")
                    } else {
                        ForEach(store.activeBookings) { booking in
                            PartnerBookingCard(
                                booking: booking,
                                primaryTitle: "Open",
                                primaryAction: { store.openBooking(booking) },
                                secondaryTitle: "Map",
                                secondaryAction: { store.openMap(booking) }
                            )
                        }
                    }
                }
            }
            .padding(18)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hi \(store.profile.name.isEmpty ? "Partner" : store.profile.name)")
                    .font(.title2.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                Text("\(store.profile.skillsLabel) - \(store.profile.serviceArea)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Button {
                store.screen = .notifications
            } label: {
                Image(systemName: "bell.fill")
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 42, height: 42)
                    .background(Color.white, in: Circle())
                    .overlay(alignment: .topTrailing) {
                        if store.notifications.contains(where: { !$0.isRead }) {
                            Circle().fill(AppTheme.rose).frame(width: 10, height: 10)
                        }
                    }
            }
        }
    }

    private var onlineCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(store.profile.online ? AppTheme.green : AppTheme.muted)
                .frame(width: 18, height: 18)
                .padding(12)
                .background(store.profile.online ? AppTheme.greenSoft : AppTheme.line, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(store.profile.online ? "You are Online" : "You are Offline")
                    .font(.headline.weight(.black))
                Text(store.profile.online ? "Receiving nearby requests" : "Turn online to receive bookings")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { store.profile.online },
                set: { _ in store.toggleOnline() }
            ))
            .labelsHidden()
        }
        .cardStyle()
    }
}

struct IncomingRequestScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "New Booking Request", subtitle: "Request received", backAction: { store.screen = .dashboard })
            ScrollView {
                if let booking = store.selectedBooking {
                    VStack(spacing: 16) {
                        PartnerBookingCard(
                            booking: booking,
                            primaryTitle: "Accept",
                            primaryAction: { store.acceptSelectedBooking() },
                            secondaryTitle: "Decline",
                            secondaryAction: { store.rejectSelectedBooking() }
                        )
                        detail("Customer", booking.customerName)
                        detail("Address", booking.address)
                        detail("Issue", booking.issue)
                        detail("Slot", booking.slot)
                        Button(store.loading ? "Processing..." : "Accept Booking") {
                            store.acceptSelectedBooking()
                        }
                        .primaryButton()
                        Button("Decline") {
                            store.rejectSelectedBooking()
                        }
                        .outlineButton()
                    }
                    .padding(18)
                } else {
                    EmptyState(title: "No request selected", subtitle: "Return to dashboard.")
                        .padding(18)
                }
            }
        }
    }

    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(AppTheme.muted)
            Text(value).font(.subheadline).foregroundStyle(AppTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

struct OrderDetailScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Order Detail", subtitle: store.selectedBooking?.displayId ?? "", backAction: { store.screen = .dashboard })
            ScrollView {
                if let booking = store.selectedBooking {
                    VStack(spacing: 16) {
                        PartnerBookingCard(
                            booking: booking,
                            primaryTitle: "Map",
                            primaryAction: { store.openMap(booking) },
                            secondaryTitle: "Chat",
                            secondaryAction: { store.openBookingChat(booking) }
                        )
                        VStack(spacing: 10) {
                            actionButton(for: booking)
                            Button {
                                store.callCustomer(booking)
                            } label: {
                                Label("Protected Call", systemImage: "phone.fill")
                                    .outlineButton()
                            }
                            Button {
                                store.reportNoResponse(reason: "Customer did not respond")
                            } label: {
                                Label("Customer No Response", systemImage: "exclamationmark.triangle.fill")
                                    .outlineButton()
                            }
                        }
                    }
                    .padding(18)
                } else {
                    EmptyState(title: "No job selected", subtitle: "Open a booking from dashboard.")
                        .padding(18)
                }
            }
        }
    }

    @ViewBuilder
    private func actionButton(for booking: PartnerBooking) -> some View {
        switch booking.status {
        case "accepted":
            Button("Mark as On The Way") { store.updateSelectedStatus("on_the_way") }.primaryButton()
        case "on_the_way":
            Button("Mark as Arrived") { store.updateSelectedStatus("arrived") }.primaryButton()
        case "arrived":
            Button("Start Service") { store.updateSelectedStatus("started") }.primaryButton()
        case "started":
            Button("Complete Service") { store.updateSelectedStatus("amount_pending") }.primaryButton()
        case "amount_pending":
            Button("Confirm Payment Received") { store.updateSelectedStatus("completed") }.primaryButton()
        default:
            Button("Refresh") { Task { await store.fetchBookings() } }.outlineButton()
        }
    }
}

struct PartnerBookingsScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "My Bookings", subtitle: "\(store.bookings.count) jobs", backAction: { store.screen = .dashboard }, trailingSystemImage: "arrow.clockwise") {
                Task { await store.fetchBookings() }
            }
            ScrollView {
                VStack(spacing: 12) {
                    if store.bookings.isEmpty {
                        EmptyState(title: "No bookings", subtitle: "Accepted and completed jobs will appear here.")
                    } else {
                        ForEach(store.bookings) { booking in
                            PartnerBookingCard(
                                booking: booking,
                                primaryTitle: "Open",
                                primaryAction: { store.openBooking(booking) },
                                secondaryTitle: booking.isActive ? "Map" : nil,
                                secondaryAction: booking.isActive ? { store.openMap(booking) } : nil
                            )
                        }
                    }
                }
                .padding(18)
            }
        }
    }
}

struct EarningsScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Earnings", subtitle: "Completed jobs", backAction: { store.screen = .dashboard })
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        StatTile(title: "Total", value: "Rs \(store.totalEarnings)", systemImage: "wallet.pass.fill", tint: AppTheme.purple)
                        StatTile(title: "Today", value: "Rs \(store.todayEarnings)", systemImage: "calendar", tint: AppTheme.rose)
                    }
                    HStack(spacing: 10) {
                        StatTile(title: "This Month", value: "Rs \(store.monthEarnings)", systemImage: "chart.bar.fill", tint: AppTheme.orange)
                        StatTile(title: "Jobs", value: "\(store.completedBookings.count)", systemImage: "checkmark.circle.fill", tint: AppTheme.green)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Download Statement")
                            .font(.headline.weight(.black))
                        TextField("From yyyy-mm-dd", text: $store.statementFrom)
                            .textFieldStyle(.roundedBorder)
                        TextField("To yyyy-mm-dd", text: $store.statementTo)
                            .textFieldStyle(.roundedBorder)
                        Button("Download PDF") {
                            store.downloadStatement()
                        }
                        .primaryButton()
                    }
                    .cardStyle()
                    ForEach(store.completedBookings) { booking in
                        PartnerBookingCard(booking: booking, primaryTitle: "Open") {
                            store.openBooking(booking)
                        }
                    }
                }
                .padding(18)
            }
        }
    }
}

struct PartnerMapScreen: View {
    @EnvironmentObject private var store: PartnerAppStore
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: AppConfig.defaultLatitude, longitude: AppConfig.defaultLongitude), span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Navigation", subtitle: store.selectedBooking?.address ?? "", backAction: { store.screen = .detail })
            if let booking = store.selectedBooking {
                Map(coordinateRegion: $region, annotationItems: [booking]) { item in
                    MapMarker(coordinate: CLLocationCoordinate2D(latitude: item.lat, longitude: item.lng), tint: .red)
                }
                .onAppear {
                    region.center = CLLocationCoordinate2D(latitude: booking.lat, longitude: booking.lng)
                }
                VStack(spacing: 10) {
                    Button("Let's Go") {
                        store.openAppleMaps(booking)
                    }
                    .primaryButton()
                    Button("Back to Order") {
                        store.screen = .detail
                    }
                    .outlineButton()
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

struct PartnerNotificationsScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Notifications", subtitle: "Booking requests and updates", backAction: { store.screen = .dashboard }, trailingSystemImage: "arrow.clockwise") {
                Task { await store.fetchNotifications() }
            }
            ScrollView {
                VStack(spacing: 12) {
                    if store.notifications.isEmpty {
                        EmptyState(title: "No notifications", subtitle: "FCM/APNs booking alerts will appear here.")
                    } else {
                        ForEach(store.notifications) { item in
                            Button {
                                store.markNotificationRead(item)
                                if let booking = store.bookings.first(where: { $0.id == item.bookingId || $0.bookingCode == item.bookingId }) {
                                    store.openBooking(booking)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(item.title).font(.headline.weight(.black))
                                        Spacer()
                                        if !item.isRead { Circle().fill(AppTheme.rose).frame(width: 9, height: 9) }
                                    }
                                    Text(item.body)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.muted)
                                }
                                .foregroundStyle(AppTheme.ink)
                                .cardStyle()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(18)
            }
        }
    }
}

struct PartnerProfileScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Profile", subtitle: store.profile.skillsLabel, backAction: { store.screen = .dashboard })
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.profile.name)
                            .font(.title3.weight(.black))
                        Text(store.profile.phone)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.muted)
                        Label(store.profile.faceVerified ? "Face verified" : "Verification pending", systemImage: store.profile.faceVerified ? "checkmark.shield.fill" : "shield")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(store.profile.faceVerified ? AppTheme.green : AppTheme.orange)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()

                    tool("Personal Information", "Name, phone and profile", "person.fill") { store.screen = .personalInfo }
                    tool("Documents", "ID proof and skill certificate", "folder.fill") { store.screen = .documents }
                    tool("My Services", "Services, radius and area", "slider.horizontal.3") { store.screen = .myServices }
                    tool("Support", "Chat, complaint, track issue", "headphones") { store.openSupport("Chat") }
                    tool("Settings", "Notifications and account", "gearshape.fill") { store.screen = .settings }
                    Button("Logout") { store.logout() }.outlineButton()
                }
                .padding(18)
            }
        }
    }

    private func tool(_ title: String, _ subtitle: String, _ image: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: image)
                    .foregroundStyle(AppTheme.rose)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.roseSoft, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.ink)
                    Text(subtitle).font(.caption).foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(AppTheme.muted)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

struct PersonalInfoScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Personal Information", subtitle: "Partner details", backAction: { store.screen = .profile })
            ScrollView {
                VStack(spacing: 14) {
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
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Backend Auth")
                            .font(.headline.weight(.black))
                        SecureField("Firebase ID token for API calls", text: $store.authToken)
                            .textFieldStyle(.roundedBorder)
                        Button("Save Token") {
                            store.saveAuthToken()
                        }
                        .outlineButton()
                        Text("In production, Firebase Auth will set this token automatically.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .cardStyle()
                }
                .padding(18)
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
            ScrollView {
                VStack(spacing: 14) {
                    documentRow("Aadhaar Card Front", "Upload clear Aadhaar image", status(for: "Aadhaar Card Front"))
                    documentRow("Aadhaar Card Back", "Upload clear Aadhaar image", status(for: "Aadhaar Card Back"))
                    documentRow("PAN Card", "Upload PAN card image", status(for: "PAN Card"))
                    documentRow("Selfie Verification", "Upload clear face photo", status(for: "Selfie Verification"))
                    documentRow("Skill Certificate", "Upload skill certificate", status(for: "Skill Certificate"))
                    documentRow("Training Certificate", "Upload training certificate", status(for: "Training Certificate"))
                    documentRow("Government License", "Upload license if applicable", status(for: "Government License"))
                    documentRow("Trade License", "Upload optional trade license", status(for: "Trade License"))
                    documentRow("Other Supporting Document", "Upload any supporting proof", status(for: "Other Supporting Document"))
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Aadhaar last 4")
                            .font(.headline.weight(.black))
                        TextField("1234", text: $store.aadhaarLast4)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                        Button("Submit Verification") {
                            store.submitVerification()
                        }
                        .primaryButton()
                        Text("Upload clear and valid verification documents. These files are used only for verification.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .cardStyle()
                }
                .padding(18)
            }
        }
        .fileImporter(
            isPresented: Binding(
                get: { importingDocumentType != nil },
                set: { if !$0 { importingDocumentType = nil } }
            ),
            allowedContentTypes: [.jpeg, .png],
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
        store.documentStatuses[documentType] ?? (documentType == "Skill Certificate" ? "Required" : "Pending")
    }

    private func documentRow(_ title: String, _ subtitle: String, _ status: String) -> some View {
        Button {
            importingDocumentType = title
        } label: {
            HStack(spacing: 12) {
                Image(systemName: status == "Uploaded" ? "checkmark.seal.fill" : "doc.fill")
                    .foregroundStyle(status == "Uploaded" ? AppTheme.green : AppTheme.rose)
                    .frame(width: 40, height: 40)
                    .background(status == "Uploaded" ? AppTheme.greenSoft : AppTheme.roseSoft, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Text(status)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(status == "Uploaded" ? AppTheme.green : AppTheme.orange)
            }
            .foregroundStyle(AppTheme.ink)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

struct MyServicesScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "My Services", subtitle: "Services and area", backAction: { store.screen = .profile })
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Selected Services")
                            .font(.headline.weight(.black))
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(PartnerSkill.allCases) { skill in
                                let selected = store.profile.skills.contains(skill)
                                Button(skill.label) {
                                    store.setSkill(skill, selected: !selected)
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(selected ? .white : AppTheme.ink)
                                .padding(.vertical, 9)
                                .frame(maxWidth: .infinity)
                                .background(selected ? AppTheme.rose : AppTheme.roseSoft, in: Capsule())
                            }
                        }
                    }
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Service Radius")
                            .font(.headline.weight(.black))
                        Picker("Radius", selection: $store.profile.serviceRadiusKm) {
                            ForEach([5, 10, 25, 50], id: \.self) { km in
                                Text("\(km) km").tag(km)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Service Area")
                            .font(.headline.weight(.black))
                        Picker("Area", selection: $store.profile.serviceArea) {
                            ForEach(["Guwahati", "Dispur", "Ganeshguri", "Zoo Road", "Six Mile"], id: \.self) { area in
                                Text(area).tag(area)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .cardStyle()

                    Button("Save Changes") {
                        store.persistProfile()
                        Task { await store.syncPartnerProfile() }
                    }
                    .primaryButton()
                }
                .padding(18)
            }
        }
    }
}

struct PartnerSettingsScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Settings", subtitle: "Account and notifications", backAction: { store.screen = .profile })
            ScrollView {
                VStack(spacing: 14) {
                    setting("Notifications", "Booking requests, cancellations and updates use APNs + Firebase Messaging.", "bell.fill") {
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
                .padding(18)
            }
        }
    }

    private func setting(_ title: String, _ subtitle: String, _ image: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: image)
                    .foregroundStyle(AppTheme.rose)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.roseSoft, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.ink)
                    Text(subtitle).font(.caption).foregroundStyle(AppTheme.muted)
                }
                Spacer()
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

struct PartnerLegalScreen: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Legal & Information", subtitle: "Partner terms", backAction: { store.screen = .settings })
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    legalCard("Privacy Policy", "ApnaServo stores profile, service area, verification, booking and payment information to operate the platform and send job updates.")
                    legalCard("Partner Terms & Conditions", "Partners must accept only eligible jobs, keep location updated during jobs, avoid direct off-platform payment disputes, and complete status updates honestly.")
                    legalCard("Account Deletion", "Deletion request is sent to backend for review. Pending bookings, statements and compliance records may be retained as required.")
                }
                .padding(18)
            }
        }
    }

    private func legalCard(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline.weight(.black))
            Text(body).font(.subheadline).foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
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
