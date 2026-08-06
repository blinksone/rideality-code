import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ProgressStepper extends StatelessWidget {
  const ProgressStepper({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.labels = const [],
  });

  final int currentStep; // 1-based
  final int totalSteps;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final pad = w / (totalSteps * 2);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: pad,
                    right: pad,
                    child: Container(
                      height: 2.5,
                      color: AppColors.outlineVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  Positioned(
                    left: pad,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      height: 2.5,
                      width: ((w - pad * 2) *
                              ((currentStep - 1).clamp(0, totalSteps - 1) /
                                  (totalSteps - 1).clamp(1, totalSteps)))
                          .clamp(0, w - pad * 2)
                          .toDouble(),
                      color: AppColors.secondary,
                    ),
                  ),
                  Row(
                    children: List.generate(totalSteps, (index) {
                      final step = index + 1;
                      return Expanded(
                        child: Center(
                          child: _StepNode(
                            step: step,
                            isCompleted: step < currentStep,
                            isActive: step == currentStep,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
        if (labels.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: List.generate(totalSteps, (index) {
              final step = index + 1;
              final label = index < labels.length ? labels[index] : '';
              final isActive = step == currentStep;
              final isCompleted = step < currentStep;
              return Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: isActive
                            ? AppColors.secondary
                            : isCompleted
                                ? AppColors.onSurfaceVariant
                                : AppColors.onSurfaceVariant.withValues(alpha: 0.45),
                      ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.step,
    required this.isCompleted,
    required this.isActive,
  });

  final int step;
  final bool isCompleted;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final size = isActive ? 34.0 : 30.0;
    final Color bg;
    final Color fg;

    if (isCompleted) {
      bg = AppColors.success;
      fg = Colors.white;
    } else if (isActive) {
      bg = AppColors.secondary;
      fg = Colors.white;
    } else {
      bg = AppColors.surfaceContainerHigh;
      fg = AppColors.onSurfaceVariant;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : Text(
                '$step',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
              ),
      ),
    );
  }
}
