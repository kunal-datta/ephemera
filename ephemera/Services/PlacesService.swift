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
    
    // MARK: - API Calls
    
    private func fetchPredictions(for query: String) async throws -> [PlacePrediction] {
        guard !apiKey.isEmpty else {
            throw PlacesError.missingApiKey
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        // Use Places Autocomplete API - filter to cities only
        let urlString = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=\(encodedQuery)&types=(cities)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw PlacesError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlacesError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw PlacesError.httpError(httpResponse.statusCode)
        }
        
        let result = try JSONDecoder().decode(PlacesAutocompleteResponse.self, from: data)
        
        if result.status != "OK" && result.status != "ZERO_RESULTS" {
            throw PlacesError.apiError(result.status, result.errorMessage)
        }
        
        return result.predictions.map { prediction in
            PlacePrediction(
                id: prediction.placeId,
                mainText: prediction.structuredFormatting.mainText,
                secondaryText: prediction.structuredFormatting.secondaryText ?? "",
                fullText: prediction.description
            )
        }
    }
}

// MARK: - API Response Models

private struct PlacesAutocompleteResponse: Codable {
    let predictions: [AutocompletePrediction]
    let status: String
    let errorMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case predictions, status
        case errorMessage = "error_message"
    }
}

private struct AutocompletePrediction: Codable {
    let placeId: String
    let description: String
    let structuredFormatting: StructuredFormatting
    
    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case description
        case structuredFormatting = "structured_formatting"
    }
}

private struct StructuredFormatting: Codable {
    let mainText: String
    let secondaryText: String?
    
    enum CodingKeys: String, CodingKey {
        case mainText = "main_text"
        case secondaryText = "secondary_text"
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

