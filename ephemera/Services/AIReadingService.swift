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
    
    /// Chart elements this section relates to (for highlighting on the chart)
    var relatedPlanets: [Planet] {
        // Map section titles to relevant planets
        let lowercasedTitle = title.lowercased()
        
        if lowercasedTitle.contains("core") || lowercasedTitle.contains("identity") || lowercasedTitle.contains("sun") {
            return [.sun]
        } else if lowercasedTitle.contains("emotional") || lowercasedTitle.contains("moon") || lowercasedTitle.contains("inner") {
            return [.moon]
        } else if lowercasedTitle.contains("meet the world") || lowercasedTitle.contains("rising") || lowercasedTitle.contains("ascendant") {
            return [] // Rising is not a planet, handled separately
        } else if lowercasedTitle.contains("soul") || lowercasedTitle.contains("journey") || lowercasedTitle.contains("evolution") {
            return [.northNode, .southNode, .pluto]
        } else if lowercasedTitle.contains("alive") || lowercasedTitle.contains("now") || lowercasedTitle.contains("transit") {
            // Current transits - highlight outer planets typically involved
            return [.saturn, .jupiter, .uranus, .neptune, .pluto]
        } else if lowercasedTitle.contains("blueprint") || lowercasedTitle.contains("cosmic") {
            // Overview section - highlight the big three
            return [.sun, .moon]
        } else if lowercasedTitle.contains("message") || lowercasedTitle.contains("closing") {
            return [] // No specific highlight for closing
        }
        
        return []
    }
    
    /// Whether this section relates to the rising sign
    var relatestoRising: Bool {
        let lowercasedTitle = title.lowercased()
        return lowercasedTitle.contains("meet the world") || 
               lowercasedTitle.contains("rising") || 
               lowercasedTitle.contains("ascendant")
    }
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
        
        // Calculate current transits
        let transits = ChartCore.shared.getSignificantTransits(natalChart: chart, limit: 6)
        
        let prompt = buildNatalReadingPrompt(chart: chart, profile: profile, contexts: contexts, transits: transits)
        
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
    
    // MARK: - Generate Element Explanation
    
    /// Generates a personalized explanation for a specific chart element
    func generateElementExplanation(
        element: ChartElementSelection,
        chart: BirthChart,
        profile: UserProfile,
        contexts: [UserContext]
    ) async throws -> String {
        // Get transits relevant to this element
        let relevantTransits = getTransitsForElement(element: element, chart: chart)
        
        let prompt = buildElementExplanationPrompt(
            element: element,
            chart: chart,
            profile: profile,
            contexts: contexts,
            relevantTransits: relevantTransits
        )
        
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw AIReadingError.noResponse
        }
        
        return text
    }
    
    private func buildElementExplanationPrompt(
        element: ChartElementSelection,
        chart: BirthChart,
        profile: UserProfile,
        contexts: [UserContext],
        relevantTransits: [TransitAspect]
    ) -> String {
        let contextSummary = contexts.formattedForPrompt()
        let currentDate = formatCurrentDate()
        let elementDescription = describeElement(element)
        
        // Format relevant transits
        let transitInfo: String
        if relevantTransits.isEmpty {
            transitInfo = "No major transits are currently activating this placement."
        } else {
            transitInfo = relevantTransits.formattedForPrompt()
        }
        
        return """
        You are a wise, compassionate evolutionary astrologer writing a brief explanation of a specific chart placement.
        
        ## Your Approach
        - Warm, personal, and grounded
        - Never generic — this is about THEIR chart and life
        - Connect the astrological meaning to their actual experiences (if they've shared any)
        - Mention what this means right now (today is \(currentDate)) — especially if there are transits
        - Keep it concise but meaningful — about 150-250 words
        - Never fear-monger or predict negative outcomes
        - Frame challenges as growth opportunities
        - DO NOT start with a greeting like "Hi \(profile.name)" — jump straight into the explanation
        - DO NOT use their name excessively — once or twice at most, if at all
        
        ## The Person
        Name: \(profile.name)
        
        ## What They've Shared About Their Life
        \(contextSummary)
        
        ## Today's Date
        \(currentDate)
        
        ## What They Tapped On
        \(elementDescription)
        
        ## Current Transits Affecting This Placement
        \(transitInfo)
        
        ## Chart Context
        \(buildChartSummary(chart: chart))
        
        ## Your Task
        Write a brief, personal explanation of this placement. 
        
        Start directly with what this placement means, then connect it to:
        1. Their specific life context (if they've shared any)
        2. Any current transits that are activating this point — this is key for making it feel timely!
        3. How this energy might be showing up for them right now
        4. A brief insight or encouragement
        
        If there are significant transits to this placement, emphasize what's happening NOW and how it connects to this natal position.
        
        Write in second person ("You..."), as if speaking directly to them. Be warm and insightful. Don't use headers or bullet points — write in flowing prose. Start immediately with the content — no greeting.
        """
    }
    
    /// Get transits that are relevant to a specific chart element
    private func getTransitsForElement(element: ChartElementSelection, chart: BirthChart) -> [TransitAspect] {
        let allTransits = ChartCore.shared.calculateTransits(natalChart: chart)
        
        switch element {
        case .planet(let pos):
            // Get transits to this specific planet
            return allTransits.filter { $0.natalPlanet == pos.planet }
            
        case .bigThree(_, _, let planet):
            // Get transits to Sun, Moon, or Ascendant
            if let planet = planet {
                return allTransits.filter { $0.natalPlanet == planet }
            }
            // For Rising, we don't have transits to the Ascendant point directly in this model
            return []
            
        case .aspect(let asp):
            // Get transits to either planet in the aspect
            return allTransits.filter { $0.natalPlanet == asp.planet1 || $0.natalPlanet == asp.planet2 }
            
        case .evolutionaryPoint(_, let pos):
            // Get transits to this evolutionary point (node or Pluto)
            return allTransits.filter { $0.natalPlanet == pos.planet }
        }
    }
    
    private func describeElement(_ element: ChartElementSelection) -> String {
        switch element {
        case .planet(let pos):
            var desc = "\(pos.planet.rawValue) in \(pos.sign.rawValue) at \(pos.formattedDegree)"
            if let house = pos.house { desc += " in House \(house)" }
            if pos.isRetrograde { desc += " (Retrograde)" }
            return desc
            
        case .bigThree(let type, let sign, _):
            switch type {
            case "Sun":
                return "Sun in \(sign.rawValue) — their core identity, ego, and life purpose"
            case "Moon":
                return "Moon in \(sign.rawValue) — their emotional nature, inner needs, and instincts"
            case "Rising":
                return "Rising Sign / Ascendant in \(sign.rawValue) — how they approach life and appear to others"
            default:
                return "\(type) in \(sign.rawValue)"
            }
            
        case .aspect(let asp):
            let nature = asp.type.isHarmonious ? "harmonious" : "dynamic/challenging"
            return "\(asp.planet1.rawValue) \(asp.type.rawValue) \(asp.planet2.rawValue) — a \(nature) aspect with \(String(format: "%.1f", asp.orb))° orb"
            
        case .evolutionaryPoint(let title, let pos):
            var desc = "\(title) in \(pos.sign.rawValue) at \(pos.formattedDegree)"
            if let house = pos.house { desc += " in House \(house)" }
            switch title {
            case "North Node":
                desc += " — the soul's growth direction and life purpose"
            case "South Node":
                desc += " — past life patterns, comfort zone, and innate gifts"
            case "Pluto":
                desc += " — the soul's evolutionary edge and transformation"
            default:
                break
            }
            return desc
        }
    }
    
    private func formatCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: Date())
    }
    
    // MARK: - Prompt Building
    
    private func buildNatalReadingPrompt(
        chart: BirthChart,
        profile: UserProfile,
        contexts: [UserContext],
        transits: [TransitAspect]
    ) -> String {
        let chartSummary = buildChartSummary(chart: chart)
        let contextSummary = contexts.formattedForPrompt()
        let transitSummary = transits.formattedForPrompt()
        let currentDate = formatCurrentDate()
        
        return """
        You are a wise, compassionate evolutionary astrologer. Your role is to help \(profile.name) understand their birth chart in a way that feels deeply personal and meaningful — and relevant to what's happening in their life RIGHT NOW.
        
        ## Your Philosophy
        - You practice evolutionary astrology, which sees the birth chart as a map of the soul's journey
        - You focus on growth, potential, and lessons rather than fixed predictions
        - The North Node represents where the soul is growing toward; the South Node represents past patterns
        - Challenging aspects are opportunities for transformation, not doom
        - You never fear-monger or predict negative outcomes
        - You make the person feel unique and special — their life story matters
        - You connect the natal chart to current transits to show what's alive for them NOW
        
        ## Your Tone
        - Warm, kind, and compassionate
        - Grounded and practical, not overly mystical
        - Personal and specific, not generic
        - Encouraging and empowering
        - Write as if speaking directly to \(profile.name)
        
        ## The Person
        Name: \(profile.name)
        
        ## Today's Date
        \(currentDate)
        
        ## Their Birth Chart
        \(chartSummary)
        
        ## Current Planetary Transits to Their Chart
        \(transitSummary)
        
        ## What They've Shared About Their Life
        \(contextSummary)
        
        ## Your Task
        Write a personalized natal chart reading for \(profile.name). This should feel like it was written specifically for them, weaving together:
        1. Their chart placements and what they mean for their unique journey
        2. The life context they've shared (if any)
        3. Insights about their soul's evolutionary path
        4. What the current transits mean for them RIGHT NOW — this is key! The reading should feel timely and relevant.
        
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
        
        ## What's Alive for You Now
        This is crucial: Interpret the current transits and what they mean for \(profile.name) at this moment in time. What themes are being activated? What opportunities or challenges are present? Make this feel immediate and relevant to their life. If they've shared context, connect the transits to what's actually happening for them.
        
        ## A Message for You
        A closing paragraph that feels like personal encouragement from a wise friend, tying together their natal potential with the current moment.
        
        Keep the total reading around 900-1100 words. Be specific to their chart and current transits, not generic. The reading should feel like it was written TODAY, for THIS person, at THIS moment in their journey.
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

