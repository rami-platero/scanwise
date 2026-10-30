import 'package:flutter/material.dart';

import '../pages/barcode_page.dart';
import '../pages/camera_page.dart';
import '../pages/condition_page.dart';
import '../pages/guidance_page.dart';
import '../pages/history_page.dart';
import '../pages/home_page.dart';
import '../pages/identifying_page.dart';
import '../pages/listing_page.dart';
import '../pages/notifications_page.dart';
import '../pages/price_page.dart';
import '../pages/result_page.dart';

Map<String, WidgetBuilder> getApplicationRoutes() {
  return <String, WidgetBuilder>{
    '/': (BuildContext context) => const MyHomePage(title: 'ScanWise'),
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
