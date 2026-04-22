import * as admin from 'firebase-admin';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';

admin.initializeApp();

function topicForCategory(categoryId: string): string {
  const safe = categoryId.replace(/[^a-zA-Z0-9_-]/g, '_');
  return `cat_${safe}`;
}

/// Публикация модератором (`moderationPublished: true`): рассылаем подписчикам
/// FCM-топика категории (см. клиент `NotificationService.applyFavoriteCategoryTopics`).
export const notifyFavoriteCategoryOnProposalPublished = onDocumentUpdated(
  'proposals/{proposalId}',
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return;
    const cat = after.categoryId as string | undefined;
    if (!cat || cat === 'uncategorized') return;

    const was = before?.moderationPublished;
    const now = after.moderationPublished;
    if (now !== true || was === true) return;

    const topic = topicForCategory(cat);
    const title = (after.title as string) || 'Новое предложение';
    await admin.messaging().send({
      topic,
      notification: {
        title: 'Новое в избранной категории',
        body: title,
      },
      data: {
        proposalId: event.params.proposalId,
        categoryId: cat,
      },
    });
  },
);

export const notifyOnStatusChange = onDocumentUpdated(
  'proposals/{proposalId}',
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const beforeStatus = before.status as string | undefined;
    const afterStatus = after.status as string | undefined;
    if (!afterStatus || beforeStatus === afterStatus) return;

    const authorId = after.authorId as string | undefined;
    if (!authorId) return;

    const userSnap = await admin.firestore().collection('users').doc(authorId).get();
    const user = userSnap.data();
    if (!user) return;

    const tokensMap = (user.fcmTokens ?? {}) as Record<string, boolean>;
    const tokens = Object.keys(tokensMap).filter((t) => tokensMap[t]);
    if (tokens.length === 0) return;

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: 'Статус предложения изменён',
        body: `Новый статус: ${afterStatus}`,
      },
      data: {
        proposalId: event.params.proposalId,
        status: afterStatus,
      },
    });
  },
);

