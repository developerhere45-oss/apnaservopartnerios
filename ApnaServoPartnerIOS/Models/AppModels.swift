import Foundation

enum PartnerScreen: String {
    case login
    case dashboard
    case request
    case detail
    case bookings
    case earnings
    case map
    case notifications
    case profile
    case personalInfo
    case documents
    case myServices
    case settings
    case legal
    case support
    case bookingChat
}

enum PartnerSkill: String, CaseIterable, Identifiable, Codable {
    case ac
    case plumbing
    case electrician
    case carpenter
    case cleaning
    case painting
    case interior
    case roadside
    case appliances
    case pest
    case laundry
    case ro

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ac: return "AC Repair"
        case .plumbing: return "Plumber"
        case .electrician: return "Electrician"
        case .carpenter: return "Carpenter"
        case .cleaning: return "Cleaning"
        case .painting: return "Painting"
        case .interior: return "Interior"
        case .roadside: return "Roadside"
        case .appliances: return "Appliances"
        case .pest: return "Pest Control"
        case .laundry: return "Laundry"
        case .ro: return "RO Service"
        }
    }
}

struct PartnerProfile: Codable, Hashable {
    var name = ""
    var phone = ""
    var email = ""
    var dob = ""
    var gender = ""
    var address = ""
    var city = AppConfig.defaultCity
    var state = "Assam"
    var pinCode = ""
    var emergencyContactNumber = ""
    var yearsOfExperience = 0
    var workingAreas = ""
    var languages = ""
    var photoURL = ""
    var faceVerified = false
    var online = true
    var skills: Set<PartnerSkill> = [.ac]
    var serviceRadiusKm = 25
    var serviceArea = "Guwahati"
    var lat = AppConfig.defaultLatitude
    var lng = AppConfig.defaultLongitude

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        phone.filter(\.isNumber).count == 10 &&
        !skills.isEmpty
    }

    var skillsLabel: String {
        skills.sorted { $0.label < $1.label }.map(\.label).joined(separator: ", ")
    }
}

struct PartnerBooking: Identifiable, Codable, Hashable {
    var id: String
    var bookingCode: String
    var serviceCategory: String
    var serviceName: String
    var issue: String
    var customerName: String
    var customerPhone: String
    var address: String
    var city: String
    var slot: String
    var defaultAmount: Int
    var finalAmount: Int
    var status: String
    var lat: Double
    var lng: Double
    var quoteStatus: String
    var quoteCounterAmount: Int
    var quoteCounterMessage: String
    var createdAtMillis: Int64
    var completedAtMillis: Int64

    var displayId: String { bookingCode.isEmpty ? id : bookingCode }
    var amount: Int { finalAmount > 0 ? finalAmount : defaultAmount }
    var isPending: Bool { status == "pending" }
    var isActive: Bool { ["accepted", "on_the_way", "arrived", "started", "amount_pending"].contains(status) }
    var isFinished: Bool { ["completed", "cancelled", "rejected"].contains(status) }

