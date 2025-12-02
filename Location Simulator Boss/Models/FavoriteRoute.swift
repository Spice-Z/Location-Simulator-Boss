//
//  FavoriteRoute.swift
//  Location Simulator Boss
//
//  Created by Yugo Ogura on 2025-12-02.
//

import Foundation
import CoreLocation

struct FavoriteRoute: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let startName: String
    let startLatitude: Double
    let startLongitude: Double
    let endName: String
    let endLatitude: Double
    let endLongitude: Double
    let createdAt: Date
    
    var startCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: startLatitude, longitude: startLongitude)
    }
    
    var endCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: endLatitude, longitude: endLongitude)
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        startName: String,
        startCoordinate: CLLocationCoordinate2D,
        endName: String,
        endCoordinate: CLLocationCoordinate2D
    ) {
        self.id = id
        self.name = name
        self.startName = startName
        self.startLatitude = startCoordinate.latitude
        self.startLongitude = startCoordinate.longitude
        self.endName = endName
        self.endLatitude = endCoordinate.latitude
        self.endLongitude = endCoordinate.longitude
        self.createdAt = Date()
    }
}


