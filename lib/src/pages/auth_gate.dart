import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'home_page.dart';
import 'login_page.dart';

/// The app's root route. Decides between the login screen and Home based
/// on whether there's a session, and switches automatically when the
/// user logs in or out (supabase_flutter restores a saved session on
/// launch, so a returning user lands straight on Home).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authService.onAuthStateChange,
      builder: (BuildContext context, AsyncSnapshot<AuthState> snapshot) {
        // The stream only fires on changes, so the already-restored
        // session is read directly rather than waited for.
        final Session? session =
            snapshot.data?.session ?? authService.currentSession;

        if (session == null) return const LoginPage();
        return const MyHomePage(title: 'ScanWise');
      },
    );
  }
}
