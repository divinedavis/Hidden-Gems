//
//  SupabaseManager.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/17/26.
//

import Supabase
import Foundation

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
