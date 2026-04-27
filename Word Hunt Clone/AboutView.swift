import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    let info: WHDictionaryInfo?
    let seed: UInt64

    var body: some View {
        NavigationStack {
            List {
                Section("Dictionary") {
                    LabeledContent("Word list", value: "wordhunt-solver")
                    LabeledContent("Words", value: "\(info?.wordCount ?? 0)")
                    if let sha = info?.sha256, !sha.isEmpty {
                        LabeledContent("Asset SHA-256", value: String(sha.prefix(12)))
                    }
                }

                Section("Attribution") {
                    Text("Dictionary source: Ammaar-Alam/wordhunt-solver. Used here for internal practice only.")
                    if let source = info?.sourceURL, let url = URL(string: source) {
                        Link("Open source file", destination: url)
                    }
                }

                Section("Current Game") {
                    LabeledContent("Seed", value: "\(seed)")
                    LabeledContent("RNG", value: "Xoshiro256**")
                    LabeledContent("Board", value: "4x4")
                    LabeledContent("Timer", value: "80 seconds")
                }
            }
            .navigationTitle("About")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
