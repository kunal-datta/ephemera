//
//  HomeView.swift
//  ephemera
//
//  Created by Kunal_Datta on 30/12/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var profiles: [UserProfile]
    @Query private var birthCharts: [BirthChart]
    @Environment(\.modelContext) private var modelContext
    
    @State private var isGeneratingChart = false
    @State private var showChart = false
    @State private var showProfile = false
    @State private var generatedChart: BirthChart?
    @State private var errorMessage: String?
    @State private var showError = false
    
    private var currentProfile: UserProfile? {
        profiles.first
    }
    
    private var currentChart: BirthChart? {
        birthCharts.first
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.08, green: 0.06, blue: 0.18),
                    Color(red: 0.04, green: 0.04, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            StarFieldView()
                .opacity(0.3)
            
            VStack(spacing: 32) {
                Spacer()
                
                // Welcome message
                VStack(spacing: 12) {
                    Text("ephemera")
                        .font(.custom("Georgia", size: 36))
                        .fontWeight(.light)
                        .tracking(4)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.92, blue: 0.88),
                                    Color(red: 0.82, green: 0.78, blue: 0.72)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    if let profile = currentProfile {
                        Text("Welcome, \(profile.name)")
                            .font(.custom("Georgia", size: 18))
                            .foregroundColor(Color(red: 0.7, green: 0.68, blue: 0.65))
                            .padding(.top, 8)
                    }
                }
                
                Spacer()
                
                // Main action buttons
                VStack(spacing: 16) {
                    // See my chart button
                    Button(action: handleSeeMyChart) {
                        HStack(spacing: 12) {
                            if isGeneratingChart {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.05, green: 0.05, blue: 0.1)))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "circle.hexagongrid.fill")
                                    .font(.system(size: 20))
                            }
                            
                            Text(isGeneratingChart ? "Calculating..." : "See my chart")
                                .font(.custom("Georgia", size: 17))
                                .fontWeight(.medium)
                        }
                        .foregroundColor(Color(red: 0.05, green: 0.05, blue: 0.1))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.95, green: 0.9, blue: 0.82),
                                            Color(red: 0.88, green: 0.83, blue: 0.75)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .shadow(color: Color(red: 0.95, green: 0.9, blue: 0.82).opacity(0.2), radius: 12, y: 4)
                    }
                    .disabled(isGeneratingChart || currentProfile == nil)
                    .opacity(currentProfile == nil ? 0.5 : 1)
                    
                    // Secondary info
                    if currentChart != nil {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(red: 0.4, green: 0.7, blue: 0.5))
                                .frame(width: 6, height: 6)
                            Text("Chart calculated")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
                        }
                    } else if currentProfile != nil {
                        Text("Tap to calculate your birth chart")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Placeholder content
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundColor(Color(red: 0.6, green: 0.55, blue: 0.5))
                    
                    Text("Your cosmic journey awaits")
                        .font(.custom("Georgia", size: 16))
                        .foregroundColor(Color(red: 0.5, green: 0.48, blue: 0.45))
                        .italic()
                }
                
                Spacer()
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showProfile = true }) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 22))
                        .foregroundColor(Color(red: 0.7, green: 0.68, blue: 0.65))
                }
                .opacity(currentProfile != nil ? 1 : 0)
            }
        }
        .navigationDestination(isPresented: $showChart) {
            if let chart = generatedChart ?? currentChart {
                BirthChartView(chart: chart)
            }
        }
        .navigationDestination(isPresented: $showProfile) {
            if let profile = currentProfile {
                ProfileEditView(profile: profile) {
                    // On profile update, delete existing chart so it can be regenerated
                    if let existingChart = currentChart {
                        modelContext.delete(existingChart)
                        generatedChart = nil
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Actions
    
    private func handleSeeMyChart() {
        // If we already have a chart, just show it
        if let existingChart = currentChart {
            generatedChart = existingChart
            showChart = true
            return
        }
        
        // Otherwise, generate a new chart
        guard let profile = currentProfile else { return }
        
        isGeneratingChart = true
        
        Task {
            await generateAndSaveChart(for: profile)
        }
    }
    
    private func generateAndSaveChart(for profile: UserProfile) async {
        // Build chart input from profile
        // Timezone is now stored directly from the Google Timezone API during onboarding
        let input = ChartInput(
            name: profile.name,
            birthDate: profile.dateOfBirth,
            birthTime: profile.timeOfBirth,
            birthTimeUnknown: profile.timeOfBirthUnknown,
            birthPlace: profile.placeOfBirth,
            latitude: profile.placeOfBirthLatitude,
            longitude: profile.placeOfBirthLongitude,
            timezone: profile.placeOfBirthTimezone,
            nodeType: .trueNode
        )
        
        // Generate the chart
        let result = ChartCore.shared.generateChart(input: input)
        
        await MainActor.run {
            isGeneratingChart = false
            
            switch result.status {
            case .ok:
                // Create BirthChart from result
                if let chart = BirthChart.from(result: result, userId: profile.id) {
                    // Save to SwiftData
                    modelContext.insert(chart)
                    
                    // Save to Firestore
                    Task {
                        do {
                            try await FirestoreService.shared.saveBirthChart(chart)
                            print("✅ Birth chart saved to Firestore")
                        } catch {
                            print("❌ Failed to save chart to Firestore: \(error)")
                        }
                    }
                    
                    generatedChart = chart
                    showChart = true
                } else {
                    errorMessage = "Failed to create birth chart from calculation"
                    showError = true
                }
                
            case .needsGeocoding:
                errorMessage = "Location data is incomplete. Please update your birth place."
                showError = true
                
            case .error:
                errorMessage = result.errors.joined(separator: "\n")
                showError = true
            }
        }
    }
    
}

#Preview {
    NavigationStack {
        HomeView()
            .modelContainer(for: [UserProfile.self, BirthChart.self], inMemory: true)
    }
}
