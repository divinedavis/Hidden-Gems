//
//  SupabaseManager.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/17/26.
//

import Supabase
import Foundation
import UIKit

// Shared Supabase client — use this everywhere in the app.
//
// The URL and key are compile-time constants from Config.swift, so a
// bad value here is a developer error, not a runtime user error. We
// still avoid force-unwrap so a malformed Config entry triggers a
// descriptive preconditionFailure instead of a crash at a random
// call site.
private func makeSupabaseClient() -> SupabaseClient {
    guard let url = URL(string: Config.supabaseURL) else {
        preconditionFailure("Config.supabaseURL is not a valid URL: \(Config.supabaseURL)")
    }
    return SupabaseClient(supabaseURL: url, supabaseKey: Config.supabaseKey)
}

let supabase = makeSupabaseClient()

// MARK: - Media uploader
//
// Uploads JPEG data to the public "media" bucket. Storage RLS scopes
// writes to `<kind>/<auth.uid()>/...` so the path prefix must match
// the caller's auth uid. Returns the public URL of the uploaded
// object.
enum MediaUploader {
    enum Kind: String { case avatars, posts }

    static func uploadJPEG(
        _ image: UIImage,
        kind: Kind,
        ownerId: UUID,
        compressionQuality: CGFloat = 0.82
    ) async throws -> String {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            throw NSError(
                domain: "MediaUploader",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Could not encode image as JPEG"]
            )
        }
        let filename = "\(UUID().uuidString).jpg"
        let path = "\(kind.rawValue)/\(ownerId.uuidString)/\(filename)"
        _ = try await supabase.storage
            .from("media")
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        let url = try supabase.storage.from("media").getPublicURL(path: path)
        return url.absoluteString
    }
}
