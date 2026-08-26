import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/customer.dart';

class KhataScreen extends StatefulWidget {
  const KhataScreen({super.key});

  @override
  State<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends State<KhataScreen> {
  List<Customer> _customers = [];
  bool _isLoading = true;
  int _activeFilter = 0; // 0: All, 1: With Due Balance, 2: Settled
  final _searchController = TextEditingController();

  final List<String> _customerTypes = [
    'Regular (عام گاہک)',
    'Merchant (دکاندار)',
    'Farmer (زمیندار)',
    'Wholesaler (ہول سیلر)',
  ];

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    try {
      final client = ApiClient();
      final data = await client.get('/customers');
      if (data is List) {
        setState(() {
          _customers = data.map((c) => Customer.fromJson(c)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load customers: $e'),
            backgroundColor: AppConstants.alertRed,
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _fetchCustomers,
            ),
          ),
        );
      }
    }
  }

  // ── Create & Update Customer Dialog ────────────────────────────────────────
  void _showAddEditCustomerDialog({Customer? customer}) {
    final isEditing = customer != null;
    final nameController = TextEditingController(text: customer?.name ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final addressController = TextEditingController(text: customer?.address ?? '');
    final openingBalanceController = TextEditingController(text: '0');

    String selectedType = customer?.type ?? 'regular';
    String matchedTypeOption = _customerTypes.firstWhere(
      (t) => t.toLowerCase().startsWith(selectedType.toLowerCase()),
      orElse: () => 'Regular (عام گاہک)',
    );

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Edit Customer / کسٹمر تبدیل کریں' : 'Add Customer / نیا کھاتہ کھولیں',
                        style: GoogleFonts.instrumentSerif(
                          color: AppConstants.charcoal,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppConstants.textMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  // 1. Customer Name
                  Text('Customer Full Name (کسٹمر کا نام) *', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Muhammad Ali / حاجی اسلم',
                      prefixIcon: Icon(Icons.person_outline, color: AppConstants.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Phone Number
                  Text('Phone / WhatsApp Number (موبائل نمبر) *', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '03001234567',
                      prefixIcon: Icon(Icons.phone_outlined, color: AppConstants.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Customer Type Dropdown
                  Text('Customer Category (کسٹمر کی قسم)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: matchedTypeOption,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    items: _customerTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.inter(fontSize: 13))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => matchedTypeOption = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // 4. Address
                  Text('Address / Mohalla (پتہ یا محلہ)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Street 4, Main Bazar Sahiwal',
                      prefixIcon: Icon(Icons.location_on_outlined, color: AppConstants.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 5. Opening Balance (Only for new customers)
                  if (!isEditing) ...[
                    Text('Opening Udhaar Balance (پہلے سے ادھار)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: openingBalanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'e.g. 1500 (Optional)',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: AppConstants.textMuted),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 16),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.deepEmerald,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final phone = phoneController.text.trim();
                              final address = addressController.text.trim();
                              final openingBal = double.tryParse(openingBalanceController.text.trim()) ?? 0.0;

                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter customer name'),
                                    backgroundColor: AppConstants.alertRed,
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              try {
                                final client = ApiClient();
                                final typeClean = matchedTypeOption.split(' (')[0].toLowerCase();
                                final payload = {
                                  'name': name,
                                  'phone': phone,
                                  'address': address,
                                  'type': typeClean,
                                  if (!isEditing) 'opening_balance': openingBal,
                                };

                                if (isEditing) {
                                  await client.put('/customers/${customer.id}', payload);
                                } else {
                                  await client.post('/customers', payload);
                                }

                                if (ctx.mounted) Navigator.pop(ctx);
                                _fetchCustomers();

                                if (mounted) {
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text(isEditing ? '✅ Customer updated successfully' : '✅ New Khata opened for $name'),
                                      backgroundColor: AppConstants.deepEmerald,
                                    ),
                                  );
                                }
                              } catch (err) {
                                setModalState(() => isSubmitting = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('Error: $err'), backgroundColor: AppConstants.alertRed),
                                  );
                                }
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              isEditing ? 'UPDATE CUSTOMER (محفوظ کریں)' : 'OPEN KHATA (کھاتہ درج کریں)',
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Customer Action Menu Bottom Sheet ──────────────────────────────────────
  void _showCustomerActionsModal(Customer customer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: AppConstants.softGreenChip,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(customer.name),
                      style: GoogleFonts.inter(
                        color: AppConstants.deepEmerald,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17, color: AppConstants.charcoal),
                      ),
                      Text(
                        customer.phone.isNotEmpty ? '+92 ${customer.phone}' : 'No phone recorded',
                        style: GoogleFonts.inter(color: AppConstants.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: customer.balanceDue > 0 ? AppConstants.softRedChip : AppConstants.softGreenChip,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    customer.balanceDue > 0
                        ? 'Due: PKR ${customer.balanceDue.toStringAsFixed(0)}'
                        : 'Cleared',
                    style: GoogleFonts.inter(
                      color: customer.balanceDue > 0 ? AppConstants.alertRed : AppConstants.deepEmerald,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action 1: Record Payment
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppConstants.softGreenChip, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.payment_rounded, color: AppConstants.deepEmerald, size: 22),
              ),
              title: Text('Record Payment / وصولی درج کریں', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('Receive cash or online transfer from customer', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                _showRecordPaymentDialog(customer);
              },
            ),

            // Action 2: Send WhatsApp Bill
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF2E7D32), size: 22),
              ),
              title: Text('Send WhatsApp Bill / واٹس ایپ پر بل بھیجیں', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('Send instant reminder statement directly on WhatsApp', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                _sendWhatsAppBill(customer);
              },
            ),

            // Action 3: Transaction History
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppConstants.creamBg, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.history_edu_outlined, color: AppConstants.charcoal, size: 22),
              ),
              title: Text('Khata Statement / کھاتہ ہسٹری', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('View all credit sales and payments for this account', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                _showTransactionHistoryModal(customer);
              },
            ),

            // Action 4: Edit Customer
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 22),
              ),
              title: Text('Edit Customer / معلومات تبدیل کریں', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('Update phone number, address or customer type', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEditCustomerDialog(customer: customer);
              },
            ),

            // Action 5: Delete Customer
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppConstants.softRedChip, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.delete_outline, color: AppConstants.alertRed, size: 22),
              ),
              title: Text('Delete Account / کھاتہ ڈیلیٹ کریں', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: AppConstants.alertRed)),
              subtitle: Text('Permanently remove customer from store records', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteCustomer(customer);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ── Record Payment Dialog ──────────────────────────────────────────────────
  void _showRecordPaymentDialog(Customer customer) {
    final amountController = TextEditingController();
    final noteController = TextEditingController(text: 'Khata payment received');
    String paymentMethod = 'cash'; // cash, jazzcash, easypaisa, bank

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppConstants.surfaceWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Record Payment: ${customer.name}',
              style: GoogleFonts.instrumentSerif(color: AppConstants.charcoal, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Balance Due: PKR ${customer.balanceDue.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(color: AppConstants.alertRed, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(color: AppConstants.charcoal, fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'Payment Received (PKR)',
                    hintText: 'e.g. 500',
                  ),
                ),
                const SizedBox(height: 12),
                Text('Payment Channel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppConstants.textMuted)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('💵 Cash'),
                      selected: paymentMethod == 'cash',
                      onSelected: (val) => setDialogState(() => paymentMethod = 'cash'),
                    ),
                    ChoiceChip(
                      label: const Text('🔴 JazzCash'),
                      selected: paymentMethod == 'jazzcash',
                      onSelected: (val) => setDialogState(() => paymentMethod = 'jazzcash'),
                    ),
                    ChoiceChip(
                      label: const Text('🟢 EasyPaisa'),
                      selected: paymentMethod == 'easypaisa',
                      onSelected: (val) => setDialogState(() => paymentMethod = 'easypaisa'),
                    ),
                    ChoiceChip(
                      label: const Text('🏦 Bank'),
                      selected: paymentMethod == 'bank',
                      onSelected: (val) => setDialogState(() => paymentMethod = 'bank'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  style: GoogleFonts.inter(color: AppConstants.charcoal),
                  decoration: const InputDecoration(
                    labelText: 'Note / تفصیل',
                    hintText: 'e.g. Partial recovery',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('CANCEL', style: GoogleFonts.inter(color: AppConstants.textMuted, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amt = double.tryParse(amountController.text.trim());
                  if (amt == null || amt <= 0) return;
                  try {
                    final client = ApiClient();
                    await client.post('/customers/payments', {
                      'customer_id': customer.id,
                      'amount': amt,
                      'payment_method': paymentMethod,
                      'note': noteController.text.trim(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    _fetchCustomers();
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text('✅ PKR ${amt.toStringAsFixed(0)} recorded for ${customer.name}'),
                          backgroundColor: AppConstants.deepEmerald,
                        ),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: AppConstants.alertRed),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.deepEmerald,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('SAVE PAYMENT', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Send WhatsApp Bill ─────────────────────────────────────────────────────
  void _sendWhatsAppBill(Customer customer) async {
    String phone = customer.phone.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) {
      phone = '92${phone.substring(1)}';
    } else if (!phone.startsWith('92')) {
      phone = '92$phone';
    }

    final message = '''*Smart Khata — کھاتہ بل*
محترم ${customer.name} صاحب،
آپ کے کھاتے کا موجودہ بقایہ: *Rs. ${customer.balanceDue.toStringAsFixed(0)}* ہے۔
برائے مہربانی بقایا رقم کی ادائیگی فرما کر شکریہ کا موقع دیں۔
_اسمارٹ کھاتہ AI اسٹور مینجمنٹ_''';

    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open WhatsApp on this device'), backgroundColor: AppConstants.alertRed),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp'), backgroundColor: AppConstants.alertRed),
        );
      }
    }
  }

  // ── Delete Customer Confirmation ──────────────────────────────────────────
  void _confirmDeleteCustomer(Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Khata Account?',
          style: GoogleFonts.instrumentSerif(color: AppConstants.alertRed, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete ${customer.name}? If they have an outstanding balance (PKR ${customer.balanceDue.toStringAsFixed(0)}), it will be removed.',
          style: GoogleFonts.inter(color: AppConstants.charcoal, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.inter(color: AppConstants.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.alertRed),
            onPressed: () async {
              try {
                final client = ApiClient();
                await client.delete('/customers/${customer.id}');
                if (ctx.mounted) Navigator.pop(ctx);
                _fetchCustomers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('🗑️ Khata for ${customer.name} deleted'), backgroundColor: AppConstants.charcoal),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppConstants.alertRed),
                  );
                }
              }
            },
            child: Text('DELETE', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Transaction History Modal ──────────────────────────────────────────────
  void _showTransactionHistoryModal(Customer customer) async {
    List<dynamic> history = [];
    try {
      final client = ApiClient();
      final data = await client.get('/customers/${customer.id}/history');
      if (data is List) history = data;
    } catch (_) {}

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.surfaceWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${customer.name} — Khata History',
                  style: GoogleFonts.instrumentSerif(color: AppConstants.charcoal, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            Text(
              'Total Balance Due: PKR ${customer.balanceDue.toStringAsFixed(0)}',
              style: GoogleFonts.inter(color: customer.balanceDue > 0 ? AppConstants.alertRed : AppConstants.deepEmerald, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Divider(),
            Expanded(
              child: history.isEmpty
                  ? Center(child: Text('No transaction history found', style: GoogleFonts.inter(color: AppConstants.textMuted)))
                  : ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (c, i) {
                        final item = history[i];
                        final isCreditSale = item['type'] == 'sale_credit';
                        return ListTile(
                          leading: Icon(
                            isCreditSale ? Icons.arrow_upward : Icons.arrow_downward,
                            color: isCreditSale ? AppConstants.alertRed : AppConstants.deepEmerald,
                          ),
                          title: Text(item['description'] ?? '', style: GoogleFonts.inter(color: AppConstants.charcoal, fontWeight: FontWeight.w600)),
                          subtitle: Text(item['date'].toString().split('T')[0], style: GoogleFonts.inter(color: AppConstants.textMuted, fontSize: 12)),
                          trailing: Text(
                            '${isCreditSale ? "+" : "-"} PKR ${item['amount']}',
                            style: GoogleFonts.inter(
                              color: isCreditSale ? AppConstants.alertRed : AppConstants.deepEmerald,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    List<String> parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'C';
  }

  @override
  Widget build(BuildContext context) {
    final filteredCustomers = _customers.where((c) {
      final matchesSearch = _searchController.text.isEmpty ||
          c.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          c.phone.contains(_searchController.text);
      if (!matchesSearch) return false;
      if (_activeFilter == 1) return c.balanceDue > 0;
      if (_activeFilter == 2) return c.balanceDue <= 0;
      return true;
    }).toList();

    double totalUdhaar = _customers.fold(0.0, (sum, c) => sum + (c.balanceDue > 0 ? c.balanceDue : 0.0));

    return Scaffold(
      backgroundColor: AppConstants.creamBg,
      appBar: AppBar(
        backgroundColor: AppConstants.creamBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppConstants.charcoal),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customers & Khata',
              style: GoogleFonts.instrumentSerif(
                color: AppConstants.charcoal,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_customers.length} total • PKR ${totalUdhaar.toStringAsFixed(0)} due',
              style: GoogleFonts.inter(
                color: AppConstants.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: AppConstants.deepEmerald, size: 26),
            tooltip: 'Add Customer',
            onPressed: () => _showAddEditCustomerDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(color: AppConstants.charcoal, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search customers by name or phone',
                hintStyle: GoogleFonts.inter(color: AppConstants.textMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppConstants.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _searchController.clear()),
                      )
                    : null,
              ),
            ),
          ),

          // 2. Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              children: [
                _buildFilterChip('All (${_customers.length})', 0),
                const SizedBox(width: 8),
                _buildFilterChip('Due Balance (${_customers.where((c) => c.balanceDue > 0).length})', 1),
                const SizedBox(width: 8),
                _buildFilterChip('Settled (${_customers.where((c) => c.balanceDue <= 0).length})', 2),
              ],
            ),
          ),

          // 3. Customer List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppConstants.deepEmerald))
                : RefreshIndicator(
                    onRefresh: _fetchCustomers,
                    color: AppConstants.deepEmerald,
                    child: filteredCustomers.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.people_outline, size: 64, color: AppConstants.textMuted),
                                    const SizedBox(height: 12),
                                    Text('No customers found', style: GoogleFonts.inter(color: AppConstants.textMuted, fontSize: 16)),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.deepEmerald),
                                      icon: const Icon(Icons.person_add, color: Colors.white),
                                      label: const Text('Add First Customer', style: TextStyle(color: Colors.white)),
                                      onPressed: () => _showAddEditCustomerDialog(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: filteredCustomers.length,
                        itemBuilder: (ctx, idx) {
                          final c = filteredCustomers[idx];
                          final hasDue = c.balanceDue > 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppConstants.surfaceWhite,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: hasDue ? AppConstants.alertRed.withValues(alpha: 0.3) : AppConstants.softBorder),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: hasDue ? AppConstants.softRedChip : AppConstants.softGreenChip,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    _getInitials(c.name),
                                    style: GoogleFonts.inter(
                                      color: hasDue ? AppConstants.alertRed : AppConstants.deepEmerald,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                c.name,
                                style: GoogleFonts.inter(
                                  color: AppConstants.charcoal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                c.phone.isNotEmpty ? '+92 ${c.phone} • ${c.type}' : c.type,
                                style: GoogleFonts.inter(
                                  color: AppConstants.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    hasDue ? 'Due Balance' : 'Cleared',
                                    style: GoogleFonts.inter(
                                      color: hasDue ? AppConstants.alertRed : AppConstants.deepEmerald,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'PKR ${c.balanceDue.toStringAsFixed(0)}',
                                    style: GoogleFonts.inter(
                                      color: hasDue ? AppConstants.alertRed : AppConstants.deepEmerald,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () => _showCustomerActionsModal(c),
                            ),
                          );
                        },
                      ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditCustomerDialog(),
        backgroundColor: AppConstants.deepEmerald,
        elevation: 3,
        child: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _activeFilter == index;
    Color bg = isSelected
        ? (index == 1 ? AppConstants.softRedChip : AppConstants.deepEmerald)
        : AppConstants.surfaceWhite;
    Color textColor = isSelected
        ? (index == 1 ? AppConstants.alertRed : Colors.white)
        : AppConstants.charcoal;

    return GestureDetector(
      onTap: () => setState(() => _activeFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? (index == 1 ? AppConstants.alertRed : AppConstants.deepEmerald) : AppConstants.softBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: textColor,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
