import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';
import 'constants.dart';

class AppUpdateManager {
  static Future<void> checkForUpdate(BuildContext context, {bool showNoUpdateMessage = false}) async {
    try {
      final client = ApiClient();
      final data = await client.get('/app/version');
      if (data is! Map) return;

      final serverVersionCode = data['version_code'] as int? ?? 1;
      final serverVersion = data['current_version'] as String? ?? '1.0.0';
      final downloadUrl = data['download_url'] as String? ?? '/api/app/download';
      final releaseNotesUr = data['release_notes_ur'] as String? ?? 'نیا ورژن دستیاب ہے!';
      final releaseNotesEn = data['release_notes_en'] as String? ?? 'New update available.';
      final sizeMb = (data['file_size_mb'] ?? 50.4).toString();

      if (serverVersionCode > AppConstants.appVersionCode) {
        if (!context.mounted) return;
        _showUpdateDialog(
          context,
          serverVersion: serverVersion,
          downloadUrl: downloadUrl,
          releaseNotesUr: releaseNotesUr,
          releaseNotesEn: releaseNotesEn,
          sizeMb: sizeMb,
        );
      } else if (showNoUpdateMessage) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'آپ کا ایپ تازہ ترین ورژن (v${AppConstants.appVersion}) پر ہے۔',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppConstants.deepEmerald,
          ),
        );
      }
    } catch (_) {
      if (showNoUpdateMessage && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('اپ ڈیٹ چیک نہیں ہو سکی۔ سرور کنکشن چیک کریں۔'),
            backgroundColor: AppConstants.alertRed,
          ),
        );
      }
    }
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String serverVersion,
    required String downloadUrl,
    required String releaseNotesUr,
    required String releaseNotesEn,
    required String sizeMb,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConstants.softGreenChip,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.wifi_protected_setup_rounded, color: AppConstants.deepEmerald, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'وائرلیس اپ ڈیٹ دستیاب ہے!',
                    style: GoogleFonts.instrumentSerif(fontWeight: FontWeight.bold, fontSize: 22, color: AppConstants.charcoal),
                  ),
                  Text(
                    'Wireless Update (No Cable Needed)',
                    style: GoogleFonts.inter(fontSize: 11, color: AppConstants.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppConstants.creamBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppConstants.softBorder),
                  ),
                  child: Text(
                    'v${AppConstants.appVersion} ➔ v$serverVersion',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.deepEmerald),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$sizeMb MB', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.textMuted)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.creamBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppConstants.softBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    releaseNotesUr,
                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppConstants.charcoal, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    releaseNotesEn,
                    style: GoogleFonts.inter(fontSize: 11.5, color: AppConstants.textMuted, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppConstants.deepEmerald, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'آپ کا تمام سابقہ ریکارڈ محفوظ رہے گا (Zero data loss)',
                    style: GoogleFonts.inter(fontSize: 11, color: AppConstants.deepEmerald, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('بعد میں (Later)', style: GoogleFonts.inter(color: AppConstants.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'ڈاؤن لوڈ شروع ہو رہا ہے... نوٹیفکیشن مکمل ہونے پر انسٹال کریں۔',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: AppConstants.deepEmerald,
                  duration: const Duration(seconds: 4),
                ),
              );

              String base = AppConstants.baseUrl;
              if (base.endsWith('/api')) {
                base = base.substring(0, base.length - 4);
              } else if (base.endsWith('/api/')) {
                base = base.substring(0, base.length - 5);
              }
              final fullUrl = downloadUrl.startsWith('http') ? downloadUrl : '$base$downloadUrl';
              final uri = Uri.parse(fullUrl);
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {
                await launchUrl(uri);
              }
            },
            icon: const Icon(Icons.download_for_offline_rounded, color: Colors.white, size: 18),
            label: Text(
              'اپ ڈیٹ کریں (Update Now)',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.deepEmerald,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
