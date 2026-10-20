import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'constants.dart';

class ReceiptHelper {
  static String formatMoney(num val) {
    return NumberFormat('#,##0').format(val);
  }

  static String formatDateTime(String? ts) {
    if (ts == null || ts.isEmpty) return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    try {
      final dt = DateTime.parse(ts).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return ts;
    }
  }

  /// Builds a formatted plain-text receipt suitable for WhatsApp, SMS, or Telegram
  static String buildReceiptText(Map<String, dynamic> order, {String storeName = 'Smart Khata Kiryana'}) {
    final orderId = order['id'] ?? 'ORD-####';
    final customerName = order['customer_name'] ?? 'Walk-in Customer';
    final total = (order['total_amount'] ?? 0.0).toDouble();
    final paidNow = (order['amount_paid_now'] ?? total).toDouble();
    final khata = (order['amount_added_to_khata'] ?? 0.0).toDouble();
    final discount = (order['discount'] ?? 0.0).toDouble();
    final paymentMethod = (order['payment_method'] ?? 'cash').toString().toUpperCase();
    final timeStr = formatDateTime(order['created_at']);
    final items = order['line_items'] as List<dynamic>? ?? [];

    final buf = StringBuffer();
    buf.writeln('🏪 *$storeName*');
    buf.writeln('📍 اسمارٹ کریانہ پوائنٹ آف سیل');
    buf.writeln('────────────────────────────');
    buf.writeln('🧾 رسید نمبر: *$orderId*');
    buf.writeln('📅 تاریخ: $timeStr');
    buf.writeln('👤 گاہک: *$customerName*');
    buf.writeln('💳 ادائیگی طریقہ: $paymentMethod');
    buf.writeln('────────────────────────────');
    buf.writeln('📦 *سامان کی تفصیل (Line Items):*');

    if (items.isEmpty) {
      buf.writeln('• جنرل کریانہ سامان: PKR ${formatMoney(total)}');
    } else {
      for (final it in items) {
        final name = it['product_name'] ?? 'Item';
        final qty = it['quantity'] ?? 1;
        final price = (it['unit_price'] ?? 0).toDouble();
        final lineTot = (it['line_total'] ?? (qty * price)).toDouble();
        buf.writeln('• $name');
        buf.writeln('  $qty x PKR ${formatMoney(price)} = *PKR ${formatMoney(lineTot)}*');
      }
    }

    buf.writeln('────────────────────────────');
    if (discount > 0) {
      buf.writeln('🏷️ رعایت (Discount): -PKR ${formatMoney(discount)}');
    }
    buf.writeln('💰 *کل بل (Total): PKR ${formatMoney(total)}*');
    buf.writeln('💵 *وصول رقم (Paid Now): PKR ${formatMoney(paidNow)}*');
    if (khata > 0) {
      buf.writeln('📒 *بقایہ ادھار (Khata): PKR ${formatMoney(khata)}*');
    }
    buf.writeln('────────────────────────────');
    buf.writeln('✨ *دوبارہ تشریف لانے کا شکریہ!*');
    buf.writeln('📱 Powered by Smart Khata AI');

    return buf.toString();
  }

  /// Shares receipt directly via WhatsApp or System Share sheet
  static Future<void> shareReceipt(BuildContext context, Map<String, dynamic> order, {String storeName = 'Smart Khata Kiryana'}) async {
    final text = buildReceiptText(order, storeName: storeName);
    final phone = order['customer_phone']?.toString().trim();

    if (phone != null && phone.isNotEmpty) {
      // Clean phone number for international format (e.g. 03001234567 -> 923001234567)
      String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '92${cleanPhone.substring(1)}';
      }
      final whatsappUrl = Uri.parse('whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(text)}');
      try {
        if (await canLaunchUrl(whatsappUrl)) {
          await launchUrl(whatsappUrl);
          return;
        }
      } catch (_) {}
    }

