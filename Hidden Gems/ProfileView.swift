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
    @State private var showingCreatePost = false
    @State private var liveFollowersCount: Int?
    @State private var liveFollowingCount: Int?
    @State private var wasFollowingAtLoad: Bool = false
    @Environment(SavedRestaurantsManager.self) private var savedManager
    @Environment(LikesManager.self) private var likesManager
    @Environment(FollowManager.self) private var followManager
    @Environment(AuthManager.self) private var authManager
    @Environment(RecommendationsManager.self) private var recommendationsManager
    @Environment(CommentsManager.self) private var commentsManager
    @Environment(PostViewsManager.self) private var postViewsManager

    private var displayUser: User {
        user ?? authManager.currentUser
    }

    private var isOwnProfile: Bool {
        user == nil || user?.id == authManager.currentUser.id
    }

    /// Followers count with an optimistic adjustment: if the session
    /// user has toggled follow on the displayed profile since we
    /// loaded the base count, the bump is reflected immediately
    /// without waiting for a re-fetch.
    private var displayedFollowersCount: Int {
        let base = liveFollowersCount ?? displayUser.followersCount
        guard !isOwnProfile else { return base }
        let followsNow = followManager.isFollowing(displayUser)
        if followsNow, !wasFollowingAtLoad { return max(0, base + 1) }
        if !followsNow, wasFollowingAtLoad { return max(0, base - 1) }
        return base
    }

    /// Own-profile following count derives from the authoritative
    /// local set so tapping Follow on someone else bumps the number
    /// instantly. Other profiles fall back to the server count.
    private var displayedFollowingCount: Int {
        if isOwnProfile { return followManager.followedUsers.count }
        return liveFollowingCount ?? displayUser.followingCount
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
                        // Prefer the just-uploaded cached UIImage for
                        // the own-profile case so the circle updates
                        // the instant Save completes, without waiting
                        // on AsyncImage to fetch the new URL.
                        if isOwnProfile, let cached = authManager.localAvatarImage {
                            Image(uiImage: cached)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else if let url = safeImageURL(from: displayUser.profileImageURL) {
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

                        if !displayUser.bio.isEmpty {
                            Text(displayUser.bio)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                                .padding(.horizontal, 32)
                        }
                    }
                    
                    HStack(spacing: 40) {
                        StatView(count: displayedFollowersCount, label: "Followers")
                        StatView(count: displayedFollowingCount, label: "Following")
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
                                    showingCreatePost = true
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
        .sheet(isPresented: $showingCreatePost) {
            CreatePostView()
                .environment(savedManager)
                .environment(likesManager)
                .environment(followManager)
                .environment(commentsManager)
                .environment(recommendationsManager)
                .environment(postViewsManager)
                .environment(authManager)
        }
        .task(id: displayUser.id) {
            wasFollowingAtLoad = followManager.isFollowing(displayUser)
            async let recs: Void = loadRecommendations()
            async let counts: Void = loadLiveCounts()
            _ = await (recs, counts)
        }
    }

    /// Pulls the displayed user's live follower / following counts
    /// from the `user_profiles` view so the stat row reflects the
    /// actual state of the follows table, not the never-populated
    /// placeholder columns on `users`.
    private func loadLiveCounts() async {
        struct Row: Decodable {
            let followersCount: Int?
            let followingCount: Int?
            enum CodingKeys: String, CodingKey {
                case followersCount = "followers_count"
                case followingCount = "following_count"
            }
        }
        do {
            let rows: [Row] = try await supabase
                .from("user_profiles")
                .select("followers_count, following_count")
                .eq("id", value: displayUser.id.uuidString)
                .limit(1)
                .execute()
                .value
            if let row = rows.first {
                liveFollowersCount = row.followersCount ?? 0
                liveFollowingCount = row.followingCount ?? 0
            }
        } catch {
            debugLog("Profile counts fetch error", error)
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

/// Lets the signed-in user pick a new profile picture and write a
/// short bio. Uploads the avatar JPEG to the media bucket and
/// persists both fields via `AuthManager.updateProfile`. Bio is
/// capped at 140 characters; beyond that the counter flips red and
/// typing is truncated.
struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @State private var pickerItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var bio: String = ""
    @State private var didSeedBio = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let maxBioLength = 140

    private var hasChanges: Bool {
        previewImage != nil || bio != authManager.currentUser.bio
    }

    var body: some View {
        NavigationStack {
            ScrollView {
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
                        } else if let cached = authManager.localAvatarImage {
                            Image(uiImage: cached)
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

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Bio")
                                .font(.headline)
                            Spacer()
                            Text("\(bio.count)/\(maxBioLength)")
                                .font(.caption)
                                .foregroundStyle(bio.count > maxBioLength ? .red : .secondary)
                        }

                        TextEditor(text: $bio)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(bio.count > maxBioLength ? Color.red : Color.clear, lineWidth: 1)
                            )
                            .onChange(of: bio) { _, newValue in
                                if newValue.count > maxBioLength {
                                    bio = String(newValue.prefix(maxBioLength))
                                }
                            }

                        Text("Tell people what you're into. \"I'm a foodie always looking for a chill vibe.\"")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
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
                            .disabled(!hasChanges)
                    }
                }
            }
            .onAppear {
                if !didSeedBio {
                    bio = authManager.currentUser.bio
                    didSeedBio = true
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
        isSaving = true
        errorMessage = nil
        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        let bioChanged = trimmedBio != authManager.currentUser.bio
        Task {
            do {
                try await authManager.updateProfile(
                    image: previewImage,
                    bio: bioChanged ? trimmedBio : nil
                )
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                errorMessage = "Could not save profile. \(error.localizedDescription)"
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
