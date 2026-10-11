import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

class TestApiPage extends StatefulWidget {
  const TestApiPage({super.key});

  @override
  State<TestApiPage> createState() => _TestApiPageState();
}

class _TestApiPageState extends State<TestApiPage> {
  String _result = 'Chưa test';
  bool _isLoading = false;

  Future<void> _testHealthApi() async {
    setState(() {
      _isLoading = true;
      _result = 'Đang gọi: ${ApiConfig.baseUrl}/api/health...';
    });

    try {
      final response = await ApiClient.instance.get('/api/health');
      setState(() {
        _result = '''Thành công!
Status Code: ${response.statusCode}
Response Data: ${response.data}''';
      });
    } on DioException catch (e) {
      setState(() {
        _result = '''Thất bại!
URL: ${ApiConfig.baseUrl}/api/health
Lỗi: ${e.message}
Type: ${e.type}''';
      });
    } catch (e) {
      setState(() {
        _result = 'Lỗi không xác định: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Connection'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nhấn nút dưới để gọi GET /api/health',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testHealthApi,
              child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Test API'),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _result,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14, color: Colors.green),
              ),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Về màn hình Login (Bỏ qua Test)'),
            )
          ],
        ),
      ),
    );
  }
}
