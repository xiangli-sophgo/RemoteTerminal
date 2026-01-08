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
            }
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
