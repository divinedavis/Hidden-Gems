//
//  FeedView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

struct FeedView: View {
    @State private var recommendations = Recommendation.samples
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(recommendations) { recommendation in
                        RecommendationCard(recommendation: recommendation)
                            .padding(.bottom, 12)
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Feed")
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct RecommendationCard: View {
    let recommendation: Recommendation
    @State private var isSaved = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // User info header
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.gray)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.user.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(recommendation.user.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(recommendation.date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            
            // Restaurant image
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(4/3, contentMode: .fit)
                .overlay {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.gray)
                }
            
            // Restaurant info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.restaurant.name)
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 4) {
                            Text(recommendation.restaurant.cuisine)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(String(repeating: "$", count: recommendation.restaurant.priceLevel))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption)
                            Text(recommendation.restaurant.location)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", recommendation.restaurant.rating))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                
                // User's note
                if !recommendation.note.isEmpty {
                    Text(recommendation.note)
                        .font(.body)
                        .padding(.top, 4)
                }
                
                // Action buttons
                HStack(spacing: 24) {
                    Button {
                        // Like action
                    } label: {
                        Image(systemName: "heart")
                            .font(.title3)
                    }
                    
                    Button {
                        // Comment action
                    } label: {
                        Image(systemName: "bubble.right")
                            .font(.title3)
                    }
                    
                    Button {
                        // Share action
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                    }
                    
                    Spacer()
                    
                    Button {
                        isSaved.toggle()
                    } label: {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.title3)
                    }
                }
                .foregroundStyle(.primary)
                .padding(.top, 8)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

#Preview {
    FeedView()
}
