import SwiftUI
import SwiftTerm

/// SwiftTerm 终端视图的 SwiftUI 包装
struct SwiftTermView: UIViewRepresentable {
    let onInput: (Data) -> Void
    let onSizeChange: (Int, Int) -> Void
    let onReady: () -> Void

    @Binding var terminalViewRef: SwiftTermTerminalView?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onInput: onInput,
            onSizeChange: onSizeChange,
            onReady: onReady
        )
    }

    func makeUIView(context: Context) -> SwiftTermTerminalView {
        let terminalView = SwiftTermTerminalView(frame: .zero)
        terminalView.terminalDelegate = context.coordinator
        terminalView.backgroundColor = UIColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1)

        // 设置字体
        terminalView.font = UIFont(name: "Menlo", size: 14) ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)

        // 设置颜色主题
        terminalView.nativeForegroundColor = UIColor(red: 0.831, green: 0.831, blue: 0.831, alpha: 1)
        terminalView.nativeBackgroundColor = UIColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1)

        // 禁用 SwiftTerm 自带的快捷键栏（使用我们自己的 SpecialKeysBar）
        terminalView.inputAccessoryView = nil

        context.coordinator.terminalView = terminalView

        DispatchQueue.main.async {
            self.terminalViewRef = terminalView
            self.onReady()
        }

        return terminalView
    }

    func updateUIView(_ uiView: SwiftTermTerminalView, context: Context) {}

    class Coordinator: NSObject, TerminalViewDelegate {
        weak var terminalView: SwiftTermTerminalView?
        let onInput: (Data) -> Void
        let onSizeChange: (Int, Int) -> Void
        let onReady: () -> Void

        init(onInput: @escaping (Data) -> Void,
             onSizeChange: @escaping (Int, Int) -> Void,
             onReady: @escaping () -> Void) {
            self.onInput = onInput
            self.onSizeChange = onSizeChange
            self.onReady = onReady
        }

        // MARK: - TerminalViewDelegate

        public func send(source: TerminalView, data: ArraySlice<UInt8>) {
            onInput(Data(data))
        }

        public func scrolled(source: TerminalView, position: Double) {}

        public func setTerminalTitle(source: TerminalView, title: String) {}

        public func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            onSizeChange(newCols, newRows)
        }

        public func clipboardCopy(source: TerminalView, content: Data) {
            if let str = String(bytes: content, encoding: .utf8) {
                UIPasteboard.general.string = str
            }
        }

        public func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        public func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
            if let fixedup = link.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: fixedup) {
                UIApplication.shared.open(url)
            }
        }

        public func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}

/// SwiftTerm TerminalView 的别名，避免与其他类型冲突
typealias SwiftTermTerminalView = SwiftTerm.TerminalView

// MARK: - 扩展 TerminalView 以便写入数据

extension SwiftTermTerminalView {
    /// 写入数据到终端
    func writeData(_ data: Data) {
        let bytes = Array(data)
        feed(byteArray: bytes[0...])
    }

    /// 写入字符串到终端
    func writeString(_ string: String) {
        feed(text: string)
    }
}
