//
//  Conversation.swift
//  PersonalJpTranslator
//
//  Created by Codex on 11/14/25.
//

import Foundation

struct Conversation: Identifiable, Codable {
    var id: UUID
    private(set) var messages: [ChatMessage]
    private(set) var likedHighlights: [String]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         messages: [ChatMessage] = [],
         likedHighlights: [String] = [],
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.messages = messages
        self.likedHighlights = likedHighlights
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var preferenceHints: String {
        guard !likedHighlights.isEmpty else { return "" }
        let recent = likedHighlights.suffix(3).joined(separator: " • ")
        return "User liked: \(recent)"
    }

    mutating func appendMessage(_ message: ChatMessage) {
        messages.append(message)
        touch()
    }

    mutating func replaceMessage(_ message: ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[index] = message
        touch()
    }

    mutating func clear() {
        self = Conversation()
    }

    mutating func addHighlight(for message: ChatMessage) {
        let snippet = message.text.prefix(160)
        likedHighlights.append(String(snippet))
        if likedHighlights.count > 10 {
            likedHighlights.removeFirst(likedHighlights.count - 10)
        }
        touch()
    }

    private mutating func touch() {
        updatedAt = Date()
    }
}
