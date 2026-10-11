import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../domain/models/signature_result_model.dart';

class ContractModel {
  final String contractId;
  final DateTime date;
  final String lessorName;
  final String lessorAddress;
  final String lessorPhone;
  final String lesseeName;
  final String lesseeId;
  final String lesseePhone;
  final String deviceName;
  final String deviceModel;
  final int quantity;
  final int pricePerDay;
  final DateTime pickupDate;
  final DateTime returnDate;
  final int rentalDays;
  final String branchName;
  final int rentalTotal;
  final int deposit;
  final int totalAmount;
  final String? status;
  final SignatureResultModel? signatureResult;
  final String? deviceImageUrl;

  ContractModel({
    required this.contractId,
    required this.date,
    required this.lessorName,
    required this.lessorAddress,
    required this.lessorPhone,
    required this.lesseeName,
    required this.lesseeId,
    required this.lesseePhone,
    required this.deviceName,
    required this.deviceModel,
    required this.quantity,
    required this.pricePerDay,
    required this.pickupDate,
    required this.returnDate,
    required this.rentalDays,
    required this.branchName,
    required this.rentalTotal,
    required this.deposit,
    required this.totalAmount,
    this.status,
    this.signatureResult,
    this.deviceImageUrl,
  });

  ContractModel copyWith({
    String? contractId,
    DateTime? date,
    String? lessorName,
    String? lessorAddress,
    String? lessorPhone,
    String? lesseeName,
    String? lesseeId,
    String? lesseePhone,
    String? deviceName,
    String? deviceModel,
    int? quantity,
    int? pricePerDay,
    DateTime? pickupDate,
    DateTime? returnDate,
    int? rentalDays,
    String? branchName,
    int? rentalTotal,
    int? deposit,
    int? totalAmount,
    String? status,
    SignatureResultModel? signatureResult,
    String? deviceImageUrl,
  }) {
    return ContractModel(
      contractId: contractId ?? this.contractId,
      date: date ?? this.date,
      lessorName: lessorName ?? this.lessorName,
      lessorAddress: lessorAddress ?? this.lessorAddress,
      lessorPhone: lessorPhone ?? this.lessorPhone,
      lesseeName: lesseeName ?? this.lesseeName,
      lesseeId: lesseeId ?? this.lesseeId,
      lesseePhone: lesseePhone ?? this.lesseePhone,
      deviceName: deviceName ?? this.deviceName,
      deviceModel: deviceModel ?? this.deviceModel,
      quantity: quantity ?? this.quantity,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      pickupDate: pickupDate ?? this.pickupDate,
      returnDate: returnDate ?? this.returnDate,
      rentalDays: rentalDays ?? this.rentalDays,
      branchName: branchName ?? this.branchName,
      rentalTotal: rentalTotal ?? this.rentalTotal,
      deposit: deposit ?? this.deposit,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      signatureResult: signatureResult ?? this.signatureResult,
      deviceImageUrl: deviceImageUrl ?? this.deviceImageUrl,
    );
  }
}

