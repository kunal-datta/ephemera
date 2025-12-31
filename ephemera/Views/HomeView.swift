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
    
    private var currentProfile: UserProfile? {
        profiles.first
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
        .preferredColorScheme(.dark)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}

