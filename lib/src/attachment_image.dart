import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Верхняя граница суммарной длины base64 всех inline-вложений в одном документе `proposals`.
const int kMaxProposalAttachmentsInlineBase64Chars = 680000;

/// Оценка длины всех полей [inlineBase64] в массиве вложений (лимит документа Firestore ~1 МБ).
int estimateInlineBase64TotalLength(List<Map<String, dynamic>> items) {
  var n = 0;
  for (final m in items) {
    final s = m['inlineBase64'];
    if (s is String) n += s.length;
  }
  return n;
}

Uint8List? decodeInlineBase64(String? b64) {
  if (b64 == null || b64.isEmpty) return null;
  try {
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}

/// Первое изображение: Firestore [inlineBase64] или старый URL из Storage.
({Uint8List? bytes, String? url})? firstImagePreviewData(Object? attachments) {
  final list = (attachments as List?)
      ?.map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  if (list == null || list.isEmpty) return null;
  for (final a in list) {
    final ct = (a['contentType'] as String?) ?? '';
    if (!ct.startsWith('image/')) continue;
    final bytes = decodeInlineBase64(a['inlineBase64'] as String?);
    if (bytes != null) {
      return (bytes: bytes, url: null);
    }
    final url = a['url'] as String?;
    if (url != null && url.isNotEmpty) {
      return (bytes: null, url: url);
    }
  }
  return null;
}

/// Превью в списке предложений (иконка / миниатюра).
/// Картинка для одного элемента [attachments] (inline или legacy URL).
Widget? imageWidgetForProposalAttachment(
  Map<String, dynamic> a, {
  double height = 220,
}) {
  final ct = (a['contentType'] as String?) ?? '';
  final bytes = decodeInlineBase64(a['inlineBase64'] as String?);
  if (bytes != null && ct.startsWith('image/')) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        bytes,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, st) =>
            const Text('Не удалось показать изображение'),
      ),
    );
  }
  final url = a['url'] as String? ?? '';
  if (url.isNotEmpty && ct.startsWith('image/')) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        height: height,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            height: height * 0.55,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (ctx, err, st) =>
            const Text('Не удалось загрузить изображение'),
      ),
    );
  }
  return null;
}

class ProposalListImageLeading extends StatelessWidget {
  const ProposalListImageLeading({super.key, required this.attachments});

  final Object? attachments;

  @override
  Widget build(BuildContext context) {
    final p = firstImagePreviewData(attachments);
    if (p == null) return const Icon(Icons.article_outlined);
    if (p.bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          p.bytes!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, st) =>
              const Icon(Icons.broken_image_outlined),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        p.url!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            width: 56,
            height: 56,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
        errorBuilder: (ctx, err, st) =>
            const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}
