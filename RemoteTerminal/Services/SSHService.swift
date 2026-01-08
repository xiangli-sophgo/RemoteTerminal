import Foundation
import NIOCore
import NIOPosix
import NIOSSH

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

    private var group: MultiThreadedEventLoopGroup?
    private var channel: Channel?
    private var sshChannel: Channel?

    var onDataReceived: ((Data) -> Void)?

    func connect(host: String, port: Int, username: String, password: String) async throws {
        guard !isConnecting else { return }

        isConnecting = true
        error = nil

        defer {
            Task { @MainActor in
                self.isConnecting = false
            }
        }

        print("[SSH] 开始连接 \(host):\(port) 用户: \(username)")

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.group = group

        do {
            let bootstrap = ClientBootstrap(group: group)
                .channelInitializer { channel in
                    let clientHandler = SSHClientHandler(
                        username: username,
                        password: password,
                        onData: { [weak self] data in
                            Task { @MainActor in
                                self?.onDataReceived?(data)
                            }
                        },
                        onConnected: { [weak self] sshChannel in
                            Task { @MainActor in
                                self?.sshChannel = sshChannel
                                self?.isConnected = true
                                print("[SSH] 连接成功!")
                            }
                        },
                        onDisconnected: { [weak self] in
                            Task { @MainActor in
                                self?.isConnected = false
                                print("[SSH] 连接断开")
                            }
                        }
                    )
                    return channel.pipeline.addHandlers([
                        NIOSSHHandler(
                            role: .client(.init(
                                userAuthDelegate: clientHandler,
                                serverAuthDelegate: AcceptAllHostKeysDelegate()
                            )),
                            allocator: channel.allocator,
                            inboundChildChannelInitializer: nil
                        ),
                        clientHandler
                    ])
                }
                .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .connectTimeout(.seconds(10))

            print("[SSH] 正在建立连接...")
            let channel = try await bootstrap.connect(host: host, port: port).get()
            self.channel = channel
            print("[SSH] TCP 连接已建立，等待 SSH 握手...")

            // Wait for connection to be established
            try await Task.sleep(nanoseconds: 500_000_000)

            if !isConnected {
                // Wait a bit more for SSH handshake
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }

            if !isConnected {
                throw SSHError.connectionFailed("SSH 握手超时")
            }

        } catch let sshError as SSHError {
            print("[SSH] 错误: \(sshError.errorDescription ?? "未知")")
            throw sshError
        } catch {
            print("[SSH] 错误: \(error)")
            throw SSHError.connectionFailed(error.localizedDescription)
        }
    }

    func disconnect() {
        channel?.close(mode: .all, promise: nil)
        channel = nil
        sshChannel = nil

        try? group?.syncShutdownGracefully()
        group = nil

        isConnected = false
    }

    func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        write(data)
    }

    func write(_ data: Data) {
        guard isConnected, let channel = sshChannel else { return }

        let buffer = channel.allocator.buffer(bytes: data)
        let dataPayload = SSHChannelData(type: .channel, data: .byteBuffer(buffer))
        channel.writeAndFlush(dataPayload, promise: nil)
    }


    func sendWindowChange(cols: Int, rows: Int) {
        guard let channel = sshChannel else { return }

        let windowChange = SSHChannelRequestEvent.WindowChangeRequest(
            terminalCharacterWidth: cols,
            terminalRowHeight: rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0
        )
        channel.triggerUserOutboundEvent(windowChange, promise: nil)
        print("[SSH] 发送窗口大小变更: \(cols)x\(rows)")
    }
}

// MARK: - SSH Client Handler

final class SSHClientHandler: ChannelInboundHandler {
    typealias InboundIn = Any

    private let username: String
    private let password: String
    private let onData: (Data) -> Void
    private let onConnected: (Channel) -> Void
    private let onDisconnected: () -> Void
    private var hasRequestedShell = false

    init(
        username: String,
        password: String,
        onData: @escaping (Data) -> Void,
        onConnected: @escaping (Channel) -> Void,
        onDisconnected: @escaping () -> Void
    ) {
        self.username = username
        self.password = password
        self.onData = onData
        self.onConnected = onConnected
        self.onDisconnected = onDisconnected
    }

