import * as admin from 'firebase-admin';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';

admin.initializeApp();

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

