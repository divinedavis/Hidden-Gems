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
    @State private var liveRecommendationCount: Int?
    @State private var wasFollowingAtLoad: Bool = false
    @Environment(SavedRestaurantsManager.self) private var savedManager
    @Environment(LikesManager.self) private var likesManager
    @Environment(FollowManager.self) private var followManager
    @Environment(AuthManager.self) private var authManager
    @Environment(RecommendationsManager.self) private var recommendationsManager
    @Environment(CommentsManager.self) private var commentsManager
    @Environment(PostViewsManager.self) private var postViewsManager
    @Environment(RatingsManager.self) private var ratingsManager

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

    /// Prefer the live count fetched from `user_profiles`. Fall back
    /// to whatever was on the User struct (from the feed-row or auth
    /// manager); the loaded grid count is also a reasonable floor for
    /// own-profile while the live fetch is in flight.
    private var displayedRecommendationCount: Int {
        if let live = liveRecommendationCount { return live }
        if isOwnProfile { return max(displayUser.recommendationCount, myRecommendations.count) }
        return displayUser.recommendationCount
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

                        RecommenderBadge(count: displayedRecommendationCount)
                            .padding(.top, 4)

                        if isOwnProfile {
                            RecommenderProgress(count: displayedRecommendationCount)
                                .padding(.top, 8)
                                .padding(.horizontal, 32)
                        }

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
                        StatView(count: displayedRecommendationCount, label: "Recommendations")
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
                .environment(ratingsManager)
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
            let recommendationCount: Int?
            enum CodingKeys: String, CodingKey {
                case followersCount = "followers_count"
                case followingCount = "following_count"
                case recommendationCount = "recommendation_count"
            }
        }
        do {
            // Select * because recommendation_count was added in
            // migration 011 — older deploys of the user_profiles view
            // won't expose it, and an explicit column list would 400
            // until the migration is applied. With select() the column
            // is absent client-side and decodes as nil.
            let rows: [Row] = try await supabase
                .from("user_profiles")
                .select()
                .eq("id", value: displayUser.id.uuidString)
                .limit(1)
                .execute()
                .value
            if let row = rows.first {
                liveFollowersCount = row.followersCount ?? 0
                liveFollowingCount = row.followingCount ?? 0
                liveRecommendationCount = row.recommendationCount
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
    @State private var name: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var didSeedFields = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var usernameStatus: UsernameStatus = .idle
    @State private var usernameCheckTask: Task<Void, Never>?

    private let maxNameLength = 50
    private let maxUsernameLength = 20
    private let minUsernameLength = 3
    private let maxBioLength = 140

    /// Status of the live availability check on the username field.
    /// Drives both the inline indicator (spinner / check / x) and the
    /// Save-button gating.
    enum UsernameStatus: Equatable {
        case idle           // unchanged from current, or empty
        case invalid(String)
        case checking
        case available
        case taken
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// User's typed username with leading "@" stripped, lowercased,
    /// trimmed. The canonical form for both validation and the live
    /// availability lookup.
    private var bareUsername: String {
        username
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .lowercased()
    }

    /// The user's existing username with the same normalisation
    /// applied. We treat reverting the field to its current value as
    /// "no change" so the Save button doesn't light up.
    private var currentBareUsername: String {
        authManager.currentUser.username
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .lowercased()
    }

    private var usernameChanged: Bool {
        !bareUsername.isEmpty && bareUsername != currentBareUsername
    }

    private var hasChanges: Bool {
        let nameChanged = !trimmedName.isEmpty && trimmedName != authManager.currentUser.name
        let usernameSavable = usernameChanged && usernameStatus == .available
        return previewImage != nil || nameChanged || usernameSavable || bio != authManager.currentUser.bio
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
                            Text("Display Name")
                                .font(.headline)
                            Spacer()
                            Text("\(name.count)/\(maxNameLength)")
                                .font(.caption)
                                .foregroundStyle(name.count > maxNameLength ? .red : .secondary)
                        }

                        TextField("Your name", text: $name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(name.count > maxNameLength ? Color.red : Color.clear, lineWidth: 1)
                            )
                            .onChange(of: name) { _, newValue in
                                if newValue.count > maxNameLength {
                                    name = String(newValue.prefix(maxNameLength))
                                }
                            }

                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Username")
                                .font(.headline)
                            Spacer()
                            usernameStatusIndicator
                        }

                        HStack(spacing: 4) {
                            Text("@")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            TextField("yourhandle", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.asciiCapable)
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(usernameBorderColor, lineWidth: 1)
                        )
                        .onChange(of: username) { _, newValue in
                            // Strip any "@" the user pasted/typed and
                            // trim length so they can't blow past the
                            // 20-char cap from a paste.
                            var cleaned = newValue.replacingOccurrences(of: "@", with: "")
                            if cleaned.count > maxUsernameLength {
                                cleaned = String(cleaned.prefix(maxUsernameLength))
                            }
                            if cleaned != newValue {
                                username = cleaned
                                return
                            }
                            scheduleUsernameCheck()
                        }

                        Text(usernameHelperText)
                            .font(.caption)
                            .foregroundStyle(usernameHelperColor)
                    }
                    .padding(.horizontal)

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
                if !didSeedFields {
                    name = authManager.currentUser.name
                    username = currentBareUsername
                    bio = authManager.currentUser.bio
                    didSeedFields = true
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
        let newName = trimmedName
        let nameChanged = !newName.isEmpty && newName != authManager.currentUser.name
        let usernameToSubmit: String? = (usernameChanged && usernameStatus == .available) ? bareUsername : nil
        Task {
            do {
                try await authManager.updateProfile(
                    image: previewImage,
                    name: nameChanged ? newName : nil,
                    username: usernameToSubmit,
                    bio: bioChanged ? trimmedBio : nil
                )
                isSaving = false
                dismiss()
            } catch let err as ProfileUpdateError {
                isSaving = false
                if err == .usernameTaken {
                    usernameStatus = .taken
                }
                errorMessage = err.errorDescription
            } catch {
                isSaving = false
                errorMessage = "Could not save profile. \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Username helpers

    /// Right-aligned indicator next to the "Username" label. Shows a
    /// spinner while a check is in flight, a green check when the
    /// handle is free, a red x when it's taken or formatted wrong.
    @ViewBuilder
    private var usernameStatusIndicator: some View {
        switch usernameStatus {
        case .idle:
            Text("\(bareUsername.count)/\(maxUsernameLength)")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .invalid:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .checking:
            ProgressView().controlSize(.small)
        case .available:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .taken:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    private var usernameBorderColor: Color {
        switch usernameStatus {
        case .invalid, .taken: return .red
        case .available: return .green
        default: return .clear
        }
    }

    private var usernameHelperText: String {
        switch usernameStatus {
        case .idle:
            return "Letters, numbers, and underscores. \(minUsernameLength)–\(maxUsernameLength) characters."
        case .invalid(let reason):
            return reason
        case .checking:
            return "Checking…"
        case .available:
            return "Looks good — @\(bareUsername) is available."
        case .taken:
            return "@\(bareUsername) is taken."
        }
    }

    private var usernameHelperColor: Color {
        switch usernameStatus {
        case .invalid, .taken: return .red
        case .available: return .green
        default: return .secondary
        }
    }

    /// Validates the current `bareUsername` against format rules
    /// (length + allowed characters + can't start with a digit) and
    /// returns the failure reason for the helper line, or nil when
    /// the input is structurally valid.
    private func validationReason(for handle: String) -> String? {
        if handle.isEmpty { return nil }  // treated as idle, not invalid
        if handle.count < minUsernameLength {
            return "At least \(minUsernameLength) characters."
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")
        if handle.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return "Only letters, numbers, and underscores."
        }
        if let first = handle.first, first.isNumber {
            return "Can't start with a number."
        }
        return nil
    }

    /// Cancels any in-flight check, validates locally, then schedules
    /// a 400ms-debounced live availability lookup. Reverting the
    /// field to the user's current handle short-circuits to .idle so
    /// the Save button stays disabled (no actual change to write).
    private func scheduleUsernameCheck() {
        usernameCheckTask?.cancel()
        let handle = bareUsername

        if handle.isEmpty {
            usernameStatus = .idle
            return
        }
        if handle == currentBareUsername {
            usernameStatus = .idle
            return
        }
        if let reason = validationReason(for: handle) {
            usernameStatus = .invalid(reason)
            return
        }

        usernameStatus = .checking
        usernameCheckTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            // The user may have kept typing during the debounce; only
            // commit a result if the field still matches what we
            // queried for.
            let queriedHandle = handle
            do {
                let available = try await authManager.isUsernameAvailable(queriedHandle)
                guard !Task.isCancelled, queriedHandle == bareUsername else { return }
                usernameStatus = available ? .available : .taken
            } catch {
                guard !Task.isCancelled, queriedHandle == bareUsername else { return }
                debugLog("Username availability check failed", error)
                // Don't block the user — let them try to save and
                // catch the 23505 there if it actually conflicts.
                usernameStatus = .available
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
