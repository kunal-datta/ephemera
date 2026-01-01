//
//  ChartCore.swift
//  ephemera
//
//  Core chart generation logic.
//  Handles timezone conversion, chart type determination, house assignments,
//  aspect calculations, and uncertainty flags.
//
//  Created by Kunal_Datta on 30/12/25.
//

import Foundation

/// Input for chart generation
struct ChartInput {
    let name: String
    let birthDate: Date           // The date component
    let birthTime: Date?          // The time component (nil if unknown)
    let birthTimeUnknown: Bool
    let birthPlace: String?
    let latitude: Double?
    let longitude: Double?
    let timezone: String?         // IANA timezone ID (e.g., "America/New_York")
    let nodeType: NodeType
    
    enum NodeType: String {
        case trueNode = "true"
        case meanNode = "mean"
    }
}

/// Result of chart generation
struct ChartResult {
    let status: ChartStatus
    let errors: [String]
    let chartType: ChartType?
    let metadata: ChartMetadata?
    let angles: ChartAngles?
    let houses: [House]?
    let planets: [PlanetaryPosition]?
    let aspects: [ChartAspect]?
    let evolutionaryCore: EvolutionaryCore?
    
    enum ChartStatus: String {
        case ok = "ok"
        case needsGeocoding = "needs_geocoding"
        case error = "error"
    }
}

/// Main chart generation service
class ChartCore {
    
    static let shared = ChartCore()
    private let ephemeris = EphemerisAdapter.shared
    
    private init() {}
    
    // MARK: - Main Chart Generation
    
    /// Generate a birth chart based on the provided input
    func generateChart(input: ChartInput) -> ChartResult {
        // Validate input
        let errors: [String] = []
        
        // Check if we need geocoding (place provided but missing lat/lon/timezone)
        if input.birthPlace != nil && (input.latitude == nil || input.longitude == nil || input.timezone == nil) {
            return ChartResult(
                status: .needsGeocoding,
                errors: ["Birth place provided but lat/lon/timezone not resolved"],
                chartType: nil,
                metadata: nil,
                angles: nil,
                houses: nil,
                planets: nil,
                aspects: nil,
                evolutionaryCore: nil
            )
        }
        
        // Determine chart type based on available data
        let chartType = determineChartType(input: input)
        var assumptions: [String] = []
        
        // Calculate the datetime to use for calculations
        let (calculationDate, utcDate) = calculateDateTime(input: input, chartType: chartType, assumptions: &assumptions)
        
        // Get planetary positions
        var planets = ephemeris.getAllPlanetPositions(
            date: calculationDate,
            useTrueNode: input.nodeType == .trueNode
        )
        
        // Check Moon sign uncertainty
        let timezone = input.timezone.flatMap { TimeZone(identifier: $0) }
        let moonUncertainty = ephemeris.checkMoonSignUncertainty(date: calculationDate, timezone: timezone)
        
        // Update Moon position with uncertainty info
        if let moonIndex = planets.firstIndex(where: { $0.planet == .moon }) {
            let moon = planets[moonIndex]
            planets[moonIndex] = PlanetaryPosition(
                planet: .moon,
                longitude: moon.longitude,
                sign: moon.sign,
                degreeInSign: moon.degreeInSign,
                house: moon.house,
                isRetrograde: moon.isRetrograde,
                signUncertain: moonUncertainty.isUncertain,
                possibleSigns: moonUncertainty.isUncertain ? moonUncertainty.possibleSigns : nil
            )
        }
        
        // Get houses and angles (only for FULL_NATAL)
        var houses: [House]? = nil
        var angles: ChartAngles? = nil
        
        if chartType == .fullNatal,
           let lat = input.latitude,
           let lon = input.longitude {
            if let result = ephemeris.getHouseCusps(date: calculationDate, latitude: lat, longitude: lon) {
                houses = result.houses
                angles = result.angles
                
                // Assign houses to planets
                if let risingSign = angles?.ascendant?.sign {
                    planets = assignHousesToPlanets(planets: planets, risingSign: risingSign)
                }
            }
        }
        
        // Calculate aspects
        let aspects = calculateAspects(planets: planets, angles: angles)
        
        // Build metadata
        let metadata = ChartMetadata(
            birthDate: input.birthDate,
            birthTimeInput: input.birthTimeUnknown ? "unknown" : formatTime(input.birthTime),
            birthPlaceInput: input.birthPlace,
            latitude: input.latitude,
            longitude: input.longitude,
            timezone: input.timezone,
            houseSystem: "PLACIDUS",
            nodeType: input.nodeType.rawValue,
            utcDateTimeUsed: utcDate,
            julianDay: nil,  // Could calculate this if needed
            assumptions: assumptions
        )
        
        // Build evolutionary core
        let evolutionaryCore = buildEvolutionaryCore(
            planets: planets,
            risingSign: angles?.ascendant?.sign,
            chartType: chartType
        )
        
        return ChartResult(
            status: .ok,
            errors: errors,
            chartType: chartType,
            metadata: metadata,
            angles: angles,
            houses: houses,
            planets: planets,
            aspects: aspects,
            evolutionaryCore: evolutionaryCore
        )
    }
    
