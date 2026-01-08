import SwiftUI
import SwiftTerm

struct TerminalContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: TerminalSession

    init(connection: SSHConnection) {
        _session = StateObject(wrappedValue: TerminalSession(connection: connection))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                terminalContent
                SpecialKeysBar(onKeyPress: session.sendSpecialKey)
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
        }
    }

    @ViewBuilder
    private var terminalContent: some View {
        switch session.connectionState {
        case .disconnected, .connecting:
            connectingView

        case .connected:
            SwiftTermView(terminal: session.terminal)
                .background(Color.black)

        case .failed:
            failedView
        }
    }

    private var connectingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在连接 \(session.connection.host)...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
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
        .background(Color.black)
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

struct SwiftTermView: UIViewRepresentable {
    let terminal: Terminal

    func makeUIView(context: Context) -> TerminalView {
        let terminalView = TerminalView(frame: .zero)
        terminalView.terminal = terminal
        terminalView.backgroundColor = .black

        let font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        terminalView.font = font

        terminalView.nativeForegroundColor = .white
        terminalView.nativeBackgroundColor = .black

        return terminalView
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {}
}
