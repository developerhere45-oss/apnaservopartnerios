import SwiftUI
import UIKit

enum AppTheme {
    static let bg = Color(hex: 0xFFF7F5)
    static let card = Color.white
    static let ink = Color(hex: 0x201C1C)
    static let muted = Color(hex: 0x696060)
    static let rose = Color(hex: 0xEF4D70)
    static let roseDark = Color(hex: 0x911243)
    static let roseSoft = Color(hex: 0xFFE9ED)
    static let line = Color(hex: 0xF1E2E0)
    static let green = Color(hex: 0x2B9953)
    static let greenSoft = Color(hex: 0xE7F9ED)
    static let blue = Color(hex: 0x2D7ADA)
    static let orange = Color(hex: 0xF19D23)
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
    func cardStyle(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
    }

    func primaryButton() -> some View {
        self
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.rose, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    func darkButton() -> some View {
        self
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    func outlineButton() -> some View {
        self
            .font(.subheadline.weight(.bold))
            .foregroundStyle(AppTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
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
                Button(action: backAction) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 36, height: 36)
                        .background(Color.white, in: Circle())
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(AppTheme.ink)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            Spacer()
            if let trailingSystemImage, let trailingAction {
                Button(action: trailingAction) {
                    Image(systemName: trailingSystemImage)
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 38, height: 38)
                        .background(Color.white, in: Circle())
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.headline.weight(.black))
                .foregroundStyle(AppTheme.ink)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.rose)
            }
        }
    }
}

struct PartnerBookingCard: View {
    let booking: PartnerBooking
    var primaryTitle = "Open"
    let primaryAction: () -> Void
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.serviceName)
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppTheme.ink)
                    Text(booking.displayId)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Text(booking.statusLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(booking.status == "completed" ? AppTheme.green : AppTheme.rose)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(booking.status == "completed" ? AppTheme.greenSoft : AppTheme.roseSoft, in: Capsule())
            }
            Text(booking.issue)
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .lineLimit(2)
            Label("\(booking.customerName) - \(booking.city)", systemImage: "person.fill")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
            Label(booking.slot, systemImage: "clock.fill")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
            HStack {
                Button(primaryTitle, action: primaryAction)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(AppTheme.rose, in: Capsule())
                if let secondaryTitle, let secondaryAction {
                    Button(secondaryTitle, action: secondaryAction)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AppTheme.roseSoft, in: Capsule())
                }
                Spacer()
                if booking.amount > 0 {
                    Text("Rs \(booking.amount)")
                        .font(.subheadline.weight(.black))
                }
            }
        }
        .cardStyle()
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: Circle())
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(AppTheme.ink)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 12)
    }
}

struct PartnerBottomNav: View {
    @EnvironmentObject private var store: PartnerAppStore

    var body: some View {
        HStack {
            nav("Home", "house.fill", .dashboard)
            nav("Bookings", "briefcase.fill", .bookings)
            nav("Earnings", "wallet.pass.fill", .earnings)
            nav("Profile", "person.fill", .profile)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white)
        .overlay(Rectangle().fill(AppTheme.line).frame(height: 1), alignment: .top)
    }

    private func nav(_ title: String, _ image: String, _ screen: PartnerScreen) -> some View {
        Button {
            store.screen = screen
        } label: {
            VStack(spacing: 4) {
                Image(systemName: image)
                Text(title).font(.caption2.weight(.semibold))
            }
            .foregroundStyle(store.screen == screen ? AppTheme.rose : AppTheme.muted)
            .frame(maxWidth: .infinity)
        }
    }
}

struct EmptyState: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title)
                .foregroundStyle(AppTheme.rose)
            Text(title)
                .font(.headline.weight(.black))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
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
