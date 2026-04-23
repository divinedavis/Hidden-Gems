//
//  ContentView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var selectedTab: Int = {
        #if DEBUG
        if let s = ProcessInfo.processInfo.environment["HG_TEST_TAB"],
           let i = Int(s) { return i }
        #endif
        return 0
    }()
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
        .task(id: authManager.currentUser.id) {
            guard authManager.isSignedIn else { return }
            let uid = authManager.currentUser.id
            await savedManager.loadSaved(userId: uid)
            await followManager.loadFollowing(userId: uid)
            await likesManager.loadLiked(userId: uid)
        }
        #if DEBUG
        .task {
            // HG_TEST_REEL=1 cycles tabs every 2s so the demo-gif capture
            // script can record a single run that shows every screen.
            if ProcessInfo.processInfo.environment["HG_TEST_REEL"] == "1" {
                let tabs = [0, 1, 2, 3]
                var i = 0
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 2_200_000_000)
                    i = (i + 1) % tabs.count
                    selectedTab = tabs[i]
                }
            }
        }
        .task {
            // HG_TEST_SHEET=create auto-presents CreatePostView so the
            // screenshot script can capture that modal without taps.
            if ProcessInfo.processInfo.environment["HG_TEST_SHEET"] == "create" {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                showingCreatePost = true
            }
        }
        #endif
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
