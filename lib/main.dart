import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/api/api_session.dart';
import 'core/navigation/app_navigator.dart';
import 'core/storage/token_storage.dart';
import 'models/api_models.dart';
import 'models/phone_verification_args.dart';
import 'models/chat_models.dart';
import 'screens/driver/become_driver_screen.dart';
import 'screens/driver/chat_thread_screen.dart';
import 'screens/driver/documents_upload_screen.dart';
import 'screens/driver/driver_dashboard_screen.dart';
import 'screens/driver/under_review_screen.dart';
import 'screens/driver/update_profile_screen.dart';
import 'screens/driver/vehicle_details_screen.dart';
import 'screens/passenger/complete_profile_screen.dart';
import 'screens/passenger/login_screen.dart';
import 'screens/passenger/notifications_screen.dart';
import 'screens/passenger/otp_verification_screen.dart';
import 'screens/passenger/passenger_dashboard_screen.dart';
import 'screens/passenger/personal_info_screen.dart';
import 'screens/passenger/phone_number_screen.dart';
import 'screens/passenger/save_location_screen.dart';
import 'screens/passenger/session_bootstrap_screen.dart';
import 'screens/passenger/welcome_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Register Manrope/Inter with the font loader so ThemeData is never Roboto.
  GoogleFonts.config.allowRuntimeFetching = true;
  GoogleFonts.manrope();
  GoogleFonts.inter();

  ApiSession.onSessionExpired = () async {
    await TokenStorage.instance.clear();
    // Let the current frame finish, then clear the stack to welcome.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNavigator.goNamedAndClear(WelcomeScreen.routeName);
    });
  };

  runApp(const RidealityApp());
}

class RidealityApp extends StatelessWidget {
  const RidealityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rideality',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: AppNavigator.key,
      // Restores SharedPreferences session → /home or /driver-home, else /welcome.
      initialRoute: SessionBootstrapScreen.routeName,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case SessionBootstrapScreen.routeName:
            return MaterialPageRoute(
              builder: (_) => const SessionBootstrapScreen(),
            );
          case WelcomeScreen.routeName:
            return MaterialPageRoute(builder: (_) => const WelcomeScreen());
          case LoginScreen.routeName:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case PhoneNumberScreen.routeName:
            final intent = settings.arguments is OnboardingIntent
                ? settings.arguments as OnboardingIntent
                : OnboardingIntent.passenger;
            return MaterialPageRoute(
              builder: (_) => PhoneNumberScreen(intent: intent),
            );
          case OtpVerificationScreen.routeName:
            final args = settings.arguments as PhoneVerificationArgs?;
            if (args == null) {
              return MaterialPageRoute(
                builder: (_) => const LoginScreen(),
              );
            }
            return MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(args: args),
            );
          case PersonalInfoScreen.routeName:
            return MaterialPageRoute(
              builder: (_) => const PersonalInfoScreen(),
            );
          case SaveLocationScreen.routeName:
            final fromDash = settings.arguments == true;
            return MaterialPageRoute(
              builder: (_) => SaveLocationScreen(fromDashboard: fromDash),
            );
          case CompleteProfileScreen.routeName:
            final fromDash = settings.arguments == true;
            return MaterialPageRoute(
              builder: (_) => CompleteProfileScreen(fromDashboard: fromDash),
            );
          case NotificationsScreen.routeName:
            return MaterialPageRoute(
              builder: (_) => const NotificationsScreen(),
            );
          case PassengerDashboardScreen.routeName:
            final tab = settings.arguments is int
                ? settings.arguments as int
                : 0;
            return MaterialPageRoute(
              builder: (_) => PassengerDashboardScreen(initialIndex: tab),
            );
          // Legacy success route → home dashboard
          case '/success':
            return MaterialPageRoute(
              builder: (_) => const PassengerDashboardScreen(),
            );
          case BecomeDriverScreen.routeName:
            return MaterialPageRoute(
              builder: (_) => const BecomeDriverScreen(),
            );
          case VehicleDetailsScreen.routeName:
            final fromDash = settings.arguments == true;
            return MaterialPageRoute(
              builder: (_) =>
                  VehicleDetailsScreen(fromDashboard: fromDash),
            );
          case DocumentsUploadScreen.routeName:
            return MaterialPageRoute(
              builder: (_) => const DocumentsUploadScreen(),
            );
          case UnderReviewScreen.routeName:
            return MaterialPageRoute(
              builder: (_) => const UnderReviewScreen(),
            );
          case UpdateProfileScreen.routeName:
            final profile = settings.arguments is UserProfile
                ? settings.arguments as UserProfile
                : null;
            return MaterialPageRoute(
              builder: (_) => UpdateProfileScreen(initialProfile: profile),
            );
          case ChatThreadScreen.routeName:
            final thread = settings.arguments is ChatThread
                ? settings.arguments as ChatThread
                : (ChatSeed.demoThreads().isNotEmpty
                    ? ChatSeed.demoThreads().first
                    : null);
            if (thread == null) {
              return MaterialPageRoute(
                builder: (_) => const DriverDashboardScreen(initialIndex: 2),
              );
            }
            return MaterialPageRoute(
              builder: (_) => ChatThreadScreen(thread: thread),
            );
          case DriverDashboardScreen.routeName:
            return MaterialPageRoute(
              builder: (_) => const DriverDashboardScreen(),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const SessionBootstrapScreen(),
            );
        }
      },
    );
  }
}
