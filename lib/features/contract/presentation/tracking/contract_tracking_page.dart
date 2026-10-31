import 'package:flutter/material.dart';
import '../../../../core/widgets/snap_loading_view.dart';
import '../../../../core/widgets/retro_camera_loader.dart';
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
import 'widgets/contract_status_steps.dart';
import '../../data/repositories/contract_repository.dart';
import '../widgets/contract_handover_card.dart';

class ContractTrackingPage extends StatefulWidget {
  final ContractModel contract;
  final ContractRepository? repository;

  const ContractTrackingPage({
    super.key,
    required this.contract,
    this.repository,
  });

  @override
  State<ContractTrackingPage> createState() => _ContractTrackingPageState();
}

class _ContractTrackingPageState extends State<ContractTrackingPage>
    with WidgetsBindingObserver {
  late ContractTrackingCubit _cubit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createCubit();
  }

  void _createCubit() {
    _cubit = ContractTrackingCubit(
      widget.contract,
      repository: widget.repository,
    )..load();
  }

  @override
  void didUpdateWidget(covariant ContractTrackingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contract.contractId != widget.contract.contractId ||
        oldWidget.repository != widget.repository) {
      _cubit.close();
      _createCubit();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      _cubit.load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: _ContractTrackingView(repository: widget.repository),
  );
}

class _ContractTrackingView extends StatelessWidget {
  final ContractRepository? repository;
  const _ContractTrackingView({this.repository});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/?tab=contracts');
            }
          },
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
          if (!state.verified) {
            if (state.error != null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText(state.error!),
                    TextButton(
                      onPressed: context.read<ContractTrackingCubit>().load,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              );
            }
            return const SnapLoadingView(
              message: 'Đang tải trạng thái hợp đồng',
              size: RetroCameraLoader.large,
            );
          }
          return Column(
            children: [
              _buildStatusTabs(context, state.status),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: context.read<ContractTrackingCubit>().load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.error != null) ...[
                          AppText(
                            state.error!,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 12),
                        ],
                        ContractTrackingSummaryCard(
                          contract: state.contract,
                          status: state.status,
                        ),
                        const SizedBox(height: 16),
                        ContractHandoverCard(
                          contract: state.contract,
                          repository: repository,
                        ),
                        const SizedBox(height: 16),
                        CurrentContractStatusCard(viewData: viewData),
                        const SizedBox(height: 16),
                        ContractProgressTimeline(steps: viewData.timelineSteps),
                      ],
                    ),
                  ),
                ),
              ),
              if (viewData.bottomCtaLabel.isNotEmpty)
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ContractStatusSteps(
        status: currentStatus,
        includeOtherStatus: true,
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
          onPressed: () async {
            final state = context.read<ContractTrackingCubit>().state;
            if (state.status == ContractTrackingStatus.renting) {
              await context.push('/contract/renewal', extra: state.contract);
              if (context.mounted) {
                await context.read<ContractTrackingCubit>().load();
              }
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
