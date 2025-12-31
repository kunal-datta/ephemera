//
//  BirthChart.swift
//  ephemera
//
//  Created by Kunal_Datta on 30/12/25.
//

import Foundation
import SwiftData

// MARK: - Chart Type

enum ChartType: String, Codable {
    case fullNatal = "FULL_NATAL"              // Has time + place
    case noonChartNoHouses = "NOON_CHART_NO_HOUSES"  // Has place, no time
    case signBasedNoHouses = "SIGN_BASED_NO_HOUSES"  // Only has date
    case whole = "whole"                        // Alias for whole sign system
}

// MARK: - Zodiac Sign

enum ZodiacSign: String, Codable, CaseIterable {
    case aries = "Aries"
    case taurus = "Taurus"
    case gemini = "Gemini"
    case cancer = "Cancer"
    case leo = "Leo"
    case virgo = "Virgo"
    case libra = "Libra"
    case scorpio = "Scorpio"
    case sagittarius = "Sagittarius"
    case capricorn = "Capricorn"
    case aquarius = "Aquarius"
    case pisces = "Pisces"
    
    var symbol: String {
        switch self {
        case .aries: return "♈"
        case .taurus: return "♉"
        case .gemini: return "♊"
        case .cancer: return "♋"
        case .leo: return "♌"
        case .virgo: return "♍"
        case .libra: return "♎"
        case .scorpio: return "♏"
        case .sagittarius: return "♐"
        case .capricorn: return "♑"
        case .aquarius: return "♒"
        case .pisces: return "♓"
        }
    }
    
    var element: Element {
        switch self {
        case .aries, .leo, .sagittarius: return .fire
        case .taurus, .virgo, .capricorn: return .earth
        case .gemini, .libra, .aquarius: return .air
        case .cancer, .scorpio, .pisces: return .water
        }
    }
    
    var modality: Modality {
        switch self {
        case .aries, .cancer, .libra, .capricorn: return .cardinal
        case .taurus, .leo, .scorpio, .aquarius: return .fixed
        case .gemini, .virgo, .sagittarius, .pisces: return .mutable
        }
    }
    
    static func from(longitude: Double) -> ZodiacSign {
        let index = Int(longitude / 30.0) % 12
        return ZodiacSign.allCases[index]
    }
    
    var index: Int {
        ZodiacSign.allCases.firstIndex(of: self) ?? 0
    }
}

enum Element: String, Codable {
    case fire = "Fire"
    case earth = "Earth"
    case air = "Air"
    case water = "Water"
    
    var color: String {
        switch self {
        case .fire: return "#FF6B6B"
        case .earth: return "#8B7355"
        case .air: return "#87CEEB"
        case .water: return "#4169E1"
        }
    }
}

enum Modality: String, Codable {
    case cardinal = "Cardinal"
    case fixed = "Fixed"
    case mutable = "Mutable"
}

// MARK: - Planet

enum Planet: String, Codable, CaseIterable {
    case sun = "Sun"
    case moon = "Moon"
    case mercury = "Mercury"
    case venus = "Venus"
    case mars = "Mars"
    case jupiter = "Jupiter"
    case saturn = "Saturn"
    case uranus = "Uranus"
    case neptune = "Neptune"
    case pluto = "Pluto"
    case northNode = "North Node"
    case southNode = "South Node"
    
    var symbol: String {
        switch self {
        case .sun: return "☉"
        case .moon: return "☽"
        case .mercury: return "☿"
        case .venus: return "♀"
        case .mars: return "♂"
        case .jupiter: return "♃"
        case .saturn: return "♄"
        case .uranus: return "♅"
        case .neptune: return "♆"
        case .pluto: return "♇"
        case .northNode: return "☊"
        case .southNode: return "☋"
        }
    }
    
    var isPersonal: Bool {
        switch self {
        case .sun, .moon, .mercury, .venus, .mars:
            return true
        default:
            return false
        }
    }
    
    var isOuter: Bool {
        switch self {
        case .uranus, .neptune, .pluto:
            return true
        default:
            return false
        }
    }
}

// MARK: - Aspect

enum AspectType: String, Codable {
    case conjunction = "Conjunction"
    case sextile = "Sextile"
    case square = "Square"
    case trine = "Trine"
    case opposition = "Opposition"
    
    var angle: Double {
        switch self {
        case .conjunction: return 0
        case .sextile: return 60
        case .square: return 90
        case .trine: return 120
        case .opposition: return 180
        }
    }
    
    var symbol: String {
        switch self {
        case .conjunction: return "☌"
        case .sextile: return "⚹"
        case .square: return "□"
        case .trine: return "△"
        case .opposition: return "☍"
        }
    }
    
    var color: String {
        switch self {
        case .conjunction: return "#FFD700"  // Gold
        case .sextile: return "#4169E1"      // Blue
        case .square: return "#DC143C"       // Red
        case .trine: return "#32CD32"        // Green
        case .opposition: return "#FF4500"   // Orange-Red
        }
    }
    
    var isHarmonious: Bool {
        switch self {
        case .trine, .sextile: return true
        case .conjunction: return true  // Neutral/depends on planets
        case .square, .opposition: return false
        }
    }
}

// MARK: - Planetary Position

