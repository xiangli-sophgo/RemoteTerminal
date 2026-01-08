import Foundation
import NMSSH

enum SSHError: LocalizedError {
    case connectionFailed(String)
    case authenticationFailed
    case channelOpenFailed
    case shellStartFailed
    case notConnected

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason):
            return "连接失败: \(reason)"
        case .authenticationFailed:
            return "认证失败，请检查用户名和密码"
        case .channelOpenFailed:
            return "无法打开通道"
        case .shellStartFailed:
            return "无法启动Shell"
        case .notConnected:
            return "未连接"
        }
    }
}

@MainActor
final class SSHService: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var isConnecting = false
    @Published var error: SSHError?

    private var session: NMSSHSession?
    private var channel: NMSSHChannel?
    private var readTask: Task<Void, Never>?

    var onDataReceived: ((Data) -> Void)?

    deinit {
        disconnect()
    }

    func connect(host: String, port: Int, username: String, password: String) async throws {
        guard !isConnecting else { return }

        isConnecting = true
        error = nil

        defer { isConnecting = false }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    let session = NMSSHSession(host: host, port: port, andUsername: username)

                    session?.connect()

                    guard let session = session, session.isConnected else {
                        throw SSHError.connectionFailed("无法连接到 \(host):\(port)")
                    }

                    session.authenticate(byPassword: password)

                    guard session.isAuthorized else {
                        session.disconnect()
                        throw SSHError.authenticationFailed
                    }

                    let channel = session.channel

                    guard let channel = channel else {
                        session.disconnect()
                        throw SSHError.channelOpenFailed
                    }

                    channel.requestPty = true
                    channel.ptyTerminalType = .xterm

                    do {
                        try channel.startShell()
                    } catch {
                        session.disconnect()
                        throw SSHError.shellStartFailed
                    }

                    DispatchQueue.main.async {
                        self?.session = session
                        self?.channel = channel
                        self?.isConnected = true
                        self?.startReadLoop()
                    }

                    continuation.resume()
                } catch let sshError as SSHError {
                    continuation.resume(throwing: sshError)
                } catch {
                    continuation.resume(throwing: SSHError.connectionFailed(error.localizedDescription))
                }
            }
        }
    }

    func disconnect() {
        readTask?.cancel()
        readTask = nil

        channel?.closeShell()
        channel = nil

        session?.disconnect()
        session = nil

        isConnected = false
    }

    func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        write(data)
    }

    func write(_ data: Data) {
        guard isConnected, let channel = channel else { return }

        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try channel.write(data)
            } catch {
                print("Write error: \(error)")
            }
        }
    }

    func sendSpecialKey(_ key: SpecialKey) {
        write(key.escapeSequence)
    }

    private func startReadLoop() {
        readTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                guard let self = self,
                      let channel = await self.channel else {
                    break
                }

                if let data = channel.read() {
                    await MainActor.run {
                        self.onDataReceived?(data)
                    }
                }

                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
    }
}

enum SpecialKey: String, CaseIterable {
    case escape = "Esc"
    case tab = "Tab"
    case ctrlC = "^C"
    case ctrlD = "^D"
    case ctrlZ = "^Z"
    case ctrlL = "^L"
    case up = "↑"
    case down = "↓"
    case left = "←"
    case right = "→"

    var escapeSequence: String {
        switch self {
        case .escape: return "\u{1B}"
        case .tab: return "\t"
        case .ctrlC: return "\u{03}"
        case .ctrlD: return "\u{04}"
        case .ctrlZ: return "\u{1A}"
        case .ctrlL: return "\u{0C}"
        case .up: return "\u{1B}[A"
        case .down: return "\u{1B}[B"
        case .left: return "\u{1B}[D"
        case .right: return "\u{1B}[C"
        }
    }
}
