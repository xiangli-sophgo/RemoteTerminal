import Foundation

@MainActor
final class TerminalSession: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var errorMessage: String?
    @Published var showTmuxNotInstalledAlert: Bool = false
    @Published var showTmuxSessionPicker: Bool = false
    @Published var tmuxSessions: [TmuxSessionInfo] = []

    let sshService: SSHService
    let connection: SSHConnection

    private var tmuxCheckPending: Bool = false
    private var tmuxListPending: Bool = false
    private var receivedDataBuffer: String = ""

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

        // 重置 tmux 相关状态
        tmuxListPending = false
        tmuxCheckPending = false
        receivedDataBuffer = ""
        showTmuxSessionPicker = false
        showTmuxNotInstalledAlert = false
        tmuxSessions = []

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
            // tmux 会话获取将在终端准备就绪后由 View 触发
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

    // MARK: - tmux 会话管理

    /// 终端准备就绪后调用，获取 tmux 会话列表
    func onTerminalReady() {
        guard connection.enableTmux else { return }
        fetchTmuxSessions()
    }

    /// 获取 tmux 会话列表
    private func fetchTmuxSessions() {
        tmuxListPending = true
        receivedDataBuffer = ""

        // 延迟发送，等待 shell 就绪
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            // 命令：先检测 tmux 是否存在，然后列出会话
            // 使用 /opt/homebrew/bin/tmux 或 /usr/local/bin/tmux 或 tmux
            let cmd = """
            TMUX_BIN=$(command -v tmux || echo /opt/homebrew/bin/tmux); \
            if [ -x "$TMUX_BIN" ]; then \
            echo '<<<TMUX_LIST_START>>>'; \
            "$TMUX_BIN" list-sessions -F '#{session_name}|#{session_windows}|#{session_created}|#{?session_attached,1,0}' 2>/dev/null || echo '<<<TMUX_NO_SESSIONS>>>'; \
            echo '<<<TMUX_LIST_END>>>'; \
            else echo '<<<TMUX_NOT_INSTALLED>>>'; fi\r
            """
            self.sshService.write(cmd)
        }
    }

    /// 执行用户选择的 tmux 操作
    func executeTmuxAction(_ action: TmuxAction) {
        // 使用完整路径或 PATH 中的 tmux
        let tmuxCmd = "TMUX_BIN=$(command -v tmux || echo /opt/homebrew/bin/tmux); \"$TMUX_BIN\""

        let cmd: String
        switch action {
        case .auto:
            showTmuxSessionPicker = false
            tmuxCheckPending = true
            let sessionName = connection.effectiveTmuxSessionName
            cmd = "\(tmuxCmd) attach-session -t \(sessionName) 2>/dev/null || \(tmuxCmd) new-session -s \(sessionName)\r"

        case .newSession(let name):
            showTmuxSessionPicker = false
            tmuxCheckPending = true
            let sessionName = name.replacingOccurrences(of: " ", with: "_")
            cmd = "\(tmuxCmd) new-session -s \(sessionName)\r"

        case .attach(let name):
            showTmuxSessionPicker = false
            tmuxCheckPending = true
            cmd = "\(tmuxCmd) attach-session -t \(name)\r"

        case .delete(let name):
            // 删除会话后刷新列表，不关闭选择器
            cmd = "\(tmuxCmd) kill-session -t \(name) 2>/dev/null\r"
            sshService.write(cmd)
            // 从本地列表中移除
            tmuxSessions.removeAll { $0.name == name }
            return
        }

        // 先清屏，再执行 tmux 命令
        sshService.write("clear\r")
        sshService.write(cmd)
    }

    /// 跳过 tmux 选择，直接使用终端
    func skipTmuxSession() {
        showTmuxSessionPicker = false
        tmuxListPending = false
        // 清屏，清除之前的 tmux 检测命令输出
        sshService.write("clear\r")
    }

    /// 处理接收到的数据
    func handleReceivedData(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }

        // 处理 tmux 会话列表响应
        if tmuxListPending {
            receivedDataBuffer += text

            // 检测标记时要求在新行开头（避免匹配命令回显）
            // 先检测列表结束标记（优先级更高）
            if receivedDataBuffer.contains("\n<<<TMUX_LIST_END>>>") ||
               receivedDataBuffer.contains("\r\n<<<TMUX_LIST_END>>>") {
                tmuxListPending = false
                parseTmuxSessions()
                receivedDataBuffer = ""
                return
            }

            // 检测 tmux 未安装 - 需要确保不是命令回显
            if receivedDataBuffer.contains("\n<<<TMUX_NOT_INSTALLED>>>") ||
               receivedDataBuffer.contains("\r\n<<<TMUX_NOT_INSTALLED>>>") {
                tmuxListPending = false
                showTmuxNotInstalledAlert = true
                receivedDataBuffer = ""
                return
            }
        }

        // 处理 tmux 命令执行结果
        if tmuxCheckPending {
            if text.contains("TMUX_NOT_INSTALLED") {
                tmuxCheckPending = false
                showTmuxNotInstalledAlert = true
            } else if text.contains("sessions should be nested") || text.contains("[") {
                // tmux 已启动成功
                tmuxCheckPending = false
            }
        }
    }

    /// 解析 tmux 会话列表
    private func parseTmuxSessions() {
        var sessions: [TmuxSessionInfo] = []

        // 使用正则表达式查找标记（处理各种换行符和控制字符）
        let startMarker = "<<<TMUX_LIST_START>>>"
        let endMarker = "<<<TMUX_LIST_END>>>"

        // 找到最后一次出现的标记（避免匹配命令回显中的标记）
        guard let startRange = receivedDataBuffer.range(of: startMarker, options: .backwards),
              let endRange = receivedDataBuffer.range(of: endMarker, options: .backwards),
              startRange.lowerBound < endRange.lowerBound else {
            // 没有找到标记，显示选择界面（空列表）
            showTmuxSessionPicker = true
            return
        }

        let content = String(receivedDataBuffer[startRange.upperBound..<endRange.lowerBound])

        // 检查是否无会话
        if content.contains("<<<TMUX_NO_SESSIONS>>>") || content.contains("no server running") {
            tmuxSessions = []
            showTmuxSessionPicker = true
            return
        }

        // 解析每行会话信息
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  !trimmed.hasPrefix("<<<"),
                  !trimmed.contains("tmux list-sessions") else { continue }

            let parts = trimmed.components(separatedBy: "|")
            if parts.count >= 4 {
                let name = parts[0]
                let windows = Int(parts[1]) ?? 1
                let createdTimestamp = Double(parts[2]) ?? 0
                let attached = parts[3] == "1"

                // 格式化创建时间
                let date = Date(timeIntervalSince1970: createdTimestamp)
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                let created = formatter.string(from: date)

                sessions.append(TmuxSessionInfo(
                    name: name,
                    windows: windows,
                    created: created,
                    attached: attached
                ))
            }
        }

        tmuxSessions = sessions
        showTmuxSessionPicker = true
    }
}
