import 'package:flutter/material.dart';

Future<int?> showDayOfMonthPicker(
  BuildContext context, {
  required String title,
  int? initialDay,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: const Color(0xFF141B24),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF232C38),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text('Select day of month', style: TextStyle(color: Color(0xFF9CA3AF))),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.1,
                children: [
                  for (var day = 1; day <= 31; day++)
                    _DayChip(
                      day: day,
                      selected: day == initialDay,
                      onTap: () => Navigator.pop(sheetContext, day),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DayChip extends StatelessWidget {
  final int day;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({required this.day, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2DD4A7) : const Color(0xFF1B2430),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$day',
          style: TextStyle(
            color: selected ? const Color(0xFF0B0F14) : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
