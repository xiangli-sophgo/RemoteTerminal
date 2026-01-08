import Foundation

// 按键项目（可以是预设或自定义）
struct KeyItem: Codable, Identifiable, Equatable {
    let id: UUID
    var label: String           // 显示标签
    var escapeSequence: String  // 转义序列
    var isCustom: Bool          // 是否是自定义按键
    var presetType: String?     // 预设类型的 rawValue（如果是预设）

    init(id: UUID = UUID(), label: String, escapeSequence: String, isCustom: Bool = true, presetType: String? = nil) {
        self.id = id
        self.label = label
        self.escapeSequence = escapeSequence
        self.isCustom = isCustom
        self.presetType = presetType
    }

    // 从预设类型创建
    init(from preset: SpecialKeyType) {
        self.id = UUID()
        self.label = preset.rawValue
        self.escapeSequence = preset.escapeSequence
        self.isCustom = false
        self.presetType = preset.rawValue
    }

    static func == (lhs: KeyItem, rhs: KeyItem) -> Bool {
        lhs.id == rhs.id
    }
}

// 所有可用的预设按键
enum SpecialKeyType: String, Codable, CaseIterable, Identifiable {
    case escape = "Esc"
    case tab = "Tab"
    case ctrlA = "^A"
    case ctrlB = "^B"
    case ctrlC = "^C"
    case ctrlD = "^D"
    case ctrlE = "^E"
    case ctrlK = "^K"
    case ctrlL = "^L"
    case ctrlR = "^R"
    case ctrlU = "^U"
    case ctrlW = "^W"
    case ctrlZ = "^Z"
    case up = "↑"
    case down = "↓"
    case left = "←"
    case right = "→"
    case home = "Home"
    case end = "End"
    case pageUp = "PgUp"
    case pageDown = "PgDn"
    case f1 = "F1"
    case f2 = "F2"
    case f3 = "F3"
    case f4 = "F4"
    case f5 = "F5"
    case f6 = "F6"
    case f7 = "F7"
    case f8 = "F8"
    case f9 = "F9"
    case f10 = "F10"
    case f11 = "F11"
    case f12 = "F12"

    var id: String { rawValue }

    var escapeSequence: String {
        switch self {
        case .escape: return "\u{1B}"
        case .tab: return "\t"
        case .ctrlA: return "\u{01}"
        case .ctrlB: return "\u{02}"
        case .ctrlC: return "\u{03}"
        case .ctrlD: return "\u{04}"
        case .ctrlE: return "\u{05}"
        case .ctrlK: return "\u{0B}"
        case .ctrlL: return "\u{0C}"
        case .ctrlR: return "\u{12}"
        case .ctrlU: return "\u{15}"
        case .ctrlW: return "\u{17}"
        case .ctrlZ: return "\u{1A}"
        case .up: return "\u{1B}[A"
        case .down: return "\u{1B}[B"
        case .left: return "\u{1B}[D"
        case .right: return "\u{1B}[C"
        case .home: return "\u{1B}[H"
        case .end: return "\u{1B}[F"
        case .pageUp: return "\u{1B}[5~"
        case .pageDown: return "\u{1B}[6~"
        case .f1: return "\u{1B}OP"
        case .f2: return "\u{1B}OQ"
        case .f3: return "\u{1B}OR"
        case .f4: return "\u{1B}OS"
        case .f5: return "\u{1B}[15~"
        case .f6: return "\u{1B}[17~"
        case .f7: return "\u{1B}[18~"
        case .f8: return "\u{1B}[19~"
        case .f9: return "\u{1B}[20~"
        case .f10: return "\u{1B}[21~"
        case .f11: return "\u{1B}[23~"
        case .f12: return "\u{1B}[24~"
        }
    }

    var displayName: String {
        switch self {
        case .ctrlA: return "Ctrl+A (行首)"
        case .ctrlB: return "Ctrl+B (后退)"
        case .ctrlC: return "Ctrl+C (中断)"
        case .ctrlD: return "Ctrl+D (退出/EOF)"
        case .ctrlE: return "Ctrl+E (行尾)"
        case .ctrlK: return "Ctrl+K (删除到行尾)"
        case .ctrlL: return "Ctrl+L (清屏)"
        case .ctrlR: return "Ctrl+R (搜索历史)"
        case .ctrlU: return "Ctrl+U (删除到行首)"
        case .ctrlW: return "Ctrl+W (删除单词)"
        case .ctrlZ: return "Ctrl+Z (挂起)"
        default: return rawValue
        }
    }
}

