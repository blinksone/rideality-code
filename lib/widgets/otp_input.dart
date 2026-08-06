import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
  });

  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  @override
  State<OtpInput> createState() => OtpInputState();
}

class OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

  String get code => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _nodes = List.generate(widget.length, (_) => FocusNode()..addListener(_onFocus));
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.removeListener(_onFocus);
      n.dispose();
    }
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _notify() {
    final value = code;
    widget.onChanged?.call(value);
    if (value.length == widget.length) {
      widget.onCompleted?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 8.0;
        final totalGap = gap * (widget.length - 1);
        final boxSize = ((constraints.maxWidth - totalGap) / widget.length)
            .clamp(40.0, 52.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (index) {
            final focused = _nodes[index].hasFocus;
            final filled = _controllers[index].text.isNotEmpty;
            return Padding(
              padding: EdgeInsets.only(right: index == widget.length - 1 ? 0 : gap),
              child: SizedBox(
                width: boxSize,
                height: boxSize + 4,
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _nodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                  cursorColor: AppColors.secondary,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(1),
                  ],
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: filled
                            ? AppColors.outline
                            : AppColors.outlineVariant,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: focused ? AppColors.secondary : AppColors.outlineVariant,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                    if (value.isNotEmpty && index < widget.length - 1) {
                      _nodes[index + 1].requestFocus();
                    }
                    if (value.isEmpty && index > 0) {
                      _nodes[index - 1].requestFocus();
                    }
                    _notify();
                  },
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
