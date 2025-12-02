//
//  Device.swift
//  Location Simulator Boss
//
//  Created by Yugo Ogura on 2025-12-02.
//

import Foundation

enum DeviceType: String, Codable {
    case iOSSimulator
    case androidEmulator
}

struct Device: Identifiable, Hashable {
    let id: String  // UDID for iOS, device serial for Android
    let name: String
    let type: DeviceType
    
    var displayName: String {
        switch type {
        case .iOSSimulator:
            return "📱 \(name)"
        case .androidEmulator:
            return "🤖 \(name)"
        }
    }
}
