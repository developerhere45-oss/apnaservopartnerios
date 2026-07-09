import SwiftUI
import UIKit

enum AppTheme {
    static let bg = Color(hex: 0xFFF7F5)
    static let bgLight = Color(hex: 0xFFF9F8)
    static let card = Color.white
    static let ink = Color(hex: 0x201C1C)
    static let textBlue = Color(hex: 0x172333)
    static let muted = Color(hex: 0x696060)
    static let rose = Color(hex: 0xEF4D70)
    static let hotPink = Color(hex: 0xF92F68)
    static let roseDark = Color(hex: 0x911243)
    static let roseSoft = Color(hex: 0xFFE9ED)
    static let line = Color(hex: 0xF1E2E0)
    static let green = Color(hex: 0x2B9953)
    static let greenSoft = Color(hex: 0xE7F9ED)
    static let blue = Color(hex: 0x2D7ADA)
    static let blueSoft = Color(hex: 0xEDEFFF)
    static let orange = Color(hex: 0xF19D23)
    static let orangeSoft = Color(hex: 0xFFF4E2)
    static let purple = Color(hex: 0xA754DD)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

extension View {
    func androidCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color(hex: 0xF6DDE3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 13, x: 0, y: 7)
    }

    func cardStyle(padding: CGFloat = 16) -> some View {
        androidCard(padding: padding)
    }

    func primaryButton() -> some View {
        self
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                LinearGradient(colors: [AppTheme.rose, AppTheme.roseDark], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: AppTheme.rose.opacity(0.22), radius: 8, x: 0, y: 5)
    }

    func greenButton() -> some View {
        self
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                LinearGradient(colors: [Color(hex: 0x0DB85B), Color(hex: 0x009A4B)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
    }

    func darkButton() -> some View {
        self
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(AppTheme.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    func outlineButton() -> some View {
        self
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(AppTheme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            )
    }

    func safeText() -> some View {
        fixedSize(horizontal: false, vertical: true)
    }
}

struct AndroidPage<Content: View>: View {
    var showsTopPadding = true
    let content: Content

    init(showsTopPadding: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsTopPadding = showsTopPadding
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, 18)
            .padding(.top, showsTopPadding ? 12 : 0)
            .padding(.bottom, 22)
        }
        .background(AppTheme.bg.ignoresSafeArea())
    }
}

struct TopBar: View {
    let title: String
    var subtitle = ""
    var backAction: (() -> Void)?
    var trailingSystemImage: String?
    var trailingAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            if let backAction {
                RoundIconButton(systemImage: "chevron.left", action: backAction)
                    .frame(width: 46, height: 46)
            } else {
                Color.clear.frame(width: 46, height: 46)
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.82)
                }
            }
            .frame(maxWidth: .infinity)

            if let trailingSystemImage, let trailingAction {
                RoundIconButton(systemImage: trailingSystemImage, action: trailingAction)
                    .frame(width: 46, height: 46)
            } else {
                Color.clear.frame(width: 46, height: 46)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(AppTheme.bg)
    }
}

struct AndroidCenteredHeader: View {
    let title: String
    let subtitle: String
    var leadingSystemImage = "line.3.horizontal"
    var trailingSystemImage: String?
    var badgeCount = 0
    var leadingAction: (() -> Void)?
    var trailingAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            RoundIconButton(systemImage: leadingSystemImage) {
                leadingAction?()
            }
            .frame(width: 48, height: 50)

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(AppTheme.textBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .safeText()
            }
            .frame(maxWidth: .infinity)

            if let trailingSystemImage {
                ZStack(alignment: .topTrailing) {
                    RoundIconButton(systemImage: trailingSystemImage) {
                        trailingAction?()
                    }
                    .frame(width: 48, height: 50)
                    if badgeCount > 0 {
                        Text("\(min(badgeCount, 99))")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(AppTheme.rose, in: Capsule())
                            .offset(x: 3, y: -4)
                    }
                }
            } else {
                Color.clear.frame(width: 48, height: 50)
            }
        }
    }
}

struct RoundIconButton: View {
    let systemImage: String
    var tint: Color = AppTheme.rose
    var background: Color = Color.white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .safeText()
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.rose)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct StatusPill: View {
    let text: String
    var tint: Color = AppTheme.rose
    var background: Color = AppTheme.roseSoft

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(background, in: Capsule())
    }
}

struct ServiceBadge: View {
    let title: String
    var size: CGFloat = 58

