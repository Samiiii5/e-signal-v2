import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class PinKeypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onDelete;

  const PinKeypad({super.key, required this.onKey, required this.onDelete});

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: row.map((key) => _KeyCell(
              label: key,
              onTap: key.isEmpty
                  ? null
                  : key == '⌫'
                      ? (_) => onDelete()
                      : (k) => onKey(k),
            )).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _KeyCell extends StatelessWidget {
  final String label;
  final void Function(String)? onTap;

  const _KeyCell({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return const SizedBox(width: 88, height: 64);
    }

    final isDelete = label == '⌫';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null ? () => onTap!(label) : null,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.green.withValues(alpha: 0.12),
        highlightColor: AppColors.greenLight,
        child: Ink(
          width: 88,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.backgroundPage,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: isDelete
                ? const Icon(
                    Icons.backspace_outlined,
                    size: 22,
                    color: AppColors.textSecondary,
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
