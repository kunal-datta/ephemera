//
//  PlacesService.swift
//  ephemera
//
//  Created by Kunal_Datta on 30/12/25.
//

import Foundation

// MARK: - Place Model

struct PlacePrediction: Identifiable, Equatable {
    let id: String
    let mainText: String      // City name
    let secondaryText: String // Region, Country
    let fullText: String      // Complete description
    
    var displayText: String {
        if secondaryText.isEmpty {
            return mainText
        }
        return "\(mainText), \(secondaryText)"
    }
}

struct PlaceDetails {
    let placeId: String
    let name: String
    let formattedAddress: String
    let latitude: Double
    let longitude: Double
    let timezoneId: String?        // IANA timezone ID (e.g., "America/New_York")
    let timezoneOffsetSeconds: Int? // UTC offset in seconds
}

// MARK: - Places Service

class PlacesService: ObservableObject {
    static let shared = PlacesService()
    
    @Published var predictions: [PlacePrediction] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private var searchTask: Task<Void, Never>?
    private let apiKey: String
    
    private init() {
        // Get API key from Info.plist
        if let key = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_PLACES_API_KEY") as? String {
            self.apiKey = key
        } else {
            self.apiKey = ""
            print("⚠️ GOOGLE_PLACES_API_KEY not found in Info.plist")
        }
    }
    
    /// Search for place predictions based on input text
    func searchPlaces(query: String) {
        // Cancel any existing search
        searchTask?.cancel()
        
        // Clear results if query is too short
        guard query.count >= 2 else {
            predictions = []
            return
        }
        
        isLoading = true
        error = nil
        
        searchTask = Task {
            // Debounce - wait a bit before making request
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            
            guard !Task.isCancelled else { return }
            
            do {
                let results = try await fetchPredictions(for: query)
                
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self.predictions = results
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self.error = error.localizedDescription
                    self.isLoading = false
                    print("❌ Places API error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Clear all predictions
    func clearPredictions() {
        searchTask?.cancel()
        predictions = []
        isLoading = false
        error = nil
    }
    
    /// Fetch place details including coordinates and timezone
    /// Pass a reference date (like birth date) to get accurate historical timezone info
    func fetchPlaceDetails(placeId: String, referenceDate: Date? = nil) async throws -> PlaceDetails {
        guard !apiKey.isEmpty else {
            throw PlacesError.missingApiKey
        }
        
        let urlString = "https://places.googleapis.com/v1/places/\(placeId)"
        
        guard let url = URL(string: urlString) else {
            throw PlacesError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("displayName,formattedAddress,location", forHTTPHeaderField: "X-Goog-FieldMask")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlacesError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Places Details API response (\(httpResponse.statusCode)): \(responseString)")
            }
            throw PlacesError.httpError(httpResponse.statusCode)
        }
        
        let result = try JSONDecoder().decode(PlaceDetailsResponse.self, from: data)
        
        let latitude = result.location?.latitude ?? 0
        let longitude = result.location?.longitude ?? 0
        
        // Fetch timezone for this location
        let timezone = try? await fetchTimezone(
            latitude: latitude,
            longitude: longitude,
            timestamp: referenceDate ?? Date()
        )
        
        return PlaceDetails(
            placeId: placeId,
            name: result.displayName?.text ?? "",
            formattedAddress: result.formattedAddress ?? "",
            latitude: latitude,
            longitude: longitude,
            timezoneId: timezone?.timezoneId,
            timezoneOffsetSeconds: timezone?.utcOffsetSeconds
        )
    }
    
    // MARK: - Timezone API
    
    /// Fetches timezone information for a given location and timestamp
    /// Uses Google Timezone API: https://developers.google.com/maps/documentation/timezone
    func fetchTimezone(latitude: Double, longitude: Double, timestamp: Date) async throws -> TimezoneResult {
        guard !apiKey.isEmpty else {
            throw PlacesError.missingApiKey
        }
        
        // Convert date to Unix timestamp
        let unixTimestamp = Int(timestamp.timeIntervalSince1970)
        
        // Build URL with query parameters
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/timezone/json")!
        components.queryItems = [
            URLQueryItem(name: "location", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "timestamp", value: String(unixTimestamp)),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = components.url else {
            throw PlacesError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlacesError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Timezone API response (\(httpResponse.statusCode)): \(responseString)")
            }
            throw PlacesError.httpError(httpResponse.statusCode)
        }
        
        let result = try JSONDecoder().decode(TimezoneAPIResponse.self, from: data)
        
        // Check for API-level errors
        if result.status != "OK" {
            print("❌ Timezone API error: \(result.status) - \(result.errorMessage ?? "Unknown error")")
            throw PlacesError.apiError(result.status, result.errorMessage)
        }
        
        guard let timezoneId = result.timeZoneId else {
            throw PlacesError.invalidResponse
        }
        
        // Total offset = rawOffset + dstOffset
        let totalOffset = (result.rawOffset ?? 0) + (result.dstOffset ?? 0)
        
        print("📍 Timezone for (\(latitude), \(longitude)): \(timezoneId) (UTC\(totalOffset >= 0 ? "+" : "")\(totalOffset / 3600))")
        
        return TimezoneResult(
            timezoneId: timezoneId,
            timezoneName: result.timeZoneName ?? timezoneId,
            rawOffsetSeconds: result.rawOffset ?? 0,
            dstOffsetSeconds: result.dstOffset ?? 0,
            utcOffsetSeconds: totalOffset
        )
    }
    
    // MARK: - API Calls (Places API New)
    
    private func fetchPredictions(for query: String) async throws -> [PlacePrediction] {
        guard !apiKey.isEmpty else {
            throw PlacesError.missingApiKey
        }
        
        // Use Places API (New) - Autocomplete endpoint
        let urlString = "https://places.googleapis.com/v1/places:autocomplete"
        
        guard let url = URL(string: urlString) else {
            throw PlacesError.invalidURL
        }
        
        // Build request body
        // Max 5 types allowed - prioritize cities and neighborhoods
        let requestBody: [String: Any] = [
            "input": query,
            "includedPrimaryTypes": [
                "locality",                      // Cities
                "sublocality",                   // Neighborhoods (e.g., Northridge, Brooklyn)
                "neighborhood",                  // Neighborhoods
                "postal_town",                   // Postal towns (UK)
                "administrative_area_level_3"    // Minor civil divisions
            ],
            "languageCode": "en"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("suggestions.placePrediction.placeId,suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat", forHTTPHeaderField: "X-Goog-FieldMask")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlacesError.invalidResponse
        }
        
        // Debug: print response for troubleshooting
        if httpResponse.statusCode != 200 {
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Places API response (\(httpResponse.statusCode)): \(responseString)")
            }
            throw PlacesError.httpError(httpResponse.statusCode)
        }
        
        let result = try JSONDecoder().decode(PlacesNewAutocompleteResponse.self, from: data)
        
        return result.suggestions?.compactMap { suggestion -> PlacePrediction? in
            guard let prediction = suggestion.placePrediction else { return nil }
            
            let mainText = prediction.structuredFormat?.mainText?.text ?? prediction.text?.text ?? ""
            let secondaryText = prediction.structuredFormat?.secondaryText?.text ?? ""
            let fullText = prediction.text?.text ?? mainText
            
            return PlacePrediction(
                id: prediction.placeId ?? UUID().uuidString,
                mainText: mainText,
                secondaryText: secondaryText,
                fullText: fullText
            )
        } ?? []
    }
}

// MARK: - Places API (New) Response Models

private struct PlacesNewAutocompleteResponse: Codable {
    let suggestions: [Suggestion]?
}

private struct Suggestion: Codable {
    let placePrediction: PlacePredictionResponse?
}

private struct PlacePredictionResponse: Codable {
    let placeId: String?
    let text: TextValue?
    let structuredFormat: StructuredFormat?
}

private struct StructuredFormat: Codable {
    let mainText: TextValue?
    let secondaryText: TextValue?
}

private struct TextValue: Codable {
    let text: String?
}

private struct PlaceDetailsResponse: Codable {
    let displayName: TextValue?
    let formattedAddress: String?
    let location: LatLng?
}

private struct LatLng: Codable {
    let latitude: Double?
    let longitude: Double?
}

// MARK: - Timezone API Response

private struct TimezoneAPIResponse: Codable {
    let status: String
    let errorMessage: String?
    let dstOffset: Int?       // DST offset in seconds
    let rawOffset: Int?       // Standard time offset in seconds
    let timeZoneId: String?   // IANA timezone ID (e.g., "America/New_York")
    let timeZoneName: String? // Human-readable name (e.g., "Eastern Daylight Time")
}

/// Result of timezone lookup
struct TimezoneResult {
    let timezoneId: String         // IANA ID (e.g., "America/New_York")
    let timezoneName: String       // Display name (e.g., "Eastern Daylight Time")
    let rawOffsetSeconds: Int      // Standard time offset from UTC
    let dstOffsetSeconds: Int      // Additional DST offset (0 if not in DST)
    let utcOffsetSeconds: Int      // Total offset (raw + dst)
    
    /// Formatted offset string (e.g., "UTC-5" or "UTC+5:30")
    var formattedOffset: String {
        let hours = utcOffsetSeconds / 3600
        let minutes = abs((utcOffsetSeconds % 3600) / 60)
        
        if minutes == 0 {
            return "UTC\(hours >= 0 ? "+" : "")\(hours)"
        } else {
            return "UTC\(hours >= 0 ? "+" : "")\(hours):\(String(format: "%02d", minutes))"
        }
    }
}

// MARK: - Errors

enum PlacesError: LocalizedError {
    case missingApiKey
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String, String?)
    
    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "Google Places API key is not configured"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let status, let message):
            return message ?? "API error: \(status)"
        }
    }
}
