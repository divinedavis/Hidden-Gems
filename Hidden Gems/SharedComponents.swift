//
//  SharedComponents.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

/// Writes to the Xcode console in Debug builds only. Release builds
/// compile this to a no-op so error details — which can contain
/// request URLs, user ids, and other metadata — never leak into device
/// crash logs or iOS's unified logging where a sufficiently motivated
/// attacker could read them.
func debugLog(_ label: String, _ value: Any? = nil) {
    #if DEBUG
    if let value {
        print("[HiddenGems] \(label): \(value)")
    } else {
        print("[HiddenGems] \(label)")
    }
    #endif
}

/// Instagram-style single-unit relative time: "now", "3m", "2h", "5d",
/// "4w", "2y". SwiftUI's `Text(date, style: .relative)` produces
/// compound strings like "5 days, 3 hr" which are too long for the
/// feed card header and comment meta row.
func shortRelative(from date: Date, now: Date = Date()) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < 60 { return "now" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h" }
    let days = hours / 24
    if days < 7 { return "\(days)d" }
    let weeks = days / 7
    if weeks < 52 { return "\(weeks)w" }
    let years = days / 365
    return "\(years)y"
}

/// Circular profile-picture view with a gray person.fill placeholder
/// fallback. Prefers the current user's in-memory `localAvatarImage`
/// when `user` is the signed-in account so a freshly uploaded avatar
/// shows up on feed cards and comments immediately, before
/// AsyncImage has had a chance to refetch the new URL from the CDN.
struct UserAvatar: View {
    let user: User
    var size: CGFloat = 36
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        let isOwn = authManager.currentUser.id == user.id
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.44))
                        .foregroundStyle(.gray)
                }

            if isOwn, let cached = authManager.localAvatarImage {
                Image(uiImage: cached)
                    .resizable()
                    .scaledToFill()
            } else if let url = safeImageURL(from: user.profileImageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color.clear
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// Returns a URL only if the string parses and uses the https scheme.
/// Used to guard AsyncImage against missing, malformed, or non-https URLs
/// (which could be used for SSRF if we ever proxied images server-side).
func safeImageURL(from string: String) -> URL? {
    guard !string.isEmpty,
          let url = URL(string: string),
          url.scheme?.lowercased() == "https" else { return nil }
    return url
}

/// AsyncImage that validates the URL is https, fills its container with
/// `scaledToFill` + hard clipping (so it can never push its parent wider),
/// shows a ProgressView while loading, and falls through to a photo
/// placeholder on failure or when the URL is missing/unsafe.
///
/// Callers must give this view an explicit frame (e.g. `.frame(height:)`
/// plus `.frame(maxWidth: .infinity)` or a fixed square). The GeometryReader
/// inside guarantees the image will clip to those bounds no matter how
/// large the underlying photo is.
struct SafeAsyncImage: View {
    let urlString: String

    var body: some View {
        GeometryReader { geo in
            Group {
                if let url = safeImageURL(from: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        case .failure:
                            placeholder
                                .frame(width: geo.size.width, height: geo.size.height)
                        case .empty:
                            ProgressView()
                                .frame(width: geo.size.width, height: geo.size.height)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    placeholder
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.gray.opacity(0.15)
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(.gray)
        }
    }
}

/// Cuisine, price level, and location rows for a restaurant. Vibe
/// tags are rendered as a standalone row by the feed card itself
/// (see `VibeTagStrip`) so they can sit between the city and the
/// post's caption.
struct RestaurantMetaInfo: View {
    let restaurant: Restaurant
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(restaurant.cuisine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("•")
                    .foregroundStyle(.secondary)
                Text(String(repeating: "$", count: restaurant.priceLevel))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(action: openInMaps) {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                    Text(restaurant.location)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(restaurant.location.isEmpty &&
                      restaurant.latitude == 0 && restaurant.longitude == 0)
        }
    }

    /// Opens Apple Maps with the restaurant's address (or coordinates,
    /// if we have them) prefilled as the directions destination. Saves
    /// the user retyping the address in Maps.
    private func openInMaps() {
        var components = URLComponents(string: "http://maps.apple.com/")!
        var items: [URLQueryItem] = []
        // Prefer coordinates when available — addresses sometimes
        // geocode to the wrong place when the city is generic.
        if restaurant.latitude != 0 || restaurant.longitude != 0 {
            items.append(URLQueryItem(name: "daddr",
                                      value: "\(restaurant.latitude),\(restaurant.longitude)"))
            items.append(URLQueryItem(name: "q", value: restaurant.name))
        } else if !restaurant.location.isEmpty {
            items.append(URLQueryItem(name: "daddr",
                                      value: "\(restaurant.name), \(restaurant.location)"))
        } else {
            return
        }
        components.queryItems = items
        guard let url = components.url else { return }
        openURL(url)
    }

    /// "date night spot" → "DateNightSpot" for chip display. Keep the
    /// lowercase canonical form as the stored value and only camel-case
    /// on render.
    static func displayTag(_ tag: String) -> String {
        tag.split(separator: " ").map { $0.capitalized }.joined()
    }
}

/// Horizontally-scrolling strip of hashtag chips. Each chip is a
/// `NavigationLink` to `TagFeedView`, which filters the in-memory
/// feed by the tapped tag. Rendered between the location row and
/// the post caption on each feed card.
struct VibeTagStrip: View {
    let tags: [String]

    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        NavigationLink(destination: TagFeedView(tag: tag)) {
                            Text("#\(RestaurantMetaInfo.displayTag(tag))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(Color.blue)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 4)
            }
        }
    }
}

/// Star rating badge.
struct RatingBadge: View {
    let rating: Double
    var font: Font = .caption

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(font)
                .foregroundStyle(.yellow)
            Text(String(format: "%.1f", rating))
                .font(font)
                .fontWeight(.semibold)
        }
    }
}

