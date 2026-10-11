import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'app_text.dart';
import 'primary_button.dart';
import '../../features/device_detail/data/device_detail_repository.dart';

class AppAvailabilityCalendar extends StatefulWidget {
  final DateTime? currentPickup;
  final DateTime? currentReturn;
  final String? branchId;
  final String deviceId;
  final int quantity;
  final String? reservationId;

  const AppAvailabilityCalendar({
    super.key,
    this.currentPickup,
    this.currentReturn,
    required this.branchId,
    required this.deviceId,
    required this.quantity,
    this.reservationId,
  });

  static Future<Map<String, DateTime>?> show(
    BuildContext context, {
    DateTime? currentPickup,
    DateTime? currentReturn,
    required String? branchId,
    required String deviceId,
    required int quantity,
    String? reservationId,
  }) {
    return showModalBottomSheet<Map<String, DateTime>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => AppAvailabilityCalendar(
        currentPickup: currentPickup,
        currentReturn: currentReturn,
        branchId: branchId,
        deviceId: deviceId,
        quantity: quantity,
        reservationId: reservationId,
      ),
    );
  }

  @override
  State<AppAvailabilityCalendar> createState() => _AppAvailabilityCalendarState();
}

class _AppAvailabilityCalendarState extends State<AppAvailabilityCalendar> {
  late DateTime _focusedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  
  final DeviceDetailRepository _repository = DeviceDetailRepository();
  bool _isLoading = false;
  String? _error;
  
