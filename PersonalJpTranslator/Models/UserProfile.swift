//
//  UserProfile.swift
//  PersonalJpTranslator
//
//  Created by Codex on 11/14/25.
//

import Foundation

struct UserProfile: Identifiable, Codable {
    var id: UUID
    var totalQuestions: Int
    var likedAnswers: Int
    var dislikedAnswers: Int
    var lastFeedbackSnippet: String?
    var lastUpdated: Date?
    var skillScores: [String: Int]

    enum CodingKeys: String, CodingKey {
        case id
        case totalQuestions
        case likedAnswers
        case dislikedAnswers
        case lastFeedbackSnippet
        case lastUpdated
        case skillScores
    }

    init(id: UUID = UUID(),
         totalQuestions: Int = 0,
         likedAnswers: Int = 0,
         dislikedAnswers: Int = 0,
         lastFeedbackSnippet: String? = nil,
         lastUpdated: Date? = nil,
         skillScores: [String: Int] = [:]) {
        self.id = id
        self.totalQuestions = totalQuestions
        self.likedAnswers = likedAnswers
        self.dislikedAnswers = dislikedAnswers
        self.lastFeedbackSnippet = lastFeedbackSnippet
        self.lastUpdated = lastUpdated
        self.skillScores = skillScores
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        totalQuestions = try container.decode(Int.self, forKey: .totalQuestions)
        likedAnswers = try container.decode(Int.self, forKey: .likedAnswers)
        dislikedAnswers = try container.decode(Int.self, forKey: .dislikedAnswers)
        lastFeedbackSnippet = try container.decodeIfPresent(String.self, forKey: .lastFeedbackSnippet)
        lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated)
        skillScores = try container.decodeIfPresent([String: Int].self, forKey: .skillScores) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(totalQuestions, forKey: .totalQuestions)
        try container.encode(likedAnswers, forKey: .likedAnswers)
        try container.encode(dislikedAnswers, forKey: .dislikedAnswers)
        try container.encodeIfPresent(lastFeedbackSnippet, forKey: .lastFeedbackSnippet)
        try container.encodeIfPresent(lastUpdated, forKey: .lastUpdated)
        try container.encode(skillScores, forKey: .skillScores)
    }

    var ratingSummary: String {
        switch (likedAnswers, dislikedAnswers) {
        case (0, 0):
            return "Still learning what the user prefers."
        case (_, 0):
            return "User consistently likes thorough, thoughtful responses."
        case (0, _):
            return "User often downvotes responses—focus on clarity and nuance."
        default:
            return "Likes: \(likedAnswers) | Dislikes: \(dislikedAnswers). Reinforce patterns found in liked answers."
        }
    }

    var learningSummary: String {
        let base = "Questions asked: \(totalQuestions). \(ratingSummary)"
        let skillText = SkillEngine.friendlySummary(from: skillScores)
        if let snippet = lastFeedbackSnippet, !snippet.isEmpty {
            return base + " Last positive snippet: \"\(snippet)\". \(skillText)"
        }
        return base + " \(skillText)"
    }

    mutating func recordQuestion() {
        totalQuestions += 1
        lastUpdated = Date()
    }

    mutating func apply(rating: Int, feedbackSource: ChatMessage?) {
        if rating > 0 {
            likedAnswers += 1
            if let snippet = feedbackSource?.text.prefix(120), !snippet.isEmpty {
                lastFeedbackSnippet = String(snippet)
            }
        } else if rating < 0 {
            dislikedAnswers += 1
        }
        lastUpdated = Date()
    }

    mutating func adjustSkills(_ skills: [PersonaSkill], delta: Int) {
        guard delta != 0 else { return }
        for skill in skills {
            let key = skill.rawValue
            let current = skillScores[key] ?? 0
            let updated = max(0, current + delta)
            skillScores[key] = updated
        }
        lastUpdated = Date()
    }
}
