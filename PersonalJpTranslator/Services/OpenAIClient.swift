//
//  OpenAIClient.swift
//  PersonalJpTranslator
//
//  Created by Codex on 11/14/25.
//

import Foundation
import OSLog

protocol OpenAIClientProtocol {
    func sendChat(messages: [ChatMessage]) async throws -> String
}

struct OpenAIClient: OpenAIClientProtocol {
    private let session: URLSession
    private let model: String
    private let maxRetries: Int
    private let requestTimeout: TimeInterval
    private let logger = Logger(subsystem: "PersonalJpTranslator", category: "OpenAIClient")

    init(session: URLSession? = nil,
         model: String = "gpt-4o-mini",
         maxRetries: Int = 1,
         requestTimeout: TimeInterval = 30) {
        if let session = session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = requestTimeout
            configuration.timeoutIntervalForResource = requestTimeout * 2
            self.session = URLSession(configuration: configuration)
        }
        self.model = model
        self.maxRetries = max(0, maxRetries)
        self.requestTimeout = requestTimeout
    }

    func sendChat(messages: [ChatMessage]) async throws -> String {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
            throw OpenAIClientError.missingAPIKey
        }

        let requestBody = ChatRequest(model: model,
                                      messages: messages.map(OpenAIMessage.init),
                                      temperature: 0.7)
        let requestData = try JSONEncoder().encode(requestBody)

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = requestTimeout
        request.httpBody = requestData

        var attempt = 0
        var lastError: Error?

        while attempt <= maxRetries {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OpenAIClientError.invalidResponse
                }

                guard (200..<300).contains(httpResponse.statusCode) else {
                    let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                    let serverError = OpenAIClientError.server(statusCode: httpResponse.statusCode, message: message)
                    if shouldRetry(statusCode: httpResponse.statusCode, attempt: attempt) {
                        lastError = serverError
                        attempt += 1
                        try await backoff(for: attempt)
                        continue
                    }
                    throw mapServerError(httpResponse.statusCode, message: message)
                }

                let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
                guard let content = decoded.choices.first?.message.content else {
                    throw OpenAIClientError.emptyResponse
                }

                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch is CancellationError {
                throw OpenAIClientError.cancelled
            } catch let error as URLError {
                if shouldRetry(urlError: error, attempt: attempt) {
                    lastError = error
                    attempt += 1
                    try await backoff(for: attempt)
                    continue
                }
                logger.error("OpenAI request failed with URL error: \(error.localizedDescription)")
                throw OpenAIClientError.transport(error)
            } catch {
                logger.error("OpenAI request failed: \(error.localizedDescription)")
                throw error
            }
        }

        throw lastError ?? OpenAIClientError.transport(URLError(.unknown))
    }

    private func shouldRetry(urlError: URLError, attempt: Int) -> Bool {
        guard attempt < maxRetries else { return false }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotFindHost:
            return true
        default:
            return false
        }
    }

    private func shouldRetry(statusCode: Int, attempt: Int) -> Bool {
        guard attempt < maxRetries else { return false }
        return statusCode == 429 || statusCode >= 500
    }

    private func backoff(for attempt: Int) async throws {
        let delay = UInt64(Double(attempt) * 0.75 * 1_000_000_000)
        try await Task.sleep(nanoseconds: delay)
    }

    private func mapServerError(_ status: Int, message: String) -> OpenAIClientError {
        switch status {
        case 401:
            return .unauthorized
        case 429:
            return .rateLimited(message: message)
        default:
            return .server(statusCode: status, message: message)
        }
    }
}

private struct ChatRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
}

private struct OpenAIMessage: Codable {
    let role: String
    let content: String

    init(from message: ChatMessage) {
        self.role = message.role.rawValue
        self.content = message.text
    }
}

private struct ChatResponse: Codable {
    struct Choice: Codable {
        struct ChoiceMessage: Codable {
            let role: String
            let content: String
        }

        let index: Int
        let message: ChoiceMessage
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }

    let choices: [Choice]
}

enum OpenAIClientError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case cancelled
    case transport(URLError)
    case server(statusCode: Int, message: String)
    case rateLimited(message: String)
    case unauthorized
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing OpenAI API Key. Please set OPENAI_API_KEY in your environment."
        case .invalidResponse:
            return "Received an invalid response from the OpenAI API."
        case .cancelled:
            return "Request cancelled."
        case .transport(let error):
            return "Network error: \(error.localizedDescription)"
        case .server(let status, let message):
            return "OpenAI API error (\(status)): \(message)"
        case .rateLimited(let message):
            return "Rate limited by OpenAI. Try again shortly. Details: \(message)"
        case .unauthorized:
            return "Invalid or missing OpenAI credentials."
        case .emptyResponse:
            return "The OpenAI API returned an empty response."
        }
    }
}
