import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_text.dart';
import '../bloc/review_state.dart';
import '../data/repositories/mock_review_repository.dart';
import '../data/review_fixtures.dart';
import '../domain/models/review_detail_model.dart';
import '../domain/models/review_target_device.dart';
import 'review_page.dart';

enum PreviewScenario {
  state1Empty('1. Chưa nhập (Trống)'),
  state2Editing('2. Đang nhập (Đủ điều kiện)'),
  state3Submitting('3. Đang gửi (Loading)'),
  state4Failure('4. Gửi lỗi (Giữ dữ liệu)'),
  state5Pending('5. Đã ẩn (Chỉ đọc)'),
  state6Approved('6. Đã gửi (Công khai)'),
  edgeMultiDevice('7. HĐ nhiều máy (Ống kính)'),
  edgeLongName('8. Tên thiết bị dài'),
  edgeIncompleted('9. HĐ chưa xong (Vô hiệu)');

  final String label;
  const PreviewScenario(this.label);
}

class ReviewPreviewPage extends StatefulWidget {
  const ReviewPreviewPage({super.key});

  @override
  State<ReviewPreviewPage> createState() => _ReviewPreviewPageState();
}

class _ReviewPreviewPageState extends State<ReviewPreviewPage> {
  PreviewScenario _scenario = PreviewScenario.state1Empty;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Trang này chỉ khả dụng trong chế độ gỡ lỗi (Debug mode).',
          ),
        ),
      );
    }

    final colors = Theme.of(context).colorScheme;

    // Resolve scenario configuration
    late ReviewTargetDevice device;
    ReviewDetailModel? initialReview;
    ReviewViewMode viewMode = ReviewViewMode.inputForm;
    final mockRepo = MockReviewRepository();

    switch (_scenario) {
      case PreviewScenario.state1Empty:
        device = ReviewFixtures.defaultDevice;
        break;

      case PreviewScenario.state2Editing:
        device = ReviewFixtures.defaultDevice;
        initialReview = ReviewFixtures.pendingReview;
        break;

      case PreviewScenario.state3Submitting:
        device = ReviewFixtures.defaultDevice;
        mockRepo.simulatedDelay = const Duration(seconds: 15);
        break;

      case PreviewScenario.state4Failure:
        device = ReviewFixtures.defaultDevice;
        mockRepo.shouldFailSubmission = true;
        mockRepo.failureErrorMessage =
            'Mất kết nối máy chủ khi gửi đánh giá. Vui lòng kiểm tra lại mạng.';
        break;

      case PreviewScenario.state5Pending:
        device = ReviewFixtures.defaultDevice;
        initialReview = ReviewFixtures.pendingReview;
        viewMode = ReviewViewMode.hidden;
        break;

      case PreviewScenario.state6Approved:
        device = ReviewFixtures.approvedDevice;
        initialReview = ReviewFixtures.approvedReview;
        viewMode = ReviewViewMode.published;
        break;

      case PreviewScenario.edgeMultiDevice:
        device = ReviewFixtures.multiDeviceItem;
        break;

      case PreviewScenario.edgeLongName:
        device = ReviewFixtures.longNameDevice;
        break;

      case PreviewScenario.edgeIncompleted:
        device = ReviewFixtures.incompletedContractDevice;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        leading: IconButton(
          tooltip: 'Đóng Preview',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Preview Đánh giá thiết bị',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            AppText(
              'Debug UI & Fixture Inspector',
              fontSize: 11,
              color: Color(0xFF1D39C4),
              fontWeight: FontWeight.w500,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Scenario selector horizontal bar
          Container(
            color: colors.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    PreviewScenario.values.map((sc) {
                      final isSelected = sc == _scenario;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(sc.label),
                          selected: isSelected,
                          selectedColor: const Color(0xFF1D39C4),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                            color: isSelected ? Colors.white : colors.onSurface,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _scenario = sc);
                            }
                          },
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
          // Embedded Review Page with Key to reload upon scenario change
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(_scenario),
              child: ReviewPage(
                device: device,
                initialReview: initialReview,
                initialViewMode: viewMode,
                repository: mockRepo,
                isPreview: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
