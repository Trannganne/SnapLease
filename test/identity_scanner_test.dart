import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:rentcam/features/identity_verification/services/identity_scanner.dart';

void main() {
  late IdentityScanner scanner;

  setUp(() {
    scanner = IdentityScanner();
  });

  TextLine createLine(String text, Rect boundingBox) {
    return TextLine(
      text: text,
      elements: [],
      boundingBox: boundingBox,
      recognizedLanguages: [],
      cornerPoints: [],
      confidence: 1.0,
      angle: 0.0,
    );
  }

  TextBlock createBlock(List<TextLine> lines) {
    return TextBlock(
      text: lines.map((e) => e.text).join('\n'),
      lines: lines,
      boundingBox: Rect.fromLTRB(10, 10, 100, 20),
      recognizedLanguages: [],
      cornerPoints: [],
    );
  }

  RecognizedText createRecognizedText(List<TextBlock> blocks) {
    return RecognizedText(
      text: blocks.map((e) => e.text).join('\n'),
      blocks: blocks,
    );
  }

  test('QR có CMND cũ rỗng nhưng 6 trường vẫn map đúng, có dấu', () {
    final qrData = '012345678901||NGUYỄN VĂN ẤT|01011990|NAM|SỐ 1, HÀ NỘI|01012022';
    final frontText = createRecognizedText([
      createBlock([
        createLine('QUỐC TỊCH: VIỆT NAM', Rect.fromLTRB(10, 10, 100, 20)),
      ])
    ]);
    final backText = createRecognizedText([
      createBlock([
        createLine('CỤC TRƯỞNG CỤC CẢNH SÁT', Rect.fromLTRB(10, 10, 100, 20)),
        createLine('QUẢN LÝ HÀNH CHÍNH VỀ TRẬT TỰ XÃ HỘI', Rect.fromLTRB(10, 25, 100, 35)),
      ])
    ]);

    final result = scanner.mergeAndValidate(qrData, frontText, backText);
    if (result.error != null) {
      print('ERROR: ${result.error}');
    }
    expect(result.isValid, isTrue);
    expect(result.cccd?.value, '012345678901');
    expect(result.hoTen?.value, 'NGUYỄN VĂN ẤT');
    expect(result.ngaySinh?.value, '1990-01-01');
    expect(result.gioiTinh?.value, 'NAM');
    expect(result.diaChiThuongTru?.value, 'SỐ 1, HÀ NỘI');
    expect(result.ngayCap?.value, '2022-01-01');
    expect(result.quocTich?.value, 'VIỆT NAM');
    expect(result.noiCap?.value, 'Cục Cảnh sát quản lý hành chính về trật tự xã hội');
  });

  test('Ngày QR hợp lệ và ngày không tồn tại', () {
    final frontText = createRecognizedText([
      createBlock([
        createLine('QUỐC TỊCH: VIỆT NAM', Rect.fromLTRB(10, 10, 100, 20)),
      ])
    ]);
    final backText = createRecognizedText([
      createBlock([
        createLine('CỤC TRƯỞNG', Rect.fromLTRB(10, 10, 100, 20)),
      ])
    ]);

    final qrInvalidDate = '012345678901||A|32131990|NAM|B|01012022';
    final result = scanner.mergeAndValidate(qrInvalidDate, frontText, backText);
    expect(result.ngaySinh?.value, null);
    expect(result.isValid, isFalse);
    expect(result.error, contains('Mã QR không đọc được và OCR không thể trích xuất đủ thông tin. Vui lòng quét mã QR trực tiếp hoặc chụp lại.'));
  });

  test('Payload thiếu trường hoặc cấu trúc không hỗ trợ', () {
    final frontText = createRecognizedText([]);
    final backText = createRecognizedText([]);

    final result = scanner.mergeAndValidate('012345678901|123456789', frontText, backText);
    expect(result.isValid, isFalse);
    expect(result.error, contains('Mã QR không đọc được và OCR không thể trích xuất đủ thông tin. Vui lòng quét mã QR trực tiếp hoặc chụp lại.'));
  });

  test('OCR đọc sai tên/địa chỉ không làm thay đổi dữ liệu QR', () {
    final qrData = '012345678901||NGUYỄN VĂN A|01011990|NAM|HÀ NỘI|01012022';
    final frontText = createRecognizedText([
      createBlock([
        createLine('HỌ VÀ TÊN: NGUYỄN VĂN B', Rect.fromLTRB(10, 10, 100, 20)),
        createLine('QUỐC TỊCH: VIỆT NAM', Rect.fromLTRB(10, 30, 100, 40)),
      ])
    ]);
    final backText = createRecognizedText([
      createBlock([
        createLine('CỤC CẢNH SÁT QUẢN LÝ HÀNH CHÍNH VỀ TRẬT TỰ XÃ HỘI', Rect.fromLTRB(10, 10, 100, 20)),
      ])
    ]);

    final result = scanner.mergeAndValidate(qrData, frontText, backText);

    expect(result.hoTen?.value, 'NGUYỄN VĂN A'); // Not NGUYỄN VĂN B
    expect(result.hoTen?.source, 'QR');
    expect(result.isValid, isTrue);
  });

  test('Quốc tịch cùng dòng với giới tính', () {
    final qrData = '012345678901||A|01011990|NAM|B|01012022';
    final frontText = createRecognizedText([
      createBlock([
        createLine('GIỚI TÍNH: NAM QUỐC TỊCH: MỸ', Rect.fromLTRB(10, 10, 100, 20)),
      ])
    ]);
    final backText = createRecognizedText([
      createBlock([
        createLine('CỤC CẢNH SÁT QUẢN LÝ HÀNH CHÍNH VỀ TRẬT TỰ XÃ HỘI', Rect.fromLTRB(10, 10, 100, 20)),
      ])
    ]);

    final result = scanner.mergeAndValidate(qrData, frontText, backText);

    expect(result.quocTich?.value, 'MỸ');
  });

  test('Nhãn quê quán ở dòng kế tiếp không bị lấy làm quốc tịch', () {
    final qrData = '012345678901||A|01011990|NAM|B|01012022';
    final frontText = createRecognizedText([
      createBlock([
        createLine('QUỐC TỊCH', Rect.fromLTRB(10, 10, 50, 20)),
        createLine('QUÊ QUÁN', Rect.fromLTRB(10, 25, 50, 35)),
        createLine('VIỆT NAM', Rect.fromLTRB(60, 10, 100, 20)), // Cùng dòng Quốc tịch
      ])
    ]);
    final backText = createRecognizedText([
      createBlock([
        createLine('CỤC CẢNH SÁT QUẢN LÝ HÀNH CHÍNH VỀ TRẬT TỰ XÃ HỘI', Rect.fromLTRB(10, 10, 100, 20)),
      ])
    ]);

    final result = scanner.mergeAndValidate(qrData, frontText, backText);

    expect(result.quocTich?.value, 'VIỆT NAM');
  });

  test('QR không đọc được fallback sang OCR nhưng thiếu thông tin', () {
    final frontText = createRecognizedText([
      createBlock([
        createLine('SỐ: 0123', Rect.fromLTRB(10, 10, 100, 20)),
        createLine('NƠI THƯỜNG TRÚ: HÀ NỘI', Rect.fromLTRB(10, 30, 100, 40)),
      ])
    ]);
    final backText = createRecognizedText([]);

    final result = scanner.mergeAndValidate(null, frontText, backText);

    expect(result.isValid, isFalse);
    expect(result.error, contains('Mã QR không đọc được và OCR không thể trích xuất đủ thông tin. Vui lòng quét mã QR trực tiếp hoặc chụp lại.'));
  });
}
