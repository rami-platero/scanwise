import 'package:flutter/material.dart';

import '../pages/home_page.dart';

Map<String, WidgetBuilder> getApplicationRoutes() {
  return <String, WidgetBuilder>{
    '/': (BuildContext context) => const MyHomePage(title: 'ScanWise'),
  };
}
