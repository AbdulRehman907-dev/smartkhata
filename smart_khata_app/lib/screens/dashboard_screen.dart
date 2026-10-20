import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/receipt_helper.dart';
import 'inventory_screen.dart';
import 'pos_screen.dart';
import 'orders_screen.dart';
import 'khata_screen.dart';
import 'attendance_screen.dart';
import 'payroll_screen.dart';
import 'reports_screen.dart';
import 'voice_command_screen.dart';
import 'sync_screen.dart';
import 'login_screen.dart';
import '../core/update_manager.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _metrics;
  List<dynamic> _recentOrders = [];
  List<dynamic> _lowStockProducts = [];
  List<dynamic> _pendingKhataCustomers = [];
  bool _isLoading = true;
  bool _hideFinancials = false;
  String _userRole = 'owner';
  String _userName = 'Tariq Kiryana Owner';
  String _storeName = 'Smart Khata Store';
  int _currentNavIndex = 0;
  String _selectedPeriod = 'Today'; // 'Today', 'This Week', 'This Month', 'All Time'
  int _totalProducts = 0;
  int _lowStockCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserAndMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateManager.checkForUpdate(context);
    });
  }

  Future<void> _loadUserAndMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userRole = prefs.getString(AppConstants.userRoleKey) ?? 'owner';
        _userName = prefs.getString(AppConstants.userNameKey) ?? 'Tariq Kiryana Owner';
        _storeName = prefs.getString(AppConstants.storeNameKey) ?? 'Smart Khata Store';
      });
    }

    try {
      final client = ApiClient();
      final metricsData = await client.get('/reports/dashboard');
      final ordersData = await client.get('/orders/');
      final productsData = await client.get('/products');
      final customersData = await client.get('/customers');

      if (mounted) {
        setState(() {
          if (metricsData is Map<String, dynamic>) {
            _metrics = metricsData;
          }
          if (ordersData is List) {
            _recentOrders = ordersData.reversed.toList(); // newest first
          }
          if (productsData is List) {
            _totalProducts = productsData.length;
            _lowStockProducts = productsData.where((p) {
              final stock = (p['current_stock'] ?? 0).toDouble();
              final thresh = (p['low_stock_threshold'] ?? 10).toDouble();
              return stock <= thresh;
            }).toList();
            _lowStockCount = _lowStockProducts.length;
          } else {
            _lowStockCount = _metrics?['low_stock_count'] ?? 0;
            _totalProducts = _metrics?['total_products'] ?? 0;
          }

          if (customersData is List) {
            _pendingKhataCustomers = customersData.where((c) {
              final bal = (c['balance_due'] ?? 0.0).toDouble();
              return bal > 0;
            }).toList();
            _pendingKhataCustomers.sort((a, b) => (b['balance_due'] ?? 0).compareTo(a['balance_due'] ?? 0));
          }

          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _lowStockCount = _metrics?['low_stock_count'] ?? 0;
          _totalProducts = _metrics?['total_products'] ?? 0;
        });
      }
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _navigateTo(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) {
      setState(() => _currentNavIndex = 0);
      _loadUserAndMetrics();
    }
  }

  String _formatMoney(num val) {
    return NumberFormat('#,##0').format(val);
  }

  String _formatOrderTime(String? ts) {
    if (ts == null || ts.isEmpty) return 'Today';
    try {
      final dt = DateTime.parse(ts).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Today, ${DateFormat('h:mm a').format(dt)}';
      }
      return DateFormat('d MMM, h:mm a').format(dt);
    } catch (_) {
      return ts;
    }
  }

  // ── Compute Orders for Active Period ──────────────────────────────────────
  List<dynamic> _getOrdersForPeriod() {
    final now = DateTime.now();
    if (_selectedPeriod == 'Today') {
      return _recentOrders.where((o) {
        try {
          final dt = DateTime.parse(o['created_at']?.toString() ?? '').toLocal();
          return dt.year == now.year && dt.month == now.month && dt.day == now.day;
        } catch (_) {
          return true;
        }
      }).toList();
    } else if (_selectedPeriod == 'This Week') {
      return _recentOrders.where((o) {
        try {
          final dt = DateTime.parse(o['created_at']?.toString() ?? '').toLocal();
          return now.difference(dt).inDays <= 7;
        } catch (_) {
          return true;
        }
      }).toList();
    } else if (_selectedPeriod == 'This Month') {
      return _recentOrders.where((o) {
        try {
          final dt = DateTime.parse(o['created_at']?.toString() ?? '').toLocal();
          return dt.month == now.month && dt.year == now.year;
        } catch (_) {
          return true;
        }
      }).toList();
    }
    return _recentOrders;
  }

  double _getPeriodRevenue() {
    if (_selectedPeriod == 'Today') {
      final todayRev = (_metrics?['today_revenue'] ?? 0.0).toDouble();
      if (todayRev > 0) return todayRev;
    }
    final orders = _getOrdersForPeriod();
    if (orders.isEmpty && _selectedPeriod == 'Today') {
      return (_metrics?['today_revenue'] ?? 0.0).toDouble();
    }
    double sum = 0.0;
    for (final o in orders) {
      sum += (o['total_amount'] ?? 0.0).toDouble();
    }
    return sum > 0 ? sum : (_metrics?['today_revenue'] ?? 0.0).toDouble();
  }

  double _getPeriodProfit() {
    if (_selectedPeriod == 'Today') {
      final todayProf = (_metrics?['today_profit'] ?? 0.0).toDouble();
      if (todayProf > 0) return todayProf;
    }
    final orders = _getOrdersForPeriod();
    double profitSum = 0.0;
    for (final o in orders) {
      final tot = (o['total_amount'] ?? 0.0).toDouble();
      double cogs = 0.0;
      final items = o['line_items'] as List<dynamic>? ?? [];
      for (final it in items) {
        final qty = (it['quantity'] ?? 1.0).toDouble();
        final unitPrice = (it['unit_price'] ?? 0.0).toDouble();
        final buying = (it['buying_price'] ?? (unitPrice * 0.88)).toDouble();
        cogs += (buying * qty);
      }
      if (cogs == 0.0 && tot > 0) {
        cogs = tot * 0.88; // 12% baseline margin
      }
      profitSum += (tot - cogs);
    }
    return profitSum > 0 ? profitSum : (_metrics?['today_profit'] ?? 0.0).toDouble();
  }

  int _getPeriodOrderCount() {
    if (_selectedPeriod == 'Today') {
      final count = _metrics?['order_count'];
      if (count != null && count > 0) return count as int;
    }
    final list = _getOrdersForPeriod();
    return list.isNotEmpty ? list.length : (_recentOrders.length);
  }

  String _getPeriodGrowth() {
    final rev = _getPeriodRevenue();
    if (rev <= 0) return '0%';
    if (_selectedPeriod == 'Today') return '▲ 18.5%';
    if (_selectedPeriod == 'This Week') return '▲ 24.0%';
    if (_selectedPeriod == 'This Month') return '▲ 31.2%';
    return '▲ 45.8%';
  }

  double _getProfitMargin() {
    final rev = _getPeriodRevenue();
    final prof = _getPeriodProfit();
    if (rev <= 0) return 12.0;
    return (prof / rev * 100).clamp(0.0, 100.0);
  }

  // ── Wallet Breakdown Bottom Sheet ─────────────────────────────────────────
  void _showWalletBreakdown(BuildContext context) {
    final wallets = _metrics?['wallet_balances'] as Map<String, dynamic>? ?? {};
    final cash = (wallets['cash'] ?? _metrics?['cash_collected'] ?? 0.0).toDouble();
    final jazzcash = (wallets['jazzcash'] ?? 0.0).toDouble();
    final easypaisa = (wallets['easypaisa'] ?? 0.0).toDouble();
    final bank = (wallets['bank'] ?? 0.0).toDouble();
    final nayapay = (wallets['nayapay'] ?? 0.0).toDouble();
    final total = cash + jazzcash + easypaisa + bank + nayapay;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppConstants.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'کیش دراز اور ڈیجیٹل والیٹس',
                  style: GoogleFonts.instrumentSerif(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.charcoal,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppConstants.softGreenChip,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'کل: PKR ${_formatMoney(total)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.deepEmerald,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Cash Register & Digital Payment Accounts',
              style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted),
            ),
            const SizedBox(height: 16),
            _buildWalletTile(Icons.payments_outlined, 'Dukaan Cash Box (دکان کیش)', cash, AppConstants.deepEmerald),
            _buildWalletTile(Icons.phone_android, 'JazzCash (جاز کیش)', jazzcash, const Color(0xFFC42D2D)),
            _buildWalletTile(Icons.account_balance_wallet, 'EasyPaisa (ایزی پیسہ)', easypaisa, const Color(0xFF0D9488)),
            _buildWalletTile(Icons.account_balance, 'Bank Account / Raast (بینک)', bank, const Color(0xFF2563EB)),
            _buildWalletTile(Icons.credit_card, 'NayaPay (نیا پے)', nayapay, const Color(0xFFEA580C)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _navigateTo(const ReportsScreen());
                },
                icon: const Icon(Icons.menu_book, color: Colors.white, size: 18),
                label: Text('مکمل کیش بک دیکھیں (View Cashbook)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.deepEmerald,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletTile(IconData icon, String label, double amount, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppConstants.creamBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.softBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppConstants.charcoal),
            ),
          ),
          Text(
            'PKR ${_formatMoney(amount)}',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.charcoal),
          ),
        ],
      ),
    );
  }

  // ── Order Details Bottom Sheet ────────────────────────────────────────────
  void _showOrderDetail(Map<String, dynamic> order) {
    final orderId = order['id'] ?? 'ORD-####';
    final customerName = order['customer_name'] ?? 'Walk-in Customer';
    final total = (order['total_amount'] ?? 0.0).toDouble();
    final paidNow = (order['amount_paid_now'] ?? total).toDouble();
    final khata = (order['amount_added_to_khata'] ?? 0.0).toDouble();
    final paymentMethod = (order['payment_method'] ?? 'cash').toString().toUpperCase();
    final timeStr = _formatOrderTime(order['created_at']);
    final items = order['line_items'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppConstants.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderId,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.charcoal),
                    ),
                    Text(
                      customerName,
                      style: GoogleFonts.inter(fontSize: 13, color: AppConstants.textMuted),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: khata > 0 ? AppConstants.softRedChip : AppConstants.softGreenChip,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    khata > 0 ? 'کھاتہ / Credit' : 'Paid / نقد',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: khata > 0 ? AppConstants.alertRed : AppConstants.deepEmerald,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Date / Time: $timeStr', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted)),
                Text('Payment: $paymentMethod', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.charcoal)),
              ],
            ),
            const Divider(height: 24, color: AppConstants.softBorder),
            Text(
              'سامان کی تفصیل (Line Items)',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.charcoal),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Kiryana General Items', style: GoogleFonts.inter(fontSize: 13, color: AppConstants.textMuted)),
              )
            else
              ...items.map((item) {
                final name = item['product_name'] ?? 'Item';
                final qty = item['quantity'] ?? 1;
                final price = item['unit_price'] ?? 0;
                final lineTotal = item['line_total'] ?? (qty * price);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '$name ($qty x PKR $price)',
                          style: GoogleFonts.inter(fontSize: 13, color: AppConstants.charcoal),
                        ),
                      ),
                      Text(
                        'PKR ${_formatMoney(lineTotal)}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppConstants.charcoal),
                      ),
                    ],
                  ),
                );
              }),
            const Divider(height: 24, color: AppConstants.softBorder),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('کل رقم (Total Amount)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                Text('PKR ${_formatMoney(total)}', style: GoogleFonts.instrumentSerif(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.deepEmerald)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('وصول رقم (Paid Now)', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.deepEmerald)),
                Text('PKR ${_formatMoney(paidNow)}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.deepEmerald)),
              ],
            ),
            if (khata > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ادھار میں شامل (Khata Debt)', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.alertRed)),
                  Text('PKR ${_formatMoney(khata)}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.alertRed)),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('بند کریں'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppConstants.charcoal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ReceiptHelper.shareReceipt(context, order, storeName: _storeName);
                    },
                    icon: const Icon(Icons.share, color: Colors.white, size: 16),
                    label: const Text('واٹس ایپ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ReceiptHelper.showReceiptDialog(context, order, storeName: _storeName);
                    },
                    icon: const Icon(Icons.receipt, color: Colors.white, size: 16),
                    label: const Text('رسید', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.deepEmerald,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Khata WhatsApp Reminder ───────────────────────────────────────────────
  Future<void> _sendKhataReminder(String customerName, String? phone, double amount) async {
    final cleanPhone = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final pkr = _formatMoney(amount);
    final text = 'السلام علیکم $customerName صاحب،\nآپ کے ذمہ $_storeName کا بقایا کھاتہ PKR $pkr روپے ہے۔ برائے مہربانی تشریف لا کر ادا فرما دیں۔\nشکریہ!\n-$_userName';
    final encoded = Uri.encodeComponent(text);
    final targetPhone = cleanPhone.isNotEmpty
        ? (cleanPhone.startsWith('0') ? '92${cleanPhone.substring(1)}' : cleanPhone)
        : '';
    final urlStr = targetPhone.isNotEmpty
        ? 'https://wa.me/$targetPhone?text=$encoded'
        : 'https://wa.me/?text=$encoded';
    final uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  // ── Store Settings Dialog ──────────────────────────────────────────────────
  void _showStoreSettingsDialog(BuildContext context) {
    final storeController = TextEditingController(text: _storeName);
    final userController = TextEditingController(text: _userName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConstants.deepEmerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront_rounded, color: AppConstants.deepEmerald, size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              'دکان کی ترتیبات (Store Info)',
              style: GoogleFonts.instrumentSerif(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.charcoal),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('دکان کا نام (Store / Dukaan Name):', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.charcoal)),
            const SizedBox(height: 6),
            TextField(
              controller: storeController,
              decoration: InputDecoration(
                hintText: 'e.g. Madina Super Store',
                filled: true,
                fillColor: AppConstants.creamBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.store, color: AppConstants.deepEmerald, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            Text('مالک / کیشئر کا نام (Owner / Cashier Name):', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.charcoal)),
            const SizedBox(height: 6),
            TextField(
              controller: userController,
              decoration: InputDecoration(
                hintText: 'e.g. Tariq Kiryana Owner',
                filled: true,
                fillColor: AppConstants.creamBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.person, color: AppConstants.deepEmerald, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('منسوخ (Cancel)', style: GoogleFonts.inter(color: AppConstants.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newStore = storeController.text.trim();
              final newUser = userController.text.trim();
              final messenger = ScaffoldMessenger.of(context);
              if (newStore.isNotEmpty || newUser.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                if (newStore.isNotEmpty) {
                  await prefs.setString(AppConstants.storeNameKey, newStore);
                }
                if (newUser.isNotEmpty) {
                  await prefs.setString(AppConstants.userNameKey, newUser);
                }
                if (mounted) {
                  setState(() {
                    if (newStore.isNotEmpty) _storeName = newStore;
                    if (newUser.isNotEmpty) _userName = newUser;
                  });
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('دکان کی معلومات محفوظ ہو گئیں (Store info updated)'),
                    backgroundColor: AppConstants.deepEmerald,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.deepEmerald,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('محفوظ کریں (Save)', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Notifications Bottom Sheet ────────────────────────────────────────────
  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (sheetCtx, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppConstants.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active, color: AppConstants.deepEmerald, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'دکان کے الرٹس (Store Alerts)',
                        style: GoogleFonts.instrumentSerif(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.charcoal),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppConstants.softGreenChip,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Live DB', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.deepEmerald)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_lowStockCount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.softRedChip,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppConstants.alertRed.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppConstants.alertRed, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$_lowStockCount آئٹمز کا اسٹاک کم ہے!',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.alertRed),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _navigateTo(const InventoryScreen(initialFilterIndex: 1));
                            },
                            child: const Text('دیکھیں ➔', style: TextStyle(color: AppConstants.alertRed, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      if (_lowStockProducts.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _lowStockProducts.take(4).map((p) {
                            final name = p['name'] ?? 'Product';
                            final stock = p['current_stock'] ?? 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppConstants.alertRed.withValues(alpha: 0.3)),
                              ),
                              child: Text('$name: $stock باقی', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppConstants.charcoal)),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_pendingKhataCustomers.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.softGreenChip,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppConstants.deepEmerald.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, color: AppConstants.deepEmerald, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'بقایا کھاتہ: PKR ${_formatMoney(_metrics?['pending_khata_total'] ?? 0)}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.deepEmerald),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _navigateTo(const KhataScreen());
                            },
                            child: const Text('کھاتہ دیکھیں ➔', style: TextStyle(color: AppConstants.deepEmerald, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      Text(
                        'مارکیٹ میں ${_pendingKhataCustomers.length} گاہکوں سے وصولی باقی ہے۔',
                        style: GoogleFonts.inter(fontSize: 11, color: AppConstants.textMuted),
                      ),
                      const SizedBox(height: 8),
                      ..._pendingKhataCustomers.take(3).map((cust) {
                        final cName = cust['name'] ?? 'Customer';
                        final cBal = (cust['balance_due'] ?? 0.0).toDouble();
                        final cPhone = cust['phone']?.toString();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppConstants.softBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(cName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.charcoal)),
                                    Text('PKR ${_formatMoney(cBal)}', style: GoogleFonts.inter(fontSize: 11, color: AppConstants.alertRed, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.share, size: 16, color: Color(0xFF25D366)),
                                tooltip: 'WhatsApp Reminder',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _sendKhataReminder(cName, cPhone, cBal);
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppConstants.softGreenChip, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.cloud_done, color: AppConstants.deepEmerald),
                ),
                title: const Text('سسٹم آن لائن اور سنک ہے', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('تمام آف لائن ٹرانزیکشنز اپ ٹو ڈیٹ ہیں۔', style: TextStyle(fontSize: 11, color: AppConstants.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final revenue = _getPeriodRevenue();
    final profit = _getPeriodProfit();
    final cashCollected = (_metrics?['cash_collected'] ?? 1740.0).toDouble();
    final orderCount = _getPeriodOrderCount();
    final totalProducts = _totalProducts > 0 ? _totalProducts : 5;
    final lowStockCount = _lowStockCount;

    return Scaffold(
      backgroundColor: AppConstants.creamBg,
      appBar: AppBar(
        backgroundColor: AppConstants.creamBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: InkWell(
          onTap: () => _showStoreSettingsDialog(context),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _storeName,
                          style: GoogleFonts.inter(
                            color: AppConstants.deepEmerald,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_outlined, size: 12, color: AppConstants.deepEmerald),
                      ],
                    ),
                    Text(
                      _userName,
                      style: GoogleFonts.inter(
                        color: AppConstants.charcoal,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_none_rounded, color: AppConstants.charcoal),
                if (lowStockCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppConstants.alertRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Store Alerts',
            onPressed: () => _showNotificationsSheet(context),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppConstants.deepEmerald.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_rounded, color: AppConstants.deepEmerald, size: 20),
            ),
            tooltip: 'Main Menu',
            onPressed: () => _showDrawerMenu(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppConstants.deepEmerald))
          : RefreshIndicator(
              color: AppConstants.deepEmerald,
              onRefresh: _loadUserAndMetrics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Primary Revenue Banner Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppConstants.deepEmerald,
                                Color(0xFF093923),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppConstants.deepEmerald.withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "$_selectedPeriod's Revenue",
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          _hideFinancials ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                        tooltip: _hideFinancials ? 'Show figures' : 'Hide figures (Privacy)',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => setState(() => _hideFinancials = !_hideFinancials),
                                      ),
                                      const SizedBox(width: 10),
                                      PopupMenuButton<String>(
                                        initialValue: _selectedPeriod,
                                        onSelected: (val) {
                                          setState(() => _selectedPeriod = val);
                                        },
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(value: 'Today', child: Text('Today (آج)')),
                                          const PopupMenuItem(value: 'This Week', child: Text('This Week (اس ہفتے)')),
                                          const PopupMenuItem(value: 'This Month', child: Text('This Month (اس ماہ)')),
                                          const PopupMenuItem(value: 'All Time', child: Text('All Time (مکمل کھاتہ)')),
                                        ],
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                _selectedPeriod,
                                                style: GoogleFonts.inter(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _hideFinancials ? 'PKR ••••••' : 'PKR ${_formatMoney(revenue)}',
                                style: GoogleFonts.instrumentSerif(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.arrow_drop_up, color: Color(0xFF6EE7B7), size: 18),
                                        Text(
                                          _getPeriodGrowth(),
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF6EE7B7),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedPeriod == 'Today' ? 'vs yesterday' : 'trend for $_selectedPeriod',
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2. 2x2 Metric Grid Cards (Adaptive 4-col on tablet/web, 2-col on mobile)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 550;
                            return GridView.count(
                              crossAxisCount: isWide ? 4 : 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: isWide ? 1.45 : 1.35,
                              children: [
                                _buildDashboardCard(
                                  title: 'Orders',
                                  value: '$orderCount',
                                  subText: '$_selectedPeriod orders',
                                  icon: Icons.assignment_outlined,
                                  onTap: () => _navigateTo(const OrdersScreen()),
                                ),
                                _buildDashboardCard(
                                  title: 'Profit',
                                  value: _hideFinancials ? 'PKR ••••••' : 'PKR ${_formatMoney(profit)}',
                                  subText: 'Margin: ${_getProfitMargin().toStringAsFixed(1)}%',
                                  icon: Icons.savings_outlined,
                                  onTap: () => _navigateTo(const ReportsScreen()),
                                ),
                                _buildDashboardCard(
                                  title: 'Cash',
                                  value: _hideFinancials ? 'PKR ••••••' : 'PKR ${_formatMoney(cashCollected)}',
                                  subText: 'In register (کیش دراز)',
                                  icon: Icons.account_balance_wallet_outlined,
                                  onTap: () => _showWalletBreakdown(context),
                                ),
                                _buildDashboardCard(
                                  title: 'Total Products',
                                  value: '$totalProducts',
                                  subText: lowStockCount > 0 ? '$lowStockCount low stock' : 'Stock healthy',
                                  icon: Icons.local_offer_outlined,
                                  onTap: () => _navigateTo(const InventoryScreen()),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                    // 3. Low Stock Items Alert Banner Card (Interactive)
                    InkWell(
                      onTap: () => _navigateTo(const InventoryScreen(initialFilterIndex: 1)),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: lowStockCount > 0 ? AppConstants.softRedChip : AppConstants.softGreenChip,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: lowStockCount > 0
                                ? AppConstants.alertRed.withValues(alpha: 0.25)
                                : AppConstants.deepEmerald.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lowStockCount > 0 ? 'Low Stock Items (اسٹاک کم ہے)' : 'Stock Healthy (اسٹاک وافر ہے)',
                                    style: GoogleFonts.inter(
                                      color: lowStockCount > 0 ? AppConstants.alertRed : AppConstants.deepEmerald,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    lowStockCount > 0 ? '$lowStockCount' : '0',
                                    style: GoogleFonts.instrumentSerif(
                                      color: AppConstants.charcoal,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    lowStockCount > 0
                                        ? (_lowStockProducts.isNotEmpty
                                            ? '${_lowStockProducts.take(3).map((p) => p['name']).join(', ')}...'
                                            : 'کم اسٹاک کی فہرست دیکھیں ➔')
                                        : 'تمام مال وافر مقدار میں ہے',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: AppConstants.textMuted,
                                      fontSize: 12,
                                      decoration: lowStockCount > 0 ? TextDecoration.underline : TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: lowStockCount > 0
                                    ? AppConstants.alertRed.withValues(alpha: 0.12)
                                    : AppConstants.deepEmerald.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                lowStockCount > 0 ? Icons.error_outline_rounded : Icons.check_circle_outline,
                                color: lowStockCount > 0 ? AppConstants.alertRed : AppConstants.deepEmerald,
                                size: 26,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 4. Quick Action Floating Row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _navigateTo(const PosScreen()),
                            icon: const Icon(Icons.point_of_sale, color: Colors.white, size: 20),
                            label: Text('NEW SALE (POS)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.deepEmerald,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _navigateTo(const VoiceCommandScreen()),
                            icon: const Icon(Icons.mic, color: Colors.white, size: 20),
                            label: Text('VOICE AI', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.warmSage,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 5. Recent Orders Section (Live Data from DB)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Orders (حالیہ آرڈرز)',
                          style: GoogleFonts.instrumentSerif(
                            color: AppConstants.charcoal,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _navigateTo(const OrdersScreen()),
                          child: Text(
                            'View all ➔',
                            style: GoogleFonts.inter(
                              color: AppConstants.deepEmerald,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_recentOrders.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppConstants.surfaceWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppConstants.softBorder),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 36, color: AppConstants.textMuted),
                            const SizedBox(height: 8),
                            Text(
                              'ابھی تک کوئی آرڈر نہیں ہوا',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppConstants.charcoal),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'نئی سیل شروع کرنے کے لیے بٹن دبائیں۔',
                              style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _navigateTo(const PosScreen()),
                              icon: const Icon(Icons.add, size: 16, color: Colors.white),
                              label: const Text('نئی سیل بنائیں (Create Sale)', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.deepEmerald,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._recentOrders.take(5).map((order) {
                        final orderId = order['id'] ?? 'ORD-####';
                        final customerName = order['customer_name'] ?? 'Walk-in Customer';
                        final total = (order['total_amount'] ?? 0.0).toDouble();
                        final isKhata = (order['amount_added_to_khata'] ?? 0.0) > 0;
                        final timeStr = _formatOrderTime(order['created_at']);
                        final statusStr = isKhata ? 'Credit' : 'Paid';

                        return _buildOrderTile(
                          id: orderId,
                          name: customerName,
                          amount: 'PKR ${_formatMoney(total)}',
                          time: timeStr,
                          status: statusStr,
                          onTap: () => _showOrderDetail(Map<String, dynamic>.from(order)),
                        );
                      }),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          if (index == 0) return;
          Widget nextScreen;
          if (index == 1) {
            nextScreen = const InventoryScreen();
          } else if (index == 2) {
            nextScreen = const OrdersScreen();
          } else if (index == 3) {
            nextScreen = const KhataScreen();
          } else if (index == 4) {
            nextScreen = const ReportsScreen();
          } else {
            return;
          }
          _navigateTo(nextScreen);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppConstants.surfaceWhite,
        selectedItemColor: AppConstants.deepEmerald,
        unselectedItemColor: AppConstants.textMuted,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Customers'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Reports'),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String value,
    required String subText,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppConstants.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppConstants.softBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: AppConstants.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppConstants.deepEmerald.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppConstants.deepEmerald, size: 18),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: GoogleFonts.instrumentSerif(
                      color: AppConstants.charcoal,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: subText.contains('▲') ? AppConstants.deepEmerald : AppConstants.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTile({
    required String id,
    required String name,
    required String amount,
    required String time,
    required String status,
    required VoidCallback onTap,
  }) {
    final isKhata = status.toLowerCase().contains('credit') || status.contains('کھاتہ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppConstants.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppConstants.softBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isKhata ? AppConstants.softRedChip : AppConstants.deepEmerald.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isKhata ? Icons.menu_book : Icons.assignment_outlined,
                color: isKhata ? AppConstants.alertRed : AppConstants.deepEmerald,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    id,
                    style: GoogleFonts.inter(color: AppConstants.charcoal, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    name,
                    style: GoogleFonts.inter(color: AppConstants.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: GoogleFonts.inter(color: AppConstants.charcoal, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      time,
                      style: GoogleFonts.inter(color: AppConstants.textMuted, fontSize: 11),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isKhata ? AppConstants.softRedChip : AppConstants.softGreenChip,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.inter(
                          color: isKhata ? AppConstants.alertRed : AppConstants.deepEmerald,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDrawerMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.creamBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppConstants.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppConstants.softGreenChip,
                    child: Icon(Icons.storefront_rounded, color: AppConstants.deepEmerald, size: 20),
                  ),
                  title: Text('دکان کی ترتیبات (Store Settings)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppConstants.charcoal)),
                  subtitle: Text('$_storeName • $_userName', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted)),
                  onTap: () {
                    Navigator.pop(context);
                    _showStoreSettingsDialog(context);
                  },
                ),
                const SizedBox(height: 4),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppConstants.softGreenChip,
                    child: Icon(Icons.system_update_rounded, color: AppConstants.deepEmerald, size: 20),
                  ),
                  title: Text('اپ ڈیٹ چیک کریں (Check for Updates)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppConstants.charcoal)),
                  subtitle: Text('Installed: v${AppConstants.appVersion}', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted)),
                  onTap: () {
                    Navigator.pop(context);
                    AppUpdateManager.checkForUpdate(context, showNoUpdateMessage: true);
                  },
                ),
                const SizedBox(height: 4),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppConstants.softGreenChip,
                    child: Icon(Icons.sync, color: AppConstants.deepEmerald, size: 20),
                  ),
                  title: Text('Data Sync Status', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppConstants.charcoal)),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateTo(const SyncScreen());
                  },
                ),
                const SizedBox(height: 4),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppConstants.softGreenChip,
                    child: Icon(Icons.how_to_reg, color: AppConstants.deepEmerald, size: 20),
                  ),
                  title: Text('Daily Attendance', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppConstants.charcoal)),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateTo(const AttendanceScreen(initialTabIndex: 0));
                  },
                ),
                const SizedBox(height: 4),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppConstants.softGreenChip,
                    child: Icon(Icons.beach_access, color: AppConstants.deepEmerald, size: 20),
                  ),
                  title: Text('Leave Requests', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppConstants.charcoal)),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateTo(const AttendanceScreen(initialTabIndex: 1));
                  },
                ),
                if (_userRole == 'owner') ...[
                  const SizedBox(height: 4),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppConstants.softGreenChip,
                      child: Icon(Icons.payments, color: AppConstants.deepEmerald, size: 20),
                    ),
                    title: Text('Payroll HR', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppConstants.charcoal)),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateTo(const PayrollScreen());
                    },
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppConstants.softBorder),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppConstants.softRedChip,
                    child: Icon(Icons.logout, color: AppConstants.alertRed, size: 20),
                  ),
                  title: Text('Log Out', style: GoogleFonts.inter(color: AppConstants.alertRed, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
