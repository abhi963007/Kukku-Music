import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/helper.dart';

class SupabaseService {
  // Can be overridden at build time via:
  // flutter build apk --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=your_key
  static const String defaultUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ybltkhkzckkkxyyfuoig.supabase.co',
  );
  static const String defaultAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlibHRraGt6Y2tra3h5eWZ1b2lnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgxNjY4NjUsImV4cCI6MjEwMzc0Mjg2NX0._e_clHX1PYbIBz-0ZOXi3DwjNIMRmLIHsBWS2x5rOO8',
  );

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;

  static bool get isAuthenticated => client.auth.currentUser != null;

  static Future<void> initialize() async {
    final url = boxGet<String>('AppPrefs', 'supabaseUrl', defaultUrl).trim();
    final anonKey = boxGet<String>('AppPrefs', 'supabaseAnonKey', defaultAnonKey).trim();

    try {
      await Supabase.initialize(
        url: url.isNotEmpty ? url : defaultUrl,
        anonKey: anonKey.isNotEmpty ? anonKey : defaultAnonKey,
      );
    } catch (e) {
      printERROR('Failed to initialize Supabase', e);
    }
  }

  /// Sign Up with Email & Password
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return await client.auth.signUp(
      email: email.trim(),
      password: password.trim(),
      data: {
        'full_name': fullName.trim(),
      },
    );
  }

  /// Sign In with Email & Password
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  /// Send Password Reset Link to Email
  static Future<void> resetPassword({required String email}) async {
    await client.auth.resetPasswordForEmail(email.trim());
  }

  static const String defaultWebClientId = '129676481545-kaonqcho5p7c2drdlcs5st40e9btaan4.apps.googleusercontent.com';

  /// Sign In with Google OAuth (Uses GoogleSignIn + Supabase ID Token exchange)
  static Future<AuthResponse?> signInWithGoogle({
    String? webClientId,
    String? iosClientId,
  }) async {
    final googleSignIn = GoogleSignIn(
      serverClientId: webClientId ?? defaultWebClientId,
      clientId: iosClientId,
      scopes: ['email', 'profile'],
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      // User cancelled Google sign-in dialog
      return null;
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw const AuthException('Could not retrieve Google ID Token for authentication');
    }

    return await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  /// Sign Out
  static Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await client.auth.signOut();
  }
}
