//
//  CommentsView.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/16/26.
//

import SwiftUI

struct CommentsView: View {
    let recommendation: Recommendation
    @Environment(\.dismiss) private var dismiss
    @Environment(CommentsManager.self) private var commentsManager
    @Environment(AuthManager.self) private var authManager
    @State private var newCommentText = ""

    private var currentUser: User { authManager.currentUser }
    @FocusState private var commentFieldFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    private var comments: [Comment] {
        commentsManager.getComments(for: recommendation)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Compact TikTok-style header: small thumbnail + restaurant info +
            // close button. Keeps the image constrained so comments get most
            // of the screen.
            HStack(spacing: 12) {
                SafeAsyncImage(urlString: recommendation.restaurant.imageURL)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.restaurant.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(recommendation.restaurant.cuisine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            // Comments — fills space between image and input
            if commentsManager.commentCount(for: recommendation) == 0 {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bubble.right")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No comments yet")
                        .font(.headline)
                    Text("Be the first to comment!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(comments) { comment in
                            CommentRow(
                                comment: comment,
                                currentUserId: currentUser.id,
                                onLike: {
                                    commentsManager.toggleCommentLike(comment, by: currentUser.id)
                                },
                                isLiked: commentsManager.isCommentLiked(comment, by: currentUser.id)
                            )
                        }

                    }
                    .padding()
                }
            }

            Divider()

            // Comment input
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.gray)
                    }

                TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .focused($commentFieldFocused)

                Button {
                    postComment()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(newCommentText.isEmpty ? Color.secondary : Color.blue)
                }
                .disabled(newCommentText.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        // Push the entire layout up by keyboard height so input stays visible
        .padding(.bottom, keyboardHeight)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
        ) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = frame.height
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
        ) { _ in
            keyboardHeight = 0
        }
    }

    private func postComment() {
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        commentsManager.addComment(newCommentText, to: recommendation, by: currentUser)
        newCommentText = ""
        commentFieldFocused = false
    }
}

struct CommentRow: View {
    let comment: Comment
    let currentUserId: UUID
    let onLike: () -> Void
    let isLiked: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User Avatar
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.gray)
                }

            // Comment Content
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(comment.user.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(comment.date, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(comment.text)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Like button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        onLike()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundStyle(isLiked ? .red : .secondary)

                        if comment.likeCount > 0 {
                            Text("\(comment.likeCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    CommentsView(recommendation: Recommendation.sample1)
        .environment(CommentsManager())
}
