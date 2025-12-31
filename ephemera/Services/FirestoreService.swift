//
//  FirestoreService.swift
//  ephemera
//
//  Created by Kunal_Datta on 30/12/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - User Profile
    
    /// Saves user profile to Firestore
    func saveUserProfile(_ profile: UserProfile) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.notAuthenticated
        }
        
        let data: [String: Any] = [
            "id": profile.id.uuidString,
            "name": profile.name,
            "email": profile.email,
            "dateOfBirth": Timestamp(date: profile.dateOfBirth),
            "timeOfBirth": profile.timeOfBirth.map { Timestamp(date: $0) } as Any,
            "timeOfBirthUnknown": profile.timeOfBirthUnknown,
            "placeOfBirth": profile.placeOfBirth as Any,
            "placeOfBirthLatitude": profile.placeOfBirthLatitude as Any,
            "placeOfBirthLongitude": profile.placeOfBirthLongitude as Any,
            "placeOfBirthUnknown": profile.placeOfBirthUnknown,
            "authProvider": profile.authProvider,
            "createdAt": Timestamp(date: profile.createdAt),
            "updatedAt": Timestamp(date: Date())
        ]
        
        try await db.collection("users").document(userId).setData(data)
        print("✅ User profile saved to Firestore for userId: \(userId)")
    }
    
    /// Fetches user profile from Firestore
    func fetchUserProfile() async throws -> UserProfile? {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.notAuthenticated
        }
        
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard document.exists, let data = document.data() else {
            return nil
        }
        
        return parseUserProfile(from: data)
    }
    
    /// Updates user profile in Firestore
    func updateUserProfile(_ fields: [String: Any]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.notAuthenticated
        }
        
        var updateData = fields
        updateData["updatedAt"] = Timestamp(date: Date())
        
        try await db.collection("users").document(userId).updateData(updateData)
        print("✅ User profile updated in Firestore")
    }
    
    // MARK: - Helpers
    
    private func parseUserProfile(from data: [String: Any]) -> UserProfile? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = data["name"] as? String,
              let email = data["email"] as? String,
              let dateOfBirthTimestamp = data["dateOfBirth"] as? Timestamp,
              let authProvider = data["authProvider"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            return nil
        }
        
        let timeOfBirth = (data["timeOfBirth"] as? Timestamp)?.dateValue()
        let timeOfBirthUnknown = data["timeOfBirthUnknown"] as? Bool ?? false
        let placeOfBirth = data["placeOfBirth"] as? String
        let placeOfBirthLatitude = data["placeOfBirthLatitude"] as? Double
        let placeOfBirthLongitude = data["placeOfBirthLongitude"] as? Double
        let placeOfBirthUnknown = data["placeOfBirthUnknown"] as? Bool ?? false
        let updatedAtTimestamp = data["updatedAt"] as? Timestamp ?? createdAtTimestamp
        
        return UserProfile(
            id: id,
            name: name,
            email: email,
            dateOfBirth: dateOfBirthTimestamp.dateValue(),
            timeOfBirth: timeOfBirth,
            timeOfBirthUnknown: timeOfBirthUnknown,
            placeOfBirth: placeOfBirth,
            placeOfBirthLatitude: placeOfBirthLatitude,
            placeOfBirthLongitude: placeOfBirthLongitude,
            placeOfBirthUnknown: placeOfBirthUnknown,
            authProvider: authProvider,
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: updatedAtTimestamp.dateValue()
        )
    }
}

// MARK: - Errors

enum FirestoreError: LocalizedError {
    case notAuthenticated
    case documentNotFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .documentNotFound:
            return "Document not found"
        case .invalidData:
            return "Invalid data format"
        }
    }
}

