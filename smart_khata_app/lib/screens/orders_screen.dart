import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/receipt_helper.dart';
import 'pos_screen.dart';

class OrdersScreen extends StatefulWidget {
  final String? initialFilter; // 'all', 'paid', 'credit', 'today'
  const OrdersScreen({super.key, this.initialFilter});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<dynamic> _allOrders = [];
  List<dynamic> _filteredOrders = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'paid', 'credit', 'today'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _selectedFilter = widget.initialFilter!;
    }
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final client = ApiClient();
      final data = await client.get('/orders/');
      if (data is List) {
        if (!mounted) return;
        setState(() {
          _allOrders = data.reversed.toList(); // newest first
          _applyFilters();
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final now = DateTime.now();
    _filteredOrders = _allOrders.where((order) {
      final customerName = (order['customer_name'] ?? '').toString().toLowerCase();
      final orderId = (order['id'] ?? '').toString().toLowerCase();
      final items = (order['line_items'] as List<dynamic>? ?? [])
          .map((i) => (i['product_name'] ?? '').toString().toLowerCase())
          .join(' ');

      // Search match
      final query = _searchQuery.toLowerCase();
      final matchesQuery = query.isEmpty ||
          customerName.contains(query) ||
          orderId.contains(query) ||
          items.contains(query);

      if (!matchesQuery) return false;

      // Status match
      final khata = (order['amount_added_to_khata'] ?? 0.0) > 0;
      final timeStr = order['created_at']?.toString() ?? '';

      if (_selectedFilter == 'paid') {
        return !khata;
      } else if (_selectedFilter == 'credit') {
        return khata;
      } else if (_selectedFilter == 'today') {
        try {
          final dt = DateTime.parse(timeStr).toLocal();
          return dt.year == now.year && dt.month == now.month && dt.day == now.day;
        } catch (_) {
          return true;
        }
      }

      return true;
    }).toList();
  }

  String _formatMoney(num val) {
    return NumberFormat('#,##0').format(val);
  }

  double get _totalVolume => _filteredOrders.fold(0.0, (sum, o) => sum + (o['total_amount'] ?? 0.0).toDouble());
  double get _totalCash => _filteredOrders.fold(0.0, (sum, o) => sum + (o['amount_paid_now'] ?? (o['total_amount'] ?? 0.0)).toDouble());
  double get _totalKhata => _filteredOrders.fold(0.0, (sum, o) => sum + (o['amount_added_to_khata'] ?? 0.0).toDouble());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.creamBg,
      appBar: AppBar(
        title: Text(
          'Orders & Receipts (آرڈرز)',
          style: GoogleFonts.instrumentSerif(color: AppConstants.charcoal, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppConstants.creamBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppConstants.charcoal),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppConstants.deepEmerald),
            tooltip: 'Refresh Orders',
            onPressed: _loadOrders,
          ),
          IconButton(
            icon: const Icon(Icons.point_of_sale, color: AppConstants.deepEmerald),
            tooltip: 'New Sale POS',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const PosScreen()));
              _loadOrders();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppConstants.deepEmerald,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('نئی سیل (New POS Sale)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const PosScreen()));
          _loadOrders();
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppConstants.deepEmerald))
          : RefreshIndicator(
              color: AppConstants.deepEmerald,
              onRefresh: _loadOrders,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      // 1. Search Bar & Filter Chips
                      Container(
                        color: AppConstants.creamBg,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                  _applyFilters();
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'گاہک، رسید نمبر یا سامان تلاش کریں...',
                                prefixIcon: const Icon(Icons.search, color: AppConstants.deepEmerald),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = '';
                                            _applyFilters();
                                          });
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppConstants.softBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppConstants.softBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppConstants.deepEmerald, width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip('all', 'All (${_allOrders.length})'),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('today', 'Today (آج)'),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('paid', 'Cash (نقد)'),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('credit', 'Khata (ادھار)'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 2. Financial Summary Banner for Filtered View
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppConstants.surfaceWhite,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppConstants.softBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text('آرڈرز', style: GoogleFonts.inter(fontSize: 11, color: AppConstants.textMuted)),
                                const SizedBox(height: 2),
                                Text('${_filteredOrders.length}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.charcoal)),
                              ],
                            ),
                            Container(width: 1, height: 24, color: AppConstants.softBorder),
                            Column(
                              children: [
                                Text('کل سیل', style: GoogleFonts.inter(fontSize: 11, color: AppConstants.textMuted)),
                                const SizedBox(height: 2),
                                Text('PKR ${_formatMoney(_totalVolume)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.deepEmerald)),
                              ],
                            ),
                            Container(width: 1, height: 24, color: AppConstants.softBorder),
                            Column(
                              children: [
                                Text('نقد (Cash)', style: GoogleFonts.inter(fontSize: 11, color: AppConstants.textMuted)),
                                const SizedBox(height: 2),
                                Text('PKR ${_formatMoney(_totalCash)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.charcoal)),
                              ],
                            ),
                            Container(width: 1, height: 24, color: AppConstants.softBorder),
                            Column(
                              children: [
                                Text('ادھار (Khata)', style: GoogleFonts.inter(fontSize: 11, color: AppConstants.alertRed)),
                                const SizedBox(height: 2),
                                Text('PKR ${_formatMoney(_totalKhata)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.alertRed)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 3. Orders List
                      Expanded(
                        child: _filteredOrders.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.receipt_long_outlined, size: 54, color: AppConstants.textMuted),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchQuery.isNotEmpty ? 'کوئی آرڈر نہیں ملا' : 'اس کیٹیگری میں کوئی آرڈر موجود نہیں ہے',
                                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.charcoal),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'نئی سیل شروع کرنے کے لیے بٹن دبائیں۔',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
                                itemCount: _filteredOrders.length,
                                itemBuilder: (context, index) {
                                  final order = _filteredOrders[index];
                                  return _buildOrderCard(order);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = key;
          _applyFilters();
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.deepEmerald : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppConstants.deepEmerald : AppConstants.softBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppConstants.charcoal,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['id'] ?? 'ORD-####';
    final customerName = order['customer_name'] ?? 'Walk-in Customer';
    final total = (order['total_amount'] ?? 0.0).toDouble();
    final paidNow = (order['amount_paid_now'] ?? total).toDouble();
    final khata = (order['amount_added_to_khata'] ?? 0.0).toDouble();
    final isKhata = khata > 0;
    final timeStr = ReceiptHelper.formatDateTime(order['created_at']);
    final items = order['line_items'] as List<dynamic>? ?? [];
    final itemsSummary = items.isEmpty
        ? 'General kiryana purchase'
        : items.map((it) => "${it['product_name'] ?? 'Item'} (${it['quantity'] ?? 1})").join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: InkWell(
        onTap: () => ReceiptHelper.showReceiptDialog(context, order),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Order ID + Status Chip + Total PKR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isKhata ? AppConstants.softRedChip : AppConstants.softGreenChip,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isKhata ? Icons.menu_book : Icons.check_circle_outline,
                          color: isKhata ? AppConstants.alertRed : AppConstants.deepEmerald,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(orderId, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(customerName, style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'PKR ${_formatMoney(total)}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppConstants.charcoal),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isKhata ? AppConstants.softRedChip : AppConstants.softGreenChip,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isKhata ? 'ادھار / Credit' : 'نقد / Paid',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isKhata ? AppConstants.alertRed : AppConstants.deepEmerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 18, color: AppConstants.softBorder),
              // Items description snippet
              Text(
                itemsSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, color: AppConstants.charcoal),
              ),
              if (isKhata) ...[
                const SizedBox(height: 4),
                Text(
                  'وصول: PKR ${_formatMoney(paidNow)} • ادھار کھاتہ: PKR ${_formatMoney(khata)}',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppConstants.alertRed),
                ),
              ],
              const SizedBox(height: 8),
              // Footer: Date & Quick Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(timeStr, style: GoogleFonts.inter(fontSize: 11, color: AppConstants.textMuted)),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => ReceiptHelper.shareReceipt(context, order),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.share, size: 14, color: Color(0xFF25D366)),
                              const SizedBox(width: 4),
                              Text('Share', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1B9E4B))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => ReceiptHelper.printReceiptPdf(order),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppConstants.deepEmerald.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.print, size: 14, color: AppConstants.deepEmerald),
                              const SizedBox(width: 4),
                              Text('Print', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.deepEmerald)),
                            ],
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
      ),
    );
  }
}
