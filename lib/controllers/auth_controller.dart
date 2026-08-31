import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../ui/screens/auth/login_screen.dart';
import '../ui/screens/main_navigation_screen.dart';
import '../ui/theme/app_theme.dart';
import '../utils/helper.dart';

class AuthController extends GetxController {
  final Rx<User?> user = Rx<User?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isPasswordVisible = false.obs;
  final RxBool isConfirmPasswordVisible = false.obs;

  StreamSubscription<AuthState>? _authSubscription;

  bool get isLoggedIn => user.value != null;
  String get userName =>
      user.value?.userMetadata?['full_name']?.toString() ??
      user.value?.email?.split('@').first ??
      'Music Lover';
  String get userEmail => user.value?.email ?? '';
  String? get userAvatar => user.value?.userMetadata?['avatar_url']?.toString();

  @override
  void onInit() {
    super.onInit();
    user.value = SupabaseService.currentUser;

    // Listen to real-time auth state changes
    try {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((data) {
        user.value = data.session?.user;
      });
    } catch (e) {
      printERROR('Auth state listener error', e);
    }
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    super.onClose();
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;
  }

  /// Sign In with Email and Password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (!_validateEmail(email) || !_validatePassword(password)) return;

    isLoading.value = true;
    try {
      final response = await SupabaseService.signInWithEmail(
        email: email,
        password: password,
      );

      if (response.user != null) {
        user.value = response.user;
        _showSuccessSnackbar('Welcome back!', 'Successfully signed in as $userName');
        Get.offAll(() => const MainNavigationScreen());
      }
    } on AuthException catch (e) {
      _showErrorSnackbar('Sign In Failed', e.message);
    } catch (e) {
      _showErrorSnackbar('Sign In Error', 'An unexpected error occurred. Please check your credentials.');
    } finally {
      isLoading.value = false;
    }
  }

  /// Sign Up with Name, Email and Password
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (fullName.trim().isEmpty) {
      _showErrorSnackbar('Invalid Name', 'Please enter your full name');
      return;
    }
    if (!_validateEmail(email)) return;
    if (!_validatePassword(password)) return;
    if (password != confirmPassword) {
      _showErrorSnackbar('Password Mismatch', 'The passwords do not match');
      return;
    }

    isLoading.value = true;
    try {
      final response = await SupabaseService.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );

      if (response.user != null) {
        user.value = response.user;
        _showSuccessSnackbar(
          'Account Created',
          response.session != null
              ? 'Welcome to Kukku Music!'
              : 'Please check your email to verify your account.',
        );
        Get.offAll(() => const MainNavigationScreen());
      }
    } on AuthException catch (e) {
      _showErrorSnackbar('Sign Up Failed', e.message);
    } catch (e) {
      _showErrorSnackbar('Sign Up Error', 'Could not complete registration. Please try again.');
    } finally {
      isLoading.value = false;
    }
  }

  /// Send Password Reset Link
  Future<bool> sendPasswordReset(String email) async {
    if (!_validateEmail(email)) return false;

    isLoading.value = true;
    try {
      await SupabaseService.resetPassword(email: email);
      _showSuccessSnackbar(
        'Reset Email Sent',
        'We sent a password reset link to $email. Please check your inbox.',
      );
      return true;
    } on AuthException catch (e) {
      _showErrorSnackbar('Reset Failed', e.message);
      return false;
    } catch (e) {
      _showErrorSnackbar('Reset Error', 'Could not send reset link. Please try again later.');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Sign In with Google
  Future<void> signInWithGoogle() async {
    isLoading.value = true;
    try {
      final response = await SupabaseService.signInWithGoogle();
      if (response != null && response.user != null) {
        user.value = response.user;
        _showSuccessSnackbar('Google Sign In', 'Welcome, $userName!');
        Get.offAll(() => const MainNavigationScreen());
      }
    } on AuthException catch (e) {
      _showErrorSnackbar('Google Sign In Failed', e.message);
    } catch (e) {
      _showErrorSnackbar('Google Sign In', 'Could not sign in with Google. Please try email sign in.');
    } finally {
      isLoading.value = false;
    }
  }

  /// Sign Out and navigate back to Login Screen
  Future<void> signOut() async {
    isLoading.value = true;
    try {
      await SupabaseService.signOut();
      user.value = null;
      _showSuccessSnackbar('Signed Out', 'You have been signed out successfully.');
      Get.offAll(() => const LoginScreen());
    } catch (e) {
      _showErrorSnackbar('Sign Out Error', 'Failed to sign out cleanly.');
    } finally {
      isLoading.value = false;
    }
  }

  // --- Validation Helpers ---
  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (email.trim().isEmpty || !emailRegex.hasMatch(email.trim())) {
      _showErrorSnackbar('Invalid Email', 'Please enter a valid email address');
      return false;
    }
    return true;
  }

  bool _validatePassword(String password) {
    if (password.length < 6) {
      _showErrorSnackbar('Weak Password', 'Password must be at least 6 characters long');
      return false;
    }
    return true;
  }

  void _showErrorSnackbar(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: AppTheme.radiusMd,
      icon: const Icon(Icons.error_outline, color: Colors.white),
      duration: const Duration(seconds: 4),
    );
  }

  void _showSuccessSnackbar(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.9),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: AppTheme.radiusMd,
      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      duration: const Duration(seconds: 3),
    );
  }
}
