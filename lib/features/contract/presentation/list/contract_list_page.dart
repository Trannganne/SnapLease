import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/app_image.dart';

import '../../../../core/widgets/user_avatar.dart';
import '../../data/contract_list_repository.dart';
import '../../domain/models/contract_summary_model.dart';
import 'bloc/contract_list_bloc.dart';
import 'bloc/contract_list_event.dart';
import 'bloc/contract_list_state.dart';

class ContractListPage extends StatelessWidget {
  const ContractListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ContractListBloc(
        repository: ContractListRepository(),
      )..add(LoadContracts()),
      child: const ContractListView(),
    );
  }
}

class ContractListView extends StatelessWidget {
  const ContractListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: BlocBuilder<ContractListBloc, ContractListState>(
          builder: (context, state) {
            if (state.status == ContractListStatus.initial ||
                state.status == ContractListStatus.loading) {
              return Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            }

            if (state.status == ContractListStatus.error) {
              return Center(child: Text(state.errorMessage ?? 'Đã có lỗi xảy ra'));
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                _buildStatusChips(context, state.selectedFilter),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      context.read<ContractListBloc>().add(LoadContracts());
                    },
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.pageMargin,
                        vertical: 16,
                      ),
                      children: _buildContractListSections(context, state),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildContractListSections(BuildContext context, ContractListState state) {
    final widgets = <Widget>[];
    
    final requiresAction = state.filteredContracts.where((c) => c.originalStatus == 'CHO_KY' || c.originalStatus == 'DA_KY').toList();
    final others = state.filteredContracts.where((c) => c.originalStatus != 'CHO_KY' && c.originalStatus != 'DA_KY').toList();

    if (requiresAction.isNotEmpty && (state.selectedFilter == ContractStatus.all || state.selectedFilter == ContractStatus.pending)) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppText(
            'Cần hoàn tất',
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
      for (var contract in requiresAction) {
        widgets.add(_buildContractCard(context, contract));
        widgets.add(const SizedBox(height: 16));
      }
      
      if (others.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 8),
            child: AppText(
              'Danh sách hợp đồng',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );
      }
    }

    for (var contract in others) {
      widgets.add(_buildContractCard(context, contract));
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.pageMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.92)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Image.asset('assets/images/logo.png', height: 24),
                  ),
                  const SizedBox(width: 8),
                  AppText(
                    'Hợp đồng',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ),
              const UserAvatar(
                displayName: 'U',
                radius: 16,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Hợp đồng',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(height: 4),
                  AppText(
                    'Theo dõi các hợp đồng thuê của bạn',
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.help_outline,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChips(BuildContext context, ContractStatus selectedFilter) {
    final Map<ContractStatus, String> statuses = {
      ContractStatus.all: 'Tất cả',
      ContractStatus.active: 'Đang thuê',
      ContractStatus.pending: 'Chờ bàn giao',
      ContractStatus.completed: 'Hoàn tất',
      ContractStatus.cancelled: 'Đã hủy',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pageMargin),
      child: Row(
        children: statuses.entries.map((entry) {
          final isSelected = selectedFilter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: AppText(
                entry.value,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              selected: isSelected,
              onSelected: (_) {
                context.read<ContractListBloc>().add(ChangeContractStatusFilter(entry.key));
              },
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              selectedColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContractCard(BuildContext context, ContractSummaryModel contract) {
    final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final dateFormatter = DateFormat('dd/MM/yyyy');

    Color badgeColor;
    String badgeText;

    switch (contract.status) {
      case ContractStatus.active:
        badgeColor = Colors.green;
        badgeText = 'Đang thuê';
        break;
      case ContractStatus.pending:
        badgeColor = Colors.orange;
        badgeText = 'Chờ bàn giao';
        if (contract.originalStatus == 'CHO_KY') {
          badgeText = 'Chờ ký';
        } else if (contract.originalStatus == 'DA_KY') {
          badgeText = 'Chờ thanh toán';
        }
        break;
      case ContractStatus.completed:
        badgeColor = Colors.blue;
        badgeText = 'Hoàn tất';
        break;
      case ContractStatus.cancelled:
        badgeColor = Colors.red;
        badgeText = 'Đã hủy';
        break;
      default:
        badgeColor = Colors.grey;
        badgeText = '';
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: ID and Badge
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: contract.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã sao chép mã hợp đồng')),
                      );
                    },
                    child: Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: AppText(
                            contract.id,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.copy,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AppText(
                    badgeText,
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Body: Image and details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Center(
                    child: AppImage(
                      imageUrl: contract.imagePath,
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                      iconSize: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        contract.deviceName,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      AppText(
                        contract.packageInfo,
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          AppText(
                            '${dateFormatter.format(contract.pickupDate)} - ${dateFormatter.format(contract.returnDate)}',
                            fontSize: 13,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: AppText(
                              contract.branchName,
                              fontSize: 13,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Alert message (if any)
          if (contract.statusAlertMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: badgeColor.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: badgeColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppText(
                      contract.statusAlertMessage ?? (contract.originalStatus == 'DA_KY' ? 'Vui lòng thanh toán để hoàn tất hợp đồng.' : 'Theo dõi tình trạng hợp đồng của bạn.'),
                      color: badgeColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          // Footer: Total amount and actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Tổng chi phí thuê',
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    AppText(
                      currencyFormatter.format(contract.totalAmount),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
                Row(
                  children: _buildActionButtons(context, contract),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context, ContractSummaryModel contract) {
    if (contract.status == ContractStatus.active) {
      return [
        OutlinedButton(
          onPressed: () async {
            await context.push('/contract/${contract.id}', extra: {'action': 'renewal'});
            if (context.mounted) {
              context.read<ContractListBloc>().add(LoadContracts());
            }
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: AppText(
            'Gia hạn',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () async {
            await context.push('/contract/${contract.id}');
            if (context.mounted) {
              context.read<ContractListBloc>().add(LoadContracts());
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const AppText(
            'Theo dõi',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ];
    } else if (contract.status == ContractStatus.pending) {
      if (contract.originalStatus == 'CHO_KY' || contract.originalStatus == 'DA_KY') {
        return [
          ElevatedButton(
            onPressed: () async {
              await context.push('/contract/${contract.id}');
              if (context.mounted) {
                context.read<ContractListBloc>().add(LoadContracts());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: AppText(
              contract.originalStatus == 'CHO_KY' ? 'Tiếp tục ký' : 'Thanh toán',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ];
      }

      return [
        ElevatedButton(
          onPressed: () async {
            await context.push('/contract/${contract.id}');
            if (context.mounted) {
              context.read<ContractListBloc>().add(LoadContracts());
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const AppText(
            'Xem chi tiết',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ];
    } else if (contract.status == ContractStatus.completed || contract.status == ContractStatus.cancelled) {
      return [
        ElevatedButton(
          onPressed: () async {
            await context.push('/contract/${contract.id}');
            if (context.mounted) {
              context.read<ContractListBloc>().add(LoadContracts());
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: AppText(
            contract.status == ContractStatus.cancelled ? 'Xem chi tiết' : 'Xem lại',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ];
    }
    return [];
  }
}
