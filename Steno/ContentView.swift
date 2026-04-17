import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: TranscriptionStore

    var body: some View {
        NavigationView {
            Group {
                if store.transcriptions.isEmpty && !store.isProcessing {
                    VStack(spacing: 16) {
                        Image(systemName: "waveform")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No transcriptions yet")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("Share a voice note from Voice Memos\nto get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        if store.isProcessing {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text("Transcribing...")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }

                        ForEach(store.transcriptions) { item in
                            TranscriptionRow(item: item)
                        }
                        .onDelete { indices in
                            store.transcriptions.remove(atOffsets: indices)
                            store.save()
                        }
                    }
                }
            }
            .navigationTitle("Steno")
        }
        .onAppear {
            store.processSharedFile()
        }
    }
}

struct TranscriptionRow: View {
    let item: Transcription
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(item.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = item.text
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            Text(item.text)
                .font(.body)

            if let error = item.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}
