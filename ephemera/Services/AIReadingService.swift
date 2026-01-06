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

/// Timeframe for periodic readings
enum ReadingTimeframe: String, CaseIterable, Codable {
    case day = "day"
    case week = "week"
    case month = "month"
    case year = "year"
    
    var displayTitle: String {
        switch self {
        case .day: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        }
    }
    
    var headerTitle: String {
        switch self {
        case .day: return "READING OF THE DAY"
        case .week: return "READING OF THE WEEK"
        case .month: return "READING OF THE MONTH"
        case .year: return "READING OF THE YEAR"
        }
    }
    
    var icon: String {
        switch self {
        case .day: return "sun.max"
        case .week: return "calendar.circle"
        case .month: return "moon.stars"
        case .year: return "sparkles"
        }
    }
    
    var cacheKey: String {
        "cachedReading_\(rawValue)"
    }
    
    /// Word count target for the reading
    var wordCount: (min: Int, max: Int) {
        switch self {
        case .day: return (100, 150)
        case .week: return (180, 250)
        case .month: return (250, 350)
        case .year: return (350, 450)
        }
    }
    
    /// How many days this reading covers
    var daysSpan: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }
    
    /// Date range description for the reading
    func dateRangeDescription() -> String {
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        
        switch self {
        case .day:
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: today)
            
        case .week:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? today
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: startOfWeek)) – \(formatter.string(from: endOfWeek))"
            
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: today)
            
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: today)
        }
    }
    
    /// Check if a cached reading is still valid
    func isCacheValid(cachedDate: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        let today = Date()
        
        switch self {
        case .day:
            return cachedDate == formatter.string(from: today)
            
        case .week:
            // Valid for the same week
            guard let cached = formatter.date(from: cachedDate) else { return false }
            let cachedWeek = calendar.component(.weekOfYear, from: cached)
            let cachedYear = calendar.component(.year, from: cached)
            let currentWeek = calendar.component(.weekOfYear, from: today)
            let currentYear = calendar.component(.year, from: today)
            return cachedWeek == currentWeek && cachedYear == currentYear
            
        case .month:
            // Valid for the same month
            guard let cached = formatter.date(from: cachedDate) else { return false }
            let cachedMonth = calendar.component(.month, from: cached)
            let cachedYear = calendar.component(.year, from: cached)
            let currentMonth = calendar.component(.month, from: today)
            let currentYear = calendar.component(.year, from: today)
            return cachedMonth == currentMonth && cachedYear == currentYear
            
        case .year:
            // Valid for the same year
            guard let cached = formatter.date(from: cachedDate) else { return false }
            let cachedYear = calendar.component(.year, from: cached)
            let currentYear = calendar.component(.year, from: today)
            return cachedYear == currentYear
        }
    }
}

/// Cached reading with timeframe
struct CachedTimeframeReading: Codable {
    let reading: String
    let date: String // Format: yyyy-MM-dd
    let timeframe: ReadingTimeframe
    
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
    
    var isValid: Bool {
        timeframe.isCacheValid(cachedDate: date)
    }
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
    
    // MARK: - Generate Daily Reading
    
    /// Generates a brief daily reading based on current transits
    func generateDailyReading(
        chart: BirthChart,
        profile: UserProfile,
        contexts: [UserContext]
    ) async throws -> String {
        // Calculate current transits
        let transits = ChartCore.shared.getSignificantTransits(natalChart: chart, limit: 4)
        
        let prompt = buildDailyReadingPrompt(chart: chart, profile: profile, contexts: contexts, transits: transits)
        
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw AIReadingError.noResponse
        }
        