class ContractPdfService {
  Future<Uint8List> generateContractPdf(ContractModel contract, {Uint8List? signaturePngBytes}) async {
    final pdf = pw.Document();

    pw.Font? regularFont;
    pw.Font? boldFont;
    pw.Font? italicFont;
    try {
      regularFont = pw.Font.ttf(await rootBundle.load('assets/fonts/times_new_roman.ttf'));
      boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/times_new_roman_bold.ttf'));
      // Fallback to regular if italic is not available
      italicFont = regularFont; 
    } catch (e) {
      debugPrint('Error loading fonts for PDF: $e');
    }

    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final dateFormatter = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont, italic: italicFont),
        build: (pw.Context context) {
          return [
            _buildHeader(contract, dateFormatter),
            pw.SizedBox(height: 16),
            _buildPartiesInfo(contract),
            pw.SizedBox(height: 8),
            _buildArticle1(contract, currencyFormatter),
            _buildArticle2(contract, dateFormatter),
            _buildArticle3(contract, currencyFormatter),
            _buildArticle4(),
            _buildArticle5(),
            _buildArticle6(),
            _buildArticle7(),
            _buildArticle8(),
            _buildArticle9(),
            pw.SizedBox(height: 32),
            _buildSignatures(contract, signaturePngBytes),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(ContractModel contract, DateFormat dateFormatter) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
        pw.Text('Độc lập – Tự do – Hạnh phúc', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
        pw.Text('------ooOoo------', style: pw.TextStyle(fontSize: 13)),
        pw.SizedBox(height: 16),
        pw.Text('HỢP ĐỒNG', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
        pw.Text('CHO THUÊ MÁY ẢNH', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
        pw.Text('Hợp đồng số: ${contract.contractId}', style: pw.TextStyle(fontSize: 13)),
        pw.SizedBox(height: 16),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('- Căn cứ Bộ luật Dân sự số 91/2015/QH13, ngày 24/11/2015;', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('- Căn cứ chức năng, nhiệm vụ, nhu cầu và khả năng thực hiện của hai bên.', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('- Hai bên thống nhất ký kết Hợp đồng cho thuê máy ảnh với các điều khoản sau đây:', style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            'Hôm nay, ngày ${contract.date.day.toString().padLeft(2, '0')} tháng ${contract.date.month.toString().padLeft(2, '0')} năm ${contract.date.year}, tại ${contract.branchName} chúng tôi gồm có:',
            style: const pw.TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPartiesInfo(ContractModel contract) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Bên A - BÊN THUÊ:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.Text('Tên đại diện/Cá nhân: ${contract.lesseeName}', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Địa chỉ: ............................................................................................................................................', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Mã số thuế/Số CCCD: ${contract.lesseeId}', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Do: ................................................................ Cấp ngày: ..............................................................', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Điện thoại: ${contract.lesseePhone}                                   Email: .......................................................................', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Tài khoản ngân hàng: ........................................... Tại ngân hàng: ..................................................', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('(Sau đây gọi tắt là bên A)', style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 12),
        pw.Text('Bên B - BÊN CHO THUÊ:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.Text('Tên đại diện/Cá nhân: ${contract.lessorName}', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Địa chỉ: ${contract.lessorAddress}', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Mã số thuế/Số CCCD: .......................................................................................................................', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Do: ................................................................ Cấp ngày: ..............................................................', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Điện thoại: ${contract.lessorPhone}                                   Email: .......................................................................', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Tài khoản ngân hàng: ........................................... Tại ngân hàng: ..................................................', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('(Sau đây gọi tắt là bên B)', style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 12),
        pw.Text('Sau khi trao đổi, hai bên thống nhất ký hợp đồng cho thuê máy với các điều khoản như sau:', style: const pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  pw.Widget _buildArticle1(ContractModel contract, NumberFormat currencyFormatter) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        pw.Text('Điều 1. NỘI DUNG, ĐỐI TƯỢNG VÀ GIÁ CẢ CỦA HỢP ĐỒNG:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.Text('1. Bên B cho Bên A thuê máy ảnh, thiết bị như sau:', style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 4),
        _buildDeviceTable(contract, currencyFormatter),
        pw.SizedBox(height: 4),
        pw.Text('* Giá thuê là tổng tiền thuê theo số lượng và thời gian thuê, chưa bao gồm tiền cọc.', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 4),
        pw.Text('2. Phụ kiện đi kèm: ..........................................................................................................................', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('3. Tiêu chuẩn chất lượng của máy, thiết bị: Tất cả máy phải đang hoạt động tốt, đạt công suất quy định của máy.', style: const pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  pw.Widget _buildDeviceTable(ContractModel contract, NumberFormat currencyFormatter) {
    return pw.TableHelper.fromTextArray(
      context: null,
      cellAlignment: pw.Alignment.center,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
      cellStyle: const pw.TextStyle(fontSize: 11),
      data: <List<String>>[
        <String>['STT', 'Tên máy, thiết bị', 'Số lượng', 'Thời gian thuê', 'Giá thuê (VNĐ)'],
        <String>[
          '1',
          '${contract.deviceName} ${contract.deviceModel}',
          contract.quantity.toString(),
          '${contract.rentalDays} ngày',
          currencyFormatter.format(contract.rentalTotal).replaceAll(' đ', '').replaceAll('đ', ''),
        ],
      ],
    );
  }

  pw.Widget _buildArticle2(ContractModel contract, DateFormat dateFormatter) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        pw.Text('Điều 2. MỤC ĐÍCH, THỜI HẠN THUÊ:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.Text('1. Mục đích thuê: Bên A thuê máy ảnh, thiết bị nêu tại Điều 1 để phục vụ học tập, chụp ảnh cá nhân hoặc các mục đích hợp pháp khác, không trái quy định pháp luật.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('2. Thời hạn thuê: Từ ngày ${dateFormatter.format(contract.pickupDate)} đến hết ngày ${dateFormatter.format(contract.returnDate)}', style: const pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  pw.Widget _buildArticle3(ContractModel contract, NumberFormat currencyFormatter) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        pw.Text('Điều 3. TIỀN ĐẶT CỌC:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.Text('Bên A đặt cọc:', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Số tiền: ${currencyFormatter.format(contract.deposit)}', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- CCCD/CMND gốc: .........................................................................................................................', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Tiền đặt cọc nhằm bảo đảm việc trả máy và bồi thường thiệt hại (nếu có).', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Sau khi kết thúc hợp đồng:', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Nếu không phát sinh hư hỏng, mất mát: hoàn trả đầy đủ.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Nếu phát sinh thiệt hại: Bên B được quyền khấu trừ tiền cọc.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Trường hợp tiền đặt cọc không đủ để bù đắp thiệt hại, Bên A có trách nhiệm thanh toán phần chênh lệch còn thiếu cho Bên B trong vòng 03 (ba) ngày làm việc kể từ khi có thông báo bồi thường.', style: const pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  pw.Widget _buildArticle4() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        pw.Text('Điều 4. THỜI HẠN VÀ PHƯƠNG THỨC THANH TOÁN:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.Text('1. Thời hạn thanh toán: Bên A có trách nhiệm thanh toán đầy đủ cho Bên B trong thời hạn 03 (ba) ngày làm việc kể từ ngày hai bên ký kết hợp đồng và/hoặc ký biên bản giao nhận tài sản, hoặc kể từ ngày Bên B có thông báo yêu cầu thanh toán hợp lệ.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('2. Phương thức thanh toán: Chuyển khoản Ngân hàng hoặc tiền mặt.', style: const pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  pw.Widget _buildArticle5() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        pw.Text('Điều 5. QUYỀN VÀ NGHĨA VỤ BÊN A:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.Text('1. Bên A có các nghĩa vụ sau đây:', style: pw.TextStyle(fontSize: 12, fontWeight:pw.FontWeight.bold)),
        pw.Text('- Trả tiền thuê đúng và đủ theo quy định của Điều 1 và Điều 4 của hợp đồng này.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Bàn giao lại máy móc, thiết bị cho thuê đúng thời gian, số lượng như đã thoả thuận và đúng tình trạng chất lượng như khi nhận máy móc, thiết bị trừ hao mòn tự nhiên.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Nếu Bên A cố tình làm hư máy móc, thiết bị cho thuê thì hai bên cùng nhau tìm cách khắc phục, nếu không khắc phục được thì Bên A có nghĩa vụ bồi thường cho Bên B trên cơ sở chi phí sửa chữa thực tế theo thỏa thuận hoặc báo giá của đơn vị sửa chữa, được hai bên xác nhận.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Trường hợp làm hư hỏng hoặc mất máy, Bên A phải bồi thường theo giá thị trường của tài sản tại thời điểm xảy ra thiệt hại.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Không cho bên thứ ba thuê, mượn lại máy móc, thiết bị mà Bên B cho Bên A thuê trong thời hạn cho thuê, trừ khi có sự đồng ý bằng văn bản của Bên B.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('2. Bên A có các quyền sau đây:', style: pw.TextStyle(fontSize: 12, fontWeight:pw.FontWeight.bold)),
        pw.Text('- Yêu cầu Bên B sửa chữa và bảo dưỡng định kì máy ảnh, thiết bị cho thuê trừ hư hỏng nhỏ, yêu cầu Bên B sửa chữa máy ảnh, thiết bị bị hư hỏng không do lỗi của Bên A.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Bên A có quyền đơn phương đình chỉ hợp đồng và yêu cầu Bên B bồi thường thiệt hại trong những trường hợp sau đây:', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('  - Sau 3 (ba) ngày làm việc như đã thoả thuận gia hạn mà Bên B vẫn không chuyển giao máy ảnh, thiết bị cho Bên A dẫn đến Bên A bị ảnh hưởng đến kế hoạch sử dụng trừ trường hợp bất khả kháng theo quy định của pháp luật.', style: const pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  pw.Widget _buildArticle6() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        pw.Text('Điều 6. QUYỀN VÀ NGHĨA VỤ BÊN B:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.Text('1. Bên B có các nghĩa vụ sau đây:', style: pw.TextStyle(fontSize: 12,fontWeight: pw.FontWeight.bold)),
        pw.Text('- Giao máy ảnh, thiết bị cho thuê đúng loại và số lượng, đúng thời gian và địa điểm đã thoả thuận, đảm bảo máy ảnh, thiết bị còn nguyên vẹn, đạt tiêu chuẩn chất lượng như đã quy định tại hợp đồng này.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Xuất biên bản bàn giao cho Bên A mỗi khi giao máy móc, thiết bị cho thuê cho Bên A theo thoả thuận.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Chịu mọi trách nhiệm về tính sở hữu của máy ảnh, thiết bị cho thuê.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Bảo đảm quyền sử dụng máy ảnh, thiết bị ổn định, lâu dài cho Bên A theo đúng thời hạn đã thoả thuận.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Sửa chữa những hư hỏng, khuyết tật của máy móc, thiết bị cho thuê và bảo dưỡng định kỳ máy móc, thiết bị trừ những hư hỏng nhỏ.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Trường hợp Bên B phát hiện ra Bên A sử dụng máy móc, thiết bị thuê không đúng mục đích đã thoả thuận và công dụng của từng loại máy móc, thiết bị thì Bên B phải gửi thông báo bằng văn bản để nhắc nhở Bên A.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('2. Bên B có các quyền sau đây:', style: pw.TextStyle(fontSize: 12,fontWeight: pw.FontWeight.bold)),
        pw.Text('- Nhận tiền thuê đúng và đủ theo quy định của Điều 1 và Điều 4 của hợp đồng này.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Nhận lại máy ảnh, thiết bị cho thuê đúng thời gian, số lượng như đã thoả thuận và đúng tình trạng chất lượng như lúc ban đầu trừ hao mòn tự nhiên.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Gia hạn thời hạn chuyển giao máy ảnh, thiết bị thuê nhưng không nhiều hơn 1 (một) ngày làm việc và phải có văn bản thông báo cho Bên A.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Yêu cầu Bên A sử dụng máy ảnh, thiết bị cho thuê đúng mục đích và công dụng.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Yêu cầu Bên A bồi thường thiệt hại theo thoả thuận nếu máy ảnh, thiết bị thuê bị hư hại do lỗi của Bên A, sau khi hai bên đã cùng nhau tìm cách khắc phục mà vẫn không thể khắc phục được thiệt hại.', style: const pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  pw.Widget _buildArticle7() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        pw.Text('Điều 7. HIỆU LỰC CỦA HỢP ĐỒNG:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.Text('1. Hợp đồng này có hiệu lực kể từ ngày hai bên ký tên.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('2. Hợp đồng này hết hiệu lực trong các trường hợp sau:', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Hai bên đã hoàn tất mọi nghĩa vụ với nhau như thoả thuận.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Hai bên thỏa thuận chấm dứt hợp đồng trước thời hạn.', style: const pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  pw.Widget _buildArticle8() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        pw.Text('Điều 8. TRÁCH NHIỆM TÀI SẢN:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.Text('- Hao mòn tự nhiên, trầy xước nhẹ không bị coi là vi phạm hợp đồng.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Trường hợp mất phụ kiện (pin, thẻ nhớ, sạc…), Bên A phải bồi thường theo giá thị trường tại thời điểm xảy ra thiệt hại.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Trường hợp mất máy ảnh hoặc hư hỏng không thể khắc phục, Bên A phải bồi thường theo giá trị thị trường của máy tại thời điểm xảy ra thiệt hại, không phụ thuộc vào số tiền đặt cọc.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('- Trường hợp Bên A chậm trả máy quá 24 giờ mà không có lý do chính đáng, Bên B có quyền tính thêm tiền thuê theo ngày.', style: const pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  pw.Widget _buildArticle9() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        pw.Text('Điều 9. ĐIỀU KHOẢN CHUNG:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.Text('1. Hai bên cam kết thực hiện đúng các điều khoản của hợp đồng, trong quá trình thực hiện nếu có gì trở ngại, khó khăn, hai bên giải quyết, thương lượng trên tinh thần hợp tác cùng có lợi.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('2. Trường hợp có vấn đề tranh chấp mà các bên không tự thương lượng, giải quyết được thì một trong các bên được quyền yêu cầu Tòa án nhân dân huyện, tỉnh giải quyết. Quyết định hay bản án của Tòa án là phán quyền cuối cùng, các bên có nghĩa vụ chấp hành.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('3. Trong trường hợp hai bên hoặc một trong hai bên muốn chấm dứt hợp đồng trước hạn phải thông báo cho nhau trước 10 (mười) ngày và khi hai bên đã hoàn thành tất cả các nghĩa vụ trong hợp đồng, không còn nợ nhau thì hợp đồng này có thêm giá trị tự thanh lý.', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('4. Hợp đồng được lập thành 02 (hai) bản tiếng Việt, mỗi bên giữ 01 (một) bản có giá trị pháp lý như nhau.', style: const pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  pw.Widget _buildSignatures(ContractModel contract, Uint8List? signaturePngBytes) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('ĐẠI DIỆN BÊN A', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text('(ký, ghi rõ họ tên)', style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 8),
            if (signaturePngBytes != null)
              pw.Image(
                pw.MemoryImage(signaturePngBytes),
                width: 100,
                height: 50,
                fit: pw.BoxFit.contain,
              )
            else
              pw.SizedBox(height: 50),
            pw.SizedBox(height: 8),
            pw.Text(contract.lesseeName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('ĐẠI DIỆN BÊN B', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text('(ký, ghi rõ họ tên)', style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 50),
            pw.SizedBox(height: 8),
            pw.Text(contract.lessorName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
