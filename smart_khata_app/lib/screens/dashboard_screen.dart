import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import 'inventory_screen.dart';
import 'pos_screen.dart';
import 'khata_screen.dart';
import 'attendance_screen.dart';
import 'payroll_screen.dart';
import 'reports_screen.dart';
import 'voice_command_screen.dart';
import 'sync_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _metrics;
  bool _isLoading = true;
  String _userRole = 'owner';
  String _userName = 'Tariq Kiryana Owner';
  String _storeName = 'Smart Khata Store';
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserAndMetrics();
  }

  Future<void> _loadUserAndMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString(AppConstants.userRoleKey) ?? 'owner';
      _userName = prefs.getString(AppConstants.userNameKey) ?? 'Tariq Kiryana Owner';
      _storeName = prefs.getString(AppConstants.storeNameKey) ?? 'Smart Khata Store';
    });

    try {
      final client = ApiClient();
      final data = await client.get('/reports/dashboard');
      setState(() {
        _metrics = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final todayRevenue = _metrics?['today_revenue'] ?? 12450;
    final todayProfit = _metrics?['today_profit'] ?? 3200;
    final cashCollected = _metrics?['cash_collected'] ?? 8500;
    final lowStockCount = _metrics?['low_stock_count'] ?? 7;

    return Scaffold(
      backgroundColor: AppConstants.creamBg,
      appBar: AppBar(
        backgroundColor: AppConstants.creamBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _storeName,
                  style: GoogleFonts.inter(
                    color: AppConstants.deepEmerald,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppConstants.charcoal),
            onPressed: () {},
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Primary Revenue Banner Card (Design 1 Dashboard)
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
                                "Today's Revenue",
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Today',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'PKR ${todayRevenue.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
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
                                      '18.5%',
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
                                'vs yesterday',
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

                    // 2. 2x2 Metric Grid Cards
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _buildDashboardCard('Orders', '34', '▲ 12%', Icons.assignment_outlined, AppConstants.deepEmerald),
                        _buildDashboardCard('Profit', 'PKR ${todayProfit.toString()}', '▲ 15%', Icons.savings_outlined, AppConstants.deepEmerald),
                        _buildDashboardCard('Cash', 'PKR ${cashCollected.toString()}', '▲ 8%', Icons.account_balance_wallet_outlined, AppConstants.deepEmerald),
                        _buildDashboardCard('Total Products', '142', 'View all', Icons.local_offer_outlined, AppConstants.deepEmerald),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. Low Stock Items Alert Banner Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppConstants.softRedChip,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppConstants.alertRed.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Low Stock Items',
                                  style: GoogleFonts.inter(
                                    color: AppConstants.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$lowStockCount',
                                  style: GoogleFonts.instrumentSerif(
                                    color: AppConstants.charcoal,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                InkWell(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const InventoryScreen()),
                                  ),
                                  child: Text(
                                    'View all',
                                    style: GoogleFonts.inter(
                                      color: AppConstants.textMuted,
                                      fontSize: 12,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppConstants.alertRed.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.error_outline_rounded,
                              color: AppConstants.alertRed,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 4. Quick Action Floating Row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PosScreen())),
                            icon: const Icon(Icons.point_of_sale, color: Colors.white, size: 20),
                            label: Text('NEW SALE (POS)', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceCommandScreen())),
                            icon: const Icon(Icons.mic, color: Colors.white, size: 20),
                            label: Text('VOICE AI', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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

                    // 5. Recent Orders Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Orders',
                          style: GoogleFonts.instrumentSerif(
                            color: AppConstants.charcoal,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PosScreen())),
                          child: Text(
                            'View all',
                            style: GoogleFonts.inter(
                              color: AppConstants.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    _buildOrderTile('ORD-0025', 'Tariq Mehmood', 'PKR 2,450', 'Today, 9:30 AM', 'Paid'),
                    _buildOrderTile('ORD-0024', 'Sajjad Khan', 'PKR 1,850', 'Today, 8:45 AM', 'Paid'),
                    _buildOrderTile('ORD-0023', 'Hassan Ali', 'PKR 3,120', 'Today, 7:20 AM', 'Paid'),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() => _currentNavIndex = index);
          if (index == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()));
          } else if (index == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PosScreen()));
          } else if (index == 3) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const KhataScreen()));
          } else if (index == 4) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
          }
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

  Widget _buildDashboardCard(String title, String value, String subText, IconData icon, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(color: AppConstants.textMuted, fontSize: 13),
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
            children: [
              Text(
                value,
                style: GoogleFonts.instrumentSerif(
                  color: AppConstants.charcoal,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subText,
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
    );
  }

  Widget _buildOrderTile(String id, String name, String amount, String time, String status) {
    return Container(
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
              color: AppConstants.deepEmerald.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_outlined, color: AppConstants.deepEmerald, size: 20),
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
                      color: AppConstants.softGreenChip,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.inter(color: AppConstants.deepEmerald, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
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
                // Drag Handle Pill Bar
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
                    child: Icon(Icons.sync, color: AppConstants.deepEmerald, size: 20),
                  ),
                  title: Text('Data Sync Status', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppConstants.charcoal)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncScreen()));
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
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen(initialTabIndex: 0)));
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
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen(initialTabIndex: 1)));
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
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollScreen()));
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
