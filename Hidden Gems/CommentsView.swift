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
    @State private var newCommentText = ""
    @State private var currentUser = User.sarah
    @State private var showAllComments = false
    
    private var comments: [Comment] {
        if showAllComments {
            return commentsManager.getComments(for: recommendation)
        } else {
            return commentsManager.getTopComments(for: recommendation, limit: 3)
        }
    }
    
    private var hasMoreComments: Bool {
        commentsManager.commentCount(for: recommendation) > 3
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Comments List
                if commentsManager.commentCount(for: recommendation) == 0 {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        
                        Text("No comments yet")
                            .font(.headline)
                        
                        Text("Be the first to comment!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: .infinity)
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
                            
                            // Show more button
                            if hasMoreComments && !showAllComments {
                                Button {
                                    withAnimation {
                                        showAllComments = true
                                    }
                                } label: {
                                    Text("View all \(commentsManager.commentCount(for: recommendation)) comments")
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                        .padding(.vertical, 8)
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Divider()
                
                // Comment Input
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
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func postComment() {
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        commentsManager.addComment(newCommentText, to: recommendation, by: currentUser)
        newCommentText = ""
        
        // Dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
