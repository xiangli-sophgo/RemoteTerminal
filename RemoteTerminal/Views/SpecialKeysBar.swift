import SwiftUI

struct SpecialKeysBar: View {
    let onKeyPress: (SpecialKey) -> Void

    private let primaryKeys: [SpecialKey] = [.escape, .tab, .ctrlC, .ctrlD]
    private let arrowKeys: [SpecialKey] = [.up, .down, .left, .right]
    private let extraKeys: [SpecialKey] = [.ctrlZ, .ctrlL]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(primaryKeys, id: \.self) { key in
                    SpecialKeyButton(key: key, action: onKeyPress)
                }

                Divider()
                    .frame(height: 24)

                ForEach(arrowKeys, id: \.self) { key in
                    SpecialKeyButton(key: key, action: onKeyPress)
                }

                Divider()
                    .frame(height: 24)

                ForEach(extraKeys, id: \.self) { key in
                    SpecialKeyButton(key: key, action: onKeyPress)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

struct SpecialKeyButton: View {
    let key: SpecialKey
    let action: (SpecialKey) -> Void

    var body: some View {
        Button {
            action(key)
        } label: {
            Text(key.rawValue)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        Spacer()
        SpecialKeysBar { key in
            print("Pressed: \(key)")
        }
    }
}
