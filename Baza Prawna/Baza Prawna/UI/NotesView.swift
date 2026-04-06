//
//  NotesView.swift
//  Baza Prawna
//

import SwiftUI
import UIKit

// MARK: - Note editor sheet (new or edit)

/// Drives `.sheet(item:)` so the quoted fragment is available the moment the sheet appears (avoids stale `isPresented` capture).
enum NoteEditorSheetState: Identifiable {
    case newNote(anchor: TextQuoteAnchor, draftId: UUID)
    case editing(DocumentNote)

    var id: String {
        switch self {
        case .newNote(_, let draftId): return "new-\(draftId.uuidString)"
        case .editing(let note): return note.id
        }
    }

    /// New-note flow should pop the keyboard; edit can stay unfocused until the user taps.
    var autoFocusNoteBodyKeyboard: Bool {
        if case .newNote = self { return true }
        return false
    }
}

func fragmentText(for state: NoteEditorSheetState) -> String {
    switch state {
    case .newNote(let anchor, _):
        return anchor.exact
    case .editing(let note):
        return note.anchor.exact
    }
}

func editorTitle(for state: NoteEditorSheetState) -> String {
    switch state {
    case .newNote:
        return "Nowa notatka"
    case .editing:
        return "Edytuj notatkę"
    }
}

// MARK: - Note body editor (UIKit — keyboard in sheets)

/// SwiftUI `TextEditor` often ignores programmatic focus inside `.sheet`; `UITextView` + `becomeFirstResponder()` is reliable.
struct NoteBodyTextEditor: UIViewRepresentable {
    @Binding var text: String
    var autoFocusKeyboard: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NoteBodyTextEditor
        var didAutoFocus = false

        init(_ parent: NoteBodyTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
        }
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.adjustsFontForContentSizeCategory = true
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5)
        tv.keyboardDismissMode = .interactive
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text {
            uiView.text = text
        }

        guard autoFocusKeyboard, !context.coordinator.didAutoFocus else { return }
        context.coordinator.didAutoFocus = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard uiView.window != nil else { return }
            uiView.becomeFirstResponder()
        }
    }
}

// MARK: - Document notes list sheet

struct MDDocumentNotesSheet: View {
    let notes: [DocumentNote]
    let onAddFromSelection: () -> Void
    let onSelectNote: (DocumentNote) -> Void
    let onEdit: (DocumentNote) -> Void
    let onDelete: (DocumentNote) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if notes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "text.cursor")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("Zaznacz fragment tekstu w dokumencie, żeby dodać notatkę")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(notes) { note in
                            Button {
                                onSelectNote(note)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(note.anchor.exact)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                                        .lineLimit(4)
                                        .multilineTextAlignment(.leading)
                                    Text(note.noteText)
                                        .font(.body)
                                        .italic()
                                        .foregroundStyle(.primary)
                                        .lineLimit(8)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    onEdit(note)
                                } label: {
                                    Label("Edytuj", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDelete(note)
                                } label: {
                                    Label("Usuń", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Notatki")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onAddFromSelection()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}
