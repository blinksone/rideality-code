import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../models/api_models.dart';
import '../../models/place_models.dart';
import '../../services/driver_location_tracker.dart';
import '../../services/places_api_service.dart';
import '../../theme/app_colors.dart';
import 'save_location_screen.dart';

/// Yango-style location search sheet — pickup or dropoff.
class PickupLocationScreen extends StatefulWidget {
  const PickupLocationScreen({
    super.key,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.savedPlaces = const [],
  });

  final String title;
  final double latitude;
  final double longitude;
  final List<SavedPlace> savedPlaces;

  static Future<SelectedLocation?> show(
    BuildContext context, {
    required String title,
    required double latitude,
    required double longitude,
    List<SavedPlace> savedPlaces = const [],
  }) {
    return showModalBottomSheet<SelectedLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PickupLocationScreen(
        title: title,
        latitude: latitude,
        longitude: longitude,
        savedPlaces: savedPlaces,
      ),
    );
  }

  @override
  State<PickupLocationScreen> createState() => _PickupLocationScreenState();
}

class _PickupLocationScreenState extends State<PickupLocationScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _api = PlacesApiService.instance;

  PlaceSuggestions? _suggestions;
  List<PlaceSearchHit> _searchHits = const [];
  String? _sessionToken;
  Timer? _debounce;
  bool _loadingSuggestions = true;
  bool _searching = false;
  bool _selecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
    _searchFocus.addListener(_onSearchFocus);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _newSessionToken() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int i) => bytes[i].toRadixString(16).padLeft(2, '0');
    return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
        '${hex(4)}${hex(5)}-'
        '${hex(6)}${hex(7)}-'
        '${hex(8)}${hex(9)}-'
        '${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
  }

  void _onSearchFocus() {
    if (_searchFocus.hasFocus && _sessionToken == null) {
      setState(() => _sessionToken = _newSessionToken());
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final q = _searchController.text.trim();
    if (q.length < 2) {
      setState(() {
        _searchHits = const [];
        _searching = false;
      });
      return;
    }
    _sessionToken ??= _newSessionToken();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_runSearch(q));
    });
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _loadingSuggestions = true;
      _error = null;
    });
    try {
      final data = await _api.getSuggestions(
        latitude: widget.latitude,
        longitude: widget.longitude,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = data;
        _loadingSuggestions = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSuggestions = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSuggestions = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    try {
      final hits = await _api.search(
        query: query,
        latitude: widget.latitude,
        longitude: widget.longitude,
        sessionToken: _sessionToken!,
      );
      if (!mounted) return;
      setState(() {
        _searchHits = hits;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    _sessionToken = null;
    setState(() => _searchHits = const []);
  }

  void _popWith(SelectedLocation location) {
    if (!mounted) return;
    Navigator.of(context).pop(location);
  }

  Future<void> _selectCurrent() async {
    if (_selecting) return;
    setState(() => _selecting = true);
    try {
      final pos = await DriverLocationTracker.instance.currentPosition();
      final lat = pos?.latitude ?? widget.latitude;
      final lng = pos?.longitude ?? widget.longitude;
      final loc = await _api.selectPlace(
        latitude: lat,
        longitude: lng,
        source: 'current',
      );
      if (!mounted) return;
      _popWith(loc);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _selecting = false);
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _selecting = false);
      _showError(e.toString());
    }
  }

  Future<void> _selectListItem(PlaceListItem item) async {
    if (_selecting) return;
    setState(() => _selecting = true);
    try {
      SelectedLocation loc;
      if (item.placeId != null && item.placeId!.isNotEmpty) {
        loc = await _api.selectPlace(placeId: item.placeId);
      } else if (item.googlePlaceId != null && item.googlePlaceId!.isNotEmpty) {
        loc = await _api.selectPlace(
          googlePlaceId: item.googlePlaceId,
          sessionToken: _sessionToken,
        );
      } else if (item.latitude != null && item.longitude != null) {
        loc = SelectedLocation(
          name: item.name,
          address: item.address,
          latitude: item.latitude!,
          longitude: item.longitude!,
          databaseId: item.placeId,
          googlePlaceId: item.googlePlaceId,
          type: item.type,
          distanceKm: item.distanceKm,
        );
      } else {
        throw ApiException('Missing place coordinates');
      }
      if (!mounted) return;
      _popWith(loc);
    } on ApiException catch (e) {
      // Local catalog rows already have coords — still return them if select fails.
      if (item.latitude != null && item.longitude != null && mounted) {
        _popWith(
          SelectedLocation(
            name: item.name,
            address: item.address,
            latitude: item.latitude!,
            longitude: item.longitude!,
            databaseId: item.placeId,
            googlePlaceId: item.googlePlaceId,
            type: item.type,
            distanceKm: item.distanceKm,
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _selecting = false);
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _selecting = false);
      _showError(e.toString());
    }
  }

  Future<void> _selectSearchHit(PlaceSearchHit hit) async {
    if (_selecting) return;
    setState(() => _selecting = true);
    try {
      SelectedLocation loc;
      if (hit.source == PlaceHitSource.google &&
          hit.googlePlaceId != null &&
          hit.googlePlaceId!.isNotEmpty) {
        loc = await _api.selectPlace(
          googlePlaceId: hit.googlePlaceId,
          sessionToken: _sessionToken,
        );
      } else if (hit.placeId != null && hit.placeId!.isNotEmpty) {
        loc = await _api.selectPlace(placeId: hit.placeId);
      } else {
        loc = await _api.selectPlace(
          googlePlaceId: hit.googlePlaceId,
          sessionToken: _sessionToken,
        );
      }
      if (!mounted) return;
      _sessionToken = null;
      _popWith(loc);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _selecting = false);
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _selecting = false);
      _showError(e.toString());
    }
  }

  Future<void> _selectSavedSlot(SavedLocationSlot slot) async {
    if (!slot.isFilled) {
      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        SaveLocationScreen.routeName,
        arguments: true,
      );
      if (!mounted) return;
      unawaited(_loadSuggestions());
      return;
    }

    if (_selecting) return;
    setState(() => _selecting = true);
    _popWith(
      SelectedLocation(
        name: slot.name ?? slot.label,
        address: slot.address ?? '',
        latitude: slot.latitude ?? widget.latitude,
        longitude: slot.longitude ?? widget.longitude,
        databaseId: slot.placeId,
      ),
    );
  }

  SavedLocationSlot _slotForLabel(String label) {
    final suggestions = _suggestions;
    if (label == 'home' && suggestions?.home != null) return suggestions!.home!;
    if (label == 'work' && suggestions?.work != null) return suggestions!.work!;

    SavedPlace? saved;
    for (final p in widget.savedPlaces) {
      if (p.label.toLowerCase() == label) {
        saved = p;
        break;
      }
    }
    if (saved != null) {
      return SavedLocationSlot(
        label: label,
        name: saved.label,
        address: saved.address,
        latitude: saved.latitude,
        longitude: saved.longitude,
        placeId: saved.id,
      );
    }
    return SavedLocationSlot(label: label);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool get _isSearching => _searchController.text.trim().length >= 2;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final tt = Theme.of(context).textTheme;
    final suggestions = _suggestions;
    final home = _slotForLabel('home');
    final work = _slotForLabel('work');

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
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
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search address or place',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.secondary,
                  ),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: _clearSearch,
                        ),
                ),
              ),
            ),
            if (_searching)
              const LinearProgressIndicator(minHeight: 2),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                children: [
                  if (_error != null && suggestions == null)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _error!,
                        style: tt.bodyMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_isSearching) ...[
                    if (_searchHits.isEmpty && !_searching)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No results',
                          style: tt.bodyMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ..._searchHits.map(
                        (hit) => _PlaceTile(
                          icon: hit.source == PlaceHitSource.google
                              ? Icons.place_outlined
                              : Icons.store_mall_directory_outlined,
                          title: hit.name.isNotEmpty ? hit.name : hit.address,
                          subtitle: hit.address,
                          distanceKm: hit.distanceKm,
                          trailing: hit.source == PlaceHitSource.google
                              ? 'Google'
                              : null,
                          onTap: _selecting ? null : () => _selectSearchHit(hit),
                        ),
                      ),
                  ] else ...[
                    if (_loadingSuggestions)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      _PlaceTile(
                        icon: Icons.my_location_rounded,
                        title: 'Current location',
                        subtitle: suggestions?.current?.address ??
                            'Use GPS position',
                        onTap: _selecting ? null : _selectCurrent,
                      ),
                      _SectionLabel('Saved'),
                      _PlaceTile(
                        icon: Icons.home_rounded,
                        title: home.isFilled
                            ? (home.name ?? 'Home')
                            : 'Add Home',
                        subtitle: home.isFilled
                            ? (home.address ?? '')
                            : 'Tap to save your home address',
                        onTap: _selecting ? null : () => _selectSavedSlot(home),
                      ),
                      _PlaceTile(
                        icon: Icons.work_rounded,
                        title: work.isFilled
                            ? (work.name ?? 'Work')
                            : 'Add Work',
                        subtitle: work.isFilled
                            ? (work.address ?? '')
                            : 'Tap to save your work address',
                        onTap: _selecting ? null : () => _selectSavedSlot(work),
                      ),
                      if (suggestions?.recents.isNotEmpty == true) ...[
                        const _SectionLabel('Recents'),
                        ...suggestions!.recents.map(
                          (item) => _PlaceTile(
                            icon: Icons.history_rounded,
                            title: item.name.isNotEmpty
                                ? item.name
                                : item.address,
                            subtitle: item.address,
                            distanceKm: item.distanceKm,
                            onTap: _selecting
                                ? null
                                : () => _selectListItem(item),
                          ),
                        ),
                      ],
                      if (suggestions?.nearby.isNotEmpty == true) ...[
                        const _SectionLabel('Nearby'),
                        ...suggestions!.nearby.map(
                          (item) => _PlaceTile(
                            icon: Icons.near_me_rounded,
                            title: item.name.isNotEmpty
                                ? item.name
                                : item.address,
                            subtitle: item.address,
                            distanceKm: item.distanceKm,
                            onTap: _selecting
                                ? null
                                : () => _selectListItem(item),
                          ),
                        ),
                      ],
                    ],
                  ],
                ],
              ),
            ),
            if (_selecting)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.distanceKm,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final double? distanceKm;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final dist = distanceKm;
    final distLabel = dist == null
        ? null
        : dist < 1
            ? '${(dist * 1000).round()} m'
            : '${dist.toStringAsFixed(1)} km';

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.surfaceContainerLow,
        child: Icon(icon, color: AppColors.onSurfaceVariant, size: 20),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: tt.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
      ),
      trailing: distLabel != null || trailing != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (distLabel != null)
                  Text(
                    distLabel,
                    style: tt.labelSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: tt.labelSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            )
          : null,
    );
  }
}
