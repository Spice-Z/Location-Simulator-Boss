//
//  Location_Simulator_BossApp.swift
//  Location Simulator Boss
//
//  Created by Yugo Ogura on 2025-12-02.
//

import SwiftUI

@main
struct Location_Simulator_BossApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .windowResizability(.contentSize)
        
        // Route Editor Window
        WindowGroup(id: "route-editor", for: RouteEditorData.self) { $data in
            if let data = data {
                RouteEditorView(
                    mode: data.mode,
                    favoritesManager: appState.favoritesManager,
                    routeSimulator: appState.routeSimulator,
                    onRouteReady: { shouldStart in
                        if shouldStart {
                            appState.shouldStartSimulation = true
                        }
                    }
                )
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1000, height: 700)
    }
}

// Shared app state
@Observable
class AppState {
    var favoritesManager = FavoritesManager()
    var routeSimulator = RouteSimulator()
    var shouldStartSimulation = false
}

// Data to pass to route editor window
struct RouteEditorData: Codable, Hashable {
    let mode: RouteEditorMode
    
    enum CodingKeys: String, CodingKey {
        case modeType
        case routeId
    }
    
    init(mode: RouteEditorMode) {
        self.mode = mode
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let modeType = try container.decode(String.self, forKey: .modeType)
        
        if modeType == "create" {
            self.mode = .create
        } else {
            // For edit mode, we just store create as placeholder - actual route is passed differently
            self.mode = .create
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch mode {
        case .create:
            try container.encode("create", forKey: .modeType)
        case .edit:
            try container.encode("edit", forKey: .modeType)
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch mode {
        case .create:
            hasher.combine("create")
        case .edit(let route):
            hasher.combine("edit")
            hasher.combine(route.id)
        }
    }
    
    static func == (lhs: RouteEditorData, rhs: RouteEditorData) -> Bool {
        switch (lhs.mode, rhs.mode) {
        case (.create, .create):
            return true
        case (.edit(let l), .edit(let r)):
            return l.id == r.id
        default:
            return false
        }
    }
}
