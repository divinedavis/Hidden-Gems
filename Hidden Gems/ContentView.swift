//
//  ContentView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var savedManager = SavedRestaurantsManager()
    @State private var likesManager = LikesManager()
    @State private var followManager = FollowManager()
    @State private var commentsManager = CommentsManager()
    @State private var showingCreatePost = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                FeedView()
                    .tag(0)
                
                SearchView()
                    .tag(1)
                
                // Placeholder for center button
                Color.clear
                    .tag(2)
                
                SavedView()
                    .tag(3)
                
                NavigationStack {
                    ProfileView()
                }
                .tag(4)
            }
            .tabViewStyle(.automatic)
            .environment(savedManager)
            .environment(likesManager)
            .environment(followManager)
            .environment(commentsManager)
            
            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab, showingCreatePost: $showingCreatePost)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showingCreatePost) {
            CreatePostView()
                .environment(savedManager)
                .environment(likesManager)
                .environment(followManager)
                .environment(commentsManager)
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showingCreatePost: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Feed
            TabBarButton(
                icon: "house.fill",
                label: "Feed",
                isSelected: selectedTab == 0
            ) {
                selectedTab = 0
            }
            
            // Search
            TabBarButton(
                icon: "magnifyingglass",
                label: "Search",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }
            
            // Center Create Button
            Button {
                showingCreatePost = true
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    
                    Image(systemName: "gem.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .offset(y: -20)
            .frame(maxWidth: .infinity)
            
            // Saved
            TabBarButton(
                icon: "bookmark.fill",
                label: "Saved",
                isSelected: selectedTab == 3
            ) {
                selectedTab = 3
            }
            
            // Profile
            TabBarButton(
                icon: "person.fill",
                label: "Profile",
                isSelected: selectedTab == 4
            ) {
                selectedTab = 4
            }
        }
        .frame(height: 80)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 0)
        )
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? .blue : .secondary)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ContentView()
}
