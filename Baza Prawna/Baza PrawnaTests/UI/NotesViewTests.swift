//
//  NotesViewTests.swift
//  Baza PrawnaTests
//
//  Pure Swift helpers from NotesView.swift (no SwiftUI hosting required).
//

import Testing
@testable import Baza_Prawna
import Foundation

struct NotesViewTests {

    @Test("NoteEditorSheetState id is stable for newNote and editing")
    func testNoteEditorSheetStateIds() {
        let draft = UUID()
        let anchor = TextQuoteAnchor(exact: "quote", prefix: "pre", suffix: "suf")
        let newState = NoteEditorSheetState.newNote(anchor: anchor, draftId: draft)
        #expect(newState.id == "new-\(draft.uuidString)")

        let note = DocumentNote(
            id: "note-1",
            documentKey: "eli:X",
            noteText: "body",
            anchor: anchor
        )
        let editState = NoteEditorSheetState.editing(note)
        #expect(editState.id == "note-1")
    }

    @Test("fragmentText exposes anchor exact for new and edit flows")
    func testFragmentText() {
        let a = TextQuoteAnchor(exact: "selected", prefix: "", suffix: "")
        let newS = NoteEditorSheetState.newNote(anchor: a, draftId: UUID())
        #expect(fragmentText(for: newS) == "selected")

        let note = DocumentNote(
            id: "n",
            documentKey: "k",
            noteText: "t",
            anchor: TextQuoteAnchor(exact: "edited", prefix: "", suffix: "")
        )
        #expect(fragmentText(for: .editing(note)) == "edited")
    }

    @Test("editorTitle is Polish for new vs edit")
    func testEditorTitle() {
        let newS = NoteEditorSheetState.newNote(
            anchor: TextQuoteAnchor(exact: "x", prefix: "", suffix: ""),
            draftId: UUID()
        )
        #expect(editorTitle(for: newS) == "Nowa notatka")

        let note = DocumentNote(
            id: "id",
            documentKey: "k",
            noteText: "t",
            anchor: TextQuoteAnchor(exact: "x", prefix: "", suffix: "")
        )
        #expect(editorTitle(for: .editing(note)) == "Edytuj notatkę")
    }

    @Test("autoFocusNoteBodyKeyboard is true only for new notes")
    func testAutoFocusKeyboardFlag() {
        let newS = NoteEditorSheetState.newNote(
            anchor: TextQuoteAnchor(exact: "x", prefix: "", suffix: ""),
            draftId: UUID()
        )
        #expect(newS.autoFocusNoteBodyKeyboard == true)

        let note = DocumentNote(
            id: "id",
            documentKey: "k",
            noteText: "t",
            anchor: TextQuoteAnchor(exact: "x", prefix: "", suffix: "")
        )
        #expect(NoteEditorSheetState.editing(note).autoFocusNoteBodyKeyboard == false)
    }
}
