//
//  UserProfile.swift
//  ephemera
//
//  Created by Kunal_Datta on 30/12/25.
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var email: String
    var dateOfBirth: Date
    var timeOfBirth: Date?
    var timeOfBirthUnknown: Bool
    var placeOfBirth: String?
    var placeOfBirthLatitude: Double?
    var placeOfBirthLongitude: Double?
    var placeOfBirthUnknown: Bool
    var authProvider: String // "google" or "email"
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        dateOfBirth: Date,
        timeOfBirth: Date? = nil,
        timeOfBirthUnknown: Bool = false,
        placeOfBirth: String? = nil,
        placeOfBirthLatitude: Double? = nil,
        placeOfBirthLongitude: Double? = nil,
        placeOfBirthUnknown: Bool = false,
        authProvider: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.dateOfBirth = dateOfBirth
        self.timeOfBirth = timeOfBirth
        self.timeOfBirthUnknown = timeOfBirthUnknown
        self.placeOfBirth = placeOfBirth
        self.placeOfBirthLatitude = placeOfBirthLatitude
        self.placeOfBirthLongitude = placeOfBirthLongitude
        self.placeOfBirthUnknown = placeOfBirthUnknown
        self.authProvider = authProvider
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

