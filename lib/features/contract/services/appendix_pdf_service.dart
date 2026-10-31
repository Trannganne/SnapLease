import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AppendixPdfService {
  Future<Uint8List> generate(Map<String, dynamic> row) async {
    final snapshot = jsonDecode(row['noiDungJson'] as String) as Map;
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/times_new_roman.ttf'),
    );
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font),
        build:
            (_) => [
              pw.Text(
                'PHỤ LỤC GIA HẠN ${row['maPhuLuc']}',
                style: const pw.TextStyle(fontSize: 18),
              ),
              pw.Text('Hợp đồng: ${row['maHopDong']}'),
              pw.Text('Hạn hiện tại: ${snapshot['HieuLucTu']}'),
              pw.Text('Hạn đề nghị: ${snapshot['ThoiHanTraMoi']}'),
              pw.Text(
                'Phí phát sinh: ${snapshot['ChiPhiPhatSinh']} VND; quyết toán khi trả máy.',
              ),
              pw.Text('Mã băm nội dung: ${row['maBamNoiDung']}'),
              ...((snapshot['dieuKhoan'] as List).cast<String>()).map(
                (t) => pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Text(t),
                ),
              ),
              pw.Text(
                'Chỉ có hiệu lực sau khi khách xác nhận OTP thành công trước hạn ký. Hợp đồng gốc và PDF gốc được giữ nguyên.',
              ),
            ],
      ),
    );
    return pdf.save();
  }
}
