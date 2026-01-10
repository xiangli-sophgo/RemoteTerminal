import SwiftUI
import WebKit

struct TerminalContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: TerminalSession
    @State private var webView: WKWebView?
    @State private var isTerminalReady = false

    init(connection: SSHConnection) {
        _session = StateObject(wrappedValue: TerminalSession(connection: connection))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                terminalContent

                SpecialKeysBar(
                    onKeyPress: { escapeSequence in
                        session.sshService.write(escapeSequence)
                    }
                )
            }
            .navigationTitle(session.connection.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("断开") {
                        session.disconnect()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    connectionStatusIndicator
                }
            }
            .task {
                await session.connect()
            }
            .onDisappear {
                session.disconnect()
            }
            .alert("tmux 未安装", isPresented: $session.showTmuxNotInstalledAlert) {
                Button("知道了", role: .cancel) { }
            } message: {
                Text("服务器未安装 tmux，无法使用会话恢复功能。\n\n安装命令:\n• Debian/Ubuntu: apt install tmux\n• CentOS/RHEL: yum install tmux\n• macOS: brew install tmux")
            }
            .sheet(isPresented: $session.showTmuxSessionPicker) {
                TmuxSessionPickerView(
                    sessions: session.tmuxSessions,
                    defaultSessionName: session.connection.effectiveTmuxSessionName,
                    onSelect: { action in
                        session.executeTmuxAction(action)
                    },
                    onCancel: {
                        session.skipTmuxSession()
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    @ViewBuilder
    private var terminalContent: some View {
        switch session.connectionState {
        case .disconnected, .connecting:
            connectingView

        case .connected:
            XtermWebView(
                onInput: { input in
                    session.sshService.write(input)
                },
                onSizeChange: { cols, rows in
                    session.sshService.sendWindowChange(cols: cols, rows: rows)
                },
                onReady: {
                    isTerminalReady = true
                    setupDataReceiver()
                },
                webViewRef: $webView
            )
            .background(Color(red: 0.118, green: 0.118, blue: 0.118))

        case .failed:
            failedView
        }
    }

    private func setupDataReceiver() {
        session.sshService.onDataReceived = { [self] data in
            DispatchQueue.main.async {
                webView?.writeDataToTerminal(data)
                // 检测 tmux 安装状态
                session.handleReceivedData(data)
            }
        }

        // 数据接收器设置完成后，通知 session 终端已准备就绪
        session.onTerminalReady()
    }

    private var connectingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在连接 \(session.connection.host)...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.118, green: 0.118, blue: 0.118))
    }

    private var failedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)

            Text("连接失败")
                .font(.headline)

            if let error = session.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("重试") {
                Task {
                    await session.connect()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.118, green: 0.118, blue: 0.118))
    }

    private var connectionStatusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
        }
    }

    private var statusColor: Color {
        switch session.connectionState {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .failed: return .red
        }
    }

    private var statusText: String {
        switch session.connectionState {
        case .disconnected: return "已断开"
        case .connecting: return "连接中"
        case .connected: return "已连接"
        case .failed: return "失败"
        }
    }
}

// MARK: - tmux 会话选择视图

struct TmuxSessionPickerView: View {
    let sessions: [TmuxSessionInfo]
    let defaultSessionName: String
    let onSelect: (TmuxAction) -> Void
    let onCancel: () -> Void

    @State private var newSessionName: String = ""
    @State private var showNewSessionInput = false

    var body: some View {
        NavigationStack {
            List {
                // 自动模式
                Section {
                    Button {
                        onSelect(.auto)
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("自动")
                                    .foregroundStyle(.primary)
                                Text("如果存在会话则附加，否则新建")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("推荐")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }

                // 新建会话
                Section {
                    Button {
                        showNewSessionInput = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                                .frame(width: 24)
                            Text("新建会话")
                                .foregroundStyle(.primary)
                        }
                    }
                }

                // 已有会话列表
                if !sessions.isEmpty {
                    Section("已有会话") {
                        ForEach(sessions) { session in
                            Button {
                                onSelect(.attach(session.name))
                            } label: {
                                HStack {
                                    Image(systemName: session.attached ? "terminal.fill" : "terminal")
                                        .foregroundStyle(session.attached ? .orange : .gray)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(session.name)
                                                .foregroundStyle(.primary)
                                            if session.attached {
                                                Text("已附加")
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.orange.opacity(0.2))
                                                    .foregroundStyle(.orange)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        Text("\(session.windows) 个窗口 · \(session.created)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onSelect(.delete(session.name))
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择 tmux 会话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("跳过") {
                        onCancel()
                    }
                }
            }
            .alert("新建会话", isPresented: $showNewSessionInput) {
                TextField("会话名称", text: $newSessionName)
                Button("取消", role: .cancel) {
                    newSessionName = ""
                }
                Button("创建") {
                    let sessionName = newSessionName.isEmpty ? defaultSessionName : newSessionName
                    onSelect(.newSession(sessionName))
                    newSessionName = ""
                }
            } message: {
                Text("输入新会话的名称，留空使用默认名称：\(defaultSessionName)")
            }
        }
    }
}
