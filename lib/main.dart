import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'app/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'features/notification/data/push_service.dart';

@pragma('vm:entry-point')
Future<void> snapleaseBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // OS displays background notification. Backend inbox is loaded on resume/open.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(snapleaseBackgroundMessage);
  await initializeDateFormatting('vi_VN', null);
  runApp(const RentCamApp());
  await PushService.instance.start();
}