    func handlerAdded(context: ChannelHandlerContext) {
        print("[SSH] Handler added")
    }

    func channelActive(context: ChannelHandlerContext) {
        print("[SSH] Channel active")
    }

    func channelInactive(context: ChannelHandlerContext) {
        print("[SSH] Channel inactive")
        onDisconnected()
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        switch event {
        case let status as UserAuthSuccessEvent:
            print("[SSH] 认证成功")
            openShellChannel(context: context)

        case is ChannelSuccessEvent:
            print("[SSH] Shell 通道已打开")
            onConnected(context.channel)

        default:
            context.fireUserInboundEventTriggered(event)
        }
    }

    private func openShellChannel(context: ChannelHandlerContext) {
        guard !hasRequestedShell else { return }
        hasRequestedShell = true

        print("[SSH] 正在请求 Shell...")

        let createChannel = context.channel.pipeline.handler(type: NIOSSHHandler.self).flatMap { handler in
            let promise = context.eventLoop.makePromise(of: Channel.self)
            handler.createChannel(promise) { childChannel, channelType in
                guard channelType == .session else {
                    return context.eventLoop.makeFailedFuture(SSHError.channelOpenFailed)
                }
                return childChannel.pipeline.addHandlers([
                    ShellDataHandler(
                        onData: self.onData,
                        onConnected: self.onConnected
                    )
                ])
            }
            return promise.futureResult
        }

        createChannel.whenSuccess { channel in
            print("[SSH] Shell 通道创建成功")
            // Request PTY and shell
            let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
                wantReply: true,
                term: "xterm-256color",
                terminalCharacterWidth: 80,
                terminalRowHeight: 24,
                terminalPixelWidth: 0,
                terminalPixelHeight: 0,
                terminalModes: .init([:])
            )
            channel.triggerUserOutboundEvent(ptyRequest, promise: nil)

            let shellRequest = SSHChannelRequestEvent.ShellRequest(wantReply: true)
            channel.triggerUserOutboundEvent(shellRequest, promise: nil)
        }

        createChannel.whenFailure { error in
            print("[SSH] Shell 通道创建失败: \(error)")
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("[SSH] 错误: \(error)")
        context.close(promise: nil)
    }
}

extension SSHClientHandler: NIOSSHClientUserAuthenticationDelegate {
    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        print("[SSH] 可用认证方法: \(availableMethods)")

        if availableMethods.contains(.password) {
            print("[SSH] 使用密码认证")
            nextChallengePromise.succeed(.init(
                username: username,
                serviceName: "",
                offer: .password(.init(password: password))
            ))
        } else {
            print("[SSH] 没有可用的认证方法")
            nextChallengePromise.succeed(nil)
        }
    }
}

// MARK: - Shell Data Handler

final class ShellDataHandler: ChannelInboundHandler {
    typealias InboundIn = SSHChannelData

    private let onData: (Data) -> Void
    private let onConnected: (Channel) -> Void

    init(onData: @escaping (Data) -> Void, onConnected: @escaping (Channel) -> Void) {
        self.onData = onData
        self.onConnected = onConnected
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let channelData = self.unwrapInboundIn(data)

        switch channelData.data {
        case .byteBuffer(let buffer):
            if let bytes = buffer.getBytes(at: buffer.readerIndex, length: buffer.readableBytes) {
                let receivedData = Data(bytes)
                onData(receivedData)
            }
        case .fileRegion:
            break
        }
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if event is ChannelSuccessEvent {
            print("[SSH] Shell 已启动")
            onConnected(context.channel)
        }
        context.fireUserInboundEventTriggered(event)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("[SSH] Shell 错误: \(error)")
    }
}

// MARK: - Accept All Host Keys (for simplicity)

final class AcceptAllHostKeysDelegate: NIOSSHClientServerAuthenticationDelegate {
    func validateHostKey(
        hostKey: NIOSSHPublicKey,
        validationCompletePromise: EventLoopPromise<Void>
    ) {
        print("[SSH] 接受主机密钥: \(hostKey)")
        validationCompletePromise.succeed(())
    }
}

