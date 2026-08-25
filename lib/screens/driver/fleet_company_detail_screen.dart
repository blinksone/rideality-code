import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/api_models.dart';
import '../../services/fleet_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';

class FleetCompanySelectionResult {
  const FleetCompanySelectionResult({
    required this.company,
    required this.joinNow,
  });

  final FleetCompanyOption company;
  final bool joinNow;
}

class FleetCompanyDetailScreen extends StatefulWidget {
  const FleetCompanyDetailScreen({
    super.key,
    required this.cityId,
    required this.companyId,
    required this.joinEnabled,
  });

  final String cityId;
  final String companyId;
  final bool joinEnabled;

  @override
  State<FleetCompanyDetailScreen> createState() =>
      _FleetCompanyDetailScreenState();
}

class _FleetCompanyDetailScreenState extends State<FleetCompanyDetailScreen> {
  bool _loading = true;
  String? _error;
  FleetCompanyOption? _company;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await FleetApiService.instance.getCompanyPublic(
        companyId: widget.companyId,
        cityId: widget.cityId,
      );
      if (!mounted) return;
      setState(() {
        _company = c;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load company details.';
        _loading = false;
      });
    }
  }

  Future<void> _openUri(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  Future<void> _call(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return;
    await _openUri(Uri(scheme: 'tel', path: digits));
  }

  Future<void> _whatsapp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    await _openUri(Uri.parse('https://wa.me/$digits'));
  }

  Future<void> _email(String email) async {
    await _openUri(Uri(scheme: 'mailto', path: email));
  }

  Widget _stars(double? avg) {
    final v = (avg ?? 0).clamp(0, 5);
    final rounded = v.round();
    return Row(
      children: List.generate(5, (i) {
        final filled = i < rounded;
        return Icon(
          filled ? Icons.star : Icons.star_border_rounded,
          size: 18,
          color: filled ? AppColors.success : AppColors.onSurfaceVariant,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final company = _company;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
        ),
        title: const Text('Company details'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: tt.bodyMedium?.copyWith(color: AppColors.error),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : company == null
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          Expanded(
                            child: ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _Logo(url: company.resolvedLogoUrl),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            company.legalName,
                                            style: tt.headlineSmall,
                                          ),
                                          const SizedBox(height: 8),
                                          _stars(company.ratingAvg),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${(company.ratingAvg ?? 0).toStringAsFixed(1)} • ${company.ratingCount ?? 0} ratings',
                                            style: tt.bodyMedium,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${company.driverCount ?? 0} drivers',
                                            style: tt.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                if (company.phone != null &&
                                    company.phone!.trim().isNotEmpty) ...[
                                  _InfoLine(
                                    icon: Icons.phone_rounded,
                                    label: 'Phone',
                                    value: company.phone!,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _call(company.phone!),
                                          icon: const Icon(Icons.call_rounded),
                                          label: const Text('Call'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _whatsapp(company.phone!),
                                          icon: const Icon(Icons.chat_rounded),
                                          label: const Text('WhatsApp'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                if (company.email != null &&
                                    company.email!.trim().isNotEmpty) ...[
                                  _InfoLine(
                                    icon: Icons.mail_outline_rounded,
                                    label: 'Email',
                                    value: company.email!,
                                    onTap: () => _email(company.email!),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                _InfoLine(
                                  icon: Icons.location_on_rounded,
                                  label: 'Address',
                                  value: company.address?.isNotEmpty == true
                                      ? company.address!
                                      : '—',
                                ),
                                const SizedBox(height: 18),
                                Text('Reviews', style: tt.titleMedium),
                                const SizedBox(height: 8),
                                if (company.reviews.isEmpty)
                                  Text(
                                    'No reviews yet.',
                                    style: tt.bodyMedium?.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  )
                                else
                                  ...company.reviews.map((r) {
                                    final created = r.createdAt == null
                                        ? ''
                                        : r.createdAt!
                                            .toLocal()
                                            .toString()
                                            .split('.')
                                            .first;
                                    return _ReviewCard(
                                      score: r.score,
                                      comment: r.comment,
                                      reviewerName: r.reviewerName,
                                      createdAt: created,
                                    );
                                  }),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppButton(
                                  label: 'Select company',
                                  icon: Icons.check_circle_rounded,
                                  isLoading: false,
                                  variant: AppButtonVariant.secondary,
                                  onPressed: () {
                                    Navigator.of(context).pop(
                                      FleetCompanySelectionResult(
                                        company: company,
                                        joinNow: false,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                AppButton(
                                  label: 'Join as driver',
                                  icon: Icons.arrow_forward_rounded,
                                  isLoading: false,
                                  onPressed: widget.joinEnabled
                                      ? () {
                                          Navigator.of(context).pop(
                                            FleetCompanySelectionResult(
                                              company: company,
                                              joinNow: true,
                                            ),
                                          );
                                        }
                                      : null,
                                ),
                                if (!widget.joinEnabled)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Complete your name and date of birth to join.',
                                      style: tt.bodySmall?.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
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

class _Logo extends StatelessWidget {
  const _Logo({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 72,
        height: 72,
        color: AppColors.secondary.withValues(alpha: 0.1),
        child: url == null
            ? const Icon(
                Icons.apartment_rounded,
                color: AppColors.secondary,
                size: 36,
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.apartment_rounded,
                  color: AppColors.secondary,
                  size: 36,
                ),
              ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: onTap != null ? AppColors.secondary : null,
                      decoration:
                          onTap != null ? TextDecoration.underline : null,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
    if (onTap == null) return child;
    return InkWell(onTap: onTap, child: child);
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.score,
    required this.comment,
    required this.reviewerName,
    required this.createdAt,
  });

  final int score;
  final String comment;
  final String reviewerName;
  final String createdAt;

  @override
  Widget build(BuildContext context) {
    final rounded = score.clamp(0, 5);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = i < rounded;
                  return Icon(
                    filled ? Icons.star : Icons.star_border_rounded,
                    size: 16,
                    color: filled
                        ? AppColors.success
                        : AppColors.onSurfaceVariant,
                  );
                }),
              ),
              const Spacer(),
              Text(
                reviewerName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(comment, style: Theme.of(context).textTheme.bodyMedium),
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              createdAt,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
