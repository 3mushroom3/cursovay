"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.notifyOnStatusChange = exports.notifyFavoriteCategoryOnProposalPublished = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
admin.initializeApp();
function topicForCategory(categoryId) {
    const safe = categoryId.replace(/[^a-zA-Z0-9_-]/g, '_');
    return `cat_${safe}`;
}
/// Публикация модератором (`moderationPublished: true`): рассылаем подписчикам
/// FCM-топика категории (см. клиент `NotificationService.applyFavoriteCategoryTopics`).
exports.notifyFavoriteCategoryOnProposalPublished = (0, firestore_1.onDocumentUpdated)('proposals/{proposalId}', async (event) => {
    var _a, _b;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const after = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (!after)
        return;
    const cat = after.categoryId;
    if (!cat || cat === 'uncategorized')
        return;
    const was = before === null || before === void 0 ? void 0 : before.moderationPublished;
    const now = after.moderationPublished;
    if (now !== true || was === true)
        return;
    const topic = topicForCategory(cat);
    const title = after.title || 'Новое предложение';
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
});
exports.notifyOnStatusChange = (0, firestore_1.onDocumentUpdated)('proposals/{proposalId}', async (event) => {
    var _a, _b, _c;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const after = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (!before || !after)
        return;
    const beforeStatus = before.status;
    const afterStatus = after.status;
    if (!afterStatus || beforeStatus === afterStatus)
        return;
    const authorId = after.authorId;
    if (!authorId)
        return;
    const userSnap = await admin.firestore().collection('users').doc(authorId).get();
    const user = userSnap.data();
    if (!user)
        return;
    const tokensMap = ((_c = user.fcmTokens) !== null && _c !== void 0 ? _c : {});
    const tokens = Object.keys(tokensMap).filter((t) => tokensMap[t]);
    if (tokens.length === 0)
        return;
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
});
