import SwiftUI

struct SettingsView: View {
    var onClose: () -> Void

    @AppStorage("boardGenerationMode") private var modeRaw: String = BoardGenerationMode.good.rawValue

    private var mode: Binding<BoardGenerationMode> {
        Binding(
            get: { BoardGenerationMode(rawValue: modeRaw) ?? .good },
            set: { modeRaw = $0.rawValue }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: -6)
    }

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
            Spacer()
            Button(action: onClose) {
                Text("Done")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Board Generation")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Picker("Mode", selection: mode) {
                ForEach(BoardGenerationMode.allCases) { m in
                    Text(m.displayName).tag(m)
                }
            }
            .pickerStyle(.segmented)

            Text(mode.wrappedValue.blurb)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Applies to both Word Hunt and Word Bites. Takes effect on the next New Game.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
    }
}

/// Drop-in overlay that animates SettingsView sliding up from the bottom and
/// down on dismiss. Mount inside a ZStack at the top level of a screen.
struct SettingsOverlay: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            if isPresented {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { close() }

                SettingsView(onClose: close)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: isPresented)
    }

    private func close() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            isPresented = false
        }
    }
}
