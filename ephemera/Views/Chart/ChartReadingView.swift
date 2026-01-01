//
//  ChartReadingView.swift
//  ephemera
//
//  Displays the AI-generated personalized reading for a birth chart.
//  This is the interpretive, narrative view that makes astrology accessible.
//
//  Created by Kunal_Datta on 30/12/25.
//

import SwiftUI
import SwiftData

struct ChartReadingView: View {
    let chart: BirthChart
    let profile: UserProfile
    
    @Query private var contexts: [UserContext]
    @StateObject private var readingService = AIReadingService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var reading: AIReading?
    @State private var showError = false
    @State private var expandedSections: Set<UUID> = []
    @State private var hasAppeared = false
    @State private var currentCardIndex = 0
    
    // Filter contexts for this user
    private var userContexts: [UserContext] {
        contexts.filter { $0.userId == profile.id }
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
                .opacity(0.2)
            
            if readingService.isGenerating {
                loadingView
            } else if let reading = reading {
                readingContent(reading)
            } else if let error = readingService.error {
                errorView(error)
            } else {
                // Initial state - will auto-generate
                loadingView
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
                Text("Your Reading")
                    .font(.custom("Georgia", size: 18))
                    .foregroundColor(Color(red: 0.9, green: 0.87, blue: 0.82))
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                generateReading()
            }
        }
        .alert("Unable to Generate Reading", isPresented: $showError) {
            Button("Try Again") {
                generateReading()
            }
            Button("Go Back", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(readingService.error ?? "An unexpected error occurred.")
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            // Animated cosmic loader
            ZStack {
                Circle()
                    .stroke(Color(red: 0.5, green: 0.45, blue: 0.6).opacity(0.2), lineWidth: 3)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.7, green: 0.6, blue: 0.8),
                                Color(red: 0.5, green: 0.45, blue: 0.6)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(hasAppeared ? 360 : 0))
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: hasAppeared)
                