  final Map<DateTime, String> _availabilityCache = {};
  final Set<String> _loadedMonths = {};
  final Set<String> _fetchingKeys = {};
  int? _currentMonth;
  int? _currentYear;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.currentPickup ?? DateTime.now();
    _rangeStart = widget.currentPickup;
    _rangeEnd = widget.currentReturn;
    _fetchMonthData(_focusedDay);
  }

  String _getCacheKey(int year, int month) {
    return '${widget.branchId}_${widget.deviceId}_${widget.quantity}_${widget.reservationId}_$year-$month';
  }

  Future<void> _fetchMonthData(DateTime date, {bool isFocused = true}) async {
    if (widget.branchId == null) return;
    
    final targetMonth = date.month;
    final targetYear = date.year;
    final cacheKey = _getCacheKey(targetYear, targetMonth);

    if (isFocused) {
      if (_currentMonth == targetMonth && _currentYear == targetYear && _error == null) {
        // If it's already loading/loaded for the current focused month, do nothing
      } else {
        setState(() {
          _isLoading = !_loadedMonths.contains(cacheKey);
          _error = null;
          _currentMonth = targetMonth;
          _currentYear = targetYear;
        });
      }
    }

    if (_loadedMonths.contains(cacheKey) || _fetchingKeys.contains(cacheKey)) {
      if (isFocused && _loadedMonths.contains(cacheKey)) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    _fetchingKeys.add(cacheKey);

    try {
      final list = await _repository.getMonthlyAvailability(
        maCuaHang: widget.branchId!,
        maDongMay: widget.deviceId,
        soLuong: widget.quantity,
        thang: targetMonth,
        nam: targetYear,
        maGiuCho: widget.reservationId,
      );

      if (!mounted) return;

      setState(() {
        if (isFocused && _currentMonth == targetMonth && _currentYear == targetYear) {
          _isLoading = false;
        }
        _loadedMonths.add(cacheKey);
        for (var item in list) {
          final d = DateTime.parse(item['ngay'] as String);
          final status = item['trangThai'] as String;
          _availabilityCache[DateTime(d.year, d.month, d.day)] = status;
        }
      });
    } catch (e) {
      if (!mounted) return;
      if (isFocused && _currentMonth == targetMonth && _currentYear == targetYear) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      _fetchingKeys.remove(cacheKey);
    }
  }

  void _fetchMissingMonthsForRange(DateTime start, DateTime end) {
    DateTime current = DateTime(start.year, start.month, 1);
    final endMonth = DateTime(end.year, end.month, 1);
    while (!current.isAfter(endMonth)) {
      final cacheKey = _getCacheKey(current.year, current.month);
      if (!_loadedMonths.contains(cacheKey) && !_fetchingKeys.contains(cacheKey)) {
        _fetchMonthData(current, isFocused: false);
      }
      current = DateTime(current.year, current.month + 1, 1);
    }
  }



  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_focusedDay, focusedDay)) {
      setState(() {
        _focusedDay = focusedDay;
      });
    }
    
    final normalizedSelected = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    if (_isDayDisabled(normalizedSelected)) return;

    setState(() {
      if (_rangeStart == null) {
        _rangeStart = normalizedSelected;
        _rangeEnd = null;
      } else if (_rangeEnd == null) {
        if (normalizedSelected.isBefore(_rangeStart!)) {
          _rangeStart = normalizedSelected;
        } else {
          _rangeEnd = normalizedSelected;
          _fetchMissingMonthsForRange(_rangeStart!, _rangeEnd!);
        }
      } else {
        _rangeStart = normalizedSelected;
        _rangeEnd = null;
      }
    });
  }

  bool _isDayDisabled(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    if (normalized.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))) {
      return true;
    }
    if (_isLoading || _error != null) return true;
    if (!_availabilityCache.containsKey(normalized)) return true;
    
    // Do not disable 'DO' days, because the user might pick a valid hour 
    // that does not overlap with the occupied time slot.
    return false;
  }
  
  bool _isRangeValid() {
    if (_rangeStart == null || _rangeEnd == null) return false;
    if (_isLoading || _error != null) return false;
    
    // Check all days from start to end inclusive
    for (DateTime d = _rangeStart!; !d.isAfter(_rangeEnd!); d = d.add(const Duration(days: 1))) {
      final normalized = DateTime(d.year, d.month, d.day);
      if (!_availabilityCache.containsKey(normalized)) {
        return false;
      }
      
      bool isStart = isSameDay(normalized, _rangeStart);
      bool isEnd = isSameDay(normalized, _rangeEnd);
      
      // Only veto the range if a day STRICTLY BETWEEN start and end is 'DO'.
      // Days at the boundaries might only be partially occupied in hours.
      if (!isStart && !isEnd) {
        if (_availabilityCache[normalized] == 'DO') {
          return false;
        }
      }
    }
    return true;
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
                'Chọn thời gian thuê',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          if (widget.branchId == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: AppText(
                  'Vui lòng chọn chi nhánh để xem lịch khả dụng.',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AppText(
                        _error!,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _fetchMonthData(_focusedDay),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            
            Stack(
              children: [
                TableCalendar(
                  locale: 'vi_VN',
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Month',
                  },
                  calendarStyle: const CalendarStyle(
                    outsideDaysVisible: false,
                  ),
                  firstDay: DateTime.now(),
                  lastDay: DateTime.now().add(const Duration(days: 180)),
                  focusedDay: _focusedDay,
                  rangeStartDay: _rangeStart,
                  rangeEndDay: _rangeEnd,
                  rangeSelectionMode: RangeSelectionMode.toggledOn,
                  onDaySelected: _onDaySelected,
                  onRangeSelected: (start, end, focusedDay) {
                    setState(() {
                      if (start != null && _isDayDisabled(start)) return;
                      _rangeStart = start;
                      _rangeEnd = end;
                      _focusedDay = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                    _fetchMonthData(focusedDay);
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      final normalized = DateTime(day.year, day.month, day.day);
                      final status = _availabilityCache[normalized];
                      
                      if (status == 'VANG') {
                        return Positioned(
                          bottom: 4,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.amber,
                            ),
                          ),
                        );
                      } else if (status == 'DO') {
                        return Positioned(
                          bottom: 4,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    defaultBuilder: (context, day, focusedDay) {
                      final normalized = DateTime(day.year, day.month, day.day);
                      if (_isDayDisabled(normalized)) {
                        return Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                ),
                if (_isLoading)
                  Positioned.fill(
                    child: Container(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.amber)),
                      const SizedBox(width: 8),
                      const AppText('Có lịch thuê, vẫn còn máy', fontSize: 12),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red)),
                      const SizedBox(width: 8),
                      const AppText('Không đủ máy cho ngày thuê', fontSize: 12),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const AppText(
                    '* Lịch tham khảo. Vui lòng chọn khoảng ngày để kiểm tra chính xác.',
                    fontSize: 12,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            if (_rangeStart != null && _rangeEnd != null && !_isRangeValid())
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppText(
                        'Khoảng thời gian đã chọn có ngày không đủ máy. Vui lòng điều chỉnh.',
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
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
                    onPressed: (_rangeStart != null && _rangeEnd != null && _isRangeValid())
                        ? () {
                            Navigator.of(context).pop({
                              'pickup': _rangeStart!,
                              'return': _rangeEnd!,
                            });
                          }
                        : null, // Disabled if range is invalid or incomplete
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
