import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/chat_models.dart';

class ChatHistoryStore {
  static final instance = ChatHistoryStore();
  final DateTime Function() now;
  Future<void> _queue = Future.value();
  bool _attached = false;
  ChatHistoryStore({DateTime Function()? now}) : now = now ?? DateTime.now;
  String key(String accountId) =>
      'snaplease_chat_v1_${sha256.convert(utf8.encode(accountId))}';
  void attach() {
    if (_attached) return;
    _attached = true;
    TokenStorage.sessionCleanups.add(_clearCurrent);
    unawaited(pruneExpired().catchError((Object error, StackTrace trace) {}));
  }

  Future<void> pruneExpired() => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    for (final name
        in prefs
            .getKeys()
            .where((key) => key.startsWith('snaplease_chat_v1_'))
            .toList()) {
      try {
        final data = jsonDecode(prefs.getString(name)!);
        final rows = _prune(
          (data as List)
              .map(
                (e) =>
                    ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList(),
        );
        if (rows.isEmpty) {
          await prefs.remove(name);
        } else {
          await prefs.setString(
            name,
            jsonEncode(rows.map((e) => e.toJson()).toList()),
          );
        }
      } catch (_) {
        await prefs.remove(name);
      }
    }
  });

  Future<void> _clearCurrent() async {
    final id = await TokenStorage.getAccountId();
    if (id != null) await clear(id);
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace trace) {},
    );
    return result;
  }

  List<ChatMessage> _prune(List<ChatMessage> messages) {
    final current = now().toUtc();
    final cutoff = current.subtract(const Duration(days: 30));
    return messages
        .where(
          (m) =>
              m.at.isAfter(cutoff) &&
              !m.at.isAfter(current.add(const Duration(minutes: 5))),
        )
        .toList();
  }

  Future<List<ChatMessage>> load(String accountId) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key(accountId));
    if (raw == null) return [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) throw const FormatException();
      final messages = _prune(
        data
            .map(
              (e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
      );
      await prefs.setString(
        key(accountId),
        jsonEncode(messages.map((m) => m.toJson()).toList()),
      );
      return messages;
    } catch (_) {
      await prefs.remove(key(accountId));
      return [];
    }
  });
  Future<void> save(
    String accountId,
    List<ChatMessage> messages,
    int generation,
  ) => _serial(() async {
    if (generation != TokenStorage.generation ||
        await TokenStorage.getAccountId() != accountId) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (generation != TokenStorage.generation) return;
    await prefs.setString(
      key(accountId),
      jsonEncode(_prune(messages).map((m) => m.toJson()).toList()),
    );
  });
  Future<void> clear(String accountId) => _serial(() async {
    await (await SharedPreferences.getInstance()).remove(key(accountId));
  });
}