/// Instagram-style vibe tag picker. Curated vibes appear as suggestion
/// chips; the user can also type their own and press return/space/comma
/// to add a free-form tag. Tags are stored lowercased for consistent
/// filtering, and display uses title-case for curated vibes.
struct VibeTagPicker: View {
    @Binding var tags: [String]
    @Binding var input: String
    let maxTags: Int

    @FocusState private var inputFocused: Bool

    private var canAddMore: Bool { tags.count < maxTags }

    private var suggestions: [String] {
        // Hide curated vibes the user has already picked.
        Vibe.curated.filter { !tags.contains(Vibe.normalize($0)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Selected tags
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        VibeChip(
                            label: displayLabel(for: tag),
                            selected: true,
                            trailingIcon: "xmark"
                        )
                        .onTapGesture { remove(tag) }
                    }
                }
            }

            // Free-form input
            HStack {
                Image(systemName: "number")
                    .foregroundStyle(.secondary)
                TextField("Add a vibe", text: $input)
                    .focused($inputFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { commitInput() }
                    .onChange(of: input) { _, newValue in
                        // Finish a tag on comma or return only — NOT on
                        // space. Multi-word tags like "good date night"
                        // stay as one entry instead of being split into
                        // three.
                        if newValue.hasSuffix(",") {
                            commitInput()
                        }
                    }
                if !input.isEmpty {
                    Button("Add") { commitInput() }
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(canAddMore ? 1 : 0.5)
            .disabled(!canAddMore)

            // Suggestion chips
            if !suggestions.isEmpty && canAddMore {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Suggestions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 8) {
                        ForEach(suggestions, id: \.self) { vibe in
                            VibeChip(label: vibe, selected: false)
                                .onTapGesture { add(vibe) }
                        }
                    }
                }
            }
        }
    }

    private func commitInput() {
        let raw = input.replacingOccurrences(of: ",", with: "")
        add(raw)
        input = ""
    }

    private func add(_ raw: String) {
        let normalized = Vibe.normalize(raw)
        guard !normalized.isEmpty, !tags.contains(normalized), canAddMore else { return }
        tags.append(normalized)
    }

    private func remove(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    /// Turn a stored lowercase tag back into a readable label. For
    /// curated vibes we re-use the canonical casing; for free-form
    /// tags we title-case each word.
    private func displayLabel(for tag: String) -> String {
        if let canonical = Vibe.curated.first(where: { Vibe.normalize($0) == tag }) {
            return canonical
        }
        return tag.split(separator: " ").map { $0.capitalized }.joined(separator: " ")
    }
}

/// A single pill-shaped vibe chip. Used in the tag picker and Search
/// filter row. `selected` flips the color treatment; `trailingIcon`
/// renders a small SF Symbol on the right (e.g. "xmark" for removal).
struct VibeChip: View {
    let label: String
    var selected: Bool = false
    var trailingIcon: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(selected ? .semibold : .regular)
            if let trailingIcon {
                Image(systemName: trailingIcon)
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(selected ? Color.blue : Color(.systemGray6))
        )
        .foregroundStyle(selected ? Color.white : Color.primary)
        .overlay(
            Capsule().stroke(selected ? Color.clear : Color(.separator), lineWidth: 0.5)
        )
        .contentShape(Capsule())
    }
}

/// Simple left-to-right wrapping flow layout for chips. iOS 16+ ships
/// with `Layout`, but writing our own keeps the behavior predictable
/// and avoids the quirks of `Grid` for variable-width items.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? rowWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// A single stat column used in the profile header (e.g. Followers, Following).
struct StatView: View {
    let count: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.headline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
