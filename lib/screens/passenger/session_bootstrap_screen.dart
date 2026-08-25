import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/navigation/app_navigator.dart';
import '../../core/storage/active_trip_store.dart';
import '../../core/storage/token_storage.dart';
import '../../models/api_models.dart';
import '../../models/phone_verification_args.dart';
import '../../services/auth_api_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/realtime_socket_service.dart';
import '../../services/trips_api_service.dart';
import '../../services/user_api_service.dart';
import '../../theme/app_colors.dart';
import '../shared/active_ride_screen.dart';
import 'passenger_dashboard_screen.dart';
import 'welcome_screen.dart';

/// Cold-start gate: restore SharedPreferences session → dashboard / onboarding.
class SessionBootstrapScreen extends StatefulWidget {
  const SessionBootstrapScreen({super.key});

  static const routeName = '/';

  @override
  State<SessionBootstrapScreen> createState() => _SessionBootstrapScreenState();
}

class _SessionBootstrapScreenState extends State<SessionBootstrapScreen> {
  bool _refreshAttempted = false;

  @override
  void initState() {
    super.initState();
    _resume();
  }

  Future<void> _resume() async {
    try {
      final hasSession = await TokenStorage.instance.hasSession;
      if (!hasSession) {
        _go(WelcomeScreen.routeName);
        return;
      }

      final me = await UserApiService.instance.getMe();
      var onboarding = me.onboarding;
      try {
        onboarding = await UserApiService.instance.getOnboarding();
      } catch (_) {}

      if (!mounted) return;

      // Merge capabilities from /users/me (can_drive / can_book) into flags.
      final merged = OnboardingStatus(
        phoneVerified: onboarding.phoneVerified || me.phone.isNotEmpty,
        personalInfo: onboarding.personalInfo ||
            (me.fullName != null && me.fullName!.trim().isNotEmpty),
        roleSelected: onboarding.roleSelected ||
            me.activeMode != null ||
            me.canDrive ||
            me.canBook,
        vehicleInfo: onboarding.vehicleInfo,
        documentsUploaded: onboarding.documentsUploaded,
        documentsApproved: onboarding.documentsApproved,
        documentStatus: onboarding.documentStatus,
        locationsSaved: onboarding.locationsSaved,
        driverApproved: onboarding.driverApproved || me.canDrive,
        profileComplete: onboarding.profileComplete,
        canBook: onboarding.canBook || me.canBook,
        canDrive: onboarding.canDrive || me.canDrive,
        isDriver: onboarding.isDriver ||
            me.activeMode?.toLowerCase() == 'driver' ||
            me.canDrive,
        pendingSteps: onboarding.pendingSteps,
      );

      var route = nextRouteAfterLogin(
        merged,
        isNewUser: false,
        activeMode: me.activeMode,
        userStatus: me.status,
      );

      // If the user chose driver onboarding (OTP intent) but abandoned before
      // submitting onboarding/driver, the backend onboarding flags may still
      // look like a passenger. Use the persisted intent to restore the correct
      // flow.
      final pendingIntent = await TokenStorage.instance.pendingOnboardingIntent;
      if (pendingIntent == OnboardingIntent.driver.name) {
        route = nextDriverRoute(merged, isNewUser: false);
      }
      // Re-register FCM after cold start so backend has a fresh token.
      // ignore: unawaited_futures
      PushNotificationService.instance.registerTokenWithBackend();
      // Resume in-progress trip rooms on cold start.
      await RealtimeSocketService.instance.resumeIfNeeded();
      ActiveRideArgs? resumeArgs;
      final rideId = await ActiveTripStore.instance.rideId;
      final role = await ActiveTripStore.instance.role;
      if (rideId != null && role != null) {
        try {
          final trip = await TripsApiService.instance.getTrip(rideId);
          if (trip.status.isTerminal) {
            await ActiveTripStore.instance.clear();
          } else {
            resumeArgs = ActiveRideArgs(
              tripId: rideId,
              role: role,
              initialTrip: trip,
            );
          }
        } catch (_) {
          // Keep cache; user can open home without blocking boot.
        }
      }
      if (!mounted) return;
      _go(route, resumeActiveRide: resumeArgs);
    } on ApiException catch (e) {
      if (e.isAuthFailure) {
        // ApiClient usually refreshes automatically; one extra attempt for cold start.
        if (!_refreshAttempted) {
          _refreshAttempted = true;
          final ok = await AuthApiService.instance.tryRefreshSession();
          if (ok && mounted) {
            await _resume();
            return;
          }
        }
        await TokenStorage.instance.clear();
        if (!mounted) return;
        _go(WelcomeScreen.routeName);
        return;
      }
      // Other API errors with a token: send to welcome so user can re-auth or retry.
      if (!mounted) return;
      _go(WelcomeScreen.routeName);
    } catch (_) {
      // Offline with stored session — open last successful home if possible.
      final hasSession = await TokenStorage.instance.hasSession;
      if (!mounted) return;
      if (hasSession) {
        _go(PassengerDashboardScreen.routeName);
      } else {
        _go(WelcomeScreen.routeName);
      }
    }
  }

  void _go(String route, {ActiveRideArgs? resumeActiveRide}) {
    // Avoid routing through bootstrap again.
    if (route == SessionBootstrapScreen.routeName) {
      route = WelcomeScreen.routeName;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    if (resumeActiveRide != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppNavigator.key.currentState?.pushNamed(
          ActiveRideScreen.routeName,
          arguments: resumeActiveRide,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.secondary),
            const SizedBox(height: 16),
            Text(
              'Restoring session…',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
