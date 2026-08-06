import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../models/api_models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';

class DestinationSearchSheet extends StatefulWidget {
  const DestinationSearchSheet({
    super.key,
    required this.places,
    this.initialQuery,
    this.canBook = true,
  });

  final List<SavedPlace> places;
  final String? initialQuery;
  final bool canBook;

  @override
  State<DestinationSearchSheet> createState() => _DestinationSearchSheetState();
}

class _DestinationSearchSheetState extends State<DestinationSearchSheet> {
  late final TextEditingController _controller;
  String? _last;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    _loadLast();
  }

  Future<void> _loadLast() async {
    final last = await DashboardPrefs.instance.lastDestination;
    if (!mounted) return;
    setState(() => _last = last);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm([String? value]) {
    final dest = (value ?? _controller.text).trim();
    if (dest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a destination')),
      );
      return;
    }
    if (!widget.canBook) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete your profile to book rides'),
        ),
      );
    }
    Navigator.of(context).pop(dest);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final query = _controller.text.trim().toLowerCase();
    final filtered = widget.places.where((p) {
      if (query.isEmpty) return true;
      return p.label.toLowerCase().contains(query) ||
          p.address.toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Where to?',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: _confirm,
                    decoration: InputDecoration(
                      hintText: 'Search destination',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.secondary,
                      ),
                      suffixIcon: _controller.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _controller.clear();
                                setState(() {});
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  if (_last != null && _last!.isNotEmpty)
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.surfaceContainer,
                        child: Icon(Icons.history_rounded,
                            color: AppColors.onSurfaceVariant),
                      ),
                      title: Text(_last!),
                      subtitle: const Text('Recent'),
                      onTap: () {
                        _controller.text = _last!;
                        _confirm(_last);
                      },
                    ),
                  if (filtered.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Text(
                        'Saved places',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    ...filtered.map(
                      (p) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.secondary.withValues(alpha: 0.1),
                          child: Icon(
                            p.isHome
                                ? Icons.home_rounded
                                : p.isWork
                                    ? Icons.work_rounded
                                    : Icons.place_rounded,
                            color: AppColors.secondary,
                          ),
                        ),
                        title: Text(
                          p.label,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(p.address),
                        onTap: () => _confirm(p.address),
                      ),
                    ),
                  ] else if (widget.places.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No saved places yet. Type any destination below.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: AppButton(
                label: 'Find rides',
                icon: Icons.directions_car_rounded,
                borderRadius: 14,
                onPressed: _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
