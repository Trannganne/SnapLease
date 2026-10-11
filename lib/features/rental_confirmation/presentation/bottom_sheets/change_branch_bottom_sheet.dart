import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/primary_button.dart';

import '../../../../domain/entities/device_detail.dart';

class ChangeBranchBottomSheet extends StatefulWidget {
  final String currentBranchId;
  final List<BranchAvailability> branches;

  const ChangeBranchBottomSheet({
    super.key, 
    required this.currentBranchId,
    required this.branches,
  });

  @override
  State<ChangeBranchBottomSheet> createState() =>
      _ChangeBranchBottomSheetState();
}

class _ChangeBranchBottomSheetState extends State<ChangeBranchBottomSheet> {
  late String selectedBranchId;

  @override
  void initState() {
    super.initState();
    selectedBranchId = widget.currentBranchId;
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
                'Thay đổi chi nhánh',
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
          ...widget.branches.map((branch) {
            final isSelected = selectedBranchId == branch.branchId;
            return InkWell(
              onTap: () {
                setState(() {
                  selectedBranchId = branch.branchId;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            branch.branchName, 
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(height: 2),
                          AppText(
                            branch.address,
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 4),
                          AppText(
                            'Chưa kiểm tra khả dụng',
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
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
                    Navigator.of(context).pop(selectedBranchId);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
