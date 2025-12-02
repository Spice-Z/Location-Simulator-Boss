//
//  FavoritesManager.swift
//  Location Simulator Boss
//
//  Created by Yugo Ogura on 2025-12-02.
//

import Foundation
import SwiftUI
import Observation

@Observable
class FavoritesManager {
    var favoriteRoutes: [FavoriteRoute] = []
    
    private let userDefaultsKey = "favoriteRoutes"
    
    init() {
        loadFavorites()
    }
    
    func addFavorite(_ route: FavoriteRoute) {
        favoriteRoutes.append(route)
        saveFavorites()
    }
    
    func removeFavorite(_ route: FavoriteRoute) {
        favoriteRoutes.removeAll { $0.id == route.id }
        saveFavorites()
    }
    
    func removeFavorite(at offsets: IndexSet) {
        favoriteRoutes.remove(atOffsets: offsets)
        saveFavorites()
    }
    
    func updateFavorite(_ route: FavoriteRoute) {
        if let index = favoriteRoutes.firstIndex(where: { $0.id == route.id }) {
            favoriteRoutes[index] = route
            saveFavorites()
        }
    }
    
    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favoriteRoutes)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save favorites: \(error)")
        }
    }
    
    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        
        do {
            favoriteRoutes = try JSONDecoder().decode([FavoriteRoute].self, from: data)
        } catch {
            print("Failed to load favorites: \(error)")
        }
    }
}

