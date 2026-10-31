import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_text.dart';
import '../data/notification_detail_fixtures.dart';
import '../data/repositories/notification_repository.dart';
import '../../contract/data/repositories/contract_repository.dart';
import 'notification_detail_page.dart';

class NotificationPreviewPage extends StatefulWidget {
  const NotificationPreviewPage({super.key});

  @override
  State<NotificationPreviewPage> createState() => _NotificationPreviewPageState();
}

class _NotificationPreviewPageState extends State<NotificationPreviewPage> {
  int _selectedIndex = 0;
  final List<NotificationDetailDemoFixture> _fixtures =
      NotificationDetailFixtures.allFixtures;

  @override
  Widget build(BuildContext context) {
    // Security check: Block preview in release mode
    if (kReleaseMode) {
      return const Scaffold(
        body: Center(
          child: Text('Trang này không khả dụng trên môi trường Release.'),
        ),
      );
    }

    final activeFixture = _fixtures[_selectedIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Chi tiết thông báo'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            height: 56,
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _fixtures.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = index == _selectedIndex;
                final fixture = _fixtures[index];
                return ChoiceChip(
                  label: AppText(
                    fixture.label,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  selected: isSelected,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    }
                  },
                );
              },
            ),
          ),
        ),
      ),
      body: KeyedSubtree(
        key: ValueKey(activeFixture.key),
        child: NotificationDetailPage(
          notificationId: activeFixture.notification.id,
          initialItem: activeFixture.notification,
          // Explicit isolated mock repositories to guarantee NO real API calls
          notificationRepository: MockNotificationRepository(),
          contractRepository: ContractRepository(),
          isDemo: true,
          demoContract: activeFixture.contract,
          demoVariant: activeFixture.variantCode,
          demoMetadata: activeFixture.metadata,
        ),
      ),
    );
  }
}
