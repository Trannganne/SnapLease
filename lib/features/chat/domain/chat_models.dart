import '../../../domain/entities/product.dart';
import '../../../core/formatters/app_money_formatter.dart';

class ChatProduct {
  final String id, name, category;
  final String? image, reason;
  final num price, discount;
  const ChatProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.discount,
    this.image,
    this.reason,
  });
  factory ChatProduct.fromJson(Map<String, dynamic> json) {
    final id = json['maDongMay'];
    final name = json['tenDongMay'];
    final price = json['giaThueNgay'];
    final discount = json['phanTramGiamGia'];
    if (id is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,40}$').hasMatch(id) ||
        name is! String ||
        name.trim().isEmpty ||
        price is! num ||
        !price.isFinite ||
        price < 0 ||
        discount is! num ||
        !discount.isFinite ||
        discount < 0 ||
        discount > 100) {
      throw const FormatException('Thẻ thiết bị không hợp lệ.');
    }
    return ChatProduct(
      id: id,
      name: name,
      category: json['tenDanhMuc'] as String? ?? '',
      image: json['anhDaiDien'] as String?,
      reason: json['reason'] as String?,
      price: price,
      discount: discount,
    );
  }
  Map<String, dynamic> toJson() => {
    'maDongMay': id,
    'tenDongMay': name,
    'tenDanhMuc': category,
    'anhDaiDien': image,
    'reason': reason,
    'giaThueNgay': price,
    'phanTramGiamGia': discount,
  };
  Product get product => Product(
    id: id,
    name: name,
    image: image ?? '',
    rating: 0,
    reviewCount: 0,
    pricePerDay: '${const AppMoneyFormatter().format(price)}/ngày',
    available: false,
    category: category,
    branchIds: const [],
  );
}

class ChatMessage {
  final String role, text;
  final DateTime at;
  final List<ChatProduct> products;
  final List<String> sources;
  const ChatMessage({
    required this.role,
    required this.text,
    required this.at,
    this.products = const [],
    this.sources = const [],
  });
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    final text = json['text'];
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    if ((role != 'user' && role != 'assistant') ||
        text is! String ||
        text.isEmpty ||
        at == null ||
        json['products'] is! List ||
        json['sources'] is! List) {
      throw const FormatException('Hội thoại không hợp lệ.');
    }
    return ChatMessage(
      role: role,
      text: text,
      at: at.toUtc(),
      products:
          (json['products'] as List)
              .map(
                (e) =>
                    ChatProduct.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList(),
      sources: (json['sources'] as List).cast<String>(),
    );
  }
  Map<String, dynamic> toJson() => {
    'role': role,
    'text': text,
    'at': at.toUtc().toIso8601String(),
    'products': products.map((e) => e.toJson()).toList(),
    'sources': sources,
  };
}

class ChatStatus {
  final bool enabled;
  final String? reason;
  const ChatStatus(this.enabled, [this.reason]);
}

class ChatFailure implements Exception {
  final String message;
  const ChatFailure(this.message);
}
