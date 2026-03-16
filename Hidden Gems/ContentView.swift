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
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem { Label("Feed", systemImage: "house.fill") }
                .tag(0)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(1)

            SavedView()
                .tabItem { Label("Saved", systemImage: "bookmark.fill") }
                .tag(2)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Profile", systemImage: "person.fill") }
            .tag(3)
        }
        .environment(savedManager)
        .environment(likesManager)
        .environment(followManager)
    }
}

#Preview {
    ContentView()
}
