import 'package:flutter/material.dart';

import '../pages/auth_gate.dart';
import '../pages/barcode_page.dart';
import '../pages/camera_page.dart';
import '../pages/condition_page.dart';
import '../pages/guidance_page.dart';
import '../pages/history_page.dart';
import '../pages/identifying_page.dart';
import '../pages/listing_page.dart';
import '../pages/login_page.dart';
import '../pages/notifications_page.dart';
import '../pages/price_page.dart';
import '../pages/register_page.dart';
import '../pages/result_page.dart';

Map<String, WidgetBuilder> getApplicationRoutes() {
  return <String, WidgetBuilder>{
    // The root decides between the login screen and Home depending on
    // whether there's a session.
    '/': (BuildContext context) => const AuthGate(),
    'login': (BuildContext context) => const LoginPage(),
    'register': (BuildContext context) => const RegisterPage(),
    'camera': (BuildContext context) => const CameraPage(),
    'identifying': (BuildContext context) => const IdentifyingPage(),
    'guidance': (BuildContext context) => const GuidancePage(),
    'result': (BuildContext context) => const ResultPage(),
    'price': (BuildContext context) => const PricePage(),
    'listing': (BuildContext context) => const ListingPage(),
    'barcode': (BuildContext context) => const BarcodePage(),
    'history': (BuildContext context) => const HistoryPage(),
    'condition': (BuildContext context) => const ConditionPage(),
    'notifications': (BuildContext context) => const NotificationsPage(),
  };
}