    var statusLabel: String {
        switch status {
        case "pending": return "New Request"
        case "accepted": return "Accepted"
        case "on_the_way": return "On The Way"
        case "arrived": return "Arrived"
        case "started": return "Started"
        case "amount_pending": return "Amount Pending"
        case "completed": return "Completed"
        case "cancelled": return "Cancelled"
        case "rejected": return "Rejected"
        default: return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    init(
        id: String,
        bookingCode: String = "",
        serviceCategory: String = "service",
        serviceName: String,
        issue: String,
        customerName: String,
        customerPhone: String = "",
        address: String,
        city: String = AppConfig.defaultCity,
        slot: String,
        defaultAmount: Int = 0,
        finalAmount: Int = 0,
        status: String = "pending",
        lat: Double = AppConfig.defaultLatitude,
        lng: Double = AppConfig.defaultLongitude,
        quoteStatus: String = "none",
        quoteCounterAmount: Int = 0,
        quoteCounterMessage: String = "",
        createdAtMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        completedAtMillis: Int64 = 0
    ) {
        self.id = id
        self.bookingCode = bookingCode
        self.serviceCategory = serviceCategory
        self.serviceName = serviceName
        self.issue = issue
        self.customerName = customerName
        self.customerPhone = customerPhone
        self.address = address
        self.city = city
        self.slot = slot
        self.defaultAmount = defaultAmount
        self.finalAmount = finalAmount
        self.status = status
        self.lat = lat
        self.lng = lng
        self.quoteStatus = quoteStatus
        self.quoteCounterAmount = quoteCounterAmount
        self.quoteCounterMessage = quoteCounterMessage
        self.createdAtMillis = createdAtMillis
        self.completedAtMillis = completedAtMillis
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = c.string("_id", "bookingId", "id", fallback: UUID().uuidString)
        bookingCode = c.string("bookingCode", "code")
        serviceCategory = c.string("serviceCategory", "serviceType", fallback: "service")
        serviceName = c.string("serviceName", "service", fallback: PartnerSkill(rawValue: serviceCategory)?.label ?? "Service")
        issue = c.string("issue", "problem", fallback: "Service request")
        customerName = c.string("customerName", "userName", "name", fallback: "Customer")
        customerPhone = c.string("customerPhone", "userPhone", "phone")
        address = c.string("address", "location", fallback: "Customer address")
        city = c.string("city", fallback: AppConfig.defaultCity)
        slot = c.string("slot", "time", fallback: "Slot pending")
        defaultAmount = c.int("defaultAmount", "price")
        finalAmount = c.int("finalAmount")
        status = c.string("status", fallback: "pending")
        lat = c.double("lat", fallback: AppConfig.defaultLatitude)
        lng = c.double("lng", fallback: AppConfig.defaultLongitude)
        quoteStatus = c.string("quoteStatus", fallback: "none")
        quoteCounterAmount = c.int("quoteCounterAmount")
        quoteCounterMessage = c.string("quoteCounterMessage")
        createdAtMillis = c.int64("createdAtMillis", "createdAt", fallback: Int64(Date().timeIntervalSince1970 * 1000))
        completedAtMillis = c.int64("completedAtMillis", "completedAt")
    }
}

struct ChatMessage: Identifiable, Codable, Hashable {
    var id: String
    var bookingId: String
    var bookingCode: String
    var senderRole: String
    var senderName: String
    var message: String
    var clientMessageId: String
    var deliveryStatus: String
    var createdAtMillis: Int64

    static func local(text: String, booking: PartnerBooking) -> ChatMessage {
        ChatMessage(
            id: "local-\(UUID().uuidString)",
            bookingId: booking.id,
            bookingCode: booking.bookingCode,
            senderRole: "partner",
            senderName: "You",
            message: text,
            clientMessageId: "IOSPARTNER\(Int(Date().timeIntervalSince1970 * 1000))",
            deliveryStatus: "queued",
            createdAtMillis: Int64(Date().timeIntervalSince1970 * 1000)
        )
    }
}

struct PartnerNotificationItem: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var body: String
    var type: String
    var bookingId: String
    var bookingCode: String
    var isRead: Bool

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = c.string("_id", "id", fallback: UUID().uuidString)
        title = c.string("title", fallback: "ApnaServo Partner")
        body = c.string("body", "message", fallback: "Booking update received")
        type = c.string("type")
        bookingId = c.string("bookingId")
        bookingCode = c.string("bookingCode")
        isRead = c.bool("read", "isRead") || !c.string("readAt").isEmpty
    }

    init(id: String, title: String, body: String, type: String, bookingId: String, isRead: Bool) {
        self.id = id
        self.title = title
        self.body = body
        self.type = type
        self.bookingId = bookingId
        self.bookingCode = ""
        self.isRead = isRead
    }
}

struct PartnerProfileEnvelope: Decodable {
    let partner: PartnerProfileDTO?
}

