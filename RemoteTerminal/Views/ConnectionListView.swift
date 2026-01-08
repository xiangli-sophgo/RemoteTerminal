import SwiftUI
import SwiftData

struct ConnectionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SSHConnection.createdAt, order: .reverse) private var connections: [SSHConnection]

    @State private var showingAddSheet = false
    @State private var selectedConnection: SSHConnection?
    @State private var connectionToEdit: SSHConnection?

    var body: some View {
        NavigationStack {
            Group {
                if connections.isEmpty {
                    emptyStateView
                } else {
                    connectionList
                }
            }
            .navigationTitle("SSH连接")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                ConnectionEditView(mode: .add)
            }
            .sheet(item: $connectionToEdit) { connection in
                ConnectionEditView(mode: .edit(connection))
            }
            .fullScreenCover(item: $selectedConnection) { connection in
                TerminalContainerView(connection: connection)
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("没有连接", systemImage: "terminal")
        } description: {
            Text("点击右上角 + 添加SSH连接")
        } actions: {
            Button("添加连接") {
                showingAddSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var connectionList: some View {
        List {
            ForEach(connections) { connection in
                ConnectionRowView(connection: connection)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedConnection = connection
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteConnection(connection)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }

                        Button {
                            connectionToEdit = connection
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func deleteConnection(_ connection: SSHConnection) {
        try? KeychainHelper.shared.deletePassword(for: connection.id)
        modelContext.delete(connection)
    }
}

struct ConnectionRowView: View {
    let connection: SSHConnection

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "terminal.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(connection.displayName)
                    .font(.headline)

                Text(connection.connectionString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ConnectionListView()
        .modelContainer(for: SSHConnection.self, inMemory: true)
}