    // Fallback to standard native Share sheet
    await Share.share(text, subject: 'Smart Khata Receipt - ${order['id']}');
  }

  /// Prints 80mm thermal receipt using Android/Web print manager
  static Future<void> printReceiptPdf(Map<String, dynamic> order, {String storeName = 'Smart Khata Kiryana'}) async {
    final doc = pw.Document();

    final orderId = order['id'] ?? 'ORD-####';
    final customerName = order['customer_name'] ?? 'Walk-in Customer';
    final total = (order['total_amount'] ?? 0.0).toDouble();
    final paidNow = (order['amount_paid_now'] ?? total).toDouble();
    final khata = (order['amount_added_to_khata'] ?? 0.0).toDouble();
    final discount = (order['discount'] ?? 0.0).toDouble();
    final paymentMethod = (order['payment_method'] ?? 'cash').toString().toUpperCase();
    final timeStr = formatDateTime(order['created_at']);
    final items = order['line_items'] as List<dynamic>? ?? [];

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(storeName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Kiryana POS Terminal #1', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 4),
              pw.Text('Receipt #: $orderId', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text(timeStr, style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Customer: $customerName', style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text('Item', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Text('Qty x Rate', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 8),
                  pw.Text('Total', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(thickness: 0.5),
              if (items.isEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text('General Kiryana Items', style: const pw.TextStyle(fontSize: 9)),
                )
              else
                ...items.map((it) {
                  final name = it['product_name'] ?? 'Item';
                  final qty = it['quantity'] ?? 1;
                  final price = (it['unit_price'] ?? 0).toDouble();
                  final lineTot = (it['line_total'] ?? (qty * price)).toDouble();
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(child: pw.Text(name, style: const pw.TextStyle(fontSize: 8))),
                        pw.Text('$qty x ${formatMoney(price)}', style: const pw.TextStyle(fontSize: 8)),
                        pw.SizedBox(width: 8),
                        pw.Text(formatMoney(lineTot), style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  );
                }),
              pw.Divider(thickness: 0.5),
              if (discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('-PKR ${formatMoney(discount)}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL BILL:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('PKR ${formatMoney(total)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Paid ($paymentMethod):', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('PKR ${formatMoney(paidNow)}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              if (khata > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Added to Khata:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('PKR ${formatMoney(khata)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.5),
              pw.Text('Thank you for shopping with us!', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('اسمارٹ کھاتہ ایپ', style: const pw.TextStyle(fontSize: 8)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Receipt_$orderId.pdf',
    );
  }

  /// Interactive Modal Thermal Receipt Dialog with Print and Share buttons
  static void showReceiptDialog(BuildContext context, Map<String, dynamic> order, {String storeName = 'Smart Khata Kiryana'}) {
    final orderId = order['id'] ?? 'ORD-####';
    final customerName = order['customer_name'] ?? 'Walk-in Customer';
    final total = (order['total_amount'] ?? 0.0).toDouble();
    final paidNow = (order['amount_paid_now'] ?? total).toDouble();
    final khata = (order['amount_added_to_khata'] ?? 0.0).toDouble();
    final discount = (order['discount'] ?? 0.0).toDouble();
    final paymentMethod = (order['payment_method'] ?? 'cash').toString().toUpperCase();
    final timeStr = formatDateTime(order['created_at']);
    final items = order['line_items'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thermal Receipt Header
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.deepEmerald.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long, color: AppConstants.deepEmerald, size: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  storeName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.charcoal),
                ),
                Text(
                  'اسمارٹ کریانہ رسید (Official Receipt)',
                  style: GoogleFonts.inter(fontSize: 11, color: AppConstants.textMuted),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppConstants.creamBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(orderId, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(timeStr, style: GoogleFonts.inter(fontSize: 11, color: AppConstants.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('گاہک: $customerName', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: khata > 0 ? AppConstants.softRedChip : AppConstants.softGreenChip,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        khata > 0 ? 'ادھار / Credit' : 'نقد / Paid',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: khata > 0 ? AppConstants.alertRed : AppConstants.deepEmerald,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Line items
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Kiryana General Products', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted)),
                  )
                else
                  ...items.map((it) {
                    final name = it['product_name'] ?? 'Item';
                    final qty = it['quantity'] ?? 1;
                    final price = (it['unit_price'] ?? 0).toDouble();
                    final lineTot = (it['line_total'] ?? (qty * price)).toDouble();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '$name ($qty x PKR ${formatMoney(price)})',
                              style: GoogleFonts.inter(fontSize: 12, color: AppConstants.charcoal),
                            ),
                          ),
                          Text(
                            'PKR ${formatMoney(lineTot)}',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }),

                const Divider(height: 20),

                // Calculations
                if (discount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('رعایت (Discount)', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.alertRed)),
                        Text('-PKR ${formatMoney(discount)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.alertRed)),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('کل رقم (Total Amount)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('PKR ${formatMoney(total)}', style: GoogleFonts.instrumentSerif(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.deepEmerald)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ادا شدہ ($paymentMethod)', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.deepEmerald)),
                    Text('PKR ${formatMoney(paidNow)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.deepEmerald)),
                  ],
                ),
                if (khata > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('کھاتے میں درج (Khata Debt)', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.alertRed)),
                      Text('PKR ${formatMoney(khata)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.alertRed)),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.creamBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'دوبارہ تشریف لانے کا شکریہ! (Thank You)',
                      style: GoogleFonts.inter(fontSize: 11, color: AppConstants.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Actions: WhatsApp Share + Print
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          shareReceipt(context, order, storeName: storeName);
                        },
                        icon: const Icon(Icons.share, size: 16, color: Colors.white),
                        label: Text('واٹس ایپ (Share)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          printReceiptPdf(order, storeName: storeName);
                        },
                        icon: const Icon(Icons.print, size: 16, color: Colors.white),
                        label: Text('پرنٹ (Print)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.deepEmerald,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('بند کریں (Close)', style: GoogleFonts.inter(color: AppConstants.textMuted, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