        return text
    }
    
    private func buildDailyReadingPrompt(
        chart: BirthChart,
        profile: UserProfile,
        contexts: [UserContext],
        transits: [TransitAspect]
    ) -> String {
        let chartSummary = buildChartSummary(chart: chart)
        let contextSummary = contexts.recentEntries(3).formattedForPrompt()
        let transitSummary = transits.formattedForPrompt()
        let currentDate = formatCurrentDate()
        
        return """
        You are a wise, compassionate evolutionary astrologer delivering a brief daily reading.
        
        ## Your Task
        Write a focused, personal daily reading (100-150 words) that:
        1. Opens with a sense of the day's energy
        2. Highlights 1-2 key themes from today's transits to their chart
        3. Offers a practical insight or gentle guidance
        4. Feels warm, grounded, and specific to them
        
        ## Guidelines
        - This is for \(currentDate) — make it feel timely
        - Be concise but meaningful — quality over quantity
        - Focus on what's most alive for them today
        - Never fear-monger — frame challenges as opportunities
        - Write in second person ("You...")
        - Don't use headers or bullet points — flowing prose only
        - Start with a single evocative sentence about the day's energy
        - End with something actionable or reflective they can carry with them
        - DO NOT greet them by name or say "Hi \(profile.name)"
        
        ## Their Birth Chart
        \(chartSummary)
        
        ## Current Transits to Their Chart
        \(transitSummary)
        
        ## Recent Context They've Shared
        \(contextSummary)
        
        Write your daily reading now. Make it feel like a personal note from the cosmos, written just for them, for today.
        """
    }
    
    // MARK: - Generate Timeframe Reading
    
    /// Generates a reading for a specific timeframe (day, week, month, year)
    func generateTimeframeReading(
        timeframe: ReadingTimeframe,
        chart: BirthChart,
        profile: UserProfile,
        contexts: [UserContext]
    ) async throws -> String {
        // Get transits appropriate for the timeframe
        let transits = getTransitsForTimeframe(timeframe: timeframe, chart: chart)
        
        let prompt = buildTimeframeReadingPrompt(
            timeframe: timeframe,
            chart: chart,
            profile: profile,
            contexts: contexts,
            transits: transits
        )
        
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw AIReadingError.noResponse
        }
        
        return text
    }
    
    /// Get transits relevant to a specific timeframe
    private func getTransitsForTimeframe(timeframe: ReadingTimeframe, chart: BirthChart) -> [TransitAspect] {
        let calendar = Calendar.current
        let today = Date()
        
        switch timeframe {
        case .day:
            // Just today's transits
            return ChartCore.shared.getSignificantTransits(natalChart: chart, transitDate: today, limit: 4)
            
        case .week:
            // Get transits for the week, sampling a few days
            var allTransits: [TransitAspect] = []
            for dayOffset in stride(from: 0, through: 6, by: 2) {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                    let transits = ChartCore.shared.getSignificantTransits(natalChart: chart, transitDate: date, limit: 3)
                    allTransits.append(contentsOf: transits)
                }
            }
            // Remove duplicates and sort by significance
            let uniqueTransits = removeDuplicateTransits(allTransits)
            return Array(uniqueTransits.sorted { $0.significance > $1.significance }.prefix(6))
            
        case .month:
            // Sample transits throughout the month
            var allTransits: [TransitAspect] = []
            for dayOffset in stride(from: 0, through: 28, by: 7) {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                    let transits = ChartCore.shared.getSignificantTransits(natalChart: chart, transitDate: date, limit: 4)
                    allTransits.append(contentsOf: transits)
                }
            }
            let uniqueTransits = removeDuplicateTransits(allTransits)
            return Array(uniqueTransits.sorted { $0.significance > $1.significance }.prefix(8))
            
        case .year:
            // Sample transits throughout the year, focusing on outer planet transits
            var allTransits: [TransitAspect] = []
            for monthOffset in 0..<12 {
                if let date = calendar.date(byAdding: .month, value: monthOffset, to: today) {
                    let transits = ChartCore.shared.calculateTransits(natalChart: chart, transitDate: date)
                    // Filter for outer planet transits which are more significant for yearly readings
                    let outerTransits = transits.filter { 
                        $0.transitingPlanet == .saturn || 
                        $0.transitingPlanet == .jupiter ||
                        $0.transitingPlanet == .uranus ||
                        $0.transitingPlanet == .neptune ||
                        $0.transitingPlanet == .pluto ||
                        $0.transitingPlanet == .northNode
                    }
                    allTransits.append(contentsOf: outerTransits.prefix(3))
                }
            }
            let uniqueTransits = removeDuplicateTransits(allTransits)
            return Array(uniqueTransits.sorted { $0.significance > $1.significance }.prefix(10))
        }
    }
    
    /// Remove duplicate transits (same transiting planet to same natal planet)
    private func removeDuplicateTransits(_ transits: [TransitAspect]) -> [TransitAspect] {
        var seen = Set<String>()
        var unique: [TransitAspect] = []
        
        for transit in transits {
            let key = "\(transit.transitingPlanet.rawValue)-\(transit.natalPlanet.rawValue)"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(transit)
            }
        }
        
        return unique
    }
    
    private func buildTimeframeReadingPrompt(
        timeframe: ReadingTimeframe,
        chart: BirthChart,
        profile: UserProfile,
        contexts: [UserContext],
        transits: [TransitAspect]
    ) -> String {
        let chartSummary = buildChartSummary(chart: chart)
        let contextSummary = contexts.recentEntries(5).formattedForPrompt()
        let transitSummary = formatTransitsForTimeframe(transits: transits, timeframe: timeframe)
        let dateRange = timeframe.dateRangeDescription()
        let wordCount = timeframe.wordCount
        
        let timeframeGuidance: String
        let focusAreas: String
        
        switch timeframe {
        case .day:
            timeframeGuidance = "This is a daily reading for \(dateRange). Focus on the immediate energy of today."
            focusAreas = """
            - The emotional tone of the day
            - One or two key themes to be aware of
            - A small, actionable insight to carry with them
            """
            
        case .week:
            timeframeGuidance = "This is a weekly reading for \(dateRange). Paint a picture of the week's unfolding energy."
            focusAreas = """
            - The overall arc of the week's energy
            - Key days or moments to watch for
            - 2-3 themes that will be prominent
            - How different areas of life might be affected
            - A guiding intention for the week
            """
            
        case .month:
            timeframeGuidance = "This is a monthly reading for \(dateRange). Explore the broader themes and opportunities of this month."
            focusAreas = """
            - The overarching theme of the month
            - Key transits and what they're activating
            - Areas of growth and challenge
            - Relationships, career, inner work — what's highlighted?
            - The emotional and spiritual undercurrent
            - A monthly intention or practice to consider
            """
            
        case .year:
            timeframeGuidance = "This is a yearly reading for \(dateRange). Offer a sweeping view of the year's major themes and evolutionary opportunities."
            focusAreas = """
            - The year's overarching narrative and themes
            - Major planetary transits and their significance
            - Key periods of change, growth, or challenge
            - Areas of life being transformed
            - The soul's evolutionary invitation for this year
            - Long-term patterns being activated
            - A guiding word or intention for the year
            """
        }
        
        return """
        You are a wise, compassionate evolutionary astrologer delivering a personalized \(timeframe.rawValue)ly reading.
        
        ## Your Task
        Write a focused, personal reading (\(wordCount.min)-\(wordCount.max) words) that:
        1. Feels timely and specific to this \(timeframe.rawValue)
        2. Weaves together their natal chart with current/upcoming transits
        3. Offers meaningful insight without being generic
        4. Empowers them to work with the energy consciously
        
        ## Timeframe Context
        \(timeframeGuidance)
        
        ## Focus Areas
        \(focusAreas)
        
        ## Guidelines
        - Write in second person ("You...")
        - Don't use headers or bullet points — flowing prose only
        - Be specific about WHICH transits are affecting WHICH parts of their chart
        - Never fear-monger — frame challenges as opportunities for growth
        - Make it feel personal to their unique chart, not generic horoscope advice
        - Start with an evocative opening that captures the \(timeframe.rawValue)'s energy
        - End with something inspiring or actionable
        - DO NOT greet them by name or say "Hi \(profile.name)"
        
        ## Their Birth Chart
        \(chartSummary)
        
        ## Transits for This \(timeframe.displayTitle)
        \(transitSummary)
        
        ## Recent Context They've Shared
        \(contextSummary)
        
        Write your \(timeframe.rawValue)ly reading now. Make it feel like a personal message from the cosmos, written just for them.
        """
    }
    
    private func formatTransitsForTimeframe(transits: [TransitAspect], timeframe: ReadingTimeframe) -> String {
        guard !transits.isEmpty else { 
            return "The cosmic weather is relatively quiet this \(timeframe.rawValue), allowing for integration and rest."
        }
        
        var result = "Key transits for this \(timeframe.rawValue):\n\n"
        
        for transit in transits {
            let transitPlanetStr = "\(transit.transitingPlanet.rawValue) in \(transit.transitingPosition.sign.rawValue)"
            let natalPlanetStr = "natal \(transit.natalPlanet.rawValue) in \(transit.natalPosition.sign.rawValue)"
            let orbStr = String(format: "%.1f", transit.orb)
            
            result += "• \(transitPlanetStr) \(transit.aspectType.rawValue.lowercased()) \(natalPlanetStr) (\(orbStr)° orb)\n"
            result += "  → \(transitInterpretationHint(transit))\n\n"
        }
        
        return result
    }
    
    private func transitInterpretationHint(_ transit: TransitAspect) -> String {
        switch transit.transitingPlanet {
        case .saturn:
            return "Themes of responsibility, structure, limitations, maturity, or karma"
        case .jupiter:
            return "Themes of expansion, opportunity, growth, or excess"
        case .pluto:
            return "Deep transformation, power dynamics, rebirth, or intensity"
        case .neptune:
            return "Spirituality, dreams, confusion, idealism, or dissolution"
        case .uranus:
            return "Sudden changes, liberation, awakening, or disruption"
        case .mars:
            return "Energy, action, conflict, drive, or assertion"
        case .venus:
            return "Relationships, values, beauty, pleasure, or harmony"
        case .mercury:
            return "Communication, thinking, short trips, or decisions"
        case .sun:
            return "Vitality, identity focus, recognition, or self-expression"
        case .moon:
            return "Emotional shifts, needs, home, or instinctive reactions"
        case .northNode:
            return "Karmic direction, growth opportunities, fated encounters"
        default:
            return "Significant energy activation"
        }
    }
    
    // MARK: - Generate Journal Insight
    
    /// Generates an insight based on journal entries and birth chart
    func generateJournalInsight(
        chart: BirthChart,
        profile: UserProfile,
        journalEntries: [UserContext]
    ) async throws -> String {
        let prompt = buildJournalInsightPrompt(chart: chart, profile: profile, entries: journalEntries)
        
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw AIReadingError.noResponse
        }
        
        return text
    }
    
    private func buildJournalInsightPrompt(
        chart: BirthChart,
        profile: UserProfile,
        entries: [UserContext]
    ) -> String {
        let chartSummary = buildChartSummary(chart: chart)
        let (latestEntry, pastSummary) = buildJournalSummaryWithLatest(entries: entries)
        let currentDate = formatCurrentDate()
        
        return """
        You are a wise, compassionate astrologer who helps people understand patterns in their life through the lens of their birth chart.
        
        ## Your Task
        Write a brief, insightful reflection (4-5 sentences, about 80-100 words) that:
        1. Acknowledges their most recent journal entry
        2. Connects it to patterns you notice across their past entries
        3. Ties this to something meaningful in their birth chart
        4. Ends with a small, actionable suggestion — something they can do, reflect on, or practice
        
        This should feel like a wise friend noticing something meaningful about where they are right now, then offering a gentle nudge forward.
        
        ## Guidelines
        - Start by reflecting on their latest entry — what they shared today matters
        - Notice how it compares to or continues themes from past entries (is this new? recurring? a shift?)
        - Connect it meaningfully to their chart (e.g., a planetary placement, aspect, or node)
        - End with ONE specific, gentle action. This could be:
          - A reflective question to sit with ("Ask yourself: what would it look like to...")
          - A small practice or ritual ("Try taking 5 minutes tonight to...")
          - Something to notice or pay attention to ("Watch for moments when...")
          - A creative or expressive prompt ("Write down three things that...")
          - A boundary or intention to set ("Consider giving yourself permission to...")
        - The action should feel doable and connected to their chart/patterns, not generic self-help
        - Be warm and personal, not clinical
        - Don't be preachy — frame the action as an invitation, not an instruction
        - Write in second person ("You...")
        - Keep it concise — quality over quantity
        - Today is \(currentDate)
        
        ## Their Birth Chart
        \(chartSummary)
        
        ## Their Most Recent Entry (TODAY)
        \(latestEntry)
        
        ## Their Past Entries (for context)
        \(pastSummary)
        
        Write your insight now. Start by acknowledging what they shared in their latest entry, connect it to their patterns and chart, and close with a small actionable suggestion.
        """
    }
    
    private func buildJournalSummaryWithLatest(entries: [UserContext]) -> (latest: String, past: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        guard let latestEntry = entries.first else {
            return ("No entries yet.", "No past entries.")
        }
        
        let latestDate = dateFormatter.string(from: latestEntry.createdAt)
        let latest = "[\(latestDate)]\n\(latestEntry.response)"
        
        // Get past entries (skip the first one)
        let pastEntries = entries.dropFirst().prefix(8)
        
        var pastSummary = ""
        for entry in pastEntries {
            let date = dateFormatter.string(from: entry.createdAt)
            pastSummary += "[\(date)]\n\(entry.response)\n\n"
        }
        
        return (latest, pastSummary.isEmpty ? "This is their first entry." : pastSummary)
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

// MARK: - Reading Conversation

extension AIReadingService {
    
    /// Continues a conversation about a reading
    /// Returns the assistant's response
    func continueReadingConversation(
        conversation: ReadingConversation,
        userMessage: String,
        chart: BirthChart,
        profile: UserProfile,
        contexts: [UserContext]
    ) async throws -> String {
        let prompt = buildConversationPrompt(
            conversation: conversation,
            userMessage: userMessage,
            chart: chart,
            profile: profile,
            contexts: contexts
        )
        
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw AIReadingError.noResponse
        }
        
        return text
    }
    
    /// Generates a summary of a conversation for future context
    func summarizeConversation(
        conversation: ReadingConversation,
        chart: BirthChart,
        profile: UserProfile
    ) async throws -> String {
        let prompt = buildSummaryPrompt(conversation: conversation, chart: chart, profile: profile)
        
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw AIReadingError.noResponse
        }
        
        return text
    }
    
    private func buildConversationPrompt(
        conversation: ReadingConversation,
        userMessage: String,
        chart: BirthChart,
        profile: UserProfile,
        contexts: [UserContext]
    ) -> String {
        let chartSummary = buildChartSummary(chart: chart)
        let contextSummary = contexts.recentEntries(5).formattedForPrompt()
        let transits = getTransitsForTimeframe(timeframe: conversation.timeframe, chart: chart)
        let transitSummary = formatTransitsForTimeframe(transits: transits, timeframe: conversation.timeframe)
        let conversationHistory = conversation.formattedForPrompt()
        let currentDate = formatCurrentDate()
        
        return """
        You are a wise, compassionate evolutionary astrologer continuing a conversation about a \(conversation.timeframe.rawValue)ly reading you gave.
        
        ## Your Role
        You're having a dialogue with \(profile.name) about their reading. They want to explore it further, ask questions, or connect it to their life. You're warm, insightful, and specific to their chart.
        
        ## Guidelines
        - Keep responses conversational and concise (50-80 words typically, up to 120 if needed)
        - Reference specific parts of the reading when relevant
        - Connect their questions back to their chart and current transits
        - If they go off-topic, gently redirect: "That's interesting—how does it connect to what's coming up for you this \(conversation.timeframe.rawValue)?"
        - You're having a dialogue, not delivering another reading
        - End with a question or reflection to keep the conversation going (unless they seem done)
        - Never discuss other users or claim to access data beyond what's provided
        - Don't start with "Great question!" or similar filler
        - Write in second person ("You...")
        
        ## Today's Date
        \(currentDate)
        
        ## The Reading You Gave (\(conversation.timeframe.displayTitle))
        \(conversation.readingContent)
        
        ## Key Transits for This Period
        \(transitSummary)
        
        ## Their Birth Chart
        \(chartSummary)
        
        ## What They've Shared About Their Life
        \(contextSummary)
        
        ## Conversation So Far
        \(conversationHistory)
        
        ## Their Latest Message
        User: \(userMessage)
        
        Respond as the astrologer. Be warm, specific, and insightful. Keep it conversational.
        """
    }
    
    private func buildSummaryPrompt(
        conversation: ReadingConversation,
        chart: BirthChart,
        profile: UserProfile
    ) -> String {
        let conversationHistory = conversation.formattedForPrompt()
        
        return """
        You are summarizing a conversation between an astrologer and \(profile.name) about their \(conversation.timeframe.rawValue)ly reading.
        
        ## The Conversation
        \(conversationHistory)
        
        ## Your Task
        Write a brief summary (2-3 sentences, max 60 words) that captures:
        1. What they explored or asked about
        2. Any key insights or realizations that emerged
        3. Relevant chart elements that were discussed
        
        This summary will be used as context for future readings, so focus on what's meaningful for their ongoing journey.
        
        Write the summary in third person ("They explored...", "The conversation revealed...").
        Do not include any preamble—just write the summary directly.
        """
    }
}

// MARK: - Errors

enum AIReadingError: LocalizedError {
    case noResponse
    case invalidChart
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .noResponse:
            return "Unable to generate reading. Please try again."
        case .invalidChart:
            return "Chart data is incomplete."
        case .rateLimited:
            return "You've reached your daily message limit. Come back tomorrow!"
        }
    }
}
