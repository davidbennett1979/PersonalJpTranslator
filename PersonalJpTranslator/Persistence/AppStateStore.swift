//
//  AppStateStore.swift
//  PersonalJpTranslator
//
//  Created by Codex on 11/14/25.
//

import Foundation
import Combine

@MainActor
final class AppStateStore: ObservableObject {
    @Published private(set) var conversation: Conversation
    @Published private(set) var userProfile: UserProfile

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let fileURL: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default, fileName: String = "AppState.json") {
        self.fileManager = fileManager
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        var directory = baseDirectory.appendingPathComponent("PersonalJpTranslator", isDirectory: true)

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try directory.setResourceValues(resourceValues)
        } catch {
            print("Failed to prepare persistence directory: \(error)")
        }

        self.fileURL = directory.appendingPathComponent(fileName)

        if let data = try? Data(contentsOf: fileURL),
           let state = try? decoder.decode(AppState.self, from: data) {
            self.conversation = state.conversation
            self.userProfile = state.userProfile
        } else {
            self.conversation = Conversation()
            self.userProfile = UserProfile()
        }
    }

    func save() {
        let state = AppState(conversation: conversation, userProfile: userProfile)
        do {
            let data = try encoder.encode(state)
            let url = fileURL
            let directory = fileURL.deletingLastPathComponent()
            let fm = fileManager
            Task.detached(priority: .background) {
                do {
                    try fm.createDirectory(at: directory, withIntermediateDirectories: true)
                    try data.write(to: url, options: [.atomic])
                } catch {
                    print("Failed to persist app state: \(error)")
                }
            }
        } catch {
            print("Encoding error: \(error)")
        }
    }

    func resetAll() {
        conversation = Conversation()
        userProfile = UserProfile()
        save()
    }

    func updateConversation(_ update: (inout Conversation) -> Void) {
        var copy = conversation
        update(&copy)
        conversation = copy
    }

    func updateUserProfile(_ update: (inout UserProfile) -> Void) {
        var copy = userProfile
        update(&copy)
        userProfile = copy
    }
}

private struct AppState: Codable {
    var conversation: Conversation
    var userProfile: UserProfile
}