    var body: some View {
        Text(short)
            .font(.system(size: size > 50 ? 16 : 13, weight: .black))
            .foregroundStyle(accent)
            .frame(width: size, height: size)
            .background(bg, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    }

    private var short: String {
        let value = title.lowercased()
        if value.contains("laundry") { return "LD" }
        if value.contains("ro") { return "RO" }
        if value.contains("ac") { return "AC" }
        if value.contains("plumb") { return "PL" }
        if value.contains("electric") { return "EL" }
        if value.contains("clean") { return "CL" }
        if value.contains("paint") { return "PT" }
        return String(title.prefix(2)).uppercased()
    }

    private var accent: Color {
        let value = title.lowercased()
        if value.contains("ro") { return AppTheme.blue }
        if value.contains("laundry") { return AppTheme.purple }
        if value.contains("clean") { return AppTheme.green }
        return AppTheme.rose
    }

    private var bg: Color {
        let value = title.lowercased()
        if value.contains("ro") { return AppTheme.blueSoft }
        if value.contains("laundry") { return Color(hex: 0xF5E9FF) }
        if value.contains("clean") { return AppTheme.greenSoft }
        return AppTheme.roseSoft
    }
}

struct PartnerBookingCard: View {
    let booking: PartnerBooking
    var primaryTitle = "Open"
    let primaryAction: () -> Void
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        Button(action: primaryAction) {
            HStack(alignment: .center, spacing: 12) {
                ServiceBadge(title: booking.serviceName)

                VStack(alignment: .leading, spacing: 5) {
                    Text(booking.serviceName)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)
                        .safeText()
                    Text(booking.issue.isEmpty ? "Customer requested inspection" : booking.issue)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)
                        .safeText()
                    Text("\(booking.city) | \(booking.slot)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)
                    Text(booking.displayId)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 8) {
                    StatusPill(text: booking.statusLabel, tint: pillTint, background: pillBg)
                    Text(amountText)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(primaryTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.rose)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(Color.white, in: Capsule())
                        .overlay(Capsule().stroke(Color(hex: 0xF4B9BE), lineWidth: 1))
                    if let secondaryTitle, let secondaryAction {
                        Button(secondaryTitle, action: secondaryAction)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.ink)
                    }
                }
                .frame(minWidth: 82, alignment: .trailing)
            }
            .androidCard(cornerRadius: 20, padding: 12)
        }
        .buttonStyle(.plain)
    }

    private var amountText: String {
        booking.amount > 0 ? "Rs \(booking.amount)" : "Quote"
    }

    private var pillTint: Color {
        booking.status == "completed" ? AppTheme.green : booking.isActive ? AppTheme.green : AppTheme.roseDark
    }

    private var pillBg: Color {
        booking.status == "completed" || booking.isActive ? AppTheme.greenSoft : AppTheme.roseSoft
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.muted)
                .lineLimit(2)
                .safeText()
        }
        .androidCard(cornerRadius: 16, padding: 12)
    }
}

struct PartnerBottomNav: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        HStack(spacing: 0) {
            nav("Home", "house.fill", .dashboard)
            nav("Bookings", "calendar", .bookings)
            nav("Earnings", "wallet.pass.fill", .earnings)
            nav("Profile", "person.fill", .profile)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color(hex: 0xF2D9DE), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
    }

    private func nav(_ title: String, _ image: String, _ screen: PartnerScreen) -> some View {
        Button {
            store.screen = screen
        } label: {
            VStack(spacing: 4) {
                Image(systemName: image)
                    .font(.system(size: 22, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(isActive(screen) ? AppTheme.hotPink : Color(hex: 0x858585))
            .frame(maxWidth: .infinity, minHeight: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func isActive(_ item: PartnerScreen) -> Bool {
        switch (item, store.screen) {
        case (.dashboard, .dashboard),
             (.bookings, .bookings),
             (.earnings, .earnings):
            return true
        case (.profile, .profile),
             (.profile, .personalInfo),
             (.profile, .documents),
             (.profile, .myServices),
             (.profile, .settings),
             (.profile, .legal),
             (.profile, .support):
            return true
        default:
            return false
        }
    }
}

struct EmptyState: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(AppTheme.rose)
            Text(title)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.center)
                .safeText()
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
                .safeText()
        }
        .frame(maxWidth: .infinity)
        .androidCard()
    }
}

struct AndroidAssetImage: View {
    let name: String
    var extensionName = "png"
    var contentMode: ContentMode = .fit

    var body: some View {
        if let url = Bundle.main.url(forResource: name, withExtension: extensionName, subdirectory: "ImportedAndroidAssets"),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            Color.clear
        }
    }
}
