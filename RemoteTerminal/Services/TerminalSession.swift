import Foundation

@MainActor
final class TerminalSession: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var errorMessage: String?

    let sshService: SSHService
    let connection: SSHConnection

    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case failed
    }

    init(connection: SSHConnection) {
        self.connection = connection
        self.sshService = SSHService()
    }

    func connect() async {
        guard connectionState != .connecting else { return }

        connectionState = .connecting
        errorMessage = nil

        let password: String
        if let saved = try? KeychainHelper.shared.getPassword(for: connection.id) {
            password = saved
        } else {
            connectionState = .failed
            errorMessage = "未找到保存的密码，请编辑连接重新输入"
            return
        }

        do {
            try await sshService.connect(
                host: connection.host,
                port: connection.port,
                username: connection.username,
                password: password
            )

            connectionState = .connected
            connection.lastConnectedAt = Date()
        } catch let error as SSHError {
            connectionState = .failed
            errorMessage = error.errorDescription
        } catch {
            connectionState = .failed
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() {
        sshService.disconnect()
        connectionState = .disconnected
    }

    func send(_ string: String) {
        sshService.write(string)
    }
}
