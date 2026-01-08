import SwiftUI
import SwiftData

enum ConnectionEditMode: Identifiable {
    case add
    case edit(SSHConnection)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let conn): return conn.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .add: return "新建连接"
        case .edit: return "编辑连接"
        }
    }

    var connection: SSHConnection? {
        switch self {
        case .add: return nil
        case .edit(let conn): return conn
        }
    }
}

struct ConnectionEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: ConnectionEditMode

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var savePassword: Bool = true
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("连接信息") {
                    TextField("名称（可选）", text: $name)
                        .textContentType(.nickname)

                    TextField("主机地址", text: $host)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    TextField("端口", text: $port)
                        .keyboardType(.numberPad)
                }

                Section("认证") {
                    TextField("用户名", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("密码", text: $password)
                        .textContentType(.password)

                    Toggle("保存密码到钥匙串", isOn: $savePassword)
                }

                Section {
                    Text("支持局域网IP (192.168.x.x) 或 Tailscale IP (100.x.x.x)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveConnection()
                    }
                    .disabled(!isValid)
                }
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                loadExistingData()
            }
        }
    }

    private var isValid: Bool {
        !host.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(port) != nil
    }

    private func loadExistingData() {
        guard let connection = mode.connection else { return }

        name = connection.name
        host = connection.host
        port = String(connection.port)
        username = connection.username

        if let savedPassword = try? KeychainHelper.shared.getPassword(for: connection.id) {
            password = savedPassword
            savePassword = true
        }
    }

    private func saveConnection() {
        guard let portNumber = Int(port) else {
            errorMessage = "端口号无效"
            showingError = true
            return
        }

        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)

        if let existing = mode.connection {
            existing.name = name
            existing.host = trimmedHost
            existing.port = portNumber
            existing.username = trimmedUsername

            if savePassword && !password.isEmpty {
                try? KeychainHelper.shared.savePassword(password, for: existing.id)
            } else {
                try? KeychainHelper.shared.deletePassword(for: existing.id)
            }
        } else {
            let connection = SSHConnection(
                name: name,
                host: trimmedHost,
                port: portNumber,
                username: trimmedUsername
            )
            modelContext.insert(connection)

            if savePassword && !password.isEmpty {
                try? KeychainHelper.shared.savePassword(password, for: connection.id)
            }
        }

        dismiss()
    }
}

#Preview("Add") {
    ConnectionEditView(mode: .add)
        .modelContainer(for: SSHConnection.self, inMemory: true)
}
