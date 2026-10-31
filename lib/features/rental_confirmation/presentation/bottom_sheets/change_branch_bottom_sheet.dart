import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/primary_button.dart';

import '../../../../domain/entities/device_detail.dart';
import '../../../branches/presentation/branch_choice_tile.dart';

class ChangeBranchBottomSheet extends StatefulWidget {
  final String? currentBranchId;
  final List<BranchAvailability> branches;
  final Future<List<BranchAvailability>> Function()? loadBranches;

  const ChangeBranchBottomSheet({
    super.key,
    required this.currentBranchId,
    required this.branches,
    this.loadBranches,
  });

  @override
  State<ChangeBranchBottomSheet> createState() =>
      _ChangeBranchBottomSheetState();
}

class _ChangeBranchBottomSheetState extends State<ChangeBranchBottomSheet> {
  String? selectedBranchId;
  late List<BranchAvailability> branches;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    selectedBranchId = widget.currentBranchId;
    branches = widget.branches;
    if (widget.loadBranches != null) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await widget.loadBranches!();
      if (!mounted) return;
      setState(() {
        branches = values;
        loading = false;
        if (!branches.any((b) => b.branchId == selectedBranchId)) {
          selectedBranchId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Chưa kiểm tra được chi nhánh. Vui lòng thử lại.';
      });
    }
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: AppText(
                    'Thay đổi chi nhánh',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (loading) const LinearProgressIndicator(),
            if (error != null) ...[
              AppText(error!),
              TextButton(onPressed: _load, child: const AppText('Thử lại')),
            ],
            if (!loading && error == null && branches.isEmpty)
              const AppText(
                'Không có chi nhánh đủ thiết bị trong thời gian đã chọn.',
              ),
            if (!loading && error == null && branches.length == 1)
              const AppText('Chỉ có một chi nhánh đáp ứng lựa chọn hiện tại.'),
            if (!loading && error == null)
              ...branches.map((branch) {
                final isSelected = selectedBranchId == branch.branchId;
                return BranchChoiceTile(
                  name: branch.branchName,
                  address: branch.address,
                  selected: isSelected,
                  subtitle:
                      widget.loadBranches == null
                          ? 'Chưa kiểm tra khả dụng'
                          : 'Đáp ứng lựa chọn hiện tại',
                  onTap: () {
                    setState(() {
                      selectedBranchId = branch.branchId;
                    });
                  },
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
                    onPressed:
                        loading ||
                                error != null ||
                                selectedBranchId == null ||
                                !branches.any(
                                  (b) => b.branchId == selectedBranchId,
                                )
                            ? null
                            : () {
                              Navigator.of(context).pop(selectedBranchId);
                            },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
