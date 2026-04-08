# Firestore schema (DGTU proposals)

## users/{uid}

| Field | Type | Notes |
| ----- | ---- | ----- |
| email | string | |
| fullName | string | FIO |
| role | string | `student`, `staff`, `moderator`, `admin` (`user` legacy treated as `student` in app) |
| status | string | `unverified`, `verified`, `disabled` |
| documentUrl | string | Scan of student/staff ID (Firestore stores URL after Storage upload) |
| fcmTokens | map or array | Optional; push tokens for FCM |
| createdAt | timestamp | |

## categories/{id}

| Field | Type |
| ----- | ---- |
| name | string |
| createdAt | timestamp |
| updatedAt | timestamp (optional) |

## proposals/{id}

| Field | Type | Notes |
| ----- | ---- | ----- |
| title | string | |
| text | string | |
| authorId | string | UID |
| categoryId | string | Refers to `categories` doc id (or `uncategorized`) |
| visibility | string | `private` or `public` (public after moderation) |
| status | string | See `ProposalStatus` in app: `new`, `review`, `at_work`, `completed`, `rejected` (legacy `at work` normalized) |
| assigneeId | string? | Responsible moderator UID |
| comment | string | Legacy single-field moderator comment (kept for UI compatibility) |
| createdAt | timestamp | |
| updatedAt | timestamp | |

### proposals/{id}/history/{eventId}

| Field | Type |
| ----- | ---- |
| status | string |
| reason | string |
| changedById | string |
| changedAt | timestamp |

### proposals/{id}/comments/{commentId}

| Field | Type |
| ----- | ---- |
| authorId | string |
| text | string |
| createdAt | timestamp |
| updatedAt | timestamp |

### proposals/{id}/likes/{uid}

| Field | Type |
| ----- | ---- |
| likedAt | timestamp |
