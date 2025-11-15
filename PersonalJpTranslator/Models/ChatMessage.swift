//
//  ChatMessage.swift
//  PersonalJpTranslator
//
//  Created by Codex on 11/14/25.
//

import Foundation

enum ChatRole: String, Codable {
    case system
    case user
    case assistant
}

struct ChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let role: ChatRole
    var text: String
    var timestamp: Date
    var rating: Int?
    var skillHints: [PersonaSkill]?

    init(id: UUID = UUID(),
         role: ChatRole,
         text: String,
         timestamp: Date = Date(),
         rating: Int? = nil,
         skillHints: [PersonaSkill]? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.rating = rating
        self.skillHints = skillHints
    }
}
