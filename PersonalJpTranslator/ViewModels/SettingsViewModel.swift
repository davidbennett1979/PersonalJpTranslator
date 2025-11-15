//
//  SettingsViewModel.swift
//  PersonalJpTranslator
//
//  Created by Codex on 11/14/25.
//

import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var userProfile: UserProfile
    @Published private(set) var totalQuestions: Int
    @Published private(set) var likedAnswers: Int
    @Published private(set) var dislikedAnswers: Int
    @Published private(set) var highlightSummary: String = ""
    @Published private(set) var skillCategories: [SkillCategoryProgress] = []

    private let store: AppStateStore
    private var cancellables = Set<AnyCancellable>()

    init(store: AppStateStore) {
        self.store = store
        self.userProfile = store.userProfile
        self.totalQuestions = store.userProfile.totalQuestions
        self.likedAnswers = store.userProfile.likedAnswers
        self.dislikedAnswers = store.userProfile.dislikedAnswers
        self.skillCategories = Self.buildSkillCategories(from: store.userProfile)

        store.$userProfile
            .receive(on: RunLoop.main)
            .sink { [weak self] profile in
                self?.userProfile = profile
                self?.totalQuestions = profile.totalQuestions
                self?.likedAnswers = profile.likedAnswers
                self?.dislikedAnswers = profile.dislikedAnswers
                self?.skillCategories = Self.buildSkillCategories(from: profile)
            }
            .store(in: &cancellables)

        store.$conversation
            .receive(on: RunLoop.main)
            .sink { [weak self] conversation in
                let hints = conversation.preferenceHints
                self?.highlightSummary = hints.isEmpty ? "No highlights yet. Upvote great explanations to teach the assistant." : hints
            }
            .store(in: &cancellables)
    }

    func clearConversation() {
        store.updateConversation { conversation in
            conversation = Conversation()
        }
        store.save()
    }

    func resetPersonalization() {
        store.resetAll()
    }

    struct SkillCategoryProgress: Identifiable {
        var id: String { category.id }
        let category: SkillCategory
        let skills: [SkillProgress]
        let totalScore: Int
    }

    struct SkillProgress: Identifiable {
        var id: String { skill.id }
        let skill: PersonaSkill
        let score: Int
        let progress: Double
    }

    private static func buildSkillCategories(from profile: UserProfile) -> [SkillCategoryProgress] {
        SkillEngine.categoryMap.map { category, skills in
            let skillProgress = skills.map { skill in
                SkillProgress(
                    skill: skill,
                    score: SkillEngine.score(for: skill, in: profile.skillScores),
                    progress: SkillEngine.progress(for: SkillEngine.score(for: skill, in: profile.skillScores))
                )
            }
            let total = skillProgress.reduce(0) { $0 + $1.score }
            return SkillCategoryProgress(category: category, skills: skillProgress, totalScore: total)
        }
        .sorted { $0.totalScore > $1.totalScore }
    }
}
