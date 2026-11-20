import 'package:supabase_flutter/supabase_flutter.dart';

/// Raised for auth problems, with a message already written for the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper over Supabase Auth, same shape as the other services.
///
/// Session persistence is handled by supabase_flutter itself: once you
/// log in, the session is stored on the device and restored on the next
/// launch, so there's nothing to do here for "stay logged in".
class AuthService {
  GoTrueClient get _auth => Supabase.instance.client.auth;

  Session? get currentSession => _auth.currentSession;
  User? get currentUser => _auth.currentUser;

  /// Id used to stamp every row this user creates.
  String? get userId => currentUser?.id;

  String get currentEmail => currentUser?.email ?? '';

  bool get isLoggedIn => currentSession != null;

  /// Fires on login, logout, and token refresh - the AuthGate listens to
  /// this to decide which screen to show.
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  /// Creates an account.
  ///
  /// Returns true when the user is logged in right away. Returns false
  /// when Supabase is configured to require email confirmation first -
  /// in that case the caller should tell them to check their inbox.
  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse response = await _auth.signUp(
        email: email.trim(),
        password: password,
      );
      return response.session != null;
    } on AuthException catch (error) {
      throw AuthFailure(_friendlyMessage(error));
    } catch (error) {
      throw AuthFailure('No se pudo crear la cuenta: $error');
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (error) {
      throw AuthFailure(_friendlyMessage(error));
    } catch (error) {
      throw AuthFailure('No se pudo iniciar sesion: $error');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (error) {
      throw AuthFailure('No se pudo cerrar sesion: $error');
    }
  }

  /// Supabase messages are in English and fairly technical; map the
  /// common ones to something a user can act on.
  String _friendlyMessage(AuthException error) {
    final String raw = error.message.toLowerCase();

    if (raw.contains('invalid login credentials')) {
      return 'Email o contrasena incorrectos.';
    }
    if (raw.contains('already registered') ||
        raw.contains('already been registered') ||
        raw.contains('user already exists')) {
      return 'Ya existe una cuenta con ese email.';
    }
    if (raw.contains('password should be at least')) {
      return 'La contrasena es demasiado corta (minimo 6 caracteres).';
    }
    if (raw.contains('unable to validate email') ||
        raw.contains('invalid email')) {
      return 'El email no tiene un formato valido.';
    }
    if (raw.contains('email not confirmed')) {
      return 'Todavia no confirmaste tu email. Revisa tu correo.';
    }
    if (raw.contains('rate limit') || raw.contains('too many')) {
      return 'Demasiados intentos. Esperá un momento e intentá de nuevo.';
    }

    return error.message;
  }
}

final AuthService authService = AuthService();
