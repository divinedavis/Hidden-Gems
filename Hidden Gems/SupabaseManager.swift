//
//  SupabaseManager.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/17/26.
//

import Supabase
import Foundation

// Shared Supabase client — use this everywhere in the app
let supabase = SupabaseClient(
    supabaseURL: URL(string: Config.supabaseURL)!,
    supabaseKey: Config.supabaseKey
)
