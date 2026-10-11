import 'package:flutter/material.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/entities/branch.dart';
import '../../../../../core/widgets/app_text.dart';

class SearchFilterBottomSheet extends StatefulWidget {
  final String? initialCategoryId;
  final String? initialBranchId;
  final List<DeviceCategory> categories;
  final List<Branch> branches;
  final Function(String? categoryId, String? branchId) onApply;

  const SearchFilterBottomSheet({
    super.key,
    required this.initialCategoryId,
    required this.initialBranchId,
    required this.categories,
    required this.branches,
    required this.onApply,
  });

  @override
  State<SearchFilterBottomSheet> createState() =>
      _SearchFilterBottomSheetState();
}

class _SearchFilterBottomSheetState extends State<SearchFilterBottomSheet> {
  String? selectedCategoryId;
  String? selectedBranchId;

  @override
  void initState() {
    super.initState();
    selectedCategoryId = widget.initialCategoryId;
    selectedBranchId = widget.initialBranchId;
  }

  void _reset() {
    setState(() {
      selectedCategoryId = null;
      selectedBranchId = null;
    });
  }

  String _getCategoryName(String? id) {
    if (id == null) return 'Tất cả';
    try {
      return widget.categories.firstWhere((c) => c.id == id).name;
    } catch (_) {
      return 'Không xác định';
    }
  }

  String _getBranchName(String? id) {
    if (id == null) return 'Tất cả';
    try {
      return widget.branches.firstWhere((b) => b.id == id).name;
    } catch (_) {
      return 'Không xác định';
    }
  }

  @override
  Widget build(BuildContext context) {
    int filterCount = 0;
    if (selectedBranchId != null) filterCount++;
    if (selectedCategoryId != null) filterCount++;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const SizedBox(width: 48), // Balance for text center
                  const Expanded(
                    child: Center(
                      child: AppText(
                        'Bộ lọc tìm kiếm',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _reset,
                    child: Container(
                      width: 48,
                      alignment: Alignment.centerRight,
                      child: AppText(
                        'Đặt lại',
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: Theme.of(context).colorScheme.outline),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      'Chi nhánh nhận máy',
                      'Chọn 1 chi nhánh',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: [
                        _buildFilterChip(
                          label: 'Tất cả',
                          isSelected: selectedBranchId == null,
                          onTap: () {
                            setState(() {
                              selectedBranchId = null;
                            });
                          },
                        ),
                        ...widget.branches.map((branch) {
                          return _buildFilterChip(
                            label: branch.name,
                            isSelected: selectedBranchId == branch.id,
                            onTap: () {
                              setState(() {
                                selectedBranchId = branch.id;
                              });
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildSectionHeader(
                      'Dòng máy & Thiết bị',
                      'Chọn 1 danh mục',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: [
                        _buildFilterChip(
                          label: 'Tất cả',
                          isSelected: selectedCategoryId == null,
                          onTap: () {
                            setState(() {
                              selectedCategoryId = null;
                            });
                          },
                        ),
                        ...widget.categories.map((cat) {
                          return _buildFilterChip(
                            label: cat.name,
                            isSelected: selectedCategoryId == cat.id,
                            onTap: () {
                              setState(() {
                                selectedCategoryId = cat.id;
                              });
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Summary Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const AppText(
                                'Đang chọn:',
                                fontWeight: FontWeight.bold,
                              ),
                              AppText(
                                '$filterCount tiêu chí lọc',
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                          if (filterCount > 0) const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (selectedBranchId != null)
                                _buildSummaryTag('Chi nhánh', _getBranchName(selectedBranchId)),
                              if (selectedCategoryId != null)
                                _buildSummaryTag('Dòng máy', _getCategoryName(selectedCategoryId)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _reset,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: AppText(
                        'Đặt lại',
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onApply(selectedCategoryId, selectedBranchId);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: AppText(
                        'Áp dụng bộ lọc →',
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AppText(title, fontWeight: FontWeight.bold, fontSize: 16),
        AppText(
          subtitle,
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.surface,
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(
                Icons.check,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: 4),
            ],
            AppText(
              label,
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTag(String prefix, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface,
            fontFamily: 'Roboto',
          ),
          children: [
            TextSpan(text: '$prefix: '),
            TextSpan(
              text: value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
