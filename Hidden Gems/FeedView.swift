//
//  FeedView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

/// Emits the current vertical scroll offset of the feed's content in
/// the "feedScroll" coordinate space so the tab bar can hide on
/// downward scrolls and reappear on upward scrolls.
private struct FeedScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct FeedView: View {
    @Environment(RecommendationsManager.self) private var recommendationsManager
    @Environment(SavedRestaurantsManager.self) private var savedManager
    @Environment(LikesManager.self) private var likesManager
    @Environment(CommentsManager.self) private var commentsManager
    @Binding var showingCreatePost: Bool

    @State private var isTabBarVisible = true
    @State private var lastScrollY: CGFloat = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(recommendationsManager.recommendations) { recommendation in
                        RecommendationCard(recommendation: recommendation)
                            .padding(.bottom, 12)
                    }
                }
                .padding(.horizontal)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: FeedScrollOffsetKey.self,
                            value: proxy.frame(in: .named("feedScroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "feedScroll")
            .onPreferenceChange(FeedScrollOffsetKey.self) { newY in
                let delta = newY - lastScrollY
                // Threshold prevents jitter from tiny movements.
                // Delta < 0 means content scrolled up (user scrolling down) → hide.
                // Delta > 0 means content scrolled down (user scrolling up) → show.
                if delta < -6, isTabBarVisible, newY < -20 {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isTabBarVisible = false
                    }
                } else if delta > 6, !isTabBarVisible {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isTabBarVisible = true
                    }
                }
                lastScrollY = newY
            }
            .refreshable {
                await refreshFeed()
            }
            .task {
                await refreshFeed()
            }
            .navigationTitle("Hidden Gems")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "gem.fill")
                            .font(.title3)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Hidden Gems")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreatePost = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .toolbar(isTabBarVisible ? .visible : .hidden, for: .tabBar)
    }
    
    private func refreshFeed() async {
        await recommendationsManager.fetchFeed(
            likesManager: likesManager,
            commentsManager: commentsManager
        )
    }
}

struct RecommendationCard: View {
    let recommendation: Recommendation
    @Environment(SavedRestaurantsManager.self) private var savedManager
    @Environment(LikesManager.self) private var likesManager
    @Environment(CommentsManager.self) private var commentsManager
    @Environment(AuthManager.self) private var authManager
    @State private var showingComments = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // User info header
            NavigationLink(destination: ProfileView(user: recommendation.user)) {
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
            }
            .buttonStyle(.plain)
            .padding()
            
            // Restaurant image
            SafeAsyncImage(urlString: recommendation.restaurant.imageURL)
                .frame(maxWidth: .infinity)
                .aspectRatio(4/3, contentMode: .fit)
                .background(Color.gray.opacity(0.2))
                .clipped()

            // Restaurant info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.restaurant.name)
                            .font(.title3)
                            .fontWeight(.bold)

                        RestaurantMetaInfo(restaurant: recommendation.restaurant)
                    }

                    Spacer()

                    RatingBadge(rating: recommendation.restaurant.rating, font: .subheadline)
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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            likesManager.toggleLike(recommendation, by: authManager.currentUser.id)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: likesManager.isLiked(recommendation) ? "heart.fill" : "heart")
                                .font(.title3)
                                .foregroundStyle(likesManager.isLiked(recommendation) ? .red : .primary)
                                .scaleEffect(likesManager.isLiked(recommendation) ? 1.15 : 1.0)

                            let count = likesManager.likeCount(for: recommendation)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    
                    Button {
                        showingComments = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.right")
                                .font(.title3)
                            
                            let count = commentsManager.commentCount(for: recommendation)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    
                    Button {
                        // Share action
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                    }
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            savedManager.toggleSave(recommendation.restaurant)
                        }
                    } label: {
                        Image(systemName: savedManager.isSaved(recommendation.restaurant) ? "bookmark.fill" : "bookmark")
                            .font(.title3)
                            .scaleEffect(savedManager.isSaved(recommendation.restaurant) ? 1.15 : 1.0)
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
        .sheet(isPresented: $showingComments) {
            CommentsView(recommendation: recommendation)
                .environment(commentsManager)
                .environment(authManager)
        }
    }
}

#Preview {
    FeedView(showingCreatePost: .constant(false))
}
