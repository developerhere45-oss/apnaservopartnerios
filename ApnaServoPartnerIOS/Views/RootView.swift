import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            if store.loggedIn {
                PartnerAppView()
            } else {
                PartnerLoginView()
            }
        }
        .alert("ApnaServo Partner", isPresented: Binding(
            get: { !store.errorMessage.isEmpty },
            set: { if !$0 { store.errorMessage = "" } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = "" }
        } message: {
            Text(store.errorMessage)
        }
        .alert("Done", isPresented: Binding(
            get: { !store.infoMessage.isEmpty },
            set: { if !$0 { store.infoMessage = "" } }
        )) {
            Button("OK", role: .cancel) { store.infoMessage = "" }
        } message: {
            Text(store.infoMessage)
        }
        .task {
            await store.restoreFirebaseSession()
        }
    }
}

struct PartnerLoginView: View {
    @EnvironmentObject private var store: PartnerAppStore
    @State private var mode: AuthMode = .landing
    @State private var importingDocumentType: String?

    var body: some View {
        Group {
            switch mode {
            case .landing:
                landingScreen
            case .login:
                authForm(title: "Login Partner", subtitle: "Use your saved partner profile to go online.", buttonTitle: "Login Existing Partner")
            case .register:
                registerScreen
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
            if case .success = result {
                store.documentStatuses[documentType] = "Selected"
                store.infoMessage = "\(documentType) selected. Login ke baad Documents screen se upload ho jayega."
            }
        }
    }

    private var landingScreen: some View {
        ZStack(alignment: .bottom) {
            AndroidAssetImage(name: "partner_login_bg", contentMode: .fill)
                .ignoresSafeArea()
            LinearGradient(
                colors: [.clear, AppTheme.bg.opacity(0.22), AppTheme.bg.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 80)
                VStack(spacing: 10) {
                    Button {
                        mode = .login
                    } label: {
                        Label("Continue with Phone OTP", systemImage: "phone.badge.checkmark")
                            .outlineButton()
                    }

                    Button("Login Existing Partner") {
                        mode = .login
                    }
                    .primaryButton()

                    Button("Register New Partner") {
                        seedRegistrationDefaults()
                        mode = .register
                    }
                    .outlineButton()

                    #if DEBUG
                    Button("Skip to Home Screen") {
                        store.skipFirebaseForHomePreview()
                    }
                    .outlineButton()
                    #endif

                    Text("v1.0.0")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity)
                }
                .androidCard(cornerRadius: 22, padding: 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
    }

    private func authForm(title: String, subtitle: String, buttonTitle: String) -> some View {
        AndroidPage {
            AndroidAssetImage(name: "apna_servo_logo")
                .frame(width: 154, height: 58)
                .padding(.top, 6)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .safeText()
            }

            VStack(spacing: 12) {
                profilePhotoBlock(compact: true)
                authInput("Partner name", text: $store.profile.name, icon: "person.fill")
                authInput("Mobile number", text: $store.profile.phone, icon: "phone.fill", keyboard: .phonePad)
                authInput("Email address", text: $store.profile.email, icon: "envelope.fill", keyboard: .emailAddress)
                authInput("Service Area / Work", text: $store.profile.workingAreas, icon: "mappin.and.ellipse")
                SkillPickerGrid()
                firebaseAuthPanel
                Button(store.phoneVerificationSent ? "Verify OTP & Continue" : buttonTitle) {
                    store.completeLogin()
                }
                .primaryButton()
                .disabled(store.loading)
            }
            .androidCard(cornerRadius: 22, padding: 18)

            Button("Back") {
                mode = .landing
            }
            .outlineButton()

            #if DEBUG
            Button("Skip to Home Screen") {
                store.skipFirebaseForHomePreview()
            }
            .outlineButton()
            #endif
        }
    }

    private var registerScreen: some View {
        AndroidPage {
            AndroidAssetImage(name: "apna_servo_logo")
                .frame(width: 154, height: 56)

            VStack(spacing: 4) {
                Text("Register as a Partner")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.center)
                    .safeText()
                Text("Join ApnaServo and grow your business with us")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                profilePhotoBlock(compact: false)
                Text("Personal Information")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                authInput("Enter your full name", text: $store.profile.name, icon: "person.fill")
                authInput("Mobile Number", text: $store.profile.phone, icon: "phone.fill", keyboard: .phonePad)
                authInput("Email address", text: $store.profile.email, icon: "at", keyboard: .emailAddress)
                authInput("DD/MM/YYYY", text: $store.profile.dob, icon: "calendar")
                genderPicker
                authInput("City", text: $store.profile.city, icon: "location.fill")
                statePicker
                authInput("PIN Code", text: $store.profile.pinCode, icon: "number", keyboard: .numberPad)
                experienceField
                authInput("Service Area / Work", text: $store.profile.workingAreas, icon: "map.fill")
                authInput("Languages Known", text: $store.profile.languages, icon: "text.bubble.fill")

                Text("Upload Documents")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .padding(.top, 4)
                Text("At least one document is mandatory.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
                documentSelectionCards

                SkillPickerGrid()
                firebaseAuthPanel

                Button(store.phoneVerificationSent ? "Verify OTP & Register" : "Register    >") {
                    if store.profile.address.isEmpty {
                        store.profile.address = generatedAddress()
                    }
                    if store.profile.emergencyContactNumber.isEmpty {
                        store.profile.emergencyContactNumber = store.profile.phone
                    }
                    store.completeLogin()
                }
                .primaryButton()
                .disabled(store.loading)
            }
            .androidCard(cornerRadius: 22, padding: 18)

            Button("Login Existing Partner") {
                mode = .login
            }
            .outlineButton()

            #if DEBUG
            Button("Skip to Home Screen") {
                store.skipFirebaseForHomePreview()
            }
            .outlineButton()
            #endif
        }
    }

    private func profilePhotoBlock(compact: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [AppTheme.roseSoft, .white], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                AndroidAssetImage(name: "partner_mascot")
                    .padding(compact ? 12 : 18)
                    .clipShape(Circle())
            }
            .frame(width: compact ? 88 : 104, height: compact ? 88 : 104)
            .overlay(Circle().stroke(AppTheme.line, lineWidth: 1))

            Text(compact ? "Your saved profile photo will be used." : "Add a clear profile photo using the camera.")
                .font(.system(size: compact ? 12 : 13, weight: compact ? .bold : .regular))
                .foregroundStyle(compact ? AppTheme.muted : AppTheme.rose)
                .multilineTextAlignment(.center)

            if !compact {
                Button("Retake Photo") {
                    store.infoMessage = "Camera/photo capture can be wired with UIImagePickerController in Xcode build."
                }
                .outlineButton()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func authInput(_ placeholder: String, text: Binding<String>, icon: String, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 10) {
            Text(iconText(for: icon))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.rose)
                .frame(width: 34, height: 34)
                .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .autocorrectionDisabled(keyboard == .emailAddress || keyboard == .phonePad || keyboard == .numberPad)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 54)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 1)
        )
    }

    private var firebaseAuthPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Firebase Auth")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
            HStack(spacing: 10) {
                Text(store.phoneVerificationSent ? "OTP" : "FIR")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(store.hasBackendSession ? AppTheme.green : AppTheme.hotPink)
                    .frame(width: 34, height: 34)
                    .background(store.hasBackendSession ? AppTheme.greenSoft : AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                if store.phoneVerificationSent {
                    TextField("Enter Firebase OTP", text: $store.phoneOTP)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                } else {
                    Text(store.hasBackendSession ? "Firebase session connected" : "Phone OTP will verify backend login")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)
                        .safeText()
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 54)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            )
            Text(store.phoneVerificationSent ? "OTP verify hote hi backend token auto save hoga." : "Manual token paste nahi; Firebase Auth backend Bearer token generate karega.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.muted)
                .safeText()
        }
    }

    private var genderPicker: some View {
        Menu {
            ForEach(["Male", "Female", "Other"], id: \.self) { item in
                Button(item) { store.profile.gender = item }
            }
        } label: {
            fakeInput(title: store.profile.gender.isEmpty ? "Gender" : store.profile.gender, icon: "G", showsChevron: true)
        }
    }

    private var statePicker: some View {
        Menu {
            ForEach(["Assam", "Meghalaya", "West Bengal", "Bihar", "Delhi", "Other"], id: \.self) { item in
                Button(item) { store.profile.state = item }
            }
        } label: {
            fakeInput(title: store.profile.state.isEmpty ? "State" : store.profile.state, icon: "B", showsChevron: true)
        }
    }

    private var experienceField: some View {
        HStack(spacing: 10) {
            fakeInput(title: "Years of Experience: \(store.profile.yearsOfExperience)", icon: "W", showsChevron: false)
            Stepper("", value: $store.profile.yearsOfExperience, in: 0...80)
                .labelsHidden()
        }
    }

    private func fakeInput(title: String, icon: String, showsChevron: Bool) -> some View {
        HStack(spacing: 10) {
            Text(icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.rose)
                .frame(width: 34, height: 34)
                .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.rose)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 1)
        )
    }

    private var documentSelectionCards: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                registrationDocumentCard(
                    title: "Aadhaar / Passport /\nBirth Certificate",
                    status: store.documentStatuses["Aadhaar Card Front"] ?? "Required",
                    type: "Aadhaar Card Front",
                    required: true
                )
                registrationDocumentCard(
                    title: "Other Certificate (Optional)",
                    status: store.documentStatuses["Other Supporting Document"] ?? "Any relevant certificate",
                    type: "Other Supporting Document",
                    required: false
                )
            }
            VStack(spacing: 10) {
                registrationDocumentCard(
                    title: "Aadhaar / Passport /\nBirth Certificate",
                    status: store.documentStatuses["Aadhaar Card Front"] ?? "Required",
                    type: "Aadhaar Card Front",
                    required: true
                )
                registrationDocumentCard(
                    title: "Other Certificate (Optional)",
                    status: store.documentStatuses["Other Supporting Document"] ?? "Any relevant certificate",
                    type: "Other Supporting Document",
                    required: false
                )
            }
        }
    }

    private func registrationDocumentCard(title: String, status: String, type: String, required: Bool) -> some View {
        Button {
            importingDocumentType = type
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: required ? "doc.badge.plus" : "doc")
                        .foregroundStyle(AppTheme.rose)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.roseSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Spacer()
                    StatusPill(text: status, tint: required ? AppTheme.rose : AppTheme.muted, background: required ? AppTheme.roseSoft : Color(hex: 0xF6F6F6))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(3)
                    .safeText()
                Text("JPG, PNG or PDF (Max 5MB)")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.muted)
                    .safeText()
            }
            .androidCard(cornerRadius: 18, padding: 12)
        }
        .buttonStyle(.plain)
    }

    private func iconText(for systemName: String) -> String {
        switch systemName {
        case "person.fill": return "P"
        case "phone.fill": return "T"
        case "at", "envelope.fill": return "@"
        case "calendar": return "D"
        case "location.fill": return "L"
        case "number": return "#"
        case "map.fill", "mappin.and.ellipse": return "A"
        case "text.bubble.fill": return "O"
        default: return "P"
        }
    }

    private func seedRegistrationDefaults() {
        if store.profile.gender.isEmpty { store.profile.gender = "Male" }
        if store.profile.city.isEmpty { store.profile.city = "Guwahati" }
        if store.profile.state.isEmpty { store.profile.state = "Assam" }
        if store.profile.languages.isEmpty { store.profile.languages = "Hindi, English" }
        if store.profile.workingAreas.isEmpty { store.profile.workingAreas = store.profile.serviceArea }
    }

    private func generatedAddress() -> String {
        [store.profile.city, store.profile.state, store.profile.pinCode]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ", ")
    }
}

private enum AuthMode {
    case landing
    case login
    case register
}

struct SkillPickerGrid: View {
    @EnvironmentObject private var store: PartnerAppStore

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 96), spacing: 8)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select multiple services. Matching bookings will appear here in real time.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.muted)
                .safeText()
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(PartnerSkill.allCases) { skill in
                    let selected = store.profile.skills.contains(skill)
                    Button {
                        store.setSkill(skill, selected: !selected)
                    } label: {
                        Text(skill.label)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(selected ? .white : AppTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .padding(.horizontal, 8)
                            .background(
                                selected
                                    ? LinearGradient(colors: [AppTheme.rose, Color(hex: 0xDA4B58)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Color.white, Color.white], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(selected ? Color.clear : AppTheme.line, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
