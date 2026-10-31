import 'package:flutter/material.dart';
import '../../../contract/domain/models/handover_models.dart';

// Reuses the contract's assigned-device models and standard list tiles.
class ReviewDevicePicker extends StatelessWidget {
  final List<AssignedContractDevice> devices;
  final List<BookedContractDevice> models;
  final ValueChanged<String> onSelected;
  const ReviewDevicePicker({
    super.key,
    required this.devices,
    required this.models,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Chọn thiết bị để đánh giá'),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final device in devices)
                ListTile(
                  key: ValueKey(device.detailId),
                  title: Text(
                    models
                            .where((x) => x.modelId == device.modelId)
                            .map((x) => x.name)
                            .firstOrNull ??
                        device.modelId,
                  ),
                  subtitle: Text('Serial: ${device.serial ?? device.deviceId}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onSelected(device.detailId),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
