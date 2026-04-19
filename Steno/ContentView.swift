import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: TranscriptionStore
    @State private var searchText = ""
    @State private var pendingDelete: Transcription?
    @State private var errorAlert: String?

    var body: some View {
        NavigationStack {
            Group {
                if store.transcriptions.isEmpty && !store.isLoading && !store.isProcessing {
                    EmptyStateView()
                } else {
                    TranscriptionListView(
                        items: filteredItems,
                        showProcessingBanner: store.isProcessing,
                        showLoadMore: searchText.isEmpty && store.hasMore && !store.transcriptions.isEmpty,
                        isLoadingMore: store.isLoadingMore,
                        onAppearItem: { item in
                            guard searchText.isEmpty else { return }
                            Task { await store.loadMoreIfNeeded(current: item) }
                        },
                        onDelete: { pendingDelete = $0 }
                    )
                }
            }
            .navigationTitle("Steno")
            .navigationDestination(for: Transcription.self) { item in
                TranscriptionDetailView(
                    item: item,
                    onConfirmDelete: { await store.delete(item) }
                )
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search transcriptions"
            )
            .refreshable { await store.refresh() }
            .task { await store.refresh() }
            .onReceive(store.$lastError.compactMap { $0 }) { msg in
                errorAlert = msg
                store.lastError = nil
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { errorAlert != nil },
                set: { if !$0 { errorAlert = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorAlert ?? "")
            }
            .confirmationDialog(
                "Delete this transcription?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { item in
                Button("Delete", role: .destructive) {
                    Task { await store.delete(item) }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: { item in
                Text(item.displayTitle)
            }
        }
    }

    private var filteredItems: [Transcription] {
        guard !searchText.isEmpty else { return store.transcriptions }
        let q = searchText.lowercased()
        return store.transcriptions.filter { item in
            if item.displayTitle.lowercased().contains(q) { return true }
            if item.description?.lowercased().contains(q) == true { return true }
            if item.text.lowercased().contains(q) { return true }
            return false
        }
    }
}

// MARK: - List

private struct TranscriptionListView: View {
    let items: [Transcription]
    let showProcessingBanner: Bool
    let showLoadMore: Bool
    let isLoadingMore: Bool
    let onAppearItem: (Transcription) -> Void
    let onDelete: (Transcription) -> Void

    var body: some View {
        List {
            if showProcessingBanner {
                Section {
                    ProcessingBanner()
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        TranscriptionRow(item: item)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onDelete(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .onAppear { onAppearItem(item) }
                }
            }

            if showLoadMore {
                Section {
                    HStack {
                        Spacer()
                        if isLoadingMore {
                            ProgressView()
                        } else {
                            Color.clear.frame(height: 1)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct TranscriptionRow: View {
    let item: Transcription

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.displayTitle)
                .font(.headline)
                .lineLimit(2)
                .foregroundStyle(.primary)

            if let desc = item.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(item.createdAt, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}

private struct ProcessingBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            VStack(alignment: .leading, spacing: 2) {
                Text("Transcribing…")
                    .font(.subheadline.weight(.medium))
                Text("This can take a minute for long recordings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Empty state

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No transcriptions yet")
                .font(.title3.weight(.semibold))
            Text("Share a voice note from Voice Memos\nto get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
