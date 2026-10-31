import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

/// Push is transport only. Targets are resolved by authenticated Backend APIs.
class PushService {
  static final instance = PushService();
  final updates = StreamController<void>.broadcast();
  final opens = StreamController<String>.broadcast();
  final _seen = <String>{};
  String? _deviceId;
  String? pendingNotificationId;
  int _generation = 0;
  Future<void> _binding = Future.value();
  Future<void> _transport = Future.value();
  bool _started = false;
  FirebaseMessaging get messaging => FirebaseMessaging.instance;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    TokenStorage.beforeSessionChange = unlink;
    TokenStorage.changes.listen((_) {
      unawaited(syncSession());
    });
    messaging.onRegistered.listen((fid) {
      final generation = _generation;
      _binding = _binding.then((_) => _bind(fid, generation)).catchError((
        Object _,
      ) {
        updates.add(null);
      });
    });
    FirebaseMessaging.onMessage.listen((message) {
      updates.add(null);
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_open);
    final initial = await messaging.getInitialMessage();
    if (initial != null) _open(initial);
    await syncSession();
  }

  void _open(RemoteMessage message) {
    final id = message.data['notificationId'];
    if (id == null || id.isEmpty || !_seen.add(id)) return;
    pendingNotificationId = id;
    opens.add(id);
  }

  Future<void> syncSession() async {
    final token = await TokenStorage.getToken();
    if (token == null) return;
    final generation = _generation;
    if (pendingNotificationId case final String id) opens.add(id);
    try {
      final permission = await messaging.requestPermission();
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;
      await _queueTransport(() async {
        if (generation != _generation ||
            await TokenStorage.getToken() != token) {
          return;
        }
        await messaging.register();
      });
    } catch (_) {
      updates.add(null);
    } // In-app notifications remain usable; no false success.
  }

  Future<void> _bind(String fid, int generation) async {
    final token = await TokenStorage.getToken();
    if (generation != _generation || token == null) {
      return;
    }
    final response = await ApiClient.instance.post(
      '/api/thong-bao/fcm-token',
      data: {'fid': fid, 'platform': 'ANDROID'},
    );
    final id = (response.data as Map)['id'] as String;
    if (generation == _generation) {
      _deviceId = id;
    } else {
      await _unlinkDevice(id, token);
    }
  }

  Future<void> unlink() async {
    final oldToken = await TokenStorage.getToken();
    ++_generation;
    final id = _deviceId;
    _deviceId = null;
    pendingNotificationId = null;
    _seen.clear();
    // A binding 401 can be awaiting TokenStorage.deleteToken(), which calls
    // this hook. Waiting for _binding here would wait on that same request.
    // Queue SDK operations in order, but never make auth wait for transport.
    unawaited(_queueTransport(() => messaging.unregister()));
    if (id != null && oldToken != null) {
      unawaited(_unlinkDevice(id, oldToken));
    }
  }

  Future<void> _queueTransport(Future<void> Function() operation) {
    _transport = _transport.then((_) => operation()).catchError((Object _) {
      updates.add(null);
    });
    return _transport;
  }

  Future<void> _unlinkDevice(String id, String oldToken) async {
    try {
      await ApiClient.instance.delete(
        '/api/thong-bao/fcm-token/$id',
        options: Options(
          headers: {'Authorization': 'Bearer $oldToken'},
          extra: {ApiClient.sessionCleanup: true},
        ),
      );
    } catch (_) {
      // Transport unregistration remains queued even if the old binding expired.
      updates.add(null);
    }
  }
}
