class CartItemModel {
  final String? version;
  final num? serverRentalTotal;
  final num? serverDepositTotal;
  final String id;
  final String branchId;
  final String branchName;
  final String modelId;
  final String modelName;
  final String imageUrl;
  final num dailyPrice;
  final num? depositPrice;
  final DateTime startDate;
  final DateTime endDate;
  final int rentalDays;
  final int quantity;
  final int? maxAvailable;
  final bool isSelected;
  final bool isAvailable;
  final String? unavailableReason;

  const CartItemModel({
    this.version,
    this.serverRentalTotal,
    this.serverDepositTotal,
    required this.id,
    required this.branchId,
    required this.branchName,
    required this.modelId,
    required this.modelName,
    required this.imageUrl,
    required this.dailyPrice,
    this.depositPrice,
    required this.startDate,
    required this.endDate,
    required this.rentalDays,
    this.quantity = 1,
    this.maxAvailable,
    this.isSelected = true,
    this.isAvailable = true,
    this.unavailableReason,
  });

  num get itemTotalPrice =>
      serverRentalTotal ?? dailyPrice * rentalDays * quantity;

  num? get itemTotalDeposit =>
      serverDepositTotal ??
      (depositPrice != null ? depositPrice! * quantity : null);

  CartItemModel copyWith({
    String? id,
    String? branchId,
    String? branchName,
    String? modelId,
    String? modelName,
    String? imageUrl,
    num? dailyPrice,
    num? depositPrice,
    DateTime? startDate,
    DateTime? endDate,
    int? rentalDays,
    int? quantity,
    int? maxAvailable,
    bool? isSelected,
    bool? isAvailable,
    String? unavailableReason,
  }) {
    return CartItemModel(
      version: version,
      serverRentalTotal: quantity == null ? serverRentalTotal : null,
      serverDepositTotal: quantity == null ? serverDepositTotal : null,
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      modelId: modelId ?? this.modelId,
      modelName: modelName ?? this.modelName,
      imageUrl: imageUrl ?? this.imageUrl,
      dailyPrice: dailyPrice ?? this.dailyPrice,
      depositPrice: depositPrice ?? this.depositPrice,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      rentalDays: rentalDays ?? this.rentalDays,
      quantity: quantity ?? this.quantity,
      maxAvailable: maxAvailable ?? this.maxAvailable,
      isSelected: isSelected ?? this.isSelected,
      isAvailable: isAvailable ?? this.isAvailable,
      unavailableReason: unavailableReason ?? this.unavailableReason,
    );
  }
}
