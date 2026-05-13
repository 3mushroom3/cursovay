# Физическая и логическая диаграммы БД — kasabov_dgtu

## Логическая диаграмма (ER-модель)

```
┌──────────────────────────────┐        ┌───────────────────────────────┐
│           USERS              │        │          CATEGORIES           │
├──────────────────────────────┤        ├───────────────────────────────┤
│ uid (PK)                     │        │ id (PK)                       │
│ email          : string      │        │ name           : string       │
│ fullName       : string      │        │ staffOnly      : boolean      │
│ firstName      : string      │        │ createdAt      : timestamp    │
│ lastName       : string      │        │ updatedAt      : timestamp?   │
│ middleName     : string?     │        └───────────────┬───────────────┘
│ role           : string      │                        │ 1
│   (student|staff|            │                        │
│    moderator|admin)          │                        │ N
│ status         : string      │        ┌───────────────┴───────────────┐
│   (unverified|verified|      │        │          PROPOSALS            │
│    disabled)                 │        ├───────────────────────────────┤
│ documentMime   : string      │◄───────┤ id (PK)                       │
│ documentInlineB64 : string   │ N:1    │ title          : string       │
│ fcmTokens      : map?        │ author │ text           : string       │
│ favoriteCategoryIds: array?  │        │ authorId (FK→users)           │
│ isVerified     : boolean     │        │ categoryId (FK→categories)    │
│ createdAt      : timestamp   │        │ visibility     : string       │
└──────────────────────────────┘        │   (private|public)            │
                                        │ status         : string       │
                                        │   (submitted|pending|         │
                                        │    in_progress|published|     │
                                        │    completed|closed|          │
                                        │    rejected|archived|         │
                                        │    transferred)               │
                                        │ moderationPublished : boolean │
                                        │ assigneeId (FK→users)?       │
                                        │ comment        : string       │
                                        │ attachments    : array        │
                                        │ votesForCount  : integer      │
                                        │ votesAgainstCount : integer   │
                                        │ votesCount     : integer      │
                                        │ votingDeadline : timestamp?   │
                                        │ autoPromotedAt : timestamp?   │
                                        │ handoverDepartmentId : string?│
                                        │ createdAt      : timestamp    │
                                        │ updatedAt      : timestamp    │
                                        └───────────────────────────────┘
                                                        │ 1
                              ┌─────────────────────────┼──────────────────────────┐
                              │ N                        │ N                        │ N
                ┌─────────────┴───────┐    ┌────────────┴──────────┐  ┌────────────┴──────────┐
                │   HISTORY           │    │      COMMENTS         │  │       VOTES           │
                ├─────────────────────┤    ├───────────────────────┤  ├───────────────────────┤
                │ id (PK)             │    │ id (PK)               │  │ userId (PK=doc id)    │
                │ status   : string   │    │ authorId (FK→users)   │  │ value    : integer    │
                │ reason   : string   │    │ authorDisplayName      │  │   (1=за, -1=против)  │
                │ changedById (FK→u.) │    │ text      : string    │  │ votedAt  : timestamp  │
                │ changedAt: timestamp│    │ createdAt : timestamp  │  └───────────────────────┘
                └─────────────────────┘    │ updatedAt : timestamp  │
                                           └───────────────────────┘
```

---

## Физическая диаграмма (Firestore Collections)

Firebase Firestore использует NoSQL-документы. Ниже — структура коллекций.

```
firestore-root/
│
├── users/                          # Коллекция пользователей
│   └── {uid}/                      # Документ = Firebase Auth UID
│       ├── email: string
│       ├── fullName: string
│       ├── role: string
│       ├── status: string
│       ├── documentMime: string
│       ├── documentInlineBase64: string  (≤500 КБ в base64)
│       ├── favoriteCategoryIds: string[]
│       ├── fcmTokens: map
│       └── createdAt: timestamp
│
├── categories/                     # Коллекция категорий
│   └── {categoryId}/
│       ├── name: string
│       ├── staffOnly: boolean      (true = только преподаватели)
│       ├── createdAt: timestamp
│       └── updatedAt: timestamp?
│
└── proposals/                      # Коллекция предложений
    └── {proposalId}/
        ├── title: string
        ├── text: string
        ├── authorId: string        → users/{uid}
        ├── categoryId: string      → categories/{id}
        ├── visibility: string      (private | public)
        ├── status: string
        ├── moderationPublished: boolean
        ├── comment: string         (комментарий модератора)
        ├── attachments: array[map] (inlineBase64-изображения)
        ├── votesForCount: integer
        ├── votesAgainstCount: integer
        ├── votesCount: integer     (за - против, legacy)
        ├── votingDeadline: timestamp?
        ├── autoPromotedAt: timestamp?
        ├── handoverDepartmentId: string?
        ├── moderatedById: string?
        ├── createdAt: timestamp
        ├── updatedAt: timestamp
        │
        ├── history/                # Субколлекция: история статусов
        │   └── {eventId}/
        │       ├── status: string
        │       ├── reason: string
        │       ├── changedById: string
        │       └── changedAt: timestamp
        │
        ├── comments/               # Субколлекция: комментарии
        │   └── {commentId}/
        │       ├── authorId: string
        │       ├── authorDisplayName: string
        │       ├── text: string
        │       ├── createdAt: timestamp
        │       └── updatedAt: timestamp
        │
        └── votes/                  # Субколлекция: голоса
            └── {userId}/           # doc id = uid проголосовавшего
                ├── value: integer  (1 = за, -1 = против)
                └── votedAt: timestamp
```

---

## Индексы Firestore

| Коллекция | Поле 1 | Поле 2 | Тип |
|---|---|---|---|
| proposals | categoryId ASC | createdAt DESC | Composite |
| proposals | status ASC | createdAt DESC | Composite |
| proposals | authorId ASC | createdAt DESC | Composite |
| proposals/*/history | changedAt DESC | — | Single field |
| proposals/*/comments | createdAt DESC | — | Single field |

---

## Правила доступа (Firestore Security Rules)

```
users:
  read:   authenticated + own document | moderator | admin
  write:  own document (limited fields) | admin

categories:
  read:   authenticated
  write:  admin | moderator

proposals:
  read:   author | public (visibility=public) | moderator | admin
  write:  author (status=submitted/pending) | moderator | admin
  votes:  authenticated verified users (not own proposal)
  comments: authenticated verified users
  history:  moderator | admin | author (read only)
```