                Text("✧")
                    .font(.system(size: 28))
                    .foregroundColor(Color(red: 0.8, green: 0.75, blue: 0.9))
            }
            
            VStack(spacing: 8) {
                Text("Interpreting the stars...")
                    .font(.custom("Georgia", size: 20))
                    .foregroundColor(Color(red: 0.9, green: 0.87, blue: 0.82))
                
                Text("Weaving together your cosmic story")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
            }
        }
    }
    
    // MARK: - Reading Content
    
    private func readingContent(_ reading: AIReading) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Interactive chart at top
                interactiveChartSection(reading: reading)
                    .padding(.top, 8)
                
                // Custom page indicator below chart
                if !reading.sections.isEmpty {
                    pageIndicator(total: reading.sections.count)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                }
                
                // Cards with swipe gesture navigation
                if !reading.sections.isEmpty {
                    let section = reading.sections[currentCardIndex]
                    sectionCard(section)
                        .id(currentCardIndex) // Force view refresh on index change
                        .transition(.opacity)
                        .gesture(
                            DragGesture(minimumDistance: 50)
                                .onEnded { value in
                                    let horizontalAmount = value.translation.width
                                    if horizontalAmount < -50 && currentCardIndex < reading.sections.count - 1 {
                                        // Swipe left - next card
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            currentCardIndex += 1
                                        }
                                    } else if horizontalAmount > 50 && currentCardIndex > 0 {
                                        // Swipe right - previous card
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            currentCardIndex -= 1
                                        }
                                    }
                                }
                        )
                } else {
                    // Fallback: show raw content if parsing failed
                    rawContentCard(reading.content)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Interactive Chart Section
    
    private func interactiveChartSection(reading: AIReading) -> some View {
        let currentSection = reading.sections.indices.contains(currentCardIndex) ? reading.sections[currentCardIndex] : nil
        let highlightedPlanets = currentSection?.relatedPlanets ?? []
        let highlightRising = currentSection?.relatestoRising ?? false
        
        // Determine which planets are actually interactive (have a linked section)
        let interactivePlanets = Set(reading.sections.flatMap { $0.relatedPlanets })
        let hasRisingSection = reading.sections.contains { $0.relatestoRising }
        
        return VStack(spacing: 8) {
            // Section title above chart
            if let section = currentSection {
                Text(cleanSectionTitle(section.title))
                    .font(.custom("Georgia", size: 16))
                    .foregroundColor(Color(red: 0.9, green: 0.87, blue: 0.82))
                    .lineLimit(1)
                    .padding(.horizontal, 20)
            }
            
            // Interactive chart wheel
            GeometryReader { geometry in
                let size = min(geometry.size.width - 40, 280)
                
                InteractiveChartWheelView(
                    planets: chart.planets,
                    houses: chart.houses,
                    risingSign: chart.risingSign,
                    size: size,
                    highlightedPlanets: highlightedPlanets,
                    highlightRising: highlightRising,
                    interactivePlanets: interactivePlanets,
                    isRisingInteractive: hasRisingSection,
                    onPlanetTapped: { planet in
                        // Find the section that relates to this planet and jump to it
                        if let index = findSectionIndex(for: planet, in: reading.sections) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentCardIndex = index
                            }
                        }
                    },
                    onRisingTapped: {
                        // Find the rising section and jump to it
                        if let index = reading.sections.firstIndex(where: { $0.relatestoRising }) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentCardIndex = index
                            }
                        }
                    }
                )
                .frame(width: size, height: size)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 280)
        }
    }
    
    /// Find the section index that best matches a tapped planet
    private func findSectionIndex(for planet: Planet, in sections: [ReadingSection]) -> Int? {
        // Priority order for matching
        // 1. Exact match where this is the only/primary planet
        // 2. Match where this planet is in the related planets list
        
        for (index, section) in sections.enumerated() {
            let related = section.relatedPlanets
            
            // Prioritize sections where this is the main planet
            if related.count == 1 && related.contains(planet) {
                return index
            }
        }
        
        // Fallback: find any section containing this planet
        for (index, section) in sections.enumerated() {
            if section.relatedPlanets.contains(planet) {
                return index
            }
        }
        
        return nil
    }
    
    // MARK: - Page Indicator (tappable)
    
    private func pageIndicator(total: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Button(action: {
                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                    impactLight.impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentCardIndex = index
                    }
                }) {
                    Circle()
                        .fill(index == currentCardIndex 
                            ? Color(red: 0.7, green: 0.65, blue: 0.8) 
                            : Color.white.opacity(0.25))
                        .frame(width: index == currentCardIndex ? 10 : 8, height: index == currentCardIndex ? 10 : 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentCardIndex)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 24, height: 24) // Larger tap target
            }
        }
    }
    
    private func sectionCard(_ section: ReadingSection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Text(cleanSectionTitle(section.title))
                .font(.custom("Georgia", size: 22))
                .foregroundColor(Color(red: 0.95, green: 0.92, blue: 0.88))
            
            // Section body with markdown rendering
            markdownText(section.body)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 20)
    }
    
    private func rawContentCard(_ content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            markdownText(content)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
        )
    }
    
    /// Renders markdown text with proper styling for bold, italic, and bullet points
    @ViewBuilder
    private func markdownText(_ text: String) -> some View {
        if let attributedString = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributedString)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(red: 0.75, green: 0.73, blue: 0.70))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            // Fallback to plain text if markdown parsing fails
            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(red: 0.75, green: 0.73, blue: 0.70))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(Color(red: 0.9, green: 0.6, blue: 0.5))
            
            Text("Unable to Generate Reading")
                .font(.custom("Georgia", size: 20))
                .foregroundColor(Color(red: 0.9, green: 0.87, blue: 0.82))
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.6, green: 0.58, blue: 0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: generateReading) {
                Text("Try Again")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.05, green: 0.05, blue: 0.1))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.92, green: 0.88, blue: 0.82))
                    )
            }
        }
    }
    
    // MARK: - Helpers
    
    private func generateReading() {
        Task {
            do {
                reading = try await readingService.generateNatalReading(
                    chart: chart,
                    profile: profile,
                    contexts: userContexts
                )
            } catch {
                showError = true
            }
        }
    }
    
    private func formatBirthInfo(_ metadata: ChartMetadata) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        if let tzId = metadata.timezone, let tz = TimeZone(identifier: tzId) {
            dateFormatter.timeZone = tz
        }
        
        var info = dateFormatter.string(from: metadata.birthDate)
        if let place = metadata.birthPlaceInput {
            info += "\n\(place)"
        }
        return info
    }
    
    private func cleanSectionTitle(_ title: String) -> String {
        // Remove any emoji or special characters at the start
        title.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Interactive Chart Wheel View

/// A chart wheel that supports highlighting specific planets and tap interactions
struct InteractiveChartWheelView: View {
    let planets: [PlanetaryPosition]
    let houses: [House]?
    let risingSign: ZodiacSign?
    let size: CGFloat
    let highlightedPlanets: [Planet]
    let highlightRising: Bool
    let interactivePlanets: Set<Planet>  // Only these planets are tappable
    let isRisingInteractive: Bool        // Whether the rising sign is tappable
    let onPlanetTapped: (Planet) -> Void
    let onRisingTapped: () -> Void
    
    private let zodiacSigns = ZodiacSign.allCases
    
    /// Computed planet positions with collision avoidance
    private var adjustedPlanetPositions: [(position: PlanetaryPosition, adjustedLongitude: Double, radiusOffset: Double)] {
        // Sort planets by longitude
        let sorted = planets.sorted { $0.longitude < $1.longitude }
        var result: [(position: PlanetaryPosition, adjustedLongitude: Double, radiusOffset: Double)] = []
        
        let minSeparation: Double = 15 // Minimum degrees between planets
        
        for (index, planet) in sorted.enumerated() {
            var adjustedLong = planet.longitude
            var radiusOffset: Double = 0
            
            // Check for collision with previous planet
            if index > 0 {
                let prevAdjusted = result[index - 1].adjustedLongitude
                let diff = adjustedLong - prevAdjusted
                
                if diff < minSeparation {
                    // Alternate between pushing outward and inward
                    if index % 2 == 0 {
                        radiusOffset = 0.06 // Push outward
                    } else {
                        radiusOffset = -0.06 // Push inward
                    }
                    // Also adjust longitude slightly
                    adjustedLong = prevAdjusted + minSeparation * 0.5
                }
            }
            
            result.append((position: planet, adjustedLongitude: adjustedLong, radiusOffset: radiusOffset))
        }
        
        return result
    }
    
    var body: some View {
        ZStack {
            // Outer zodiac ring (dimmed when highlighting)
            outerZodiacRing
            
            // House divisions (if available)
            if houses != nil {
                houseDivisions
            }
            
            // Planet positions with highlighting
            planetPositions
            
            // Center with rising sign
            centerCircle
        }
        .frame(width: size, height: size)
    }
    
    private var outerZodiacRing: some View {
        ZStack {
            // Outer circle - subtle border
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
            
            // Zodiac sign segments - very subtle watermark style
            ForEach(0..<12) { index in
                let sign = zodiacSigns[index]
                let midAngle = Angle(degrees: Double(index) * 30 + 15 - 90)
                
                // Sign symbol - watermark style (very faint)
                let symbolRadius = size * 0.43
                let symbolX = size/2 + cos(midAngle.radians) * symbolRadius
                let symbolY = size/2 + sin(midAngle.radians) * symbolRadius
                
                Text(sign.symbol)
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(Color.white.opacity(0.08))
                    .position(x: symbolX, y: symbolY)
            }
        }
        .allowsHitTesting(false)
    }
    
    private var houseDivisions: some View {
        // Inner ring only - no house numbers to avoid confusion
        Circle()
            .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
            .frame(width: size * 0.7, height: size * 0.7)
            .allowsHitTesting(false)
    }
    
    private var planetPositions: some View {
        ZStack {
            ForEach(adjustedPlanetPositions, id: \.position.planet) { item in
                let position = item.position
                let angle = Angle(degrees: item.adjustedLongitude - 90)
                let baseRadius = size * 0.32
                let adjustedRadius = baseRadius + (size * item.radiusOffset)
                let x = size/2 + cos(angle.radians) * adjustedRadius
                let y = size/2 + sin(angle.radians) * adjustedRadius
                
                let isInteractive = interactivePlanets.contains(position.planet)
                let isHighlighted = highlightedPlanets.contains(position.planet)
                let shouldDim = !highlightedPlanets.isEmpty && !isHighlighted
                
                if isInteractive {
                    // Interactive planet - button style
                    PlanetButton(
                        planet: position.planet,
                        sign: position.sign,
                        isHighlighted: isHighlighted,
                        shouldDim: shouldDim,
                        onTap: { onPlanetTapped(position.planet) }
                    )
                    .position(x: x, y: y)
                } else {
                    // Non-interactive planet - just a subtle symbol
                    DecorativePlanetView(
                        planet: position.planet,
                        sign: position.sign
                    )
                    .position(x: x, y: y)
                }
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
                if isRisingInteractive {
                    RisingButton(
                        sign: rising,
                        isHighlighted: highlightRising,
                        size: size,
                        onTap: onRisingTapped
                    )
                } else {
                    // Non-interactive rising - just display
                    DecorativeRisingView(sign: rising, size: size)
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

// MARK: - Planet Button (with proper tap target)

/// A tappable planet with 44x44pt minimum tap target and visual feedback
struct PlanetButton: View {
    let planet: Planet
    let sign: ZodiacSign
    let isHighlighted: Bool
    let shouldDim: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    private var elementColor: Color {
        switch sign.element {
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
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactLight = UIImpactFeedbackGenerator(style: .light)
            impactLight.impactOccurred()
            onTap()
        }) {
            ZStack {
                // Invisible tap target (minimum 44x44)
                Circle()
                    .fill(Color.clear)
                    .frame(width: 44, height: 44)
                
                // Highlight glow for active planets
                if isHighlighted {
                    Circle()
                        .fill(elementColor.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .blur(radius: 10)
                    
                    // Pulsing ring
                    Circle()
                        .stroke(elementColor.opacity(0.7), lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
                
                // Background glow
                Circle()
                    .fill(elementColor.opacity(shouldDim ? 0.15 : 0.35))
                    .frame(width: 26, height: 26)
                    .blur(radius: 4)
                
                // Solid background for better visibility
                Circle()
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                    .frame(width: 24, height: 24)
                
                // Colored ring
                Circle()
                    .stroke(elementColor.opacity(shouldDim ? 0.3 : 0.8), lineWidth: 1.5)
                    .frame(width: 24, height: 24)
                
                // Symbol
                Text(planet.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(elementColor.opacity(shouldDim ? 0.4 : 1.0))
            }
            .scaleEffect(isPressed ? 1.2 : 1.0)
        }
        .buttonStyle(PlanetTapStyle(isPressed: $isPressed))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHighlighted)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
    }
}

/// Custom button style for planet tap feedback
struct PlanetTapStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

// MARK: - Rising Button (center tap target)

/// A tappable rising sign indicator with proper tap feedback
struct RisingButton: View {
    let sign: ZodiacSign
    let isHighlighted: Bool
    let size: CGFloat
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    private var elementColor: Color {
        switch sign.element {
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
    
    var body: some View {
        Button(action: {
            let impactLight = UIImpactFeedbackGenerator(style: .light)
            impactLight.impactOccurred()
            onTap()
        }) {
            ZStack {
                // Highlight glow when rising is highlighted
                if isHighlighted {
                    Circle()
                        .fill(elementColor.opacity(0.35))
                        .frame(width: size * 0.26, height: size * 0.26)
                        .blur(radius: 8)
                }
                
                VStack(spacing: 2) {
                    Text("ASC")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(Color.white.opacity(isHighlighted ? 0.9 : 0.5))
                    Text(sign.symbol)
                        .font(.system(size: 24))
                        .foregroundColor(elementColor.opacity(isHighlighted ? 1.0 : 0.75))
                }
            }
            .frame(width: size * 0.26, height: size * 0.26) // Full center area is tappable
            .contentShape(Circle())
            .scaleEffect(isPressed ? 1.1 : 1.0)
        }
        .buttonStyle(PlanetTapStyle(isPressed: $isPressed))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHighlighted)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
    }
}

// MARK: - Decorative Planet View (non-interactive)

/// A non-interactive planet display - just a subtle symbol, no button styling
struct DecorativePlanetView: View {
    let planet: Planet
    let sign: ZodiacSign
    
    private var elementColor: Color {
        switch sign.element {
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
    
    var body: some View {
        // Just the symbol, no background circle - clearly not a button
        Text(planet.symbol)
            .font(.system(size: 12, weight: .regular))
            .foregroundColor(elementColor.opacity(0.35))
            .allowsHitTesting(false)
    }
}

// MARK: - Decorative Rising View (non-interactive)

/// A non-interactive rising sign display
struct DecorativeRisingView: View {
    let sign: ZodiacSign
    let size: CGFloat
    
    private var elementColor: Color {
        switch sign.element {
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
    
    var body: some View {
        VStack(spacing: 2) {
            Text("ASC")
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(Color.white.opacity(0.3))
            Text(sign.symbol)
                .font(.system(size: 20))
                .foregroundColor(elementColor.opacity(0.5))
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    NavigationStack {
        // Create mock data for preview
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
                houseSystem: "PLACIDUS",
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
            ],
            aspects: nil,
            evolutionaryCore: EvolutionaryCore(
                pluto: nil,
                northNode: PlanetaryPosition(planet: .northNode, longitude: 90, sign: .cancer, degreeInSign: 0, house: 4, isRetrograde: true, signUncertain: false, possibleSigns: nil),
                southNode: PlanetaryPosition(planet: .southNode, longitude: 270, sign: .capricorn, degreeInSign: 0, house: 10, isRetrograde: true, signUncertain: false, possibleSigns: nil),
                moon: nil,
                sun: nil,
                risingSign: .aries,
                notes: []
            )
        )
        
        let mockProfile = UserProfile(
            name: "Alex",
            email: "alex@test.com",
            dateOfBirth: Date(),
            authProvider: "email"
        )
        
        ChartReadingView(chart: mockChart, profile: mockProfile)
    }
}

