# PROJECT_STRUCTURE.md — kasabov_dgtu

## Overview

| Property | Value |
|---|---|
| Name | kasabov_dgtu |
| Type | Flutter Mobile App + Firebase Backend |
| Architecture | Feature-driven + Clean Architecture (data / domain / presentation) |
| Firebase project | kasabov-dgtu |
| Dart SDK | ^3.10.4 |

---

## Repository Layout

```
kasabov_dgtu/
├── lib/                        # Flutter source code (Dart)
│   ├── main.dart               # Entry point — Firebase init, theme, providers
│   ├── firebase_options.dart   # Auto-generated (do not edit)
│   └── src/
│       ├── app.dart            # Root widget
│       ├── auth_gate.dart      # Auth state router
│       ├── auth_service.dart   # Auth + user profile (ChangeNotifier)
│       ├── attachment_image.dart
│       ├── data/moderation/    # Client-side automated moderation
│       ├── domain/             # Pure domain: entities, policies, failures
│       ├── models/             # Firestore DTOs
│       ├── pages/              # All screens (14 pages)
│       ├── repositories/       # Firestore CRUD
│       └── services/           # FCM, PDF/Excel export
├── functions/                  # Firebase Cloud Functions (TypeScript)
│   └── src/index.ts            # FCM notification triggers
├── assets/
│   ├── logo.svg
│   └── icon.png
├── docs/
│   ├── firestore_schema.md     # Firestore data model reference
│   └── test_checklist.md       # Manual QA checklist by role
├── android/                    # Android-specific config
├── ios/                        # iOS-specific config
├── firebase.json               # Firebase CLI config (emulator ports)
├── firestore.rules             # Firestore security rules
├── firestore.indexes.json      # Composite indexes
├── storage.rules               # Cloud Storage security rules
├── .firebaserc                 # Firebase project binding
└── pubspec.yaml                # Flutter dependencies
```

---

## lib/src/ Details

### pages/ — Screens

| File | Description |
|---|---|
| `auth_page.dart` | Login |
| `signup_page.dart` | Registration |
| `email_verification_page.dart` | Email verification prompt |
| `landing_page.dart` | Initial screen |
| `home_page.dart` | Main shell / navigation |
| `feed_page.dart` | Proposal feed with filters |
| `detail_page.dart` | Proposal detail |
| `create_proposal_page.dart` | New proposal form |
| `voting_page.dart` | Comments and voting |
| `statistics_page.dart` | Analytics dashboard |
| `users_page.dart` | User directory |
| `users_admin_page.dart` | Admin: user management |
| `categories_admin_page.dart` | Admin: category management |
| `reports_export_page.dart` | PDF/Excel export |

### repositories/ — Firestore CRUD

| File | Collection |
|---|---|
| `proposals_repository.dart` | `proposals` |
| `categories_repository.dart` | `categories` |
| `user_profile_repository.dart` | `users` |

### domain/ — Business Logic (pure Dart)

```
domain/
├── core/failure.dart
├── entities/handover_department.dart
├── moderation/automated_moderation_result.dart
└── policies/voting_policy.dart
```

### data/moderation/ — Client Moderation Pipeline

```
data/moderation/
├── simple_profanity_gate.dart
├── client_moderation_pipeline.dart
└── firestore_duplicate_heuristic.dart
```

---

## Firebase Cloud Functions

**File:** `functions/src/index.ts`

| Function | Trigger | Action |
|---|---|---|
| `notifyFavoriteCategoryOnProposalPublished` | Proposal status → published | FCM to category subscribers |
| `notifyOnStatusChange` | Proposal status update | FCM to proposal author |

---

## Data Model (Firestore)

```
users/{uid}
  email, fullName, role, status, documentUrl, fcmTokens, createdAt

categories/{id}
  name, createdAt, updatedAt

proposals/{id}
  title, text, authorId, categoryId, visibility, status,
  assigneeId, comment, createdAt, updatedAt
  └── history/{eventId}   — status, reason, changedById, changedAt
  └── comments/{commentId} — authorId, text, createdAt, updatedAt
  └── likes/{uid}         — likedAt
```

Roles: `student` | `staff` | `moderator` | `admin`
Statuses: `new` → `review` → `at_work` → `completed` / `rejected`

---

## Key Dependencies

| Package | Version | Purpose |
|---|---|---|
| firebase_core | 4.2.1 | Firebase initialization |
| firebase_auth | 6.1.2 | Authentication |
| cloud_firestore | 6.1.0 | Database |
| firebase_messaging | 16.0.4 | Push notifications |
| firebase_app_check | 0.4.2 | Security |
| provider | 6.0.5 | State management |
| flutter_svg | 2.0.9 | SVG rendering |
| pdf | 3.11.1 | PDF export |
| excel | 4.0.6 | Excel export |
| image_picker | 1.1.0 | Image selection |
| file_picker | 8.3.7 | Document selection |
| share_plus | 10.1.4 | Share files |

---

## Local Development

```bash
# Start Firebase emulators
cd functions && npm run serve
# Ports: auth=9099, firestore=8080, storage=9199, functions=5001, ui=4000

# Run Flutter app
flutter run
```
