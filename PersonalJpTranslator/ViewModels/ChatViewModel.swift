//
//  ChatViewModel.swift
//  PersonalJpTranslator
//
//  Created by Codex on 11/14/25.
//

import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var personalizationSummary: String = ""

    private let store: AppStateStore
    private let client: OpenAIClientProtocol
    private var cancellables = Set<AnyCancellable>()
    private var sendTask: Task<Void, Never>?

    init(store: AppStateStore, client: OpenAIClientProtocol) {
        self.store = store
        self.client = client
        self.messages = store.conversation.messages

        store.$conversation
            .map(\.messages)
            .receive(on: RunLoop.main)
            .sink { [weak self] newMessages in
                self?.messages = newMessages
            }
            .store(in: &cancellables)

        store.$userProfile
            .receive(on: RunLoop.main)
            .sink { [weak self] profile in
                self?.personalizationSummary = profile.learningSummary
            }
            .store(in: &cancellables)
    }

    func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        sendTask?.cancel()

        let intent = inferIntent(for: trimmed)
        let skillHints = skillHints(for: intent)
        let userMessage = ChatMessage(role: .user, text: trimmed, skillHints: skillHints)
        append(message: userMessage)
        inputText = ""

        store.updateUserProfile { profile in
            profile.recordQuestion()
        }
        store.save()

        sendTask = Task { [weak self] in
            guard let self else { return }
            await self.requestResponse(for: userMessage, intent: intent, skillHints: skillHints)
        }
    }

    func rate(message: ChatMessage, rating: Int) {
        guard message.role == .assistant else { return }
        guard message.rating != rating else { return }

        var updatedMessage = message
        updatedMessage.rating = rating

        store.updateConversation { conversation in
            conversation.replaceMessage(updatedMessage)
            if rating > 0 {
                conversation.addHighlight(for: message)
            }
        }

        let skills = message.skillHints ?? SkillEngine.fallbackSkills(from: message)
        store.updateUserProfile { profile in
            profile.apply(rating: rating, feedbackSource: message)
            let delta = rating > 0 ? 2 : -1
            profile.adjustSkills(skills, delta: delta)
        }

        store.save()
    }

    func clearChat() {
        store.updateConversation { conversation in
            conversation = Conversation()
        }
        sendTask?.cancel()
        store.save()
    }

    private func append(message: ChatMessage) {
        store.updateConversation { conversation in
            conversation.appendMessage(message)
        }
        store.save()
    }

    private func requestResponse(for userMessage: ChatMessage, intent: InteractionIntent, skillHints: [PersonaSkill]) async {
        isLoading = true
        defer {
            isLoading = false
            sendTask = nil
        }

        do {
            let context = buildMessages(for: userMessage, intent: intent)
            let responseText = try await client.sendChat(messages: context)
            let assistantMessage = ChatMessage(role: .assistant, text: responseText, skillHints: skillHints)
            append(message: assistantMessage)
        } catch is CancellationError {
            errorMessage = "Request cancelled."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buildMessages(for userMessage: ChatMessage, intent: InteractionIntent) -> [ChatMessage] {
        let profile = store.userProfile
        var components: [String] = [
            "You are a personalized Japanese ↔ English language partner.",
            "Infer the user's intent (translation, comprehension, tone adjustment, or writing feedback) from their message automatically.",
            intent.systemDirective
        ]

        components.append(profile.ratingSummary)

        if !store.conversation.preferenceHints.isEmpty {
            components.append(store.conversation.preferenceHints)
        }
        let skillPrompt = SkillEngine.promptAdditions(from: profile.skillScores)
        if !skillPrompt.isEmpty {
            components.append(skillPrompt)
        }

        let systemMessage = ChatMessage(role: .system, text: components.joined(separator: " "))

        var history = store.conversation.messages
        if let index = history.firstIndex(where: { $0.id == userMessage.id }) {
            history.remove(at: index)
        }
        let recentHistory = Array(history.suffix(6))

        var guidance = [
            "Detected intent: \(intent.summary)",
            "Tasks:",
            "- detect what the user needs (translation, explanation, rewrite, or feedback).",
            "- follow the directive: \(intent.userFacingDirective)",
            "- keep tone friendly and adaptive; invite the user to rate or ask follow-ups."
        ]
        if let snippet = profile.lastFeedbackSnippet, !snippet.isEmpty {
            guidance.append("Remember the user liked responses similar to: \(snippet)")
        }
        let instructionMessage = ChatMessage(role: .system, text: guidance.joined(separator: " "))

        return [systemMessage, instructionMessage] + recentHistory + [userMessage]
    }
}

private extension ChatViewModel {
    enum InteractionIntent {
        case translationOnly
        case explanationOrFeedback
        case general

        var systemDirective: String {
            switch self {
            case .translationOnly:
                return "When the user simply pastes non-native text without asking for extra detail, focus on delivering the cleanest translation and limit follow-up commentary to one short sentence only when essential."
            case .explanationOrFeedback:
                return "The user is requesting explanations, feedback, or tone adjustments—provide a clear translation if needed, followed by thorough but concise guidance."
            case .general:
                return "Provide helpful translations first when necessary, then add brief explanations only if they aid understanding."
            }
        }

        var userFacingDirective: String {
            switch self {
            case .translationOnly:
                return "Give the translation only; add at most one brief note if a nuance is critical."
            case .explanationOrFeedback:
                return "Offer translation plus the requested explanation/feedback with actionable pointers."
            case .general:
                return "Interpret the request and respond with translation plus minimal context."
            }
        }

        var summary: String {
            switch self {
            case .translationOnly:
                return "Quick translation"
            case .explanationOrFeedback:
                return "Detailed explanation/feedback"
            case .general:
                return "Mixed intent"
            }
        }
    }

    func inferIntent(for text: String) -> InteractionIntent {
        let lower = text.lowercased()
        let explanationKeywords = ["explain", "explanation", "grammar", "nuance", "why", "meaning", "breakdown"]
        let feedbackKeywords = ["feedback", "revise", "rewrite", "tone", "sound natural", "make it", "improve", "check"]

        if explanationKeywords.contains(where: { lower.contains($0) }) ||
            feedbackKeywords.contains(where: { lower.contains($0) }) {
            return .explanationOrFeedback
        }

        let hasJapanese = text.range(of: #"[一-龯ぁ-んァ-ン]"#, options: .regularExpression) != nil
        let hasLatin = text.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil

        if hasJapanese && !hasLatin {
            return .translationOnly
        }

        return .general
    }

    func skillHints(for intent: InteractionIntent) -> [PersonaSkill] {
        switch intent {
        case .translationOnly:
            return [.crystalTranslation, .speedSummarizer]
        case .explanationOrFeedback:
            return [.grammarGuide, .toneCoach, .rewriteMentor]
        case .general:
            return [.crystalTranslation, .grammarGuide]
        }
    }
}
