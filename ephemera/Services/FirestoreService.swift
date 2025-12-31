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
            "placeOfBirthTimezone": profile.placeOfBirthTimezone as Any,
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
    
    // MARK: - Birth Charts
    
    /// Saves birth chart to Firestore
    func saveBirthChart(_ chart: BirthChart) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.notAuthenticated
        }
        
        let data: [String: Any] = [
            "id": chart.id.uuidString,
            "userId": chart.userId.uuidString,
            "chartType": chart.chartType,
            "status": chart.status,
            "errorsJSON": chart.errorsJSON,
            "metadataJSON": chart.metadataJSON,
            "anglesJSON": chart.anglesJSON as Any,
            "housesJSON": chart.housesJSON as Any,
            "planetsJSON": chart.planetsJSON,
            "aspectsJSON": chart.aspectsJSON as Any,
            "evolutionaryCoreJSON": chart.evolutionaryCoreJSON,
            "createdAt": Timestamp(date: chart.createdAt),
            "updatedAt": Timestamp(date: Date())
        ]
        
        try await db.collection("users").document(userId).collection("birthCharts").document(chart.id.uuidString).setData(data)
        print("✅ Birth chart saved to Firestore for userId: \(userId)")
    }
    
    /// Fetches the user's birth chart from Firestore
    func fetchBirthChart() async throws -> BirthChart? {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.notAuthenticated
        }
        
        let snapshot = try await db.collection("users").document(userId).collection("birthCharts")
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments()
        
        guard let document = snapshot.documents.first else {
            return nil
        }
        
        return parseBirthChart(from: document.data())
    }
    
    /// Fetches a specific birth chart by ID
    func fetchBirthChart(chartId: String) async throws -> BirthChart? {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.notAuthenticated
        }
        
        let document = try await db.collection("users").document(userId).collection("birthCharts").document(chartId).getDocument()
        
        guard document.exists, let data = document.data() else {
            return nil
        }
        
        return parseBirthChart(from: data)
    }
    
    private func parseBirthChart(from data: [String: Any]) -> BirthChart? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let userIdString = data["userId"] as? String,
              let userId = UUID(uuidString: userIdString),
              let chartType = data["chartType"] as? String,
              let status = data["status"] as? String,
              let metadataJSON = data["metadataJSON"] as? String,
              let planetsJSON = data["planetsJSON"] as? String,
              let evolutionaryCoreJSON = data["evolutionaryCoreJSON"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            return nil
        }
        
        // Handle errorsJSON - prefer new format, fall back to legacy format
        let errorsJSON: String
        if let storedErrorsJSON = data["errorsJSON"] as? String {
            errorsJSON = storedErrorsJSON
        } else if let legacyErrors = data["errors"] as? [String] {
            // Convert legacy format to JSON
            errorsJSON = (try? String(data: JSONEncoder().encode(legacyErrors), encoding: .utf8)) ?? "[]"
        } else {
            errorsJSON = "[]"
        }
        
        let anglesJSON = data["anglesJSON"] as? String
        let housesJSON = data["housesJSON"] as? String
        let aspectsJSON = data["aspectsJSON"] as? String
        let updatedAtTimestamp = data["updatedAt"] as? Timestamp ?? createdAtTimestamp
        
        let chart = BirthChart(
            id: id,
            userId: userId,
            chartType: chartType,
            status: status,
            errors: [],  // Will be overwritten below
            metadata: ChartMetadata(
                birthDate: Date(),
                birthTimeInput: nil,
                birthPlaceInput: nil,
                latitude: nil,
                longitude: nil,
                timezone: nil,
                houseSystem: "WHOLE_SIGN",
                nodeType: "true",
                utcDateTimeUsed: nil,
                julianDay: nil,
                assumptions: []
            ),
            angles: nil,
            houses: nil,
            planets: [],
            aspects: nil,
            evolutionaryCore: EvolutionaryCore(
                pluto: nil,
                northNode: nil,
                southNode: nil,
                moon: nil,
                sun: nil,
                risingSign: nil,
                notes: []
            ),
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: updatedAtTimestamp.dateValue()
        )
        
        // Override with actual JSON data
        chart.errorsJSON = errorsJSON
        chart.metadataJSON = metadataJSON
        chart.anglesJSON = anglesJSON
        chart.housesJSON = housesJSON
        chart.planetsJSON = planetsJSON
        chart.aspectsJSON = aspectsJSON
        chart.evolutionaryCoreJSON = evolutionaryCoreJSON
        
        return chart
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
        let placeOfBirthTimezone = data["placeOfBirthTimezone"] as? String
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
            placeOfBirthTimezone: placeOfBirthTimezone,
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

