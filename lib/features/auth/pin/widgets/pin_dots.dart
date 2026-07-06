import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class PinDots extends StatelessWidget {
  final int filled;
  final int total;
  final bool hasError;
  const PinDots({
    super.key,
    required this.filled,
    this.total = 5,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isFilled = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? (hasError ? Colors.redAccent : AppColors.green)
                : Colors.transparent,
            border: Border.all(
              color: isFilled
                  ? (hasError ? Colors.redAccent : AppColors.green)
                  : AppColors.borderLight,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}
