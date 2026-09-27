import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Smart Khata';

  // ── API Base URL ───────────────────────────────────────────────────────────
  // Default cloud live production URL (Render Free Forever)
  static const String defaultCloudUrl = 'https://smartkhata-api-fyp.onrender.com/api';
  static String? customServerUrl;

  static String get baseUrl {
    if (customServerUrl != null && customServerUrl!.isNotEmpty) {
      return customServerUrl!;
    }
    return defaultCloudUrl;
  }

  /// Fallback physical device IP
  static const String physicalDeviceIp = '192.168.100.12';
  static String get physicalDeviceUrl => 'http://$physicalDeviceIp:8000/api';

  // ── Timeouts ───────────────────────────────────────────────────────────────
  /// Extra-long timeout for Whisper STT processing (server-side)
  static const int voiceApiTimeoutSeconds = 30;

  // ── Storage Keys ───────────────────────────────────────────────────────────
  static const String tokenKey = 'jwt_token';
  static const String userRoleKey = 'user_role';
  static const String userNameKey = 'user_name';
  static const String storeNameKey = 'user_store_name';
  static const String customServerUrlKey = 'custom_server_url';
  static const String lastSyncKey = 'last_sync_timestamp';

  // ── Pakistani Kiryana / Dukaan Design System 1.0 ──────────────────────────
  static const Color deepEmerald = Color(0xFF0F5132);
  static const Color primaryGreen = Color(0xFF0F5132);
  static const Color warmSage = Color(0xFF7DA37D);
  static const Color creamBg = Color(0xFFF7F3EB);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color charcoal = Color(0xFF1C1C1C);
  static const Color textDark = Color(0xFF1C1C1C);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color mutedTerracotta = Color(0xFFC46A4A);
  static const Color accentGold = Color(0xFFC46A4A);
  static const Color alertRed = Color(0xFFC0392B);
  static const Color errorRed = Color(0xFFC0392B);
  static const Color softGreenChip = Color(0xFFE6F2ED);
  static const Color softRedChip = Color(0xFFFDF2F2);
  static const Color softBorder = Color(0xFFE5E7EB);
  static const Color darkBg = Color(0xFF111827);
  static const Color cardDark = Color(0xFF1F2937);
  static const Color textLight = Color(0xFFF9FAFB);

  // ── UI Radiuses ────────────────────────────────────────────────────────────
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
  static const double inputRadius = 12.0;
}