struct PartnerProfileDTO: Decodable {
    let name: String?
    let phone: String?
    let email: String?
    let dob: String?
    let gender: String?
    let address: String?
    let city: String?
    let state: String?
    let pinCode: String?
    let emergencyContactNumber: String?
    let yearsOfExperience: Int?
    let workingAreas: String?
    let languages: String?
    let serviceCategory: [String]?
    let isOnline: Bool?
    let serviceRadiusKm: Int?
    let serviceArea: String?
    let photoUrl: String?
    let faceVerified: Bool?

    func toProfile(fallback: PartnerProfile) -> PartnerProfile {
        var profile = fallback
        profile.name = name ?? profile.name
        profile.phone = phone ?? profile.phone
        profile.email = email ?? profile.email
        profile.dob = dob ?? profile.dob
        profile.gender = gender ?? profile.gender
        profile.address = address ?? profile.address
        profile.city = city ?? profile.city
        profile.state = state ?? profile.state
        profile.pinCode = pinCode ?? profile.pinCode
        profile.emergencyContactNumber = emergencyContactNumber ?? profile.emergencyContactNumber
        profile.yearsOfExperience = yearsOfExperience ?? profile.yearsOfExperience
        profile.workingAreas = workingAreas ?? profile.workingAreas
        profile.languages = languages ?? profile.languages
        profile.skills = Set((serviceCategory ?? []).compactMap(PartnerSkill.init(rawValue:)))
        if profile.skills.isEmpty { profile.skills = fallback.skills }
        profile.online = isOnline ?? profile.online
        profile.serviceRadiusKm = serviceRadiusKm ?? profile.serviceRadiusKm
        profile.serviceArea = serviceArea ?? profile.serviceArea
        profile.photoURL = photoUrl ?? profile.photoURL
        profile.faceVerified = faceVerified ?? profile.faceVerified
        return profile
    }
}

struct BookingEnvelope: Decodable {
    let booking: PartnerBooking?
    let bookings: [PartnerBooking]?
}

struct NotificationsEnvelope: Decodable {
    let notifications: [PartnerNotificationItem]?
}

struct ChatEnvelope: Decodable {
    let messages: [ChatMessage]
}

struct SendChatEnvelope: Decodable {
    let message: ChatMessage?
}

struct EmptyResponse: Decodable {}

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

extension KeyedDecodingContainer where Key == DynamicCodingKey {
    func string(_ keys: String..., fallback: String = "") -> String {
        for key in keys {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            if let value = try? decodeIfPresent(String.self, forKey: codingKey), !value.isEmpty {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: codingKey) {
                return String(value)
            }
        }
        return fallback
    }

    func int(_ keys: String..., fallback: Int = 0) -> Int {
        for key in keys {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            if let value = try? decodeIfPresent(Int.self, forKey: codingKey) { return value }
            if let value = try? decodeIfPresent(Double.self, forKey: codingKey) { return Int(value) }
            if let value = try? decodeIfPresent(String.self, forKey: codingKey), let parsed = Int(value) { return parsed }
        }
        return fallback
    }

    func int64(_ keys: String..., fallback: Int64 = 0) -> Int64 {
        for key in keys {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            if let value = try? decodeIfPresent(Int64.self, forKey: codingKey) { return value }
            if let value = try? decodeIfPresent(Int.self, forKey: codingKey) { return Int64(value) }
            if let value = try? decodeIfPresent(String.self, forKey: codingKey), let parsed = Int64(value) { return parsed }
        }
        return fallback
    }

    func double(_ keys: String..., fallback: Double = 0) -> Double {
        for key in keys {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            if let value = try? decodeIfPresent(Double.self, forKey: codingKey) { return value }
            if let value = try? decodeIfPresent(String.self, forKey: codingKey), let parsed = Double(value) { return parsed }
        }
        return fallback
    }

    func bool(_ keys: String..., fallback: Bool = false) -> Bool {
        for key in keys {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            if let value = try? decodeIfPresent(Bool.self, forKey: codingKey) { return value }
        }
        return fallback
    }
}
