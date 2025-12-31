//
//  BirthChartView.swift
//  ephemera
//
//  A beautiful visualization of the user's birth chart.
//  Displays the chart wheel, planetary placements, and key information.
//
//  Created by Kunal_Datta on 30/12/25.
//

import SwiftUI
import SwiftData

struct BirthChartView: View {
    let chart: BirthChart
    @Query private var profiles: [UserProfile]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPlanet: PlanetaryPosition?
    @State private var showPlanetDetail = false
    @State private var showProfile = false
    
    private var currentProfile: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.03, blue: 0.08),
                    Color(red: 0.06, green: 0.04, blue: 0.14),
                    Color(red: 0.02, green: 0.02, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle star field
            StarFieldView()
                .opacity(0.25)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    headerSection
                    
                    // Chart Wheel
                    chartWheelSection
                    
                    // Big Three
                    bigThreeSection
                    
                    // Planetary Placements
                    planetaryPlacementsSection
                    
                    // Evolutionary Core
                    evolutionaryCoreSection
                    
                    // Aspects (if available)
                    if let aspects = chart.aspects, !aspects.isEmpty {
                        aspectsSection(aspects: aspects)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.7, green: 0.68, blue: 0.65))
                }
            }
            
            ToolbarItem(placement: .principal) {
                Text("Your Birth Chart")
                    .font(.custom("Georgia", size: 18))
                    .foregroundColor(Color(red: 0.9, green: 0.87, blue: 0.82))
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showProfile = true }) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 22))
                        .foregroundColor(Color(red: 0.7, green: 0.68, blue: 0.65))
                }
            }
        }
        .navigationDestination(isPresented: $showProfile) {
            if let profile = currentProfile {
                ProfileEditView(profile: profile) {
                    // On profile update, delete this chart so it can be regenerated
                    modelContext.delete(chart)
                    dismiss()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            if let metadata = chart.metadata {
                let dateFormatter: DateFormatter = {
                    let f = DateFormatter()
                    f.dateStyle = .long
                    return f
                }()
                
                Text(dateFormatter.string(from: metadata.birthDate))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
                    .tracking(1)
                
                if let place = metadata.birthPlaceInput {
                    Text(place)
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
                }
                
                // Chart type indicator
                Text(chartTypeLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.45, blue: 0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.5, green: 0.45, blue: 0.6).opacity(0.15))
                    )
                    .padding(.top, 4)
            }
        }
    }
    
    private var chartTypeLabel: String {
        switch chart.chartType {
        case "FULL_NATAL":
            return "Full Natal Chart"
        case "NOON_CHART_NO_HOUSES":
            return "Noon Chart (Time Unknown)"
        case "SIGN_BASED_NO_HOUSES":
            return "Sign-Based Chart"
        default:
            return "Whole Sign Houses"
        }
    }
    
    // MARK: - Chart Wheel Section
    
    private var chartWheelSection: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, 340)
            
            ZStack {
                // Outer ring with zodiac signs
                ChartWheelView(
                    planets: chart.planets,
                    houses: chart.houses,
                    risingSign: chart.risingSign,
                    size: size
                )
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 340)
    }
    
    // MARK: - Big Three Section
    
    private var bigThreeSection: some View {
        VStack(spacing: 16) {
            Text("THE BIG THREE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
                .tracking(2)
            
            HStack(spacing: 20) {
                if let sun = chart.position(for: .sun) {
                    bigThreeCard(title: "Sun", sign: sun.sign, symbol: "☉")
                }
                
                if let moon = chart.position(for: .moon) {
                    bigThreeCard(
                        title: "Moon",
                        sign: moon.sign,
                        symbol: "☽",
                        isUncertain: moon.signUncertain
                    )
                }
                
                if let rising = chart.risingSign {
                    bigThreeCard(title: "Rising", sign: rising, symbol: "↑")
                } else {
                    // Placeholder for missing rising
                    bigThreePlaceholder(title: "Rising")
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
    
    private func bigThreeCard(title: String, sign: ZodiacSign, symbol: String, isUncertain: Bool = false) -> some View {
        VStack(spacing: 8) {
            Text(symbol)
                .font(.system(size: 24))
                .foregroundColor(elementColor(for: sign.element))
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
                .tracking(1)
            
            Text(sign.rawValue)
                .font(.custom("Georgia", size: 15))
                .foregroundColor(Color(red: 0.9, green: 0.87, blue: 0.82))
            
            Text(sign.symbol)
                .font(.system(size: 20))
                .foregroundColor(elementColor(for: sign.element))
            
            if isUncertain {
                Text("uncertain")
                    .font(.system(size: 9))
                    .foregroundColor(Color.orange.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func bigThreePlaceholder(title: String) -> some View {
        VStack(spacing: 8) {
            Text("?")
                .font(.system(size: 24))
                .foregroundColor(Color(red: 0.4, green: 0.38, blue: 0.35))
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
                .tracking(1)
            
            Text("Unknown")
                .font(.custom("Georgia", size: 15))
                .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
            
            Text("–")
                .font(.system(size: 20))
                .foregroundColor(Color(red: 0.4, green: 0.38, blue: 0.35))
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Planetary Placements Section
    
    private var planetaryPlacementsSection: some View {
        VStack(spacing: 16) {
            Text("PLANETARY PLACEMENTS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(chart.planets, id: \.planet) { position in
                    planetCard(position: position)
                }
            }
        }
    }
    
    private func planetCard(position: PlanetaryPosition) -> some View {
        HStack(spacing: 12) {
            // Planet symbol
            Text(position.planet.symbol)
                .font(.system(size: 22))
                .foregroundColor(elementColor(for: position.sign.element))
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(position.planet.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 0.85, green: 0.82, blue: 0.78))
                    
                    if position.isRetrograde {
                        Text("℞")
                            .font(.system(size: 11))
                            .foregroundColor(Color.orange.opacity(0.8))
                    }
                }
                
                HStack(spacing: 4) {
                    Text(position.sign.symbol)
                        .font(.system(size: 14))
                    Text(position.formattedDegree)
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
                }
                
                if let house = position.house {
                    Text("House \(house)")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Evolutionary Core Section
    
    private var evolutionaryCoreSection: some View {
        VStack(spacing: 16) {
            Text("EVOLUTIONARY ASTROLOGY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let evoCore = chart.evolutionaryCore {
                VStack(spacing: 12) {
                    // Nodes row
                    HStack(spacing: 16) {
                        if let northNode = evoCore.northNode {
                            evolutionaryCard(
                                title: "North Node",
                                subtitle: "Soul's Direction",
                                position: northNode,
                                color: Color(red: 0.4, green: 0.7, blue: 0.5)
                            )
                        }
                        
                        if let southNode = evoCore.southNode {
                            evolutionaryCard(
                                title: "South Node",
                                subtitle: "Past Patterns",
                                position: southNode,
                                color: Color(red: 0.7, green: 0.5, blue: 0.4)
                            )
                        }
                    }
                    
                    // Pluto
                    if let pluto = evoCore.pluto {
                        evolutionaryCard(
                            title: "Pluto",
                            subtitle: "Soul's Evolution",
                            position: pluto,
                            color: Color(red: 0.6, green: 0.4, blue: 0.7),
                            fullWidth: true
                        )
                    }
                }
                
                // Notes
                if !evoCore.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(evoCore.notes, id: \.self) { note in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(red: 0.5, green: 0.45, blue: 0.6))
                                    .frame(width: 4, height: 4)
                                Text(note)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.5, green: 0.4, blue: 0.6).opacity(0.3),
                                    Color(red: 0.4, green: 0.5, blue: 0.6).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private func evolutionaryCard(title: String, subtitle: String, position: PlanetaryPosition, color: Color, fullWidth: Bool = false) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(position.planet.symbol)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 0.85, green: 0.82, blue: 0.78))
                
                Text("\(position.sign.rawValue) \(position.formattedDegree)")
                    .font(.system(size: 12))
                    .foregroundColor(color)
                
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
            }
            
            if fullWidth {
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.05))
        )
    }
    
    // MARK: - Aspects Section
    
    private func aspectsSection(aspects: [ChartAspect]) -> some View {
        VStack(spacing: 16) {
            Text("MAJOR ASPECTS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                ForEach(aspects.prefix(10)) { aspect in
                    aspectRow(aspect: aspect)
                }
            }
        }
    }
    
    private func aspectRow(aspect: ChartAspect) -> some View {
        HStack(spacing: 12) {
            Text(aspect.planet1.symbol)
                .font(.system(size: 18))
                .frame(width: 28)
            
            Text(aspect.type.symbol)
                .font(.system(size: 16))
                .foregroundColor(aspectColor(for: aspect.type))
                .frame(width: 24)
            
            Text(aspect.planet2.symbol)
                .font(.system(size: 18))
                .frame(width: 28)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(aspect.type.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.7, green: 0.68, blue: 0.65))
                
                Text(String(format: "%.1f° orb", aspect.orb))
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
        )
    }
    
    // MARK: - Helper Functions
    
    private func elementColor(for element: Element) -> Color {
        switch element {
        case .fire:
            return Color(red: 0.95, green: 0.5, blue: 0.4)
        case .earth:
            return Color(red: 0.6, green: 0.75, blue: 0.5)
        case .air:
            return Color(red: 0.5, green: 0.7, blue: 0.9)
        case .water:
            return Color(red: 0.5, green: 0.55, blue: 0.85)
        }
    }
    
    private func aspectColor(for type: AspectType) -> Color {
        switch type {
        case .conjunction:
            return Color(red: 0.9, green: 0.8, blue: 0.4)
        case .sextile:
            return Color(red: 0.4, green: 0.7, blue: 0.9)
        case .square:
            return Color(red: 0.9, green: 0.4, blue: 0.4)
        case .trine:
            return Color(red: 0.4, green: 0.8, blue: 0.5)
        case .opposition:
            return Color(red: 0.9, green: 0.5, blue: 0.3)
        }
    }
}

// MARK: - Chart Wheel View

struct ChartWheelView: View {
    let planets: [PlanetaryPosition]
    let houses: [House]?
    let risingSign: ZodiacSign?
    let size: CGFloat
    
    private let zodiacSigns = ZodiacSign.allCases
    
    var body: some View {
        ZStack {
            // Outer zodiac ring
            outerZodiacRing
            
            // House divisions (if available)
            if houses != nil {
                houseDivisions
            }
            
            // Planet positions
            planetPositions
            
            // Center
            centerCircle
        }
        .frame(width: size, height: size)
    }
    
    private var outerZodiacRing: some View {
        ZStack {
            // Outer circle
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.38, blue: 0.5).opacity(0.5),
                            Color(red: 0.3, green: 0.28, blue: 0.4).opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
            
            // Zodiac sign segments
            ForEach(0..<12) { index in
                let sign = zodiacSigns[index]
                let startAngle = Angle(degrees: Double(index) * 30 - 90)
                let midAngle = Angle(degrees: Double(index) * 30 + 15 - 90)
                
                // Sign divider lines
                Path { path in
                    let center = CGPoint(x: size/2, y: size/2)
                    let innerRadius = size * 0.35
                    let outerRadius = size * 0.48
                    
                    let startX = center.x + cos(startAngle.radians) * innerRadius
                    let startY = center.y + sin(startAngle.radians) * innerRadius
                    let endX = center.x + cos(startAngle.radians) * outerRadius
                    let endY = center.y + sin(startAngle.radians) * outerRadius
                    
                    path.move(to: CGPoint(x: startX, y: startY))
                    path.addLine(to: CGPoint(x: endX, y: endY))
                }
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                
                // Sign symbol
                let symbolRadius = size * 0.42
                let symbolX = size/2 + cos(midAngle.radians) * symbolRadius
                let symbolY = size/2 + sin(midAngle.radians) * symbolRadius
                
                Text(sign.symbol)
                    .font(.system(size: 16))
                    .foregroundColor(elementColor(for: sign.element).opacity(0.8))
                    .position(x: symbolX, y: symbolY)
            }
        }
    }
    
    private var houseDivisions: some View {
        ZStack {
            // House number ring
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: size * 0.7, height: size * 0.7)
            
            // House cusps and numbers
            if let risingSignIndex = risingSign?.index {
                ForEach(0..<12) { houseIndex in
                    let signIndex = (risingSignIndex + houseIndex) % 12
                    let angle = Angle(degrees: Double(signIndex) * 30 - 90)
                    let midAngle = Angle(degrees: Double(signIndex) * 30 + 15 - 90)
                    
                    // House cusp line
                    Path { path in
                        let center = CGPoint(x: size/2, y: size/2)
                        let innerRadius = size * 0.15
                        let outerRadius = size * 0.35
                        
                        let startX = center.x + cos(angle.radians) * innerRadius
                        let startY = center.y + sin(angle.radians) * innerRadius
                        let endX = center.x + cos(angle.radians) * outerRadius
                        let endY = center.y + sin(angle.radians) * outerRadius
                        
                        path.move(to: CGPoint(x: startX, y: startY))
                        path.addLine(to: CGPoint(x: endX, y: endY))
                    }
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    
                    // House number
                    let numberRadius = size * 0.25
                    let numberX = size/2 + cos(midAngle.radians) * numberRadius
                    let numberY = size/2 + sin(midAngle.radians) * numberRadius
                    
                    Text("\(houseIndex + 1)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.3))
                        .position(x: numberX, y: numberY)
                }
            }
        }
    }
    
    private var planetPositions: some View {
        ZStack {
            ForEach(planets, id: \.planet) { position in
                let angle = Angle(degrees: position.longitude - 90)
                let radius = size * 0.32
                let x = size/2 + cos(angle.radians) * radius
                let y = size/2 + sin(angle.radians) * radius
                
                // Planet symbol with glow
                ZStack {
                    // Glow
                    Circle()
                        .fill(elementColor(for: position.sign.element).opacity(0.3))
                        .frame(width: 24, height: 24)
                        .blur(radius: 4)
                    
                    // Symbol
                    Text(position.planet.symbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(elementColor(for: position.sign.element))
                }
                .position(x: x, y: y)
            }
        }
    }
    
    private var centerCircle: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.1, green: 0.1, blue: 0.18),
                            Color(red: 0.05, green: 0.05, blue: 0.1)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.15
                    )
                )
                .frame(width: size * 0.28, height: size * 0.28)
            
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                .frame(width: size * 0.28, height: size * 0.28)
            
            // Rising sign indicator
            if let rising = risingSign {
                VStack(spacing: 2) {
                    Text("ASC")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.4))
                    Text(rising.symbol)
                        .font(.system(size: 24))
                        .foregroundColor(elementColor(for: rising.element))
                }
            }
        }
    }
    
    private func elementColor(for element: Element) -> Color {
        switch element {
        case .fire:
            return Color(red: 0.95, green: 0.5, blue: 0.4)
        case .earth:
            return Color(red: 0.6, green: 0.75, blue: 0.5)
        case .air:
            return Color(red: 0.5, green: 0.7, blue: 0.9)
        case .water:
            return Color(red: 0.5, green: 0.55, blue: 0.85)
        }
    }
}

