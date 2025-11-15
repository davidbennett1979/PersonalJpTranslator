//
//  SkillTree.swift
//  PersonalJpTranslator
//
//  Created by Codex on 11/14/25.
//

import Foundation

enum SkillCategory: String, CaseIterable, Identifiable, Codable {
    case clarity
    case nuance
    case tone
    case culture
    case coaching

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clarity: return "Clarity"
        case .nuance: return "Nuance"
        case .tone: return "Tone"
        case .culture: return "Culture"
        case .coaching: return "Coaching"
        }
    }

    var icon: String {
        switch self {
        case .clarity: return "sparkles"
        case .nuance: return "text.book.closed"
        case .tone: return "music.note"
        case .culture: return "globe.asia.australia"
        case .coaching: return "person.2.fill"
        }
    }

    var flavorText: String {
        switch self {
        case .clarity:
            return "How literal and precise the assistant should be."
        case .nuance:
            return "How much grammar or nuance detail you enjoy."
        case .tone:
            return "How often to suggest tone or style tweaks."
        case .culture:
            return "How deep to go on culture/context notes."
        case .coaching:
            return "How much critique or rewriting help you want."
        }
    }
}

enum PersonaSkill: String, CaseIterable, Identifiable, Codable {
    case crystalTranslation
    case grammarGuide
    case toneCoach
    case cultureSensei
    case rewriteMentor
    case speedSummarizer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .crystalTranslation: return "Crystal Translation"
        case .grammarGuide: return "Grammar Guide"
        case .toneCoach: return "Tone Coach"
        case .cultureSensei: return "Culture Sensei"
        case .rewriteMentor: return "Rewrite Mentor"
        case .speedSummarizer: return "Speed Summarizer"
        }
    }

    var description: String {
        switch self {
        case .crystalTranslation:
            return "Prioritizes literal, dependable translations."
        case .grammarGuide:
            return "Adds concise grammar or nuance notes."
        case .toneCoach:
            return "Suggests how to adjust tone or politeness."
        case .cultureSensei:
            return "Explains cultural or situational context."
        case .rewriteMentor:
            return "Provides feedback on drafts and rewrites them."
        case .speedSummarizer:
            return "Keeps answers short and to the point."
        }
    }

    var category: SkillCategory {
        switch self {
        case .crystalTranslation, .speedSummarizer:
            return .clarity
        case .grammarGuide:
            return .nuance
        case .toneCoach:
            return .tone
        case .cultureSensei:
            return .culture
        case .rewriteMentor:
            return .coaching
        }
    }

    var promptDescriptor: String {
        switch self {
        case .crystalTranslation:
            return "keep translations crisp and literal"
        case .grammarGuide:
            return "include one short grammar/nuance note when useful"
        case .toneCoach:
            return "suggest tone or politeness tweaks"
        case .cultureSensei:
            return "add cultural context when it helps comprehension"
        case .rewriteMentor:
            return "critique and rewrite drafts thoughtfully"
        case .speedSummarizer:
            return "keep explanations brief and efficient"
        }
    }
}

struct SkillEngine {
    static let categoryMap: [SkillCategory: [PersonaSkill]] = {
        Dictionary(grouping: PersonaSkill.allCases, by: { $0.category })
    }()

    static func score(for skill: PersonaSkill, in scores: [String: Int]) -> Int {
        scores[skill.rawValue] ?? 0
    }

    static func topSkillDescriptors(from scores: [String: Int], limit: Int = 2) -> [String] {
        PersonaSkill.allCases
            .map { ($0, score(for: $0, in: scores)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { "\($0.0.title.lowercased())" }
    }

    static func promptAdditions(from scores: [String: Int]) -> String {
        let descriptors = PersonaSkill.allCases
            .map { ($0, score(for: $0, in: scores)) }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .filter { $0.1 > 0 }
            .map { $0.0.promptDescriptor }
        guard !descriptors.isEmpty else { return "" }
        return "Lean into the user's favorites: \(descriptors.joined(separator: ", "))."
    }

    static func friendlySummary(from scores: [String: Int]) -> String {
        let favorites = PersonaSkill.allCases
            .map { ($0, score(for: $0, in: scores)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(2)
            .map { $0.0.title }
        guard !favorites.isEmpty else {
            return "Still learning what makes the perfect answer."
        }
        return "Currently favoring: \(favorites.joined(separator: ", "))."
    }

    static func progress(for score: Int) -> Double {
        let normalized = Double(score) / 8.0
        return min(max(normalized, 0), 1)
    }

    static func fallbackSkills(from message: ChatMessage) -> [PersonaSkill] {
        let text = message.text.lowercased()
        var skills: [PersonaSkill] = []
        if text.contains("tone") || text.contains("polite") || text.contains("casual") {
            skills.append(.toneCoach)
        }
        if text.contains("grammar") || text.contains("nuance") || text.contains("structure") {
            skills.append(.grammarGuide)
        }
        if text.contains("culture") || text.contains("context") || text.contains("situation") {
            skills.append(.cultureSensei)
        }
        if text.contains("rewrite") || text.contains("draft") || text.contains("feedback") {
            skills.append(.rewriteMentor)
        }
        if text.contains("summary") || text.contains("short") {
            skills.append(.speedSummarizer)
        }
        if skills.isEmpty {
            skills.append(.crystalTranslation)
        }
        return Array(Set(skills))
    }
}
