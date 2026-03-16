//
//  ProfileView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

struct ProfileView: View {
    @State private var user = User.samples[0]
    @State private var myRecommendations = Recommendation.samples.filter { $0.user.id == User.samples[0].id }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    VStack(spacing: 12) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.gray)
                            }
                        
                        VStack(spacing: 4) {
                            Text(user.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(user.username)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 40) {
                            VStack(spacing: 4) {
                                Text("\(user.followersCount)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Text("Followers")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            VStack(spacing: 4) {
                                Text("\(user.followingCount)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Text("Following")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            VStack(spacing: 4) {
                                Text("\(myRecommendations.count)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Text("Recommendations")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 8)
                        
                        Button {
                            // Edit profile action
                        } label: {
                            Text("Edit Profile")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 40)
                    }
                    .padding(.top)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // My Recommendations Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("My Recommendations")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if myRecommendations.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                
                                Text("No recommendations yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                Button {
                                    // Add recommendation action
                                } label: {
                                    Text("Add Your First Recommendation")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.accentColor)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(myRecommendations) { recommendation in
                                    ProfileRecommendationCard(recommendation: recommendation)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Settings action
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }
}

struct ProfileRecommendationCard: View {
    let recommendation: Recommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.gray)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.restaurant.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", recommendation.restaurant.rating))
                        .font(.caption)
                }
            }
            .padding(8)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

#Preview {
    ProfileView()
}
