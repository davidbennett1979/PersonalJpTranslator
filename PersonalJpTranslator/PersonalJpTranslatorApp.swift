//
//  PersonalJpTranslatorApp.swift
//  PersonalJpTranslator
//
//  Created by David Bennett on 11/14/25.
//

import SwiftUI

@main
struct PersonalJpTranslatorApp: App {
    @StateObject private var store: AppStateStore
    @StateObject private var chatViewModel: ChatViewModel
    @StateObject private var settingsViewModel: SettingsViewModel

    init() {
        let store = AppStateStore()
        _store = StateObject(wrappedValue: store)
        let client = OpenAIClient()
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(store: store, client: client))
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(chatViewModel)
                .environmentObject(settingsViewModel)
        }
    }
}
