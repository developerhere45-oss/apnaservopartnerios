import SwiftUI

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
    }
}

struct PartnerLoginView: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        ZStack {
            AndroidAssetImage(name: "partner_login_bg", contentMode: .fill)
                .ignoresSafeArea()
                .opacity(0.22)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    AndroidAssetImage(name: "apna_servo_logo")
                        .frame(width: 132, height: 70)
                    Text("ApnaServo Partner")
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(AppTheme.roseDark)
                    Text("Login Existing Partner")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                    Text("Go online, receive bookings, accept jobs, update service status and track earnings.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                }
                .padding(.top, 28)

                VStack(spacing: 12) {
                    TextField("Partner name", text: $store.profile.name)
                        .textContentType(.name)
                        .textFieldStyle(.roundedBorder)
                    TextField("Phone number", text: $store.profile.phone)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.roundedBorder)
                    TextField("Email optional", text: $store.profile.email)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)
                    skillGrid
                    Button("Continue") {
                        store.completeLogin()
                    }
                    .primaryButton()
                    Button {
                        store.infoMessage = "Google sign-in uses Firebase Auth when the Firebase and GoogleSignIn packages are added in Xcode."
                    } label: {
                        Label("Continue with Google", systemImage: "g.circle.fill")
                            .outlineButton()
                    }
                }
                .cardStyle()
            }
            .padding(18)
            }
        }
    }

    private var skillGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Services")
                .font(.headline.weight(.bold))
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
    }
}