    // MARK: - Chart Type Determination
    
    private func determineChartType(input: ChartInput) -> ChartType {
        let hasTime = !input.birthTimeUnknown && input.birthTime != nil
        let hasLocation = input.latitude != nil && input.longitude != nil && input.timezone != nil
        
        if hasTime && hasLocation {
            return .fullNatal
        } else if hasLocation && !hasTime {
            return .noonChartNoHouses
        } else {
            return .signBasedNoHouses
        }
    }
    
    // MARK: - DateTime Calculation
    
    private func calculateDateTime(input: ChartInput, chartType: ChartType, assumptions: inout [String]) -> (Date, Date?) {
        switch chartType {
        case .fullNatal:
            // Use exact birth time with timezone
            guard let birthTime = input.birthTime,
                  let tzid = input.timezone,
                  let tz = TimeZone(identifier: tzid) else {
                // Fallback - shouldn't happen if chartType is correct
                return (input.birthDate, nil)
            }
            
            // Combine date and time
            let combinedDate = combineDateAndTime(date: input.birthDate, time: birthTime, timezone: tz)
            return (combinedDate, combinedDate)
            
        case .noonChartNoHouses:
            // Use noon in local timezone
            assumptions.append("Birth time unknown; using local noon (12:00)")
            guard let tzid = input.timezone,
                  let tz = TimeZone(identifier: tzid) else {
                return (setToNoonUTC(input.birthDate), nil)
            }
            
            let noonDate = setToNoon(input.birthDate, timezone: tz)
            return (noonDate, noonDate)
            
        case .signBasedNoHouses, .whole:
            // Use noon UTC (or local noon if timezone available)
            if let tzid = input.timezone, let tz = TimeZone(identifier: tzid) {
                assumptions.append("Birth time/place unknown; using local noon")
                let noonDate = setToNoon(input.birthDate, timezone: tz)
                return (noonDate, noonDate)
            } else {
                assumptions.append("Birth time/place unknown; using 12:00 UTC")
                let noonUTC = setToNoonUTC(input.birthDate)
                return (noonUTC, noonUTC)
            }
        }
    }
    
    // MARK: - House Assignment (Placidus)
    
    private func assignHousesToPlanets(planets: [PlanetaryPosition], risingSign: ZodiacSign) -> [PlanetaryPosition] {
        let risingSignIndex = risingSign.index
        
        return planets.map { planet in
            let planetSignIndex = planet.sign.index
            let houseNumber = ((planetSignIndex - risingSignIndex + 12) % 12) + 1
            
            return PlanetaryPosition(
                planet: planet.planet,
                longitude: planet.longitude,
                sign: planet.sign,
                degreeInSign: planet.degreeInSign,
                house: houseNumber,
                isRetrograde: planet.isRetrograde,
                signUncertain: planet.signUncertain,
                possibleSigns: planet.possibleSigns
            )
        }
    }
    
    // MARK: - Aspect Calculation
    
    private func calculateAspects(planets: [PlanetaryPosition], angles: ChartAngles?) -> [ChartAspect] {
        var aspects: [ChartAspect] = []
        
        // Define orbs
        let sunMoonOrb = 8.0
        let personalOrb = 6.0
        let outerOrb = 5.0
        
        func getOrb(for planet: Planet) -> Double {
            switch planet {
            case .sun, .moon:
                return sunMoonOrb
            case .mercury, .venus, .mars:
                return personalOrb
            default:
                return outerOrb
            }
        }
        
        // Aspect angles
        let aspectAngles: [(AspectType, Double)] = [
            (.conjunction, 0),
            (.sextile, 60),
            (.square, 90),
            (.trine, 120),
            (.opposition, 180)
        ]
        
        // Compare all planet pairs
        for i in 0..<planets.count {
            for j in (i+1)..<planets.count {
                let planet1 = planets[i]
                let planet2 = planets[j]
                
                let orb = min(getOrb(for: planet1.planet), getOrb(for: planet2.planet))
                
                // Calculate angular difference
                var diff = abs(planet1.longitude - planet2.longitude)
                if diff > 180 {
                    diff = 360 - diff
                }
                
                // Check each aspect type
                for (aspectType, angle) in aspectAngles {
                    let orbDiff = abs(diff - angle)
                    if orbDiff <= orb {
                        aspects.append(ChartAspect(
                            planet1: planet1.planet,
                            planet2: planet2.planet,
                            type: aspectType,
                            exactAngle: diff,
                            orb: orbDiff,
                            isApplying: nil  // Could calculate if we had speed data
                        ))
                        break  // Only one aspect per pair
                    }
                }
            }
        }
        
        return aspects
    }
    
