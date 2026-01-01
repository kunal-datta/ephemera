//
//  EphemerisAdapter.swift
//  ephemera
//
//  Swiss Ephemeris wrapper for planetary calculations.
//  Uses the SwissEphemeris Swift package for accurate astronomical data.
//
//  Created by Kunal_Datta on 30/12/25.
//

import Foundation
import SwissEphemeris

/// Adapter for Swiss Ephemeris calculations
/// Handles planetary longitudes, Ascendant, MC, and related astronomical data
class EphemerisAdapter {
    
    static let shared = EphemerisAdapter()
    
    private init() {
        // Set ephemeris path to the bundled JPL files
        JPLFileManager.setEphemerisPath()
    }
    
    // MARK: - Planetary Positions
    
    /// Get coordinate for a specific planet at a given date
    func getPlanetPosition(planet: Planet, date: Date) -> PlanetaryPosition {
        let coord: Coordinate<SwissEphemeris.Planet>
        
        switch planet {
        case .sun:
            coord = Coordinate<SwissEphemeris.Planet>(body: .sun, date: date)
        case .moon:
            coord = Coordinate<SwissEphemeris.Planet>(body: .moon, date: date)
        case .mercury:
            coord = Coordinate<SwissEphemeris.Planet>(body: .mercury, date: date)
        case .venus:
            coord = Coordinate<SwissEphemeris.Planet>(body: .venus, date: date)
        case .mars:
            coord = Coordinate<SwissEphemeris.Planet>(body: .mars, date: date)
        case .jupiter:
            coord = Coordinate<SwissEphemeris.Planet>(body: .jupiter, date: date)
        case .saturn:
            coord = Coordinate<SwissEphemeris.Planet>(body: .saturn, date: date)
        case .uranus:
            coord = Coordinate<SwissEphemeris.Planet>(body: .uranus, date: date)
        case .neptune:
            coord = Coordinate<SwissEphemeris.Planet>(body: .neptune, date: date)
        case .pluto:
            coord = Coordinate<SwissEphemeris.Planet>(body: .pluto, date: date)
        case .northNode, .southNode:
            // Handle nodes separately
            return getNodePosition(isNorth: planet == .northNode, date: date)
        }
        
        let longitude = coord.longitude
        let sign = ZodiacSign.from(longitude: longitude)
        let degreeInSign = longitude.truncatingRemainder(dividingBy: 30)
        let isRetrograde = coord.speedLongitude < 0
        
        return PlanetaryPosition(
            planet: planet,
            longitude: longitude,
            sign: sign,
            degreeInSign: degreeInSign,
            house: nil,  // Will be set by ChartCore if we have houses
            isRetrograde: isRetrograde,
            signUncertain: false,
            possibleSigns: nil
        )
    }
    
    /// Get node position (True Node by default)
    func getNodePosition(isNorth: Bool, date: Date, useTrueNode: Bool = true) -> PlanetaryPosition {
        let nodeCoord = Coordinate<LunarNorthNode>(
            body: useTrueNode ? .trueNode : .meanNode,
            date: date
        )
        
        var longitude = nodeCoord.longitude
        
        // South Node is opposite North Node
        if !isNorth {
            longitude = (longitude + 180).truncatingRemainder(dividingBy: 360)
        }
        
        let sign = ZodiacSign.from(longitude: longitude)
        let degreeInSign = longitude.truncatingRemainder(dividingBy: 30)
        
        // Nodes are always "retrograde" in motion
        return PlanetaryPosition(
            planet: isNorth ? .northNode : .southNode,
            longitude: longitude,
            sign: sign,
            degreeInSign: degreeInSign,
            house: nil,
            isRetrograde: true,
            signUncertain: false,
            possibleSigns: nil
        )
    }
    
    /// Get all planetary positions for a given date
    func getAllPlanetPositions(date: Date, useTrueNode: Bool = true) -> [PlanetaryPosition] {
        var positions: [PlanetaryPosition] = []
        
        // Get main planets
        let planets: [Planet] = [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune, .pluto]
        for planet in planets {
            positions.append(getPlanetPosition(planet: planet, date: date))
        }
        
        // Get nodes
        positions.append(getNodePosition(isNorth: true, date: date, useTrueNode: useTrueNode))
        positions.append(getNodePosition(isNorth: false, date: date, useTrueNode: useTrueNode))
        
        return positions
    }
    
    // MARK: - House Cusps & Angles
    