// 辅助函数：解析按键组合并生成转义序列
struct KeyComboParser {
    // 特殊键名映射
    private static let specialKeys: [String: (base: String, label: String)] = [
        "tab": ("\t", "Tab"),
        "esc": ("\u{1B}", "Esc"),
        "escape": ("\u{1B}", "Esc"),
        "enter": ("\r", "Enter"),
        "return": ("\r", "Enter"),
        "space": (" ", "Space"),
        "backspace": ("\u{7F}", "BS"),
        "delete": ("\u{1B}[3~", "Del"),
        "up": ("\u{1B}[A", "↑"),
        "down": ("\u{1B}[B", "↓"),
        "left": ("\u{1B}[D", "←"),
        "right": ("\u{1B}[C", "→"),
        "home": ("\u{1B}[H", "Home"),
        "end": ("\u{1B}[F", "End"),
        "pageup": ("\u{1B}[5~", "PgUp"),
        "pgup": ("\u{1B}[5~", "PgUp"),
        "pagedown": ("\u{1B}[6~", "PgDn"),
        "pgdn": ("\u{1B}[6~", "PgDn"),
        "insert": ("\u{1B}[2~", "Ins"),
    ]

    // 解析类似 "Ctrl+Shift+W" 或 "Shift+Tab" 的格式
    static func parse(_ input: String) -> (label: String, sequence: String)? {
        let trimmed = input.trimmingCharacters(in: .whitespaces).lowercased()

        // 解析组合键格式 (ctrl+a, ctrl+shift+a 等)
        let parts = trimmed.split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }

        var hasCtrl = false
        var hasShift = false
        var hasAlt = false
        var keyChar: Character?
        var specialKey: String?

        for part in parts {
            switch part {
            case "ctrl", "control", "^":
                hasCtrl = true
            case "shift", "⇧":
                hasShift = true
            case "alt", "option", "opt", "⌥":
                hasAlt = true
            default:
                if part.count == 1 {
                    keyChar = part.first
                } else if part.hasPrefix("f") && part.count <= 3 {
                    // F1-F12
                    if let fNum = Int(part.dropFirst()), fNum >= 1 && fNum <= 12 {
                        let sequence = getFunctionKeySequence(fNum, shift: hasShift, ctrl: hasCtrl, alt: hasAlt)
                        let label = buildLabel(ctrl: hasCtrl, shift: hasShift, alt: hasAlt, key: "F\(fNum)")
                        return (label, sequence)
                    }
                } else if specialKeys[part] != nil {
                    specialKey = part
                }
            }
        }

        // 处理特殊键 (Tab, Esc, Enter 等)
        if let special = specialKey, let keyInfo = specialKeys[special] {
            let sequence = generateSpecialKeySequence(base: keyInfo.base, keyName: special, ctrl: hasCtrl, shift: hasShift, alt: hasAlt)
            let label = buildLabel(ctrl: hasCtrl, shift: hasShift, alt: hasAlt, key: keyInfo.label)
            return (label, sequence)
        }

        // 处理普通字符键
        guard let char = keyChar else { return nil }

        // 生成转义序列
        let sequence = generateEscapeSequence(char: char, ctrl: hasCtrl, shift: hasShift, alt: hasAlt)
        let label = buildLabel(ctrl: hasCtrl, shift: hasShift, alt: hasAlt, key: String(char).uppercased())

