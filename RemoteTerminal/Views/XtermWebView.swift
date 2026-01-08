import SwiftUI
import WebKit

struct XtermWebView: UIViewRepresentable {
    let onInput: (String) -> Void
    let onSizeChange: (Int, Int) -> Void
    let onReady: () -> Void

    @Binding var webViewRef: WKWebView?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onInput: onInput,
            onSizeChange: onSizeChange,
            onReady: onReady
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "terminalInput")
        config.userContentController.add(context.coordinator, name: "terminalSize")
        config.userContentController.add(context.coordinator, name: "terminalReady")

        // 允许内联播放
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false

        // 禁用缩放
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0

        context.coordinator.webView = webView

        // 加载 HTML
        if let htmlPath = Bundle.main.path(forResource: "terminal", ofType: "html") {
            let htmlURL = URL(fileURLWithPath: htmlPath)
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        } else {
            // 如果找不到本地文件，使用内联 HTML
            loadInlineHTML(webView: webView)
        }

        DispatchQueue.main.async {
            self.webViewRef = webView
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private func loadInlineHTML(webView: WKWebView) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/xterm@5.3.0/css/xterm.css">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { width: 100%; height: 100%; overflow: hidden; background-color: #1e1e1e; }
                #terminal { width: 100%; height: 100%; }
                .xterm { padding: 8px; }
            </style>
        </head>
        <body>
            <div id="terminal"></div>
            <script src="https://cdn.jsdelivr.net/npm/xterm@5.3.0/lib/xterm.min.js"></script>
            <script src="https://cdn.jsdelivr.net/npm/xterm-addon-fit@0.8.0/lib/xterm-addon-fit.min.js"></script>
            <script>
                const term = new Terminal({
                    cursorBlink: true,
                    fontSize: 14,
                    fontFamily: 'Menlo, Monaco, monospace',
                    theme: { background: '#1e1e1e', foreground: '#d4d4d4' },
                    convertEol: true
                });
                const fitAddon = new FitAddon.FitAddon();
                term.loadAddon(fitAddon);
                term.open(document.getElementById('terminal'));
                fitAddon.fit();

                window.addEventListener('resize', () => { fitAddon.fit(); notifySizeChange(); });
                setTimeout(() => { fitAddon.fit(); notifySizeChange(); }, 100);

                term.onData((data) => {
                    if (window.webkit?.messageHandlers?.terminalInput) {
                        window.webkit.messageHandlers.terminalInput.postMessage(data);
                    }
                });

                function notifySizeChange() {
                    if (window.webkit?.messageHandlers?.terminalSize) {
                        window.webkit.messageHandlers.terminalSize.postMessage({ cols: term.cols, rows: term.rows });
                    }
                }

                function writeToTerminal(data) { term.write(data); }
                function clearTerminal() { term.clear(); }
                function focusTerminal() { term.focus(); }
                function resizeTerminal() { fitAddon.fit(); notifySizeChange(); }

                if (window.webkit?.messageHandlers?.terminalReady) {
                    window.webkit.messageHandlers.terminalReady.postMessage('ready');
                }
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?
        let onInput: (String) -> Void
        let onSizeChange: (Int, Int) -> Void
        let onReady: () -> Void

        init(onInput: @escaping (String) -> Void,
             onSizeChange: @escaping (Int, Int) -> Void,
             onReady: @escaping () -> Void) {
            self.onInput = onInput
            self.onSizeChange = onSizeChange
            self.onReady = onReady
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            switch message.name {
            case "terminalInput":
                if let input = message.body as? String {
                    onInput(input)
                }
            case "terminalSize":
                if let sizeDict = message.body as? [String: Int],
                   let cols = sizeDict["cols"],
                   let rows = sizeDict["rows"] {
                    onSizeChange(cols, rows)
                }
            case "terminalReady":
                onReady()
            default:
                break
            }
        }

        func write(_ data: String) {
            let escaped = data
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
            webView?.evaluateJavaScript("writeToTerminal('\(escaped)')", completionHandler: nil)
        }

        func writeData(_ data: Data) {
            // 转换为 Base64，然后在 JS 中解码
            let base64 = data.base64EncodedString()
            webView?.evaluateJavaScript("""
                (function() {
                    const bytes = atob('\(base64)');
                    writeToTerminal(bytes);
                })();
            """, completionHandler: nil)
        }

        func focus() {
            webView?.evaluateJavaScript("focusTerminal()", completionHandler: nil)
        }

        func resize() {
            webView?.evaluateJavaScript("resizeTerminal()", completionHandler: nil)
        }
    }
}

// MARK: - 辅助扩展

extension WKWebView {
    func writeToTerminal(_ text: String) {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        evaluateJavaScript("writeToTerminal('\(escaped)')", completionHandler: nil)
    }

    func writeDataToTerminal(_ data: Data) {
        // 将 Data 转换为 UTF-8 字符串
        if let text = String(data: data, encoding: .utf8) {
            writeToTerminal(text)
        } else {
            // 如果不是有效的 UTF-8，使用 Base64 + TextDecoder
            let base64 = data.base64EncodedString()
            evaluateJavaScript("""
                (function() {
                    const binary = atob('\(base64)');
                    const bytes = new Uint8Array(binary.length);
                    for (let i = 0; i < binary.length; i++) {
                        bytes[i] = binary.charCodeAt(i);
                    }
                    const text = new TextDecoder('utf-8').decode(bytes);
                    writeToTerminal(text);
                })();
            """, completionHandler: nil)
        }
    }
}
