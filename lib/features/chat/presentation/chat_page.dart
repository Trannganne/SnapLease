import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/snap_loading_view.dart';
import '../../home/presentation/widgets/product_card.dart';
import '../data/chat_history_store.dart';
import '../data/dio_chat_repository.dart';
import '../domain/chat_repository.dart';
import '../domain/chat_models.dart';
import 'chat_cubit.dart';
import 'chat_availability_sheet.dart';

class ChatPage extends StatelessWidget {
  final ChatRepository? repository;
  final ChatHistoryStore? history;
  const ChatPage({super.key, this.repository, this.history});
  @override
  Widget build(BuildContext context) {
    final repo = repository ?? DioChatRepository();
    return BlocProvider(
      create:
          (_) => ChatCubit(
            repository: repo,
            history: history ?? ChatHistoryStore.instance,
          )..load(),
      child: _ChatView(repository: repo),
    );
  }
}

class _ChatView extends StatefulWidget {
  final ChatRepository repository;
  const _ChatView({required this.repository});
  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final cubit = context.read<ChatCubit>();
    final text = _input.text.trim();
    if (text.isEmpty || cubit.state.sending || !cubit.state.enabled) return;
    _input.clear();
    cubit.send(text);
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<ChatCubit, ChatState>(
    listener: (context, state) {
      if (state.messages.isEmpty && !state.enabled) _input.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    },
    builder: (context, state) {
      final cubit = context.read<ChatCubit>();
      final colors = Theme.of(context).colorScheme;
      return Scaffold(
        appBar: AppBar(
          title: const AppText('Trợ lý SNAPLEASE', fontWeight: FontWeight.bold),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/?tab=4');
              }
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Xóa lịch sử',
              icon: const Icon(Icons.delete_outline),
              onPressed:
                  state.loading
                      ? null
                      : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder:
                              (dialog) => AlertDialog(
                                title: const Text('Xóa lịch sử?'),
                                content: const Text(
                                  'Xóa toàn bộ hội thoại local của tài khoản này. Thao tác không thể hoàn tác.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(dialog).pop(false),
                                    child: const Text('Hủy'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(dialog).pop(true),
                                    child: const Text('Xóa lịch sử'),
                                  ),
                                ],
                              ),
                        );
                        if (confirmed == true && context.mounted) {
                          await cubit.clearHistory();
                        }
                      },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child:
                    state.loading && state.messages.isEmpty
                        ? const SnapLoadingView(message: 'Đang mở hội thoại')
                        : ListView(
                          controller: _scroll,
                          padding: const EdgeInsets.all(AppSizes.pageMargin),
                          children: [
                            AppText(
                              'Lịch sử lưu trên máy tối đa 30 ngày, xóa khi đăng xuất. Không nhập giấy tờ, OTP hoặc thông tin đăng nhập. Giá/lịch trống cũ cần kiểm tra lại.',
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(height: AppSizes.spacingS),
                            if (state.error != null) ...[
                              AppText(
                                state.error!,
                                color: colors.error,
                                fontSize: 12,
                              ),
                              if (!state.enabled && !state.loading)
                                TextButton(
                                  onPressed: cubit.load,
                                  child: const Text('Tải lại trợ lý'),
                                ),
                            ],
                            if (state.messages.isEmpty) ...[
                              const AppText(
                                'Bạn cần hỗ trợ gì?',
                                fontWeight: FontWeight.bold,
                              ),
                              const SizedBox(height: AppSizes.spacingS),
                              Wrap(
                                spacing: AppSizes.spacingS,
                                runSpacing: AppSizes.spacingS,
                                children: [
                                  for (final question in [
                                    'Thuê máy như thế nào?',
                                    'Tôi muốn chụp chân dung, ngân sách 500k/ngày',
                                    'Gia hạn như thế nào?',
                                  ])
                                    ActionChip(
                                      label: Text(question),
                                      onPressed:
                                          state.enabled && !state.sending
                                              ? () {
                                                _input.text = question;
                                              }
                                              : null,
                                    ),
                                ],
                              ),
                            ],
                            for (final message in state.messages)
                              _bubble(context, message),
                            if (state.sending)
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: SnapButtonLoader(),
                              ),
                          ],
                        ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSizes.pageMargin),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTextField(
                      label: 'Tin nhắn',
                      hintText: 'Mô tả nhu cầu hoặc câu hỏi của bạn',
                      controller: _input,
                    ),
                    const SizedBox(height: AppSizes.spacingS),
                    PrimaryButton(
                      text: 'Gửi',
                      isLoading: state.sending,
                      onPressed:
                          state.enabled && !state.loading && !state.sending
                              ? _send
                              : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  Widget _bubble(BuildContext context, ChatMessage message) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingM),
      child: Column(
        crossAxisAlignment:
            message.role == 'user'
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.pageMargin),
            decoration: BoxDecoration(
              color:
                  message.role == 'user'
                      ? colors.primaryContainer
                      : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  message.role == 'user' ? 'Bạn' : 'Trợ lý SNAPLEASE',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: AppSizes.spacingS),
                SelectableText(message.text),
                const SizedBox(height: AppSizes.spacingS),
                AppText(
                  DateFormat('HH:mm dd/MM/yyyy').format(message.at.toLocal()),
                  fontSize: 11,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
          if (message.products.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spacingS),
            const AppText(
              'Giá niêm yết tại thời điểm tư vấn. Mở Chi tiết để xem giá/ưu đãi hiện hành; chưa xác nhận còn máy.',
              fontSize: 12,
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in message.products)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSizes.spacingS),
                      child: SizedBox(
                        width: 210,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 270,
                              child: ProductCard(
                                product: item.product,
                                showAvailability: false,
                                showAddAction: false,
                                showReviews: false,
                              ),
                            ),
                            if (item.reason != null)
                              AppText(item.reason!, fontSize: 12),
                            if (item.discount > 0)
                              AppText(
                                'Ưu đãi catalog lúc tư vấn: ${item.discount}%. Xem điều kiện/giá cuối ở Chi tiết.',
                                fontSize: 12,
                              ),
                            TextButton(
                              onPressed:
                                  () => showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    builder:
                                        (_) => ChatAvailabilitySheet(
                                          productId: item.id,
                                          repository: widget.repository,
                                        ),
                                  ),
                              child: const Text('Kiểm tra lịch trống'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (message.sources.isNotEmpty)
            AppText(
              'Nguồn: ${message.sources.join('; ')}',
              fontSize: 11,
              color: colors.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}
