import Foundation
import SwiftTerm

@MainActor
final class TerminalSession: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var errorMessage: String?

    let terminal: Terminal
    let sshService: SSHService
    let connection: SSHConnection

    private var terminalDelegate: TerminalSessionDelegate?

    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case failed
    }

    init(connection: SSHConnection) {
        self.connection = connection
        self.terminal = Terminal(delegate: nil)
        self.sshService = SSHService()

        let delegate = TerminalSessionDelegate(session: self)
        self.terminalDelegate = delegate
        self.terminal.delegate = delegate

        setupSSHCallbacks()
    }

    private func setupSSHCallbacks() {
        sshService.onDataReceived = { [weak self] data in
            guard let self = self else { return }
            let bytes = [UInt8](data)
            self.terminal.feed(byteArray: bytes)
        }
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

            terminal.resize(cols: 80, rows: 24)
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

    func sendSpecialKey(_ key: SpecialKey) {
        sshService.sendSpecialKey(key)
    }

    func resize(cols: Int, rows: Int) {
        terminal.resize(cols: cols, rows: rows)
    }
}

private final class TerminalSessionDelegate: TerminalDelegate {
    weak var session: TerminalSession?

    init(session: TerminalSession) {
        self.session = session
    }

    func send(source: Terminal, data: ArraySlice<UInt8>) {
        let bytes = Array(data)
        let data = Data(bytes)
        Task { @MainActor in
            session?.sshService.write(data)
        }
    }

    func scrolled(source: Terminal, yDisp: Int) {}
    func setTerminalTitle(source: Terminal, title: String) {}
    func setTerminalIconTitle(source: Terminal, title: String) {}
    func sizeChanged(source: Terminal) {}
    func bell(source: Terminal) {}
    func isProcessTrusted(source: Terminal) -> Bool { true }
    func mouseModeChanged(source: Terminal) -> Bool { false }
    func hostCurrentDirectoryUpdate(source: Terminal, directory: String?) {}
    func colorChanged(source: Terminal, idx: Int) {}
    func clipboardCopy(source: Terminal, content: Data) {}
    func rangeChanged(source: Terminal, startY: Int, endY: Int) {}
    func linefeed(source: Terminal) {}
}
