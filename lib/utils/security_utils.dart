// Security Utilities - input sanitization, validation, and security helpers
library security_utils;

import 'package:flutter/foundation.dart';

class SecurityUtils {
  // Private constructor - static utility class
  SecurityUtils._();

  // ========== INPUT SANITIZATION ==========

  /// Sanitizes user input to prevent injection attacks
  /// Removes HTML tags, control characters, and trims whitespace
  static String sanitizeInput(String input) {
    if (input.isEmpty) return input;

    return input
        .trim()
        // Remove HTML/XML tags
        .replaceAll(RegExp(r'<[^>]*>'), '')
        // Remove potential script injections
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        // Remove control characters (except newline/tab for text areas)
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        // Remove null bytes
        .replaceAll('\x00', '');
  }

  /// Sanitizes email input specifically
  static String sanitizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  /// Sanitizes phone number - keeps only digits and + symbol
  static String sanitizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }

  /// Sanitizes name input - removes special characters but allows letters, spaces, hyphens
  static String sanitizeName(String name) {
    return sanitizeInput(name)
        .replaceAll(RegExp(r'[^\p{L}\s\-\.]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ') // Collapse multiple spaces
        .trim();
  }

  // ========== PASSWORD VALIDATION ==========

  /// Password strength result
  static PasswordStrength checkPasswordStrength(String password) {
    if (password.length < 8) {
      return PasswordStrength.weak;
    }

    int score = 0;

    // Length bonus
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;

    // Character variety
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'\d'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    if (score < 3) return PasswordStrength.weak;
    if (score < 5) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  /// Validates password meets minimum requirements
  /// Returns null if valid, or error message if invalid
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain a lowercase letter';
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain an uppercase letter';
    }

    if (!password.contains(RegExp(r'\d'))) {
      return 'Password must contain a number';
    }

    return null; // Password is valid
  }

  /// Validates password with simple rules (for MVP)
  static String? validatePasswordSimple(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    // At least one letter and one number
    if (!password.contains(RegExp(r'[a-zA-Z]'))) {
      return 'Password must contain at least one letter';
    }

    if (!password.contains(RegExp(r'\d'))) {
      return 'Password must contain at least one number';
    }

    return null;
  }

  // ========== EMAIL VALIDATION ==========

  /// Validates email format
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email.trim())) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  // ========== PHONE VALIDATION ==========

  /// Validates Philippine phone number format
  static String? validatePhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) {
      return null; // Phone is optional
    }

    final cleaned = sanitizePhone(phone);

    // Philippine format: 09XXXXXXXXX or +639XXXXXXXXX
    final phRegex = RegExp(r'^(\+63|0)9\d{9}$');

    if (!phRegex.hasMatch(cleaned)) {
      return 'Please enter a valid phone number (e.g., 09123456789)';
    }

    return null;
  }

  // ========== NAME VALIDATION ==========

  /// Validates name input - returns error message or null
  static String? validateName(String? name) {
    if (name == null || name.isEmpty) {
      return 'Name is required';
    }

    final cleaned = sanitizeName(name);

    if (cleaned.length < 2) {
      return 'Name must be at least 2 characters';
    }

    if (cleaned.length > 100) {
      return 'Name is too long';
    }

    return null;
  }

  // ========== BOOLEAN VALIDATORS (for simpler checks) ==========

  /// Returns true if email format is valid
  static bool isValidEmail(String email) {
    return validateEmail(email) == null;
  }

  /// Returns true if phone format is valid (or empty)
  static bool isValidPhone(String? phone) {
    return validatePhoneNumber(phone) == null;
  }

  /// Returns true if name format is valid
  static bool isValidName(String name) {
    return validateName(name) == null;
  }

  /// Returns true if password meets requirements
  static bool isValidPassword(String password) {
    return validatePasswordSimple(password) == null;
  }

  // ========== DEBUG LOGGING ==========

  /// Safe debug print - only prints in debug mode
  static void debugLog(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[DEBUG] $message');
    }
  }

  /// Safe debug print for sensitive data - redacts in debug mode
  static void debugLogSensitive(String label, String? value) {
    if (kDebugMode) {
      final redacted = value != null
          ? '${value.substring(0, value.length > 3 ? 3 : value.length)}***'
          : 'null';
      // ignore: avoid_print
      print('[DEBUG] $label: $redacted');
    }
  }
}

/// Password strength levels
enum PasswordStrength { weak, medium, strong }

extension PasswordStrengthExtension on PasswordStrength {
  String get label {
    switch (this) {
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.medium:
        return 'Medium';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }

  bool get isAcceptable => this != PasswordStrength.weak;
}
