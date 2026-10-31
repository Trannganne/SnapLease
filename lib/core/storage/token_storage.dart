import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _tokenKey = 'access_token';
  static const String _accountKey = 'session_account_id';
  static int generation = 0;
  static int _changing = 0;
  static bool get isChanging => _changing > 0;
  static final _willChange = StreamController<void>.broadcast(sync: true);
  static Stream<void> get willChange => _willChange.stream;
  static final Set<Future<void> Function()> sessionCleanups = {};
  static final _changes = StreamController<void>.broadcast(sync: true);
  static Stream<void> get changes => _changes.stream;
  static Future<void> Function()? beforeSessionChange;

  // Keep the existing opaque-token/session interface used throughout the app.
  // Session events never contain credentials.
  static Future<void> saveToken(String token, {String? accountId}) async {
    generation++;
    _changing++;
    _willChange.add(null);
    try {
      for (final cleanup in List.of(sessionCleanups)) {
        await cleanup();
      }
      await beforeSessionChange?.call();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accountKey);
      await prefs.remove('persistedMaGiuCho');
      await prefs.setString(_tokenKey, token);
      if (accountId != null && accountId.isNotEmpty) {
        await prefs.setString(_accountKey, accountId);
      }
      _changes.add(null);
    } finally {
      _changing--;
    }
  }

  static Future<String?> getToken() async =>
      (await SharedPreferences.getInstance()).getString(_tokenKey);

  static Future<String?> getAccountId() async =>
      (await SharedPreferences.getInstance()).getString(_accountKey);

  static Future<bool> bindAccount(
    String token,
    String accountId,
    int expectedGeneration,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (isChanging ||
        generation != expectedGeneration ||
        prefs.getString(_tokenKey) != token) {
      return false;
    }
    await prefs.setString(_accountKey, accountId);
    return generation == expectedGeneration;
  }

  static Future<void> deleteToken() async {
    generation++;
    _changing++;
    _willChange.add(null);
    try {
      for (final cleanup in List.of(sessionCleanups)) {
        await cleanup();
      }
      await beforeSessionChange?.call();
    } finally {
      try {
        // Invalid credentials must be removed even if optional push cleanup fails.
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
        await prefs.remove(_accountKey);
        await prefs.remove('persistedMaGiuCho');
        _changes.add(null);
      } finally {
        _changing--;
      }
    }
  }
}
