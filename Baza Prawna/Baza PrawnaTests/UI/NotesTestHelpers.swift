//
//  NotesTestHelpers.swift
//  Baza PrawnaTests
//

import Foundation
@testable import Baza_Prawna

enum NotesTestHelpers {

    /// Removes all notes whose `documentKey` has the given prefix (test isolation).
    @MainActor
    static func removeNotes(documentKeyPrefix prefix: String) {
        let mgr = NotesManager.shared
        let ids = mgr.notes.filter { $0.documentKey.hasPrefix(prefix) }.map(\.id)
        for id in ids {
            mgr.remove(id: id)
        }
    }
}