    /// Get house cusps and angles for a given date and location
    /// Returns nil if location data is missing
    /// Uses Placidus house system by default
    func getHouseCusps(date: Date, latitude: Double, longitude: Double) -> (houses: [House], angles: ChartAngles)? {
        let cusps = HouseCusps(
            date: date,
            latitude: latitude,
            longitude: longitude,
            houseSystem: .placidus
        )
        
        // Get Ascendant - using the tropical property
        let ascLongitude = cusps.ascendent.tropical.value
        let ascSign = ZodiacSign.from(longitude: ascLongitude)
        let ascDegree = ascLongitude.truncatingRemainder(dividingBy: 30)
        
        let ascendant = PlanetaryPosition(
            planet: .sun, // Placeholder - Ascendant isn't a planet but we use this structure
            longitude: ascLongitude,
            sign: ascSign,
            degreeInSign: ascDegree,
            house: 1,
            isRetrograde: false,
            signUncertain: false,
            possibleSigns: nil
        )
        
        // Get MC (Midheaven) - using the tropical property
        let mcLongitude = cusps.midHeaven.tropical.value
        let mcSign = ZodiacSign.from(longitude: mcLongitude)
        let mcDegree = mcLongitude.truncatingRemainder(dividingBy: 30)
        
        let midheaven = PlanetaryPosition(
            planet: .sun,
            longitude: mcLongitude,
            sign: mcSign,
            degreeInSign: mcDegree,
            house: 10,
            isRetrograde: false,
            signUncertain: false,
            possibleSigns: nil
        )
        
        // Calculate Descendant (opposite Ascendant)
        let descLongitude = (ascLongitude + 180).truncatingRemainder(dividingBy: 360)
        let descSign = ZodiacSign.from(longitude: descLongitude)
        let descDegree = descLongitude.truncatingRemainder(dividingBy: 30)
        
        let descendant = PlanetaryPosition(
            planet: .sun,
            longitude: descLongitude,
            sign: descSign,
            degreeInSign: descDegree,
            house: 7,
            isRetrograde: false,
            signUncertain: false,
            possibleSigns: nil
        )
        
        // Calculate IC (opposite MC)
        let icLongitude = (mcLongitude + 180).truncatingRemainder(dividingBy: 360)
        let icSign = ZodiacSign.from(longitude: icLongitude)
        let icDegree = icLongitude.truncatingRemainder(dividingBy: 30)
        
        let imumCoeli = PlanetaryPosition(
            planet: .sun,
            longitude: icLongitude,
            sign: icSign,
            degreeInSign: icDegree,
            house: 4,
            isRetrograde: false,
            signUncertain: false,
            possibleSigns: nil
        )
        
        let angles = ChartAngles(
            ascendant: ascendant,
            midheaven: midheaven,
            descendant: descendant,
            imumCoeli: imumCoeli
        )
        
        // Build Placidus houses from cusps
        // The HouseCusps object provides the actual cusp degrees for each house
        var houses: [House] = []
        
        // Get cusp longitudes from the HouseCusps object
        let cuspLongitudes = [
            cusps.first.tropical.value,
            cusps.second.tropical.value,
            cusps.third.tropical.value,
            cusps.fourth.tropical.value,
            cusps.fifth.tropical.value,
            cusps.sixth.tropical.value,
            cusps.seventh.tropical.value,
            cusps.eighth.tropical.value,
            cusps.ninth.tropical.value,
            cusps.tenth.tropical.value,
            cusps.eleventh.tropical.value,
            cusps.twelfth.tropical.value
        ]
        
        for i in 0..<12 {
            let houseNumber = i + 1
            let cuspDegree = cuspLongitudes[i]
            let sign = ZodiacSign.from(longitude: cuspDegree)
            
            houses.append(House(
                number: houseNumber,
                sign: sign,
                cuspDegree: cuspDegree
            ))
        }
        
        return (houses, angles)
    }
    
    // MARK: - Moon Sign Uncertainty Check
    
    /// Check if Moon changes signs during the given date
    /// Returns possible signs if uncertain
    func checkMoonSignUncertainty(date: Date, timezone: TimeZone?) -> (isUncertain: Bool, possibleSigns: [ZodiacSign]) {
        let tz = timezone ?? TimeZone(identifier: "UTC")!
        
        var calendarWithTZ = Calendar.current
        calendarWithTZ.timeZone = tz
        
        // Get start of day (00:00)
        let startOfDay = calendarWithTZ.startOfDay(for: date)
        
        // Get end of day (23:59)
        guard let endOfDay = calendarWithTZ.date(bySettingHour: 23, minute: 59, second: 59, of: date) else {
            // Fallback: just use the provided date
            let moonPos = getPlanetPosition(planet: .moon, date: date)
            return (false, [moonPos.sign])
        }
        
        // Get Moon position at start and end of day
        let moonStart = getPlanetPosition(planet: .moon, date: startOfDay)
        let moonEnd = getPlanetPosition(planet: .moon, date: endOfDay)
        
        if moonStart.sign == moonEnd.sign {
            return (false, [moonStart.sign])
        } else {
            return (true, [moonStart.sign, moonEnd.sign])
        }
    }
}