    // MARK: - Evolutionary Core
    
    private func buildEvolutionaryCore(planets: [PlanetaryPosition], risingSign: ZodiacSign?, chartType: ChartType) -> EvolutionaryCore {
        let pluto = planets.first { $0.planet == .pluto }
        let northNode = planets.first { $0.planet == .northNode }
        let southNode = planets.first { $0.planet == .southNode }
        let moon = planets.first { $0.planet == .moon }
        let sun = planets.first { $0.planet == .sun }
        
        var notes: [String] = ["Placidus houses used"]
        
        if chartType != .fullNatal {
            notes.append("Houses omitted when birth time/place unknown")
        }
        
        if moon?.signUncertain == true {
            notes.append("Moon sign uncertain - may change during birth date")
        }
        
        return EvolutionaryCore(
            pluto: pluto,
            northNode: northNode,
            southNode: southNode,
            moon: moon,
            sun: sun,
            risingSign: risingSign,
            notes: notes
        )
    }
    
    // MARK: - Helper Methods
    
    private func combineDateAndTime(date: Date, time: Date, timezone: TimeZone) -> Date {
        // The timeOfBirth is normalized during onboarding/profile edit to contain:
        // - The correct birth date
        // - The correct birth location timezone
        //
        // We extract and recombine to ensure the date from birthDate is used
        // with the time from timeOfBirth, all in the birth location's timezone.
        
        var birthLocationCalendar = Calendar.current
        birthLocationCalendar.timeZone = timezone
        
        // Extract date components from birthDate
        let dateComponents = birthLocationCalendar.dateComponents([.year, .month, .day], from: date)
        
        // Extract time components from timeOfBirth
        let timeComponents = birthLocationCalendar.dateComponents([.hour, .minute, .second], from: time)
        
        // Combine date and time in birth location timezone
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = timeComponents.second
        combined.timeZone = timezone
        
        return birthLocationCalendar.date(from: combined) ?? date
    }
    
    private func setToNoon(_ date: Date, timezone: TimeZone) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = timezone
        
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 12
        components.minute = 0
        components.second = 0
        components.timeZone = timezone
        
        return calendar.date(from: components) ?? date
    }
    
    private func setToNoonUTC(_ date: Date) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 12
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")
        
        return calendar.date(from: components) ?? date
    }
    
    private func formatTime(_ time: Date?) -> String? {
        guard let time = time else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }
}

// MARK: - Transit Calculation

/// A transit aspect between a transiting planet and a natal planet
struct TransitAspect: Identifiable {
    var id: String { "\(transitingPlanet.rawValue)-\(aspectType.rawValue)-\(natalPlanet.rawValue)" }
    
    let transitingPlanet: Planet
    let transitingPosition: PlanetaryPosition
    let natalPlanet: Planet
    let natalPosition: PlanetaryPosition
    let aspectType: AspectType
    let orb: Double
    let isApplying: Bool?
    
    /// How significant is this transit (higher = more important)
    var significance: Int {
        var score = 0
        
        // Outer planets transiting personal planets are most significant
        if transitingPlanet.isOuter && natalPlanet.isPersonal {
            score += 10
        }
        
        // Saturn and Jupiter are significant
        if transitingPlanet == .saturn || transitingPlanet == .jupiter {
            score += 7
        }
        
        // Transits to Sun, Moon, or Ascendant-ruler are important
        if natalPlanet == .sun || natalPlanet == .moon {
            score += 5
        }
        
        // Conjunctions and oppositions are strongest
        if aspectType == .conjunction || aspectType == .opposition {
            score += 3
        }
        
        // Tighter orbs are more potent
        if orb < 1.0 {
            score += 3
        } else if orb < 2.0 {
            score += 2
        }
        
        return score
    }
}

extension ChartCore {
    
    // MARK: - Transit Calculation
    
