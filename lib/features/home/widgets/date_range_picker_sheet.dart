import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

class DateRangePickerSheet extends StatefulWidget {
  const DateRangePickerSheet({
    required this.initialStart,
    required this.initialEnd,
    required this.minDate,
    required this.maxDate,
    super.key,
  });

  final DateTime initialStart;
  final DateTime initialEnd;
  final DateTime minDate;
  final DateTime maxDate;

  @override
  State<DateRangePickerSheet> createState() => _DateRangePickerSheetState();
}

class _DateRangePickerSheetState extends State<DateRangePickerSheet> {
  late PickerDateRange _selectedRange;

  @override
  void initState() {
    super.initState();
    _selectedRange = PickerDateRange(widget.initialStart, widget.initialEnd);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Choisir une plage de dates',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SfDateRangePicker(
                selectionMode: DateRangePickerSelectionMode.range,
                initialSelectedRange: PickerDateRange(widget.initialStart, widget.initialEnd),
                minDate: widget.minDate,
                maxDate: widget.maxDate,
                navigationDirection: DateRangePickerNavigationDirection.vertical,
                monthViewSettings: const DateRangePickerMonthViewSettings(firstDayOfWeek: 1),
                onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                  final value = args.value;
                  if (value is PickerDateRange) {
                    setState(() {
                      _selectedRange = value;
                    });
                  }
                },
                startRangeSelectionColor: colorScheme.primary,
                endRangeSelectionColor: colorScheme.primary,
                rangeSelectionColor: colorScheme.primary.withValues(alpha: 0.2),
                todayHighlightColor: colorScheme.primary,
                selectionColor: colorScheme.primary,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _selectedRange),
                      child: const Text('Appliquer'),
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
}

Future<DateTimeRange?> showDateRangePickerSheet(
  BuildContext context, {
  required DateTime initialStart,
  required DateTime initialEnd,
  required DateTime minDate,
  required DateTime maxDate,
}) {
  return showModalBottomSheet<PickerDateRange>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DateRangePickerSheet(
      initialStart: initialStart,
      initialEnd: initialEnd,
      minDate: minDate,
      maxDate: maxDate,
    ),
  ).then((selectedRange) {
    if (selectedRange == null) return null;

    final start = selectedRange.startDate;
    final end = selectedRange.endDate ?? selectedRange.startDate;
    if (start == null || end == null) return null;

    return DateTimeRange(start: start, end: end);
  });
}
