# Логическая модель БД (Firestore)

Проект использует **Firebase Firestore** (документная БД). Ниже — логическая модель сущностей и связей в формате ER-диаграммы.

```mermaid
erDiagram
    USERS {
        string uid PK
        string email
        string firstName
        string lastName
        string middleName
        string fullName
        string role
        string status
        boolean isVerified
        string documentMime
        string documentInlineBase64
        string documentStorage
        map fcmTokens
        timestamp createdAt
        timestamp updatedAt
    }

    CATEGORIES {
        string id PK
        string name
        timestamp createdAt
        timestamp updatedAt
    }

    PROPOSALS {
        string id PK
        string title
        string text
        string authorId FK
        string categoryId FK
        string visibility
        string status
        string comment
        int votesCount
        list attachments
        timestamp createdAt
        timestamp updatedAt
    }

    PROPOSAL_COMMENTS {
        string id PK
        string proposalId FK
        string authorId FK
        string authorDisplayName
        string text
        timestamp createdAt
        timestamp updatedAt
    }

    PROPOSAL_HISTORY {
        string id PK
        string proposalId FK
        string status
        string reason
        string changedById FK
        timestamp changedAt
    }

    PROPOSAL_VOTES {
        string userId PK
        string proposalId FK
        timestamp votedAt
    }

    ATTACHMENT {
        string name
        string contentType
        string inlineBase64
        string storage
        string url
    }

    USERS ||--o{ PROPOSALS : "authorId"
    CATEGORIES ||--o{ PROPOSALS : "categoryId"

    PROPOSALS ||--o{ PROPOSAL_COMMENTS : "comments subcollection"
    USERS ||--o{ PROPOSAL_COMMENTS : "authorId"

    PROPOSALS ||--o{ PROPOSAL_HISTORY : "history subcollection"
    USERS ||--o{ PROPOSAL_HISTORY : "changedById"

    PROPOSALS ||--o{ PROPOSAL_VOTES : "votes subcollection"
    USERS ||--o{ PROPOSAL_VOTES : "userId(docId)"

    PROPOSALS ||--o{ ATTACHMENT : "attachments[] (embedded)"
```

## Примечания по реализации

- `PROPOSAL_COMMENTS`, `PROPOSAL_HISTORY`, `PROPOSAL_VOTES` — это **субколлекции** внутри документа `proposals/{proposalId}`.
- В `PROPOSAL_VOTES` идентификатор документа равен `userId` (гарантирует один голос пользователя на предложение).
- `votesCount` в `PROPOSALS` — денормализованный счетчик голосов для быстрой сортировки/отображения.
- `attachments` хранятся как встроенный массив объектов внутри `PROPOSALS` (в текущей реализации чаще в base64).
- `categoryId` может быть служебным значением `uncategorized` (без явного документа в `CATEGORIES`).
- В Firestore связи логические (по `id`), без жестких FK-ограничений на уровне БД.
