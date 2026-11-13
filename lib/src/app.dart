import 'package:flutter/material.dart';

import 'routes/routes.dart';

/// Lets a screen know when it becomes visible again after something was
/// popped off on top of it (see home_page.dart) - that's how Home finds
/// out it needs to refresh its "recent scans" after a product gets
/// created or deleted elsewhere in the app.
final RouteObserver<PageRoute<void>> routeObserver =
    RouteObserver<PageRoute<void>>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScanWise',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: getApplicationRoutes(),
      navigatorObservers: [routeObserver],
    );
  }
}
