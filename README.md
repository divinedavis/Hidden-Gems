# Hidden Gems

An iOS app that gives locals better insight into what restaurants and cafes are around them — discover and share under-the-radar recommendations from people you trust.

## Screenshots

<p align="center">
  <img src="screenshots/feed_hero.png" width="440" alt="Feed"/>
</p>

## Features

- **Feed** — Browse restaurant recommendations from people you follow, with likes, comments, and saves
- **Search** — Find hidden gem restaurants by name, cuisine, or location
- **Saved** — Bookmark restaurants you want to try
- **Profile** — View your recommendations and manage followers/following
- **Comments** — Comment on posts and like other people's comments
- **Follow** — Follow other users and see their recommendations in your feed

## Tech Stack

- Swift / SwiftUI
- iOS 17+
- Xcode

## Project Structure

```
Hidden Gems/
├── Hidden_GemsApp.swift      # App entry point
├── ContentView.swift         # Root tab navigation + environment setup
├── FeedView.swift            # Recommendation feed with likes, comments, saves
├── CommentsView.swift        # Comments sheet with post image preview
├── SearchView.swift          # Search screen
├── SavedView.swift           # Saved restaurants
├── ProfileView.swift         # User profile with follow/unfollow
├── CreatePostView.swift      # Create a new recommendation post
├── SharedComponents.swift    # Reusable UI components
└── Models.swift              # Data models and state managers
```

## Getting Started

1. Clone the repo
2. Open `Hidden Gems.xcodeproj` in Xcode
3. Select a simulator or device and run

## Development Workflow

**Claude must push to GitHub *and* upload a new TestFlight build after every change.**

### 1. Git
- Repo: `git@github.com:divinedavis/Hidden-Gems.git` (branch: `main`)
- After any code edit: `git add -A && git commit -m "<message>" && git push origin main`
- Do not batch multiple unrelated changes into one commit — commit and push per logical change

### 2. Documentation review
After every change, scan what was done and ask: *does this change introduce anything a future reader of this repo would benefit from knowing?* If yes, put it in this README (or a sibling `.md`) before moving on. Examples of things worth capturing:

- New scripts, commands, or CLI flags
- New config files, env vars, or required credentials
- New setup steps (migrations to run, capabilities to enable, keys to rotate)
- New architectural decisions or non-obvious workflows
- New integrations with external services
- Conventions other contributors should follow (naming, routing, etc.)

Trivia like bug fixes, UI tweaks, or typo corrections usually don't need a README entry — the commit message covers them.

### 3. TestFlight
After the git push, ship a new build so the latest state is always testable on device. A one-shot script does the bump + archive + export + upload:

```sh
./scripts/ship.sh
```

First-time setup:
1. Copy `scripts/asc-config.env.example` to `scripts/asc-config.env` and fill in the Issuer ID (App Store Connect → Users and Access → Integrations → App Store Connect API). `asc-config.env` is gitignored.
2. Ensure the API key is at `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`.

The script bumps `CURRENT_PROJECT_VERSION` automatically (ASC rejects duplicate build numbers), archives with `xcodebuild`, exports via `ExportOptions.plist`, and uploads via `xcrun altool`. Processing in App Store Connect takes ~5 minutes before the build is testable.

Only report the task complete after both the git push **and** the TestFlight upload succeed.

## Sign in with Apple

Native iOS Sign in with Apple is wired up. Requirements:

- `Hidden Gems/HiddenGems.entitlements` declares `com.apple.developer.applesignin = ["Default"]` and `CODE_SIGN_ENTITLEMENTS` in `project.pbxproj` points at it.
- **Supabase dashboard setup (one-time):** Authentication → Providers → Apple → *Enable*, then register `com.divinedavis.hiddengems` as a native **Client ID**. No secret key needed for the native iOS flow.
- The code path generates a random nonce, passes SHA256(nonce) to Apple's authorization request, and sends the raw nonce + identity token to `supabase.auth.signInWithIdToken(...)`. See `LandingView.swift` + `AuthManager.signInWithApple` in `AuthView.swift`.

If the Apple provider isn't enabled in Supabase yet, tapping the Apple button will fail with "Could not sign in with Apple. Please try again." — enable the provider and try again.

## Author

Divine Davis
