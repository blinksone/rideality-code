import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../services/fleet_api_service.dart';
import '../../theme/app_colors.dart';
import 'fleet_company_detail_screen.dart';

class FleetCompaniesInCityScreen extends StatefulWidget {
  const FleetCompaniesInCityScreen({
    super.key,
    required this.cityId,
    this.cityLabel,
    required this.joinEnabled,
  });

  static const routeName = '/fleet-companies-in-city';

  final String cityId;
  final String? cityLabel;
  final bool joinEnabled;

  @override
  State<FleetCompaniesInCityScreen> createState() =>
      _FleetCompaniesInCityScreenState();
}

class _FleetCompaniesInCityScreenState
    extends State<FleetCompaniesInCityScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<FleetCompanyOption> _companies = const [];

  @override
  void initState() {
    super.initState();
    _fetchTop();
  }

  Future<void> _fetchTop() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final companies = await FleetApiService.instance.listCompanies(
        cityId: widget.cityId,
        search: null,
      );
      if (!mounted) return;
      setState(() {
        _companies = companies;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load companies.';
        _loading = false;
      });
    }
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final q = query.trim();
    try {
      final companies = await FleetApiService.instance.listCompanies(
        cityId: widget.cityId,
        search: q.isEmpty ? null : q,
      );
      if (!mounted) return;
      setState(() {
        _companies = companies;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load companies.';
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(v);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          widget.cityLabel == null ? 'Fleet companies' : widget.cityLabel!,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Search companies',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.trim().isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            _search('');
                          },
                        )
                      : null,
                ),
              ),
            ),
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.error),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _fetchTop,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_companies.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No fleet companies in this city',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _companies.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = _companies[i];
                    final avgText = (c.ratingAvg ?? 0).toStringAsFixed(1);
                    final logo = c.resolvedLogoUrl;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: _CompanyLogo(url: logo, size: 48),
                      title: Text(
                        c.legalName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              _RatingStars(avg: c.ratingAvg ?? 0),
                              const SizedBox(width: 8),
                              Text(
                                c.ratingCount != null
                                    ? '$avgText (${c.ratingCount})'
                                    : avgText,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${c.driverCount ?? 0} drivers',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        final result =
                            await navigator.push<FleetCompanySelectionResult>(
                          MaterialPageRoute(
                            builder: (_) => FleetCompanyDetailScreen(
                              cityId: widget.cityId,
                              companyId: c.id,
                              joinEnabled: widget.joinEnabled,
                            ),
                          ),
                        );
                        if (!mounted) return;
                        if (result != null) navigator.pop(result);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo({required this.url, this.size = 48});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: AppColors.secondary.withValues(alpha: 0.1),
        child: url == null
            ? Icon(
                Icons.apartment_rounded,
                color: AppColors.secondary,
                size: size * 0.45,
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.apartment_rounded,
                  color: AppColors.secondary,
                  size: size * 0.45,
                ),
              ),
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.avg});

  final double avg;

  @override
  Widget build(BuildContext context) {
    final rounded = avg.clamp(0, 5).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rounded;
        return Icon(
          filled ? Icons.star : Icons.star_border_rounded,
          size: 16,
          color: filled ? AppColors.success : AppColors.onSurfaceVariant,
        );
      }),
    );
  }
}