        return (label, sequence)
    }

    private static func generateSpecialKeySequence(base: String, keyName: String, ctrl: Bool, shift: Bool, alt: Bool) -> String {
        // Shift+Tab 特殊处理 (反向 Tab)
        if keyName == "tab" && shift && !ctrl && !alt {
            return "\u{1B}[Z"  // CSI Z - Shift+Tab 的标准序列
        }

        // 如果有修饰键，使用 CSI 序列
        var modifier = 1
        if shift { modifier += 1 }
        if alt { modifier += 2 }
        if ctrl { modifier += 4 }

        if modifier > 1 {
            // 根据键类型生成不同的修饰序列
            switch keyName {
            case "tab":
                return "\u{1B}[9;\(modifier)u"  // CSI u 格式
            case "esc", "escape":
                return "\u{1B}[27;\(modifier)u"
            case "enter", "return":
                return "\u{1B}[13;\(modifier)u"
            case "space":
                return "\u{1B}[32;\(modifier)u"
            case "backspace":
                return "\u{1B}[127;\(modifier)u"
            case "up":
                return "\u{1B}[1;\(modifier)A"
            case "down":
                return "\u{1B}[1;\(modifier)B"
            case "right":
                return "\u{1B}[1;\(modifier)C"
            case "left":
                return "\u{1B}[1;\(modifier)D"
            case "home":
                return "\u{1B}[1;\(modifier)H"
            case "end":
                return "\u{1B}[1;\(modifier)F"
            case "insert":
                return "\u{1B}[2;\(modifier)~"
            case "delete":
                return "\u{1B}[3;\(modifier)~"
            case "pageup", "pgup":
                return "\u{1B}[5;\(modifier)~"
            case "pagedown", "pgdn":
                return "\u{1B}[6;\(modifier)~"
            default:
                break
            }
        }

        return base
    }

    private static func buildLabel(ctrl: Bool, shift: Bool, alt: Bool, key: String) -> String {
        var parts: [String] = []
        if ctrl { parts.append("^") }
        if shift { parts.append("⇧") }
        if alt { parts.append("⌥") }
        parts.append(key)
        return parts.joined()
    }

    private static func generateEscapeSequence(char: Character, ctrl: Bool, shift: Bool, alt: Bool) -> String {
        let upperChar = char.uppercased().first!

        if ctrl && !shift && !alt {
            // 纯 Ctrl 组合：生成控制字符
            if let ascii = upperChar.asciiValue, ascii >= 65 && ascii <= 90 {
                // A-Z: Ctrl+A = 0x01, Ctrl+Z = 0x1A
                return String(UnicodeScalar(ascii - 64))
            }
        }

        // 带修饰键的组合使用 CSI 序列
        // 格式: ESC [ 1 ; modifier char
        // modifier: 1=none, 2=shift, 3=alt, 4=alt+shift, 5=ctrl, 6=ctrl+shift, 7=ctrl+alt, 8=ctrl+alt+shift
        var modifier = 1
        if shift { modifier += 1 }
        if alt { modifier += 2 }
        if ctrl { modifier += 4 }

        if modifier > 1 {
            // 使用 xterm 风格的修饰键序列
            return "\u{1B}[1;\(modifier)\(upperChar)"
        }

        // 普通字符
        return String(char)
    }

    private static func getFunctionKeySequence(_ num: Int, shift: Bool, ctrl: Bool, alt: Bool) -> String {
        var modifier = 1
        if shift { modifier += 1 }
        if alt { modifier += 2 }
        if ctrl { modifier += 4 }

        let codes = [
            1: "P", 2: "Q", 3: "R", 4: "S"  // F1-F4 使用 SS3 序列
        ]
        let tildeCode = [
            5: "15", 6: "17", 7: "18", 8: "19", 9: "20", 10: "21", 11: "23", 12: "24"
        ]

        if num <= 4 {
            if modifier > 1 {
                return "\u{1B}[1;\(modifier)\(codes[num]!)"
            }
            return "\u{1B}O\(codes[num]!)"
        } else if let code = tildeCode[num] {
            if modifier > 1 {
                return "\u{1B}[\(code);\(modifier)~"
            }
            return "\u{1B}[\(code)~"
        }
        return ""
    }
}

class KeyBarSettings: ObservableObject {
    static let shared = KeyBarSettings()

    @Published var enabledKeys: [KeyItem] {
        didSet {
            saveSettings()
        }
    }

    private static var defaultKeys: [KeyItem] {
        [
            KeyItem(from: .escape),
            KeyItem(from: .tab),
            KeyItem(from: .ctrlC),
            KeyItem(from: .ctrlD),
            KeyItem(from: .up),
            KeyItem(from: .down),
            KeyItem(from: .left),
            KeyItem(from: .right),
            KeyItem(from: .ctrlZ),
            KeyItem(from: .ctrlL)
        ]
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: "enabledKeysV2"),
           let keys = try? JSONDecoder().decode([KeyItem].self, from: data) {
            self.enabledKeys = keys
        } else {
            self.enabledKeys = Self.defaultKeys
        }
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(enabledKeys) {
            UserDefaults.standard.set(data, forKey: "enabledKeysV2")
        }
    }

    func resetToDefault() {
        enabledKeys = Self.defaultKeys
    }

    func addPresetKey(_ preset: SpecialKeyType) {
        let key = KeyItem(from: preset)
        if !enabledKeys.contains(where: { $0.presetType == preset.rawValue }) {
            enabledKeys.append(key)
        }
    }

    func addCustomKey(label: String, escapeSequence: String) {
        let key = KeyItem(label: label, escapeSequence: escapeSequence, isCustom: true)
        enabledKeys.append(key)
    }

    func addCustomKeyFromCombo(_ combo: String) -> Bool {
        guard let parsed = KeyComboParser.parse(combo) else { return false }
        addCustomKey(label: parsed.label, escapeSequence: parsed.sequence)
        return true
    }

    func removeKey(_ key: KeyItem) {
        enabledKeys.removeAll { $0.id == key.id }
    }

    func moveKey(from source: IndexSet, to destination: Int) {
        enabledKeys.move(fromOffsets: source, toOffset: destination)
    }
}
