# Authentication & Cloud Backup Implementation Plan

## Overview
Add user authentication and cloud backup to Writer's Cue so users can restore their writing projects if they delete and reinstall the app.

## Architecture Decision: Supabase Direct Integration

Rather than building a separate backend server, we'll use **Supabase's direct client SDK** for iOS. Supabase provides:
- Built-in authentication (including Apple Sign-In)
- PostgreSQL database for storing projects
- Row-level security for data isolation per user
- Swift SDK for native iOS integration

This approach eliminates the need for a separate `writers-cue-backend` folder - Supabase handles everything.

## Authentication Methods: Apple Sign-In + Google Sign-In
- **Apple Sign-In**: Native iOS experience, required by Apple when offering social logins
- **Google Sign-In**: Popular alternative, familiar to many users
- Both supported natively by Supabase Auth
- User chooses their preferred method on sign-in screen

---

## Implementation Steps

### Phase 1: Supabase Project Setup
1. Create Supabase project at supabase.com
2. Enable authentication providers in Supabase Auth settings:
   - Apple Sign-In (requires Apple Developer account, App ID configuration)
   - Google Sign-In (requires Google Cloud Console project, OAuth credentials)
3. Create database schema for `writing_projects` table:
   ```sql
   create table writing_projects (
     id uuid primary key,
     user_id uuid references auth.users(id) not null,
     title text not null,
     content_data bytea,  -- RTFD binary data
     deadline timestamptz,
     created_at timestamptz default now(),
     last_edited_at timestamptz default now(),
     nudge_enabled boolean default true,
     nudge_mode text default 'afterInactivity',
     nudge_hour int default 9,
     nudge_minute int default 0,
     max_inactivity_hours int default 48,
     updated_at timestamptz default now()
   );

   -- Row-level security: users can only access their own projects
   alter table writing_projects enable row level security;

   create policy "Users can CRUD own projects"
     on writing_projects for all
     using (auth.uid() = user_id);
   ```

### Phase 2: iOS - Add Supabase SDK
1. Add Supabase Swift package dependency
2. Create `Managers/SupabaseManager.swift` - singleton for Supabase client
3. Configure with project URL and anon key

### Phase 3: iOS - Authentication Flow
1. Create `Views/Auth/SignInView.swift` - Sign-in screen with:
   - "Sign in with Apple" button (native ASAuthorizationAppleIDButton)
   - "Sign in with Google" button (GoogleSignIn SDK)
   - "Continue without account" option for local-only use
2. Create `Managers/AuthManager.swift` - handle auth state
3. Update `writers_cueApp.swift` - check auth state on launch
4. Add sign-out option to `AppSettingsView.swift`

### Phase 4: iOS - Content Encryption
1. Create `Managers/EncryptionManager.swift` - handle client-side encryption
   - AES-256-GCM encryption using Apple's CryptoKit
   - Key derivation from user's auth session
   - `func encrypt(_ data: Data) -> Data` - encrypt before upload
   - `func decrypt(_ data: Data) -> Data` - decrypt after download

### Phase 5: iOS - Cloud Sync
1. Create `Managers/SyncManager.swift` - handle sync logic
2. Add sync methods to `WritingProject`:
   - `func uploadToCloud()` - encrypt then save to Supabase
   - `func downloadFromCloud()` - download then decrypt from Supabase
3. Sync triggers (smart, not on every keystroke):
   - **Debounced**: 30 seconds after last edit (wait for typing pause)
   - **Leave editor**: When navigating back to home
   - **App backgrounds**: Critical - `scenePhase == .background`
   - **App launch**: Pull cloud changes from other devices
   - **Manual**: "Sync Now" button for peace of mind
4. Offline handling:
   - All writes go to SwiftData first (local-first)
   - `needsSync` flag marks pending changes
   - Queue uploads until connectivity returns
5. Conflict resolution (when cloud and local both have unsaved changes):
   - Detect conflict: `cloud.lastEditedAt > local.lastSyncedAt` AND `local.needsSync == true`
   - Show alert prompting user to choose:
     - "Keep This Device" - upload local, overwrite cloud
     - "Keep Other Device" - download cloud, discard local changes
   - Never auto-merge (RTFD is binary, can't merge)
   - Never lose data silently - always ask user

### Phase 6: iOS - UI Updates
1. Show sync status indicator in EditorView
2. Add "Sync Now" button in settings
3. Show "Last synced" timestamp
4. Handle offline gracefully (queue changes)

---

## File Changes Summary

### New Files
- `Managers/SupabaseManager.swift` - Supabase client configuration
- `Managers/AuthManager.swift` - Authentication state management
- `Managers/EncryptionManager.swift` - Client-side AES-256 encryption for content
- `Managers/SyncManager.swift` - Cloud sync logic
- `Views/Auth/SignInView.swift` - Sign-in screen with Apple/Google Sign-In
- `Views/Auth/AuthContainerView.swift` - Wrapper to show sign-in or main app

### Modified Files
- `writers_cueApp.swift` - Add auth state check, show SignInView or HomeView
- `AppSettingsView.swift` - Add sign-out button, sync status
- `EditorView.swift` - Trigger sync on save
- `WritingProject.swift` - Add sync-related properties (lastSyncedAt, needsSync)

---

## User Flow

1. **First Launch**: User sees SignInView with "Sign in with Apple" button
2. **After Sign-In**: Existing local projects are uploaded to cloud
3. **Normal Use**: Projects sync automatically on save
4. **Reinstall App**: User signs in, projects are restored from cloud
5. **Optional**: Can use app without signing in (local-only mode)

---

## Dependencies to Add

```swift
// Package.swift or via Xcode SPM
dependencies: [
    .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
    .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.0.0")
]
```

Note: Apple Sign-In uses the native AuthenticationServices framework (no external dependency needed).

---

## Security Considerations
- Apple Sign-In tokens handled by Supabase
- Row-level security ensures users only see their own data
- Anon key is safe to include in app (RLS protects data)
- **Content encryption**: RTFD data will be encrypted client-side before upload using AES-256-GCM
  - Encryption key derived from user's auth token (unique per user)
  - Data is encrypted on device before sending to Supabase
  - Supabase only stores encrypted blobs - cannot read content
  - Decryption happens on device after download
- HTTPS for all API communication (handled by Supabase SDK)
