//
//  ProfileEditView.swift
//  ephemera
//
//  Allows users to view and edit their profile information.
//
//  Created by Kunal_Datta on 30/12/25.
//

import SwiftUI
import SwiftData

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var birthCharts: [BirthChart]
    
    let profile: UserProfile
    var onProfileUpdated: (() -> Void)?
    
    // Form state - initialized from profile
    @State private var name: String = ""
    @State private var dateOfBirth: Date = Date()
    @State private var timeOfBirth: Date = Date()
    @State private var timeOfBirthUnknown: Bool = false
    @State private var placeOfBirth: String = ""
    @State private var placeOfBirthLatitude: Double?
    @State private var placeOfBirthLongitude: Double?
    @State private var placeOfBirthTimezone: String?
    @State private var placeOfBirthUnknown: Bool = false
    
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    // Place search
    @StateObject private var placesService = PlacesService.shared
    @State private var searchText = ""
    @State private var showDropdown = false
    @State private var selectedPlace: PlacePrediction?
    @FocusState private var isPlaceFocused: Bool
    
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
                .opacity(0.25)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.7, green: 0.65, blue: 0.55),
                                        Color(red: 0.5, green: 0.45, blue: 0.4)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        Text("Edit Profile")
                            .font(.custom("Georgia", size: 24))
                            .foregroundColor(Color(red: 0.95, green: 0.92, blue: 0.88))
                    }
                    .padding(.top, 20)
                    
                    // Form fields
                    VStack(spacing: 24) {
                        // Name
                        nameField
                        
                        // Date of Birth
                        dateOfBirthField
                        
                        // Time of Birth
                        timeOfBirthField
                        
                        // Place of Birth
                        placeOfBirthField
                    }
                    .padding(.horizontal, 24)
                    
                    // Save Button
                    Button(action: saveProfile) {
                        HStack(spacing: 12) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.05, green: 0.05, blue: 0.1)))
                                    .scaleEffect(0.8)
                            }
                            Text(isSaving ? "Saving..." : "Save Changes")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.05, green: 0.05, blue: 0.1))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(red: 0.92, green: 0.88, blue: 0.82))
                        )
                    }
                    .disabled(isSaving || !isFormValid)
                    .opacity(isFormValid ? 1 : 0.5)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.7, green: 0.68, blue: 0.65))
                }
            }
            
            ToolbarItem(placement: .principal) {
                Text("Profile")
                    .font(.custom("Georgia", size: 18))
                    .foregroundColor(Color(red: 0.9, green: 0.87, blue: 0.82))
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadProfileData()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .alert("Saved", isPresented: $showSaveSuccess) {
            Button("OK") { 
                onProfileUpdated?()
                dismiss()
            }
        } message: {
            Text("Your profile and chart have been updated!")
        }
    }
    
    // MARK: - Form Fields
    
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NAME")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.4))
                .tracking(2)
            
            TextField("", text: $name, prompt: Text("Your name")
                .foregroundColor(Color.white.opacity(0.25)))
            .font(.system(size: 17))
            .foregroundColor(.white)
            .textContentType(.name)
            .autocorrectionDisabled()
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
    
    private var dateOfBirthField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DATE OF BIRTH")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.4))
                .tracking(2)
            
            DatePicker(
                "",
                selection: $dateOfBirth,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .colorScheme(.dark)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
    
    private var timeOfBirthField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TIME OF BIRTH")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.4))
                .tracking(2)
            
            if !timeOfBirthUnknown {
                DatePicker(
                    "",
                    selection: $timeOfBirth,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .colorScheme(.dark)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.25)) {
                    timeOfBirthUnknown.toggle() 
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: timeOfBirthUnknown ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(timeOfBirthUnknown 
                                         ? Color(red: 0.7, green: 0.65, blue: 0.55) 
                                         : Color.white.opacity(0.3))
                    
                    Text("I don't know my birth time")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var placeOfBirthField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PLACE OF BIRTH")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.4))
                .tracking(2)
            
            if !placeOfBirthUnknown {
                VStack(spacing: 0) {
                    // Search field
                    HStack {
                        TextField("", text: $searchText, prompt: Text("Search for a city...")
                            .foregroundColor(Color.white.opacity(0.25)))
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .focused($isPlaceFocused)
                        .onChange(of: searchText) { _, newValue in
                            if selectedPlace == nil || newValue != selectedPlace?.displayText {
                                placesService.searchPlaces(query: newValue)
                                showDropdown = !newValue.isEmpty
                            }
                        }
                        
                        if placesService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.7, green: 0.65, blue: 0.55)))
                                .scaleEffect(0.8)
                        } else if !searchText.isEmpty {
                            Button(action: clearPlace) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.white.opacity(0.3))
                                    .font(.system(size: 18))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isPlaceFocused 
                                            ? Color(red: 0.5, green: 0.45, blue: 0.6) 
                                            : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                    )
                    
                    // Dropdown with predictions
                    if showDropdown && !placesService.predictions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(placesService.predictions) { prediction in
                                Button(action: { selectPlace(prediction) }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(Color(red: 0.6, green: 0.55, blue: 0.7))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(prediction.mainText)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.white)
                                            
                                            if !prediction.secondaryText.isEmpty {
                                                Text(prediction.secondaryText)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Color.white.opacity(0.5))
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.clear)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if prediction.id != placesService.predictions.last?.id {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 1)
                                        .padding(.leading, 48)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.top, 8)
                    }
                }
            }
            
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.25)) {
                    placeOfBirthUnknown.toggle()
                    if placeOfBirthUnknown {
                        placesService.clearPredictions()
                        showDropdown = false
                    }
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: placeOfBirthUnknown ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(placeOfBirthUnknown 
                                         ? Color(red: 0.7, green: 0.65, blue: 0.55) 
                                         : Color.white.opacity(0.3))
                    
                    Text("I don't know my birth place")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (placeOfBirthUnknown || !placeOfBirth.trimmingCharacters(in: .whitespaces).isEmpty)
    }
    
    // MARK: - Actions
    
    private func loadProfileData() {
        name = profile.name
        timeOfBirthUnknown = profile.timeOfBirthUnknown
        placeOfBirthUnknown = profile.placeOfBirthUnknown
        
        placeOfBirthLatitude = profile.placeOfBirthLatitude
        placeOfBirthLongitude = profile.placeOfBirthLongitude
        placeOfBirthTimezone = profile.placeOfBirthTimezone
        
        if let place = profile.placeOfBirth {
            placeOfBirth = place
            searchText = place
        }
        
        // Get the birth location timezone
        let birthTimezone: TimeZone
        if let tzId = profile.placeOfBirthTimezone, let tz = TimeZone(identifier: tzId) {
            birthTimezone = tz
        } else {
            birthTimezone = TimeZone.current
        }
        
        // Extract date components from stored date using birth location timezone
        var birthLocationCalendar = Calendar.current
        birthLocationCalendar.timeZone = birthTimezone
        let dateComponents = birthLocationCalendar.dateComponents([.year, .month, .day], from: profile.dateOfBirth)
        
        // Create a Date that displays correctly in device timezone
        var deviceCalendar = Calendar.current
        deviceCalendar.timeZone = TimeZone.current
        
        var localDate = DateComponents()
        localDate.year = dateComponents.year
        localDate.month = dateComponents.month
        localDate.day = dateComponents.day
        localDate.hour = 12  // Noon in device timezone for display
        localDate.minute = 0
        localDate.timeZone = TimeZone.current
        
        dateOfBirth = deviceCalendar.date(from: localDate) ?? profile.dateOfBirth
        
        // Extract time components from stored time using birth location timezone
        // Then create a Date that displays those same numbers in device timezone
        if let storedTime = profile.timeOfBirth {
            let timeComponents = birthLocationCalendar.dateComponents([.hour, .minute, .second], from: storedTime)
            
            var deviceTime = DateComponents()
            deviceTime.year = dateComponents.year
            deviceTime.month = dateComponents.month
            deviceTime.day = dateComponents.day
            deviceTime.hour = timeComponents.hour
            deviceTime.minute = timeComponents.minute
            deviceTime.second = timeComponents.second
            deviceTime.timeZone = TimeZone.current
            
            timeOfBirth = deviceCalendar.date(from: deviceTime) ?? storedTime
        }
    }
    
    private func clearPlace() {
        searchText = ""
        placeOfBirth = ""
        placeOfBirthLatitude = nil
        placeOfBirthLongitude = nil
        placeOfBirthTimezone = nil
        selectedPlace = nil
        placesService.clearPredictions()
        showDropdown = false
    }
    
    private func selectPlace(_ prediction: PlacePrediction) {
        selectedPlace = prediction
        searchText = prediction.displayText
        placeOfBirth = prediction.displayText
        showDropdown = false
        placesService.clearPredictions()
        isPlaceFocused = false
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Fetch place details
        Task {
            do {
                let details = try await placesService.fetchPlaceDetails(
                    placeId: prediction.id,
                    referenceDate: dateOfBirth
                )
                await MainActor.run {
                    placeOfBirthLatitude = details.latitude
                    placeOfBirthLongitude = details.longitude
                    placeOfBirthTimezone = details.timezoneId
                }
            } catch {
                print("❌ Failed to fetch place details: \(error)")
            }
        }
    }
    
    private func saveProfile() {
        isSaving = true
        
        // Store dateOfBirth at noon in the birth location's timezone
        // This ensures the date is always correct regardless of device timezone
        let normalizedDateOfBirth: Date = {
            let birthTimezone: TimeZone
            if let tzId = placeOfBirthTimezone, let tz = TimeZone(identifier: tzId) {
                birthTimezone = tz
            } else {
                birthTimezone = TimeZone.current
            }
            
            // Extract date as user sees it on their device
            var deviceCalendar = Calendar.current
            deviceCalendar.timeZone = TimeZone.current
            let dateComponents = deviceCalendar.dateComponents([.year, .month, .day], from: dateOfBirth)
            
            // Store at noon in birth location timezone
            var birthLocationCalendar = Calendar.current
            birthLocationCalendar.timeZone = birthTimezone
            
            var normalized = DateComponents()
            normalized.year = dateComponents.year
            normalized.month = dateComponents.month
            normalized.day = dateComponents.day
            normalized.hour = 12  // Noon in birth location timezone
            normalized.minute = 0
            normalized.second = 0
            normalized.timeZone = birthTimezone
            
            return birthLocationCalendar.date(from: normalized) ?? dateOfBirth
        }()
        
        // Normalize the timeOfBirth with correct date and timezone
        let normalizedTimeOfBirth: Date? = {
            guard !timeOfBirthUnknown else { return nil }
            
            let birthTimezone: TimeZone
            if let tzId = placeOfBirthTimezone, let tz = TimeZone(identifier: tzId) {
                birthTimezone = tz
            } else {
                birthTimezone = TimeZone.current
            }
            
            var deviceCalendar = Calendar.current
            deviceCalendar.timeZone = TimeZone.current
            let timeComponents = deviceCalendar.dateComponents([.hour, .minute, .second], from: timeOfBirth)
            let dateComponents = deviceCalendar.dateComponents([.year, .month, .day], from: dateOfBirth)
            
            var birthLocationCalendar = Calendar.current
            birthLocationCalendar.timeZone = birthTimezone
            
            var combined = DateComponents()
            combined.year = dateComponents.year
            combined.month = dateComponents.month
            combined.day = dateComponents.day
            combined.hour = timeComponents.hour
            combined.minute = timeComponents.minute
            combined.second = timeComponents.second
            combined.timeZone = birthTimezone
            
            return birthLocationCalendar.date(from: combined)
        }()
        
        // Update the profile object
        profile.name = name
        profile.dateOfBirth = normalizedDateOfBirth
        profile.timeOfBirth = normalizedTimeOfBirth
        profile.timeOfBirthUnknown = timeOfBirthUnknown
        profile.placeOfBirth = placeOfBirthUnknown ? nil : placeOfBirth
        profile.placeOfBirthLatitude = placeOfBirthUnknown ? nil : placeOfBirthLatitude
        profile.placeOfBirthLongitude = placeOfBirthUnknown ? nil : placeOfBirthLongitude
        profile.placeOfBirthTimezone = placeOfBirthUnknown ? nil : placeOfBirthTimezone
        profile.placeOfBirthUnknown = placeOfBirthUnknown
        profile.updatedAt = Date()
        
        // Delete existing charts (they need to be regenerated with new data)
        for chart in birthCharts {
            modelContext.delete(chart)
        }
        
        // Save to Firestore, delete old charts, and generate new chart
        Task {
            do {
                // Delete charts from Firestore first
                try await FirestoreService.shared.deleteAllBirthCharts()
                
                // Save updated profile
                try await FirestoreService.shared.saveUserProfile(profile)
                
                // Generate new chart with updated profile data
                await generateNewChart()
                
                await MainActor.run {
                    isSaving = false
                    showSaveSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save profile: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func generateNewChart() async {
        // Build chart input from updated profile
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
            if result.status == .ok, let chart = BirthChart.from(result: result, userId: profile.id) {
                // Save to SwiftData
                modelContext.insert(chart)
                
                // Save to Firestore
                Task {
                    do {
                        try await FirestoreService.shared.saveBirthChart(chart)
                        print("✅ New birth chart generated and saved to Firestore")
                    } catch {
                        print("❌ Failed to save new chart to Firestore: \(error)")
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileEditView(
            profile: UserProfile(
                name: "Test User",
                email: "test@example.com",
                dateOfBirth: Date(),
                authProvider: "email"
            )
        )
    }
}

