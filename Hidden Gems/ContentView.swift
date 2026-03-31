//
//  ContentView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var selectedTab = 0
    @State private var savedManager = SavedRestaurantsManager()
    @State private var likesManager = LikesManager()
    @State private var followManager = FollowManager()
    @State private var commentsManager = CommentsManager()
    @State private var recommendationsManager = RecommendationsManager()
    @State private var showingCreatePost = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView(showingCreatePost: $showingCreatePost)
                .tabItem {
                    Label("Feed", systemImage: "house.fill")
                }
                .tag(0)
            
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)
            
            SavedView()
                .tabItem {
                    Label("Saved", systemImage: "bookmark.fill")
                }
                .tag(2)
            
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(3)
        }
        .environment(savedManager)
        .environment(likesManager)
        .environment(followManager)
        .environment(commentsManager)
        .environment(recommendationsManager)
        .sheet(isPresented: $showingCreatePost) {
            CreatePostView()
                .environment(savedManager)
                .environment(likesManager)
                .environment(followManager)
                .environment(commentsManager)
                .environment(recommendationsManager)
                .environment(authManager)
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthManager())
}
