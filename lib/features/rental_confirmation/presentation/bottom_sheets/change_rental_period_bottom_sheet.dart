import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/primary_button.dart';

class ChangeRentalPeriodBottomSheet extends StatefulWidget {
  final DateTime currentPickup;
  final DateTime currentReturn;

  const ChangeRentalPeriodBottomSheet({
    super.key,
    required this.currentPickup,
    required this.currentReturn,
  });

  @override
  State<ChangeRentalPeriodBottomSheet> createState() =>
      _ChangeRentalPeriodBottomSheetState();
}

class _ChangeRentalPeriodBottomSheetState
    extends State<ChangeRentalPeriodBottomSheet> {
  late DateTime selectedPickup;
  late DateTime selectedReturn;

  @override
  void initState() {
    super.initState();
    selectedPickup = widget.currentPickup;
    selectedReturn = widget.currentReturn;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppText(
                'Thay đổi thời gian',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDateCard(
                  'Ngày nhận',
                  _formatDate(selectedPickup),
                  '09:00', // Default time
                  context,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedPickup,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedPickup = picked;
                        if (selectedPickup.isAfter(selectedReturn) || selectedPickup.isAtSameMomentAs(selectedReturn)) {
                          selectedReturn = selectedPickup.add(const Duration(days: 1));
                        }
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateCard(
                  'Ngày trả',
                  _formatDate(selectedReturn),
                  '18:00', // Default time
                  context,
                  onTap: () async {
                    final firstDate = selectedPickup.add(const Duration(days: 1));
                    DateTime initialDate = selectedReturn;
                    if (initialDate.isBefore(firstDate)) {
                      initialDate = firstDate;
                    }
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: firstDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedReturn = picked;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const AppText('Hủy'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PrimaryButton(
                  text: 'Áp dụng',
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pop({'pickup': selectedPickup, 'return': selectedReturn});
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildDateCard(
    String title,
    String date,
    String time,
    BuildContext context, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: 4),
                AppText(
                  title,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppText(date, fontWeight: FontWeight.bold, fontSize: 16),
            SizedBox(height: 2),
            AppText(
              time,
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
