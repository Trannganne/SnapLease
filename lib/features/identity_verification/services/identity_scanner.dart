import 'dart:io';
import 'dart:ui';
import 'package:flutter/widgets.dart' show decodeImageFromList;
import 'package:meta/meta.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ScanDebugData {
  static bool enableDebug = false; // Mặc định tắt, có thể bật trong UI để debug
  
  static String? frontImagePath;
  static String? fallbackImagePath;
  static String? backImagePath;
  static Size? imageSize;
  static List<Rect> issuerRects = [];
  static List<String> issuerTexts = [];

  static int barcodeCount = -1;
  static List<String> barcodeTypes = [];
  static bool hasRawValue = false;
  static String? qrException;
  static String? barcodeDiagnostic;
  
  static String? rawCapturedImagePath;
  static Rect? cropRect;
  
  static bool isScanned = false;
  static Size? frontImageSize;
  static Rect? fallbackCropRect;

  static void clearFront() {
    frontImagePath = null;
    fallbackImagePath = null;
    barcodeCount = -1;
    barcodeTypes.clear();
    hasRawValue = false;
    qrException = null;
    barcodeDiagnostic = null;
    rawCapturedImagePath = null;
    cropRect = null;
    isScanned = false;
    frontImageSize = null;
    fallbackCropRect = null;
  }
}

class IdentityField {
  final String value;
  final String source; // 'QR' or 'OCR'
  
  IdentityField(this.value, this.source);
}

class ExtractedIdentityData {
  final IdentityField? cccd;
  final IdentityField? hoTen;
  final IdentityField? ngaySinh;
  final IdentityField? gioiTinh;
  final IdentityField? quocTich;
  final IdentityField? diaChiThuongTru;
  final IdentityField? ngayCap;
  final IdentityField? noiCap;
  final String? error;

  ExtractedIdentityData({
    this.cccd,
    this.hoTen,
    this.ngaySinh,
    this.gioiTinh,
    this.quocTich,
    this.diaChiThuongTru,
    this.ngayCap,
    this.noiCap,
    this.error,
  });

  bool get isValid => 
      cccd != null && hoTen != null && ngaySinh != null && 
      gioiTinh != null && quocTich != null && diaChiThuongTru != null && 
      ngayCap != null && noiCap != null && error == null;
}

class IdentityScanner {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _barcodeScanner = BarcodeScanner();

