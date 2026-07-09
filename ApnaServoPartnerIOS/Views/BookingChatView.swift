import SwiftUI

struct BookingChatView: View {
    @EnvironmentObject private var store: PartnerAppStore
    @State private var text = ""

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                title: store.selectedBooking?.customerName ?? "Customer Chat",
                subtitle: store.selectedBooking?.displayId ?? "",
                backAction: { store.screen = .detail },
                trailingSystemImage: "arrow.clockwise"
            ) {
                Task { await store.loadBookingChat() }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        if store.messages.isEmpty {
                            EmptyState(title: "No chat yet", subtitle: "Send a booking message to the customer.")
                        }
                        ForEach(store.messages) { message in
                            ChatBubble(message: message, isMe: message.senderRole == "partner")
                                .id(message.id)
                        }
                    }
                    .padding(18)
                }
                .onChange(of: store.messages.count) { _ in
                    if let last = store.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            HStack(spacing: 10) {
                TextField("Message customer", text: $text)
                    .textFieldStyle(.roundedBorder)
                Button {
                    store.sendBookingChatMessage(text)
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
        .task {
            await store.loadBookingChat()
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    let isMe: Bool

    var body: some View {
        HStack {
            if isMe { Spacer(minLength: 42) }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                Text(message.senderName.isEmpty ? (isMe ? "You" : "Customer") : message.senderName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isMe ? .white.opacity(0.8) : AppTheme.muted)
                Text(message.message)
                    .font(.subheadline)
                    .foregroundStyle(isMe ? .white : AppTheme.ink)
                if !message.deliveryStatus.isEmpty {
                    Text(message.deliveryStatus)
                        .font(.caption2)
                        .foregroundStyle(isMe ? .white.opacity(0.7) : AppTheme.muted)
                }
            }
            .padding(12)
            .background(isMe ? AppTheme.roseDark : Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(isMe ? Color.clear : AppTheme.line, lineWidth: 1))
            if !isMe { Spacer(minLength: 42) }
        }
    }
}
