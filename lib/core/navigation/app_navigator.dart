import 'package:flutter/material.dart';

/// Root navigator for non-UI layers (e.g. API client session expiry).
abstract final class AppNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static NavigatorState? get state => key.currentState;

  static void goNamedAndClear(String routeName) {
    state?.pushNamedAndRemoveUntil(routeName, (_) => false);
  }
}
