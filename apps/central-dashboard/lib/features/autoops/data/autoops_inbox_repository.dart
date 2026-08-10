/// Dart port of `src/api/inbox.ts`.
library;

import '../../../core/utils/autoops_local_store.dart';
import '../../../domain/autoops/domain.dart';
import 'autoops_mock_data.dart' as mock;

class AutoOpsInboxRepository {
  AutoOpsInboxRepository() : _items = List.of(mock.inboxItems);

  List<UnifiedInboxItem> _items;

  static List<Map<String, dynamic>> _encode(List<UnifiedInboxItem> value) =>
      value.map((e) => e.toJson()).toList();

  static List<UnifiedInboxItem> _decode(Object? json) => (json as List)
      .map((e) => UnifiedInboxItem.fromJson(e as Map<String, dynamic>))
      .toList();

  Future<List<UnifiedInboxItem>> list([InboxCategory? category]) {
    final key = 'autoops:inbox:${category?.value ?? 'all'}';
    return cachedMock<List<UnifiedInboxItem>>(
      key,
      () async => category == null
          ? _items
          : _items.where((item) => item.category == category).toList(),
      encode: _encode,
      decode: _decode,
      fallback: const [],
    );
  }

  Future<UnifiedInboxItem?> autoReply(String id) async {
    await sleep(const Duration(milliseconds: 420));
    _items = _items
        .map((item) => item.id == id ? item.copyWith(status: InboxStatus.autoReplied) : item)
        .toList();
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}
