import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// A write-ahead marker survives route changes and app restarts after a lost POST response.
class ExtensionSubmissionStore {
  Future<Map<String, dynamic>?> read(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('extension_submission_$id');
    return value == null ? null : Map<String, dynamic>.from(jsonDecode(value));
  }

  Future<void> write(String id, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('extension_submission_$id', jsonEncode(value))) {
      throw StateError('Không thể lưu trạng thái gửi yêu cầu.');
    }
  }

  Future<void> clear(String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove('extension_submission_$id')) {
      throw StateError('Không thể cập nhật trạng thái gửi yêu cầu.');
    }
  }
}
