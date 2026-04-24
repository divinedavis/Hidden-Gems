//
//  ProfileView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI
import Supabase
import PhotosUI

struct ProfileView: View {
    var user: User? = nil // Optional user parameter - if nil, show current user
    @State private var myRecommendations: [Recommendation] = []
    @State private var showingSettings = false
    @State private var showingEditProfile = false
    @Environment(SavedRestaurantsManager.self) private var savedManager
    @Environment(LikesManager.self) private var likesManager
    @Environment(FollowManager.self) private var followManager
    @Environment(AuthManager.self) private var authManager
    @Environment(RecommendationsManager.self) private var recommendationsManager

    private var displayUser: User {
        user ?? authManager.currentUser
    }

    private var isOwnProfile: Bool {
        user == nil || user?.id == authManager.currentUser.id
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.gray)
                            }
                        if let url = safeImageURL(from: displayUser.profileImageURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    Color.clear
                                }
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        }
                    }
                    
                    VStack(spacing: 4) {
                        Text(displayUser.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(displayUser.username)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 40) {
                        StatView(count: displayUser.followersCount, label: "Followers")
                        StatView(count: displayUser.followingCount, label: "Following")
                        StatView(count: myRecommendations.count, label: "Recommendations")
                    }
                    .padding(.top, 8)
                    
                    if isOwnProfile {
                        Button {
                            showingEditProfile = true
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
                    } else {
                        let isFollowing = followManager.isFollowing(displayUser)
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                followManager.toggleFollow(
                                    displayUser,
                                    by: authManager.currentUser.id
                                )
                            }
                        } label: {
                            Text(isFollowing ? "Following" : "Follow")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(isFollowing ? Color(.systemGray5) : Color.accentColor)
                                .foregroundStyle(isFollowing ? Color.primary : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.horizontal, 40)
                    }
                }
                .padding(.top)
                
                Divider()
                    .padding(.horizontal)
                
                // Recommendations Section
                VStack(alignment: .leading, spacing: 12) {
                    Text(isOwnProfile ? "My Recommendations" : "Recommendations")
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
                            
                            if isOwnProfile {
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
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(myRecommendations) { recommendation in
                                NavigationLink(destination: PostDetailView(recommendation: recommendation)) {
                                    ProfileRecommendationCard(recommendation: recommendation)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle(isOwnProfile ? "Profile" : displayUser.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwnProfile {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .confirmationDialog("Settings", isPresented: $showingSettings) {
            Button("Log Out", role: .destructive) {
                authManager.signOut()
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileSheet()
                .environment(authManager)
        }
        .task(id: displayUser.id) {
            await loadRecommendations()
        }
    }

    /// Fetches this profile's posts directly from the `feed` view so
    /// the list is populated even when the global feed tab hasn't been
    /// visited yet (or when viewing another user's profile).
    private func loadRecommendations() async {
        let targetId = displayUser.id
        do {
            let posts: [SupabaseFeedPost] = try await supabase
                .from("feed")
                .select()
                .eq("user_id", value: targetId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            myRecommendations = posts.map { $0.toRecommendation() }
        } catch {
            debugLog("Profile recs fetch error", error)
            myRecommendations = recommendationsManager.recommendations
                .filter { $0.user.id == targetId }
        }
    }
}

struct ProfileRecommendationCard: View {
    let recommendation: Recommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SafeAsyncImage(urlString: recommendation.restaurant.imageURL)
                .aspectRatio(1, contentMode: .fit)
                .background(Color.gray.opacity(0.2))
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.restaurant.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                RatingBadge(rating: recommendation.restaurant.rating, font: .caption2)
            }
            .padding(8)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

/// Lets the signed-in user pick a new profile picture. Uploads the
/// JPEG to the media bucket and writes the public URL back to their
/// users row via `AuthManager.updateProfileImage`. Current scope is
/// avatar-only; name / username edits can slot in later.
struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @State private var pickerItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 140, height: 140)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 54))
                                .foregroundStyle(.gray)
                        }
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                    } else if let url = safeImageURL(from: authManager.currentUser.profileImageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Color.clear
                            }
                        }
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                    }
                }
                .padding(.top, 12)

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Text(previewImage == nil ? "Choose photo" : "Choose a different photo")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { save() }
                            .fontWeight(.semibold)
                            .disabled(previewImage == nil)
                    }
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        previewImage = image
                    }
                }
            }
        }
    }

    private func save() {
        guard let image = previewImage else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await authManager.updateProfileImage(image)
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                errorMessage = "Could not save profile picture. \(error.localizedDescription)"
            }
        }
    }
}

/// Full post view pushed when a user taps a thumbnail on a profile
/// grid. Reuses `RecommendationCard` so likes, saves, shares, and the
/// comments sheet behave identically to the feed.
struct PostDetailView: View {
    let recommendation: Recommendation

    var body: some View {
        ScrollView {
            RecommendationCard(recommendation: recommendation)
                .padding(.horizontal)
                .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(recommendation.restaurant.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView()
}
