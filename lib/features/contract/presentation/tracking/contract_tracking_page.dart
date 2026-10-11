import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../contract/services/contract_pdf_service.dart';
import 'bloc/contract_tracking_cubit.dart';
import 'bloc/contract_tracking_state.dart';
import 'models/contract_tracking_status.dart';
import 'widgets/contract_tracking_summary_card.dart';
import 'widgets/current_contract_status_card.dart';
import 'widgets/contract_progress_timeline.dart';
import 'widgets/pickup_location_card.dart';
import 'widgets/payment_deposit_card.dart';
import 'widgets/legal_verification_card.dart';
import 'widgets/important_notice_card.dart';

class ContractTrackingPage extends StatelessWidget {
  final ContractModel contract;

  const ContractTrackingPage({super.key, required this.contract});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ContractTrackingCubit(contract),
      child: const _ContractTrackingView(),
    );
  }
}

class _ContractTrackingView extends StatelessWidget {
  const _ContractTrackingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const AppText(
          'Theo dõi trạng thái',
          fontWeight: FontWeight.bold,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              radius: 16,
              child: Icon(
                Icons.person,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: BlocBuilder<ContractTrackingCubit, ContractTrackingState>(
        builder: (context, state) {
          final viewData = state.viewData;
          return Column(
            children: [
              _buildStatusTabs(context, state.status),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ContractTrackingSummaryCard(
                        contract: state.contract,
                        status: state.status,
                      ),
                      const SizedBox(height: 16),
                      CurrentContractStatusCard(viewData: viewData),
                      const SizedBox(height: 16),
                      ContractProgressTimeline(steps: viewData.timelineSteps),
                      if (viewData.showPickupSection) ...[
                        const SizedBox(height: 16),
                        const PickupLocationCard(),
                      ],
                      if (viewData.showPaymentSection) ...[
                        const SizedBox(height: 16),
                        const PaymentDepositCard(),
                      ],
                      if (viewData.showLegalSection) ...[
                        const SizedBox(height: 16),
                        const LegalVerificationCard(),
                      ],
                      if (viewData.showNoticeSection) ...[
                        const SizedBox(height: 16),
                        const ImportantNoticeCard(),
                      ],
                    ],
                  ),
                ),
              ),
              _buildBottomAction(context, viewData.bottomCtaLabel),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusTabs(
    BuildContext context,
    ContractTrackingStatus currentStatus,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children:
            ContractTrackingStatus.values.map((status) {
              final isActive = status == currentStatus;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: InkWell(
                  onTap: () {
                    context.read<ContractTrackingCubit>().changeStatus(status);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: AppText(
                      status.label,
                      color:
                          isActive
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: PrimaryButton(
          onPressed: () {
            final state = context.read<ContractTrackingCubit>().state;
            if (state.status == ContractTrackingStatus.renting) {
              context.push('/contract/renewal', extra: state.contract);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chức năng: (đang phát triển)')),
              );
            }
          },
          text: label,
        ),
      ),
    );
  }
}
