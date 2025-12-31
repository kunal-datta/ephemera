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
            houseSystem: "WHOLE_SIGN",
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
    
    // MARK: - House Assignment (Whole Sign)
    
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
        
        var notes: [String] = ["Whole Sign houses used"]
        
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
        // The timeOfBirth is normalized during onboarding to contain:
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

