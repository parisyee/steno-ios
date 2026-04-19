import SwiftUI
import UIKit

struct TranscriptionDetailView: View {
    let item: Transcription
    var onConfirmDelete: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var variant: Variant = .raw
    @State private var copied = false
    @State private var confirmingDelete = false

    enum Variant: Hashable {
        case raw, light, polished

        var label: String {
            switch self {
            case .raw: return "Raw"
            case .light: return "Light"
            case .polished: return "Polished"
            }
        }
    }

    private var availableVariants: [Variant] {
        var v: [Variant] = [.raw]
        if item.cleaned?.light?.isEmpty == false { v.append(.light) }
        if item.cleaned?.polished?.isEmpty == false { v.append(.polished) }
        return v
    }

    private var currentText: String {
        switch variant {
        case .raw: return item.text
        case .light: return item.cleaned?.light ?? item.text
        case .polished: return item.cleaned?.polished ?? item.text
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if availableVariants.count > 1 {
                    Picker("Variant", selection: $variant) {
                        ForEach(availableVariants, id: \.self) { v in
                            Text(v.label).tag(v)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Text(currentText)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .navigationTitle(item.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        copyCurrent()
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    Divider()
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Delete this transcription?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    dismiss()
                    await onConfirmDelete()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(item.displayTitle)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.displayTitle)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(item.createdAt, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            if let desc = item.description, !desc.isEmpty {
                Text(desc)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func copyCurrent() {
        UIPasteboard.general.string = currentText
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
}
