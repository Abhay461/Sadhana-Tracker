import 'package:flutter/foundation.dart';

/// Security utility functions for the app.
/// Provides input sanitization, error message cleaning, and validation helpers.
class SecurityUtils {
  /// Sanitize user input to prevent injection attacks.
  /// Removes potentially dangerous characters while preserving normal text.
  static String sanitizeInput(String input) {
    // Remove any null bytes
    String sanitized = input.replaceAll('\x00', '');
    // Trim whitespace
    sanitized = sanitized.trim();
    // Limit length to prevent DoS via extremely long strings
    if (sanitized.length > 5000) {
      sanitized = sanitized.substring(0, 5000);
    }
    return sanitized;
  }

  /// Sanitize error messages for display to users.
  /// Strips internal details, stack traces, and sensitive info.
  static String sanitizeErrorMessage(dynamic error) {
    final String message = error.toString();

    // In debug mode, show full error for development
    if (kDebugMode) {
      return message;
    }

    // In release mode, show generic messages
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('network') || lowerMessage.contains('socket') || lowerMessage.contains('connection')) {
      return 'Network error. Please check your internet connection and try again.';
    }
    if (lowerMessage.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (lowerMessage.contains('permission') || lowerMessage.contains('denied') || lowerMessage.contains('unauthorized')) {
      return 'You do not have permission to perform this action.';
    }
    if (lowerMessage.contains('not found')) {
      return 'The requested resource was not found.';
    }
    if (lowerMessage.contains('duplicate') || lowerMessage.contains('23505')) {
      return 'This record already exists.';
    }
    if (lowerMessage.contains('invalid') && lowerMessage.contains('email')) {
      return 'Please enter a valid email address.';
    }
    if (lowerMessage.contains('password')) {
      return 'Invalid credentials. Please try again.';
    }

    // Default generic message
    return 'Something went wrong. Please try again later.';
  }

  /// Validate and sanitize email input.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    final sanitized = sanitizeInput(value);
    if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(sanitized)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// Validate password strength.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Validate WhatsApp number (10 digits).
  static String? validateWhatsApp(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter WhatsApp number';
    }
    if (!RegExp(r'^[0-9]{10}$').hasMatch(value.trim())) {
      return 'Enter a valid 10-digit number';
    }
    return null;
  }

  /// Validate a name field.
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }
    final sanitized = sanitizeInput(value);
    // Name should only contain letters, spaces, and basic punctuation
    if (!RegExp(r"^[a-zA-Z\s\.\-']+$").hasMatch(sanitized)) {
      return 'Name contains invalid characters';
    }
    if (sanitized.length < 2) {
      return 'Name is too short';
    }
    if (sanitized.length > 100) {
      return 'Name is too long';
    }
    return null;
  }

  /// Check if a file is a valid image based on extension.
  static bool isValidImageFile(String filePath) {
    final allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final lowerPath = filePath.toLowerCase();
    return allowedExtensions.any((ext) => lowerPath.endsWith(ext));
  }

  /// Max file size for uploads (5 MB).
  static const int maxUploadFileSize = 5 * 1024 * 1024;
}