  Future<ExtractedIdentityData> scanBothSides(File frontImage, File backImage, {String? manuallyScannedQr}) async {
    try {
      final frontInput = InputImage.fromFile(frontImage);
      final backInput = InputImage.fromFile(backImage);

      if (ScanDebugData.enableDebug) {
        ScanDebugData.isScanned = true;
        ScanDebugData.frontImagePath = frontImage.path;
      }

      // Extract QR from front
      String? qrData = manuallyScannedQr;
      if (qrData == null) {
        try {
        final barcodes = await _barcodeScanner.processImage(frontInput);
        if (ScanDebugData.enableDebug) {
          ScanDebugData.barcodeCount = barcodes.length;
          ScanDebugData.barcodeTypes = barcodes.map((b) => b.format.name).toList();
        }

        if (barcodes.isEmpty) {
          ScanDebugData.barcodeDiagnostic = 'Engine chạy nhưng trả về 0 barcode.';
        } else {
          bool foundQr = false;
          for (final barcode in barcodes) {
            if (barcode.format == BarcodeFormat.qrCode) {
              foundQr = true;
              if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                ScanDebugData.hasRawValue = true;
                if (barcode.rawValue!.contains('|')) {
                  qrData = barcode.rawValue;
                  ScanDebugData.barcodeDiagnostic = 'Đọc thành công QR hợp lệ.';
                  break;
                } else {
                  ScanDebugData.barcodeDiagnostic = 'Decode được payload nhưng thiếu "|" (không phải định dạng CCCD).';
                }
              } else {
                ScanDebugData.barcodeDiagnostic = 'Có QR nhưng rawValue rỗng.';
              }
            }
          }
          if (!foundQr) {
            ScanDebugData.barcodeDiagnostic = 'Có barcode nhưng không phải QR.';
          }
        }
      } catch (e) {
        ScanDebugData.barcodeDiagnostic = 'Engine (quét toàn bộ ảnh) không chạy được: $e';
      }
      }

      if (qrData == null && manuallyScannedQr == null) {
        // Fallback: try cropping the top-right region of the image for QR scanning
        try {
          final qrFile = await getOrCreateQrFallbackCrop(frontImage);
          if (qrFile != null) {
            final qrInput = InputImage.fromFile(qrFile);
            final qrBarcodes = await _barcodeScanner.processImage(qrInput);
            
            for (final barcode in qrBarcodes) {
              if (barcode.rawValue != null && barcode.rawValue!.contains('|')) {
                qrData = barcode.rawValue;
                ScanDebugData.barcodeDiagnostic = 'Đọc thành công từ ảnh crop dự phòng 40% góc phải.';
                break;
              }
            }
            if (qrData == null) {
              ScanDebugData.barcodeDiagnostic = '${ScanDebugData.barcodeDiagnostic} -> Fallback 40% cũng thất bại (tìm thấy ${qrBarcodes.length} barcode).';
            }
            // Cleanup temp file if not debugging
            if (!ScanDebugData.enableDebug && await qrFile.exists()) {
               await qrFile.delete();
            }
          }
        } catch (e) {
          print('Error cropping for QR fallback: $e');
        }
      }

      // Extract Text from both sides
      final frontText = await _textRecognizer.processImage(frontInput);
      final backText = await _textRecognizer.processImage(backInput);

      if (ScanDebugData.enableDebug) {
        ScanDebugData.backImagePath = backImage.path;
        ScanDebugData.issuerRects.clear();
        ScanDebugData.issuerTexts.clear();
        
        final decoded = await decodeImageFromList(await backImage.readAsBytes());
        ScanDebugData.imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
      }

      return mergeAndValidate(qrData, frontText, backText);
    } catch (e) {
      return ExtractedIdentityData(error: 'Lỗi khi đọc ảnh: $e');
    }
  }

  Future<File?> getOrCreateQrFallbackCrop(File frontImage) async {
    if (ScanDebugData.enableDebug && ScanDebugData.frontImagePath == frontImage.path && ScanDebugData.fallbackImagePath != null) {
      final f = File(ScanDebugData.fallbackImagePath!);
      if (await f.exists()) return f;
    }
    
    try {
      final bytes = await frontImage.readAsBytes();
      final captured = img.decodeImage(bytes);
      if (captured != null) {
        final qx = (captured.width * 0.4).toInt();
        final qy = 0;
        final qw = captured.width - qx;
        final qh = (captured.height * 0.4).toInt();
        final qrCrop = img.copyCrop(captured, x: qx, y: qy, width: qw, height: qh);
        
        final tempDir = await getTemporaryDirectory();
        final qrFile = File('${tempDir.path}/qr_crop_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await qrFile.writeAsBytes(img.encodeJpg(qrCrop, quality: 100));
        
        if (ScanDebugData.enableDebug) {
          ScanDebugData.fallbackImagePath = qrFile.path;
          ScanDebugData.fallbackCropRect = Rect.fromLTWH(qx.toDouble(), qy.toDouble(), qw.toDouble(), qh.toDouble());
          ScanDebugData.frontImageSize = Size(captured.width.toDouble(), captured.height.toDouble());
        }
        return qrFile;
      }
    } catch (e) {
      print('Error generating QR fallback crop: $e');
    }
    return null;
  }

  String? _parseQrDate(String? raw) {
    if (raw == null) return null;
    final clean = raw.replaceAll(' ', '');
    if (clean.length != 8) return null;
    
    final d = clean.substring(0, 2);
    final m = clean.substring(2, 4);
    final y = clean.substring(4, 8);
    
    final dateStr = '$y-$m-$d';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return null;
    
    // Check valid date (e.g., prevent Feb 30 -> Mar 2)
    if (dt.year.toString().padLeft(4, '0') == y &&
        dt.month.toString().padLeft(2, '0') == m &&
        dt.day.toString().padLeft(2, '0') == d) {
      return dateStr;
    }
    return null;
  }

  List<TextLine> _getLines(RecognizedText text) {
    List<TextLine> lines = [];
    for (var block in text.blocks) {
      for (var line in block.lines) {
        lines.add(line);
      }
    }
    return lines;
  }

  String _removeDiacritics(String str) {
    var withDia = 'àáãạảăắằẳẵặâấầẩẫậèéẹẻẽêềếểễệđìíĩỉịòóõọỏôốồổỗộơớờởỡợùúũụủưứừửữựỳỵỷỹýÀÁÃẠẢĂẮẰẲẴẶÂẤẦẨẪẬÈÉẸẺẼÊỀẾỂỄỆĐÌÍĨỈỊÒÓÕỌỎÔỐỒỔỖỘƠỚỜỞỠỢÙÚŨỤỦƯỨỪỬỮỰỲỴỶỸÝ';
    var withoutDia = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeediiiiiooooooooooooooooouuuuuuuuuuuyyyyyAAAAAAAAAAAAAAAAAEEEEEEEEEEEDIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYY';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  @visibleForTesting
  @visibleForTesting
  ExtractedIdentityData mergeAndValidate(String? qrData, RecognizedText frontText, RecognizedText backText) {
    final frontLines = _getLines(frontText);
    final backLines = _getLines(backText);

    String? cccd, hoTen, ngaySinh, gioiTinh, diaChi, ngayCap;
    String source = 'QR';

    bool isQrValid = false;
    if (qrData != null) {
      final parts = qrData.split('|');
      if (parts.length >= 7) {
        final qCccd = parts[0].trim();
        final qHoTen = parts[2].trim();
        final qNgaySinh = _parseQrDate(parts[3].trim());
        final qGioiTinh = parts[4].trim();
        final qDiaChi = parts[5].trim();
        final qNgayCap = _parseQrDate(parts[6].trim());

        if (qCccd.isNotEmpty && qCccd.length == 12 && RegExp(r'^\d+$').hasMatch(qCccd) &&
            qHoTen.isNotEmpty && qNgaySinh != null && qGioiTinh.isNotEmpty &&
            qDiaChi.isNotEmpty && qNgayCap != null) {
          cccd = qCccd;
          hoTen = qHoTen;
          ngaySinh = qNgaySinh;
          gioiTinh = qGioiTinh;
          diaChi = qDiaChi;
          ngayCap = qNgayCap;
          isQrValid = true;
        }
      }
    }

    if (!isQrValid) {
      source = 'OCR';
      // OCR Fallback for all fields
      for (var i = 0; i < frontLines.length; i++) {
        final text = frontLines[i].text.trim();
        final upper = text.toUpperCase();

        // Extract CCCD
        if (cccd == null) {
          final match = RegExp(r'\b\d{12}\b').firstMatch(text);
          if (match != null) cccd = match.group(0);
        }

        // Extract DOB
        if (ngaySinh == null) {
          final match = RegExp(r'\b(\d{2}/\d{2}/\d{4})\b').firstMatch(text);
          if (match != null) {
            final dateStr = match.group(1);
            if (upper.contains('SINH') || upper.contains('BIRTH') || upper.contains('DOB')) {
              ngaySinh = _parseQrDate(dateStr!.replaceAll('/', ''));
            } else if (ngaySinh == null) {
              ngaySinh = _parseQrDate(dateStr!.replaceAll('/', ''));
            }
          }
        }

        // Extract Gender
        if (gioiTinh == null) {
          if (upper.contains('NAM') && !upper.contains('VIỆT NAM')) {
            gioiTinh = 'Nam';
          } else if (upper.contains('NỮ')) {
            gioiTinh = 'Nữ';
          }
        }
        
        // Extract Ho Ten
        if (hoTen == null) {
          if (upper.contains('HỌ VÀ TÊN') || upper.contains('FULL NAME')) {
             if (upper.replaceAll(RegExp(r'HỌ VÀ TÊN|FULL NAME|:|/', caseSensitive: false), '').trim().length > 3) {
                hoTen = text.replaceAll(RegExp(r'HỌ VÀ TÊN|FULL NAME|:|/', caseSensitive: false), '').trim();
             } else if (i + 1 < frontLines.length) {
                hoTen = frontLines[i+1].text.trim();
             }
          }
        }
      }

      // Extract Ngày cấp (usually on back)
      for (var textLine in backLines) {
        final match = RegExp(r'\b(\d{2}/\d{2}/\d{4})\b').firstMatch(textLine.text);
        if (match != null) {
           ngayCap = _parseQrDate(match.group(1)!.replaceAll('/', ''));
           break;
        }
      }
      
      // Extract Địa chỉ (just combine anything after Thường trú)
      bool foundAddress = false;
      List<String> addressLines = [];
      for (var i = 0; i < frontLines.length; i++) {
        final upper = frontLines[i].text.toUpperCase();
        if (upper.contains('THƯỜNG TRÚ') || upper.contains('RESIDENCE')) {
           foundAddress = true;
           final remain = frontLines[i].text.replaceAll(RegExp(r'nơi thường trú|thường trú|place of residence|:|/', caseSensitive: false), '').trim();
           if (remain.isNotEmpty) addressLines.add(remain);
           continue;
        }
        if (foundAddress && !upper.contains('CÓ GIÁ TRỊ ĐẾN') && !upper.contains('UNTIL')) {
           addressLines.add(frontLines[i].text.trim());
        } else if (foundAddress) {
           break;
        }
      }
      if (addressLines.isNotEmpty) diaChi = addressLines.join(', ');

      if (cccd == null || hoTen == null || cccd!.length != 12) {
         final diag = ScanDebugData.barcodeDiagnostic != null ? '\nChẩn đoán: ${ScanDebugData.barcodeDiagnostic}' : '';
         return ExtractedIdentityData(error: 'Mã QR không đọc được và OCR không thể trích xuất đủ thông tin. Vui lòng quét mã QR trực tiếp hoặc chụp lại.$diag');
      }
    }
    
    // OCR Quốc tịch
    String? ocrQuocTich;
    TextLine? natLine;
    for (var line in frontLines) {
      final text = line.text.toUpperCase();
      if (text.contains('QUỐC TỊCH') || text.contains('NATIONALITY')) {
         natLine = line;
         break;
      }
    }
    
    if (natLine != null) {
      final text = natLine.text.toUpperCase();
      final idx = text.indexOf('QUỐC TỊCH');
      final idx2 = text.indexOf('NATIONALITY');
      final startIdx = (idx != -1) ? idx : idx2;
      
      if (startIdx != -1) {
          final sub = text.substring(startIdx);
          final p = sub.split(RegExp(r'[:]+'));
          if (p.length > 1) {
             final val = p.last.trim();
             if (val.isNotEmpty && val != 'NATIONALITY') {
                 ocrQuocTich = val;
             }
          } else {
             final afterNat = sub.replaceFirst(RegExp(r'QUỐC TỊCH|NATIONALITY'), '').trim();
             if (afterNat.isNotEmpty) {
                ocrQuocTich = afterNat;
             }
          }
      }
      
      if (ocrQuocTich == null || ocrQuocTich.isEmpty) {
          // Look for right-side block
          for (var line in frontLines) {
              if (line == natLine) continue;
              if (line.boundingBox.top < natLine.boundingBox.bottom && line.boundingBox.bottom > natLine.boundingBox.top) {
                  if (line.boundingBox.left > natLine.boundingBox.left) {
                      final t = line.text.toUpperCase();
                      if (!t.contains('QUÊ QUÁN') && !t.contains('ORIGIN')) {
                          ocrQuocTich = t.trim();
                          break;
                      }
                  }
              }
          }
      }
      
      if (ocrQuocTich == null || ocrQuocTich.isEmpty) {
          final natIdx = frontLines.indexOf(natLine);
          if (natIdx != -1 && natIdx + 1 < frontLines.length) {
              final nextLine = frontLines[natIdx + 1].text.toUpperCase();
              if (!nextLine.contains('QUÊ QUÁN') && !nextLine.contains('ORIGIN') && !nextLine.contains('THƯỜNG TRÚ') && !nextLine.contains('RESIDENCE')) {
                  ocrQuocTich = nextLine.trim();
              }
          }
      }
    }

    // Nơi cấp
    String? ocrNoiCap;
    
    List<String> possibleIssuerLines = [];
    for (var txtLine in backLines) {
      final line = txtLine.text.toUpperCase();
      if (line.contains('<<') || line.contains('>>') || (line.length > 25 && !line.contains(' '))) continue;
      if (line.contains('NGÓN TRỎ') || line.contains('VẾT KẾT') || line.contains('SẸO') || line.contains('ĐẶC ĐIỂM') || line.contains('NHẬN DẠNG') || line.contains('TRÁI') || line.contains('PHẢI')) continue;
      if (RegExp(r'\d').hasMatch(line)) continue;
      if (line.contains('NƠI CẤP') || line.contains('PLACE OF ISSUE')) continue;
      
      possibleIssuerLines.add(line);
      if (ScanDebugData.enableDebug) {
        ScanDebugData.issuerTexts.add(line);
        ScanDebugData.issuerRects.add(txtLine.boundingBox);
      }
    }
    
    String combinedIssuer = possibleIssuerLines.join(' ');
    String normIssuer = _removeDiacritics(combinedIssuer).toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    
    if (normIssuer.contains('CUCCANHSAT') && 
       (normIssuer.contains('QUANLYHANHCHINH') || normIssuer.contains('QLHCVETTXH') || normIssuer.contains('QLHC'))) {
      ocrNoiCap = 'Cục Cảnh sát quản lý hành chính về trật tự xã hội';
    } else if (normIssuer.contains('TRUNGTAMDULIEUQUOCGIA') || normIssuer.contains('DULIEUQUOCGIAVEDANCU')) {
      ocrNoiCap = 'Trung tâm Dữ liệu quốc gia về dân cư';
    } else if (normIssuer.contains('CUCCANHSAT') && normIssuer.contains('CUTRU')) {
      ocrNoiCap = 'Cục Cảnh sát ĐKQL cư trú và DLQG về dân cư';
    } else if (normIssuer.contains('CONGAN')) {
      // Fallback cho thẻ CMND cũ nếu đủ bằng chứng, ta giữ lại regex trên text chưa remove space để lấy tên Tỉnh/TP
      final match = RegExp(r'CÔNG AN\s+TỈNH\s+([A-Z\s]+)|CÔNG AN\s+THÀNH PHỐ\s+([A-Z\s]+)').firstMatch(combinedIssuer);
      if (match != null) {
        ocrNoiCap = match.group(0);
      }
    }

    // Kết hợp kết quả
    if (ocrQuocTich == null || ocrQuocTich.isEmpty) {
       return ExtractedIdentityData(error: 'Không đọc được Quốc tịch trên mặt trước CCCD. Vui lòng chụp lại mặt trước.');
    }
    if (ocrNoiCap == null || ocrNoiCap.isEmpty) {
       if (possibleIssuerLines.isEmpty) {
         return ExtractedIdentityData(error: 'Mặt sau mờ/chói: Không tìm thấy chữ ở phần Cơ quan cấp. Vui lòng chụp rõ hơn.');
       } else {
         return ExtractedIdentityData(error: 'Đọc được chữ mặt sau nhưng không khớp Cơ quan cấp nào. Vui lòng chụp thẳng và rõ nét hơn.');
       }
    }

    return ExtractedIdentityData(
      cccd: IdentityField(cccd!, source),
      hoTen: IdentityField(hoTen!, source),
      ngaySinh: IdentityField(ngaySinh ?? '', source),
      gioiTinh: IdentityField(gioiTinh ?? '', source),
      quocTich: IdentityField(ocrQuocTich, 'OCR'),
      diaChiThuongTru: IdentityField(diaChi ?? '', source),
      ngayCap: IdentityField(ngayCap ?? '', source),
      noiCap: IdentityField(ocrNoiCap, 'OCR'),
    );
  }

  void dispose() {
    _textRecognizer.close();
    _barcodeScanner.close();
  }
}
