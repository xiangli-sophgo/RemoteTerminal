import Foundation
import SwiftData

enum AuthType: String, Codable {
    case password
    case publicKey
}

@Model
final class SSHConnection {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var authTypeRaw: String
    var createdAt: Date
    var lastConnectedAt: Date?

    var authType: AuthType {
        get { AuthType(rawValue: authTypeRaw) ?? .password }
        set { authTypeRaw = newValue.rawValue }
    }

    init(
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        authType: AuthType = .password
    ) {
        self.id = UUID()
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authTypeRaw = authType.rawValue
        self.createdAt = Date()
    }

    var displayName: String {
        name.isEmpty ? "\(username)@\(host)" : name
    }

    var connectionString: String {
        "\(username)@\(host):\(port)"
    }
}