#Preview {
    NavigationStack {
        // Create a mock chart for preview
        let mockChart = BirthChart(
            userId: UUID(),
            chartType: "FULL_NATAL",
            metadata: ChartMetadata(
                birthDate: Date(),
                birthTimeInput: "14:30",
                birthPlaceInput: "New York, NY",
                latitude: 40.7128,
                longitude: -74.0060,
                timezone: "America/New_York",
                houseSystem: "WHOLE_SIGN",
                nodeType: "true",
                utcDateTimeUsed: Date(),
                julianDay: nil,
                assumptions: []
            ),
            angles: nil,
            houses: nil,
            planets: [
                PlanetaryPosition(planet: .sun, longitude: 280, sign: .capricorn, degreeInSign: 10, house: 10, isRetrograde: false, signUncertain: false, possibleSigns: nil),
                PlanetaryPosition(planet: .moon, longitude: 45, sign: .taurus, degreeInSign: 15, house: 2, isRetrograde: false, signUncertain: false, possibleSigns: nil),
                PlanetaryPosition(planet: .mercury, longitude: 265, sign: .sagittarius, degreeInSign: 25, house: 9, isRetrograde: true, signUncertain: false, possibleSigns: nil),
                PlanetaryPosition(planet: .venus, longitude: 300, sign: .capricorn, degreeInSign: 30, house: 10, isRetrograde: false, signUncertain: false, possibleSigns: nil),
                PlanetaryPosition(planet: .mars, longitude: 180, sign: .libra, degreeInSign: 0, house: 7, isRetrograde: false, signUncertain: false, possibleSigns: nil),
            ],
            aspects: nil,
            evolutionaryCore: EvolutionaryCore(
                pluto: PlanetaryPosition(planet: .pluto, longitude: 290, sign: .capricorn, degreeInSign: 20, house: 10, isRetrograde: false, signUncertain: false, possibleSigns: nil),
                northNode: PlanetaryPosition(planet: .northNode, longitude: 90, sign: .cancer, degreeInSign: 0, house: 4, isRetrograde: true, signUncertain: false, possibleSigns: nil),
                southNode: PlanetaryPosition(planet: .southNode, longitude: 270, sign: .capricorn, degreeInSign: 0, house: 10, isRetrograde: true, signUncertain: false, possibleSigns: nil),
                moon: nil,
                sun: nil,
                risingSign: .aries,
                notes: ["Whole Sign houses used"]
            )
        )
        
        BirthChartView(chart: mockChart)
    }
}

