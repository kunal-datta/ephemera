//
//  AIReadingService.swift
//  ephemera
//
//  Generates personalized astrological readings using Firebase AI (Gemini).
//  Combines birth chart data with user life context for deeply personal insights.
//
//  Created by Kunal_Datta on 30/12/25.
//

import Foundation
import FirebaseAI

/// Types of readings the AI can generate
enum ReadingType: String {
    case natalOverview = "natal_overview"    // Full birth chart interpretation
    case bigThree = "big_three"              // Sun, Moon, Rising focus
    case dailyGuidance = "daily"             // Daily transit reading
    case weeklyForecast = "weekly"           // Weekly themes
}

/// A generated reading from the AI
struct AIReading {
    let type: ReadingType
    let content: String
    let generatedAt: Date
    
    /// Sections parsed from the reading (if structured)
    var sections: [ReadingSection] {
        parseSecionsFromContent()
    }
    
    private func parseSecionsFromContent() -> [ReadingSection] {
        // Simple section parsing based on markdown-style headers
        var sections: [ReadingSection] = []
        let lines = content.components(separatedBy: "\n")
        var currentTitle: String?
        var currentBody: [String] = []
        
        for line in lines {
            if line.hasPrefix("## ") {
                // Save previous section
                if let title = currentTitle {
                    sections.append(ReadingSection(title: title, body: currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                currentTitle = String(line.dropFirst(3))
                currentBody = []
            } else if currentTitle != nil {
                currentBody.append(line)
            }
        }
        
        // Save last section
        if let title = currentTitle {
            sections.append(ReadingSection(title: title, body: currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        
        return sections
    }
}

struct ReadingSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

@MainActor
class AIReadingService: ObservableObject {
    static let shared = AIReadingService()
    
    @Published var isGenerating = false
    @Published var currentReading: AIReading?
    @Published var error: String?
    
    private let ai: FirebaseAI
    private let model: GenerativeModel
    
    private init() {
        // Initialize Firebase AI with Gemini Developer API backend
        self.ai = FirebaseAI.firebaseAI(backend: .googleAI())
        self.model = ai.generativeModel(modelName: "gemini-2.0-flash")
    }
    
    // MARK: - Generate Natal Chart Reading
    
    /// Generates a personalized natal chart reading
    func generateNatalReading(
        chart: BirthChart,
        profile: UserProfile,
        contexts: [UserContext]
    ) async throws -> AIReading {
        isGenerating = true
        error = nil
        
        defer { isGenerating = false }
        
        let prompt = buildNatalReadingPrompt(chart: chart, profile: profile, contexts: contexts)
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let text = response.text else {
                throw AIReadingError.noResponse
            }
            
            let reading = AIReading(
                type: .natalOverview,
                content: text,
                generatedAt: Date()
            )
            
            currentReading = reading
            return reading
            
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Prompt Building
    
    private func buildNatalReadingPrompt(
        chart: BirthChart,
        profile: UserProfile,
        contexts: [UserContext]
    ) -> String {
        let chartSummary = buildChartSummary(chart: chart)
        let contextSummary = contexts.formattedForPrompt()
        
        return """
        You are a wise, compassionate evolutionary astrologer. Your role is to help \(profile.name) understand their birth chart in a way that feels deeply personal and meaningful.
        
        ## Your Philosophy
        - You practice evolutionary astrology, which sees the birth chart as a map of the soul's journey
        - You focus on growth, potential, and lessons rather than fixed predictions
        - The North Node represents where the soul is growing toward; the South Node represents past patterns
        - Challenging aspects are opportunities for transformation, not doom
        - You never fear-monger or predict negative outcomes
        - You make the person feel unique and special — their life story matters
        
        ## Your Tone
        - Warm, kind, and compassionate
        - Grounded and practical, not overly mystical
        - Personal and specific, not generic
        - Encouraging and empowering
        - Write as if speaking directly to \(profile.name)
        
        ## The Person
        Name: \(profile.name)
        
        ## Their Birth Chart
        \(chartSummary)
        
        ## What They've Shared About Their Life
        \(contextSummary)
        
        ## Your Task
        Write a personalized natal chart reading for \(profile.name). This should feel like it was written specifically for them, weaving together:
        1. Their chart placements and what they mean for their unique journey
        2. The life context they've shared (if any)
        3. Insights about their soul's evolutionary path
        
        Structure your reading with these sections (use ## headers):
        
        ## Your Cosmic Blueprint
        A warm, personal introduction that captures the essence of their chart and makes them feel seen.
        
        ## The Core of Who You Are
        Their Sun sign and placement — their identity, vitality, and life purpose. Connect it to what you know about them.
        
        ## Your Emotional World
        Their Moon sign and placement — their inner life, needs, and what nurtures them.
        
        ## How You Meet the World
        Their Rising sign (if known) — their approach to life and first impressions.
        
        ## Your Soul's Journey
        The North Node/South Node axis — where they're growing from and toward. This is the heart of evolutionary astrology.
        
        ## Gifts & Challenges
        Key aspects and patterns that represent their strengths and growth edges.
        
        ## A Message for You
        A closing paragraph that feels like personal encouragement from a wise friend.
        
        Keep the total reading around 800-1000 words. Be specific to their chart, not generic. If they've shared life context, weave it in naturally where relevant.
        """
    }
    
    private func buildChartSummary(chart: BirthChart) -> String {
        var summary = ""
        
        // Big Three
        if let sun = chart.position(for: .sun) {
            summary += "Sun: \(sun.sign.rawValue) at \(sun.formattedDegree)"
            if let house = sun.house { summary += " in House \(house)" }
            summary += "\n"
        }
        
        if let moon = chart.position(for: .moon) {
            summary += "Moon: \(moon.sign.rawValue) at \(moon.formattedDegree)"
            if let house = moon.house { summary += " in House \(house)" }
            if moon.signUncertain { summary += " (may be in adjacent sign)" }
            summary += "\n"
        }
        
        if let rising = chart.risingSign {
            summary += "Rising/Ascendant: \(rising.rawValue)\n"
        } else {
            summary += "Rising/Ascendant: Unknown (birth time not provided)\n"
        }
        
        summary += "\n"
        
        // Other planets
        summary += "Other Planetary Placements:\n"
        for position in chart.planets where ![.sun, .moon].contains(position.planet) {
            summary += "- \(position.planet.rawValue): \(position.sign.rawValue) \(position.formattedDegree)"
            if let house = position.house { summary += " (House \(house))" }
            if position.isRetrograde { summary += " Retrograde" }
            summary += "\n"
        }
        
        // Evolutionary core
        if let evoCore = chart.evolutionaryCore {
            summary += "\nEvolutionary Astrology Points:\n"
            if let northNode = evoCore.northNode {
                summary += "- North Node: \(northNode.sign.rawValue)"
                if let house = northNode.house { summary += " in House \(house)" }
                summary += " — Soul's growth direction\n"
            }
            if let southNode = evoCore.southNode {
                summary += "- South Node: \(southNode.sign.rawValue)"
                if let house = southNode.house { summary += " in House \(house)" }
                summary += " — Past patterns and gifts\n"
            }
            if let pluto = evoCore.pluto {
                summary += "- Pluto: \(pluto.sign.rawValue)"
                if let house = pluto.house { summary += " in House \(house)" }
                summary += " — Soul's evolutionary edge\n"
            }
        }
        
        // Aspects
        if let aspects = chart.aspects, !aspects.isEmpty {
            summary += "\nKey Aspects:\n"
            for aspect in aspects.prefix(8) {
                summary += "- \(aspect.planet1.rawValue) \(aspect.type.rawValue) \(aspect.planet2.rawValue) (orb: \(String(format: "%.1f", aspect.orb))°)\n"
            }
        }
        
        // Chart type note
        switch chart.chartType {
        case "NOON_CHART_NO_HOUSES":
            summary += "\nNote: Birth time unknown — houses and rising sign not available. Moon sign may vary.\n"
        case "SIGN_BASED_NO_HOUSES":
            summary += "\nNote: Only birth date known — limited chart data available.\n"
        default:
            break
        }
        
        return summary
    }
}

// MARK: - Errors

enum AIReadingError: LocalizedError {
    case noResponse
    case invalidChart
    
    var errorDescription: String? {
        switch self {
        case .noResponse:
            return "Unable to generate reading. Please try again."
        case .invalidChart:
            return "Chart data is incomplete."
        }
    }
}