    /// Calculate current transits to a natal chart
    func calculateTransits(
        natalChart: BirthChart,
        transitDate: Date = Date()
    ) -> [TransitAspect] {
        // Get current planetary positions
        let transitingPlanets = ephemeris.getAllPlanetPositions(date: transitDate, useTrueNode: true)
        let natalPlanets = natalChart.planets
        
        var transits: [TransitAspect] = []
        
        // Define orbs for transits (tighter than natal aspects)
        func getTransitOrb(transitPlanet: Planet, natalPlanet: Planet) -> Double {
            // Outer planets get wider orbs as they move slowly
            if transitPlanet == .pluto || transitPlanet == .neptune || transitPlanet == .uranus {
                return 3.0
            } else if transitPlanet == .saturn || transitPlanet == .jupiter {
                return 4.0
            } else if transitPlanet == .sun || transitPlanet == .moon {
                return 5.0
            } else {
                return 3.0  // Inner planets
            }
        }
        
        // Aspect angles
        let aspectAngles: [(AspectType, Double)] = [
            (.conjunction, 0),
            (.sextile, 60),
            (.square, 90),
            (.trine, 120),
            (.opposition, 180)
        ]
        
        // Compare each transiting planet to each natal planet
        for transitPos in transitingPlanets {
            // Skip South Node (redundant with North Node)
            if transitPos.planet == .southNode { continue }
            
            for natalPos in natalPlanets {
                // Skip South Node
                if natalPos.planet == .southNode { continue }
                
                let orb = getTransitOrb(transitPlanet: transitPos.planet, natalPlanet: natalPos.planet)
                
                // Calculate angular difference
                var diff = abs(transitPos.longitude - natalPos.longitude)
                if diff > 180 {
                    diff = 360 - diff
                }
                
                // Check each aspect type
                for (aspectType, angle) in aspectAngles {
                    let orbDiff = abs(diff - angle)
                    if orbDiff <= orb {
                        // Determine if applying or separating
                        // (simplified - would need speed data for accuracy)
                        let isApplying: Bool? = nil
                        
                        transits.append(TransitAspect(
                            transitingPlanet: transitPos.planet,
                            transitingPosition: transitPos,
                            natalPlanet: natalPos.planet,
                            natalPosition: natalPos,
                            aspectType: aspectType,
                            orb: orbDiff,
                            isApplying: isApplying
                        ))
                        break  // Only one aspect per pair
                    }
                }
            }
        }
        
        // Sort by significance (most important first)
        return transits.sorted { $0.significance > $1.significance }
    }
    
    /// Get a summary of the most important current transits
    func getSignificantTransits(
        natalChart: BirthChart,
        transitDate: Date = Date(),
        limit: Int = 5
    ) -> [TransitAspect] {
        let allTransits = calculateTransits(natalChart: natalChart, transitDate: transitDate)
        return Array(allTransits.prefix(limit))
    }
}

// MARK: - Transit Formatting for AI

extension Array where Element == TransitAspect {
    /// Format transits for inclusion in an AI prompt
    func formattedForPrompt() -> String {
        guard !isEmpty else { return "No significant transits at this time." }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        let today = dateFormatter.string(from: Date())
        
        var result = "Current Transits (as of \(today)):\n\n"
        
        for transit in self {
            let transitPlanetStr = "\(transit.transitingPlanet.rawValue) at \(transit.transitingPosition.formattedDegree) \(transit.transitingPosition.sign.rawValue)"
            let natalPlanetStr = "natal \(transit.natalPlanet.rawValue) at \(transit.natalPosition.formattedDegree) \(transit.natalPosition.sign.rawValue)"
            let orbStr = String(format: "%.1f", transit.orb)
            
            result += "• Transiting \(transitPlanetStr) is \(transit.aspectType.rawValue.lowercased()) your \(natalPlanetStr) (\(orbStr)° orb)\n"
            
            // Add brief interpretation hint
            result += "  → \(transitInterpretationHint(transit))\n\n"
        }
        
        return result
    }
    
    private func transitInterpretationHint(_ transit: TransitAspect) -> String {
        // Brief hints to guide the AI
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
}

// MARK: - BirthChart Creation Extension

extension BirthChart {
    /// Create a BirthChart from a ChartResult
    static func from(result: ChartResult, userId: UUID) -> BirthChart? {
        guard result.status == .ok,
              let chartType = result.chartType,
              let metadata = result.metadata,
              let planets = result.planets,
              let evolutionaryCore = result.evolutionaryCore else {
            return nil
        }
        
        return BirthChart(
            userId: userId,
            chartType: chartType.rawValue,
            status: result.status.rawValue,
            errors: result.errors,
            metadata: metadata,
            angles: result.angles,
            houses: result.houses,
            planets: planets,
            aspects: result.aspects,
            evolutionaryCore: evolutionaryCore
        )
    }
}

