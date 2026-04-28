import SwiftUI
import UIKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    let info: WHDictionaryInfo?
    let seed: UInt64
    @State private var sharingItem: ShareItem?

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

                Section("Telemetry") {
                    Button("Export board metrics") {
                        if let url = BoardMetricsLogger.shared.fileLocation,
                           FileManager.default.fileExists(atPath: url.path) {
                            sharingItem = ShareItem(url: url)
                        }
                    }
                    .disabled(BoardMetricsLogger.shared.fileLocation.flatMap {
                        FileManager.default.fileExists(atPath: $0.path) ? false : true
                    } ?? true)
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
            .sheet(item: $sharingItem) { item in
                ShareSheet(items: [item.url])
            }
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