struct PlanetaryPosition: Codable, Equatable {
    let planet: Planet
    let longitude: Double           // 0-360 degrees
    let sign: ZodiacSign
    let degreeInSign: Double        // 0-30 degrees
    let house: Int?                 // 1-12, nil if unknown
    let isRetrograde: Bool
    let signUncertain: Bool         // For Moon when it changes signs
    let possibleSigns: [ZodiacSign]?
    
    var formattedDegree: String {
        let degrees = Int(degreeInSign)
        let minutes = Int((degreeInSign - Double(degrees)) * 60)
        return "\(degrees)°\(String(format: "%02d", minutes))'"
    }
    
    var fullDescription: String {
        var desc = "\(sign.symbol) \(formattedDegree)"
        if isRetrograde {
            desc += " ℞"
        }
        return desc
    }
}

// MARK: - Aspect

struct ChartAspect: Codable, Equatable, Identifiable {
    var id: String { "\(planet1.rawValue)-\(planet2.rawValue)-\(type.rawValue)" }
    
    let planet1: Planet
    let planet2: Planet
    let type: AspectType
    let exactAngle: Double
    let orb: Double
    let isApplying: Bool?  // nil if unknown
}

// MARK: - House

struct House: Codable, Equatable {
    let number: Int      // 1-12
    let sign: ZodiacSign
    let cuspDegree: Double
}

// MARK: - Angles

struct ChartAngles: Codable, Equatable {
    let ascendant: PlanetaryPosition?
    let midheaven: PlanetaryPosition?
    let descendant: PlanetaryPosition?
    let imumCoeli: PlanetaryPosition?
}

// MARK: - Chart Metadata

struct ChartMetadata: Codable, Equatable {
    let birthDate: Date
    let birthTimeInput: String?
    let birthPlaceInput: String?
    let latitude: Double?
    let longitude: Double?
    let timezone: String?
    let houseSystem: String
    let nodeType: String
    let utcDateTimeUsed: Date?
    let julianDay: Double?
    let assumptions: [String]
}

// MARK: - Evolutionary Core

struct EvolutionaryCore: Codable, Equatable {
    let pluto: PlanetaryPosition?
    let northNode: PlanetaryPosition?
    let southNode: PlanetaryPosition?
    let moon: PlanetaryPosition?
    let sun: PlanetaryPosition?
    let risingSign: ZodiacSign?
    let notes: [String]
}

// MARK: - Birth Chart

@Model
final class BirthChart {
    var id: UUID
    var userId: UUID                    // Links to UserProfile
    var chartType: String               // "whole", "FULL_NATAL", etc.
    var createdAt: Date
    var updatedAt: Date
    
    // Stored as JSON strings for SwiftData compatibility
    var metadataJSON: String
    var anglesJSON: String?
    var housesJSON: String?
    var planetsJSON: String
    var aspectsJSON: String?
    var evolutionaryCoreJSON: String
    
    // Computed status
    var status: String                  // "ok", "needs_geocoding", "error"
    var errors: [String]
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        chartType: String,
        status: String = "ok",
        errors: [String] = [],
        metadata: ChartMetadata,
        angles: ChartAngles?,
        houses: [House]?,
        planets: [PlanetaryPosition],
        aspects: [ChartAspect]?,
        evolutionaryCore: EvolutionaryCore,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.chartType = chartType
        self.status = status
        self.errors = errors
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        self.metadataJSON = (try? String(data: encoder.encode(metadata), encoding: .utf8)) ?? "{}"
        self.anglesJSON = angles.flatMap { try? String(data: encoder.encode($0), encoding: .utf8) }
        self.housesJSON = houses.flatMap { try? String(data: encoder.encode($0), encoding: .utf8) }
        self.planetsJSON = (try? String(data: encoder.encode(planets), encoding: .utf8)) ?? "[]"
        self.aspectsJSON = aspects.flatMap { try? String(data: encoder.encode($0), encoding: .utf8) }
        self.evolutionaryCoreJSON = (try? String(data: encoder.encode(evolutionaryCore), encoding: .utf8)) ?? "{}"
    }
    
    // MARK: - Computed Properties
    
    var metadata: ChartMetadata? {
        guard let data = metadataJSON.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ChartMetadata.self, from: data)
    }
    
    var angles: ChartAngles? {
        guard let json = anglesJSON, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ChartAngles.self, from: data)
    }
    
    var houses: [House]? {
        guard let json = housesJSON, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([House].self, from: data)
    }
    
    var planets: [PlanetaryPosition] {
        guard let data = planetsJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([PlanetaryPosition].self, from: data)) ?? []
    }
    
    var aspects: [ChartAspect]? {
        guard let json = aspectsJSON, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([ChartAspect].self, from: data)
    }
    
    var evolutionaryCore: EvolutionaryCore? {
        guard let data = evolutionaryCoreJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(EvolutionaryCore.self, from: data)
    }
    
    // MARK: - Convenience Accessors
    
    func position(for planet: Planet) -> PlanetaryPosition? {
        planets.first { $0.planet == planet }
    }
    
    var sunSign: ZodiacSign? {
        position(for: .sun)?.sign
    }
    
    var moonSign: ZodiacSign? {
        position(for: .moon)?.sign
    }
    
    var risingSign: ZodiacSign? {
        angles?.ascendant?.sign
    }
    
    var bigThree: (sun: ZodiacSign?, moon: ZodiacSign?, rising: ZodiacSign?) {
        (sunSign, moonSign, risingSign)
    }
}

