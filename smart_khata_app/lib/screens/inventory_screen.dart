import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/product.dart';

class InventoryScreen extends StatefulWidget {
  final int initialFilterIndex;
  const InventoryScreen({super.key, this.initialFilterIndex = 0});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product> _products = [];
  bool _isLoading = true;
  late int _activeFilterIndex;
  String? _selectedCategory;
  final _searchController = TextEditingController();

  final List<String> _categories = [
    'All Categories',
    'Grains (اناج)',
    'Flour (آٹا)',
    'Grocery (کریانہ)',
    'Dairy (ڈیری)',
    'Spices (مصالحہ جات)',
    'Oil & Ghee (تیل و گھی)',
    'Beverages (مشروبات)',
    'Snacks (بسکٹ و نمکو)',
    'Personal Care (صابن و شیمپو)',
    'General (متفرق)',
  ];

  final List<String> _units = [
    'kg',
    'litre',
    'piece',
    'packet',
    'bori',
    'gram',
    'dozen',
    'box',
  ];

  @override
  void initState() {
    super.initState();
    _activeFilterIndex = widget.initialFilterIndex;
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final client = ApiClient();
      bool lowStockOnly = _activeFilterIndex == 1;
      String endpoint = '/products?low_stock_only=$lowStockOnly';
      if (_searchController.text.isNotEmpty) {
        endpoint += '&search=${Uri.encodeComponent(_searchController.text.trim())}';
      }
      if (_selectedCategory != null && _selectedCategory != 'All Categories') {
        final cleanCat = _selectedCategory!.split(' (')[0];
        endpoint += '&category=${Uri.encodeComponent(cleanCat)}';
      }
      final data = await client.get(endpoint);
      if (data is List) {
        List<Product> list = data.map((p) => Product.fromJson(p)).toList();
        if (_activeFilterIndex == 2) {
          list = list.where((p) => p.currentStock <= 0).toList();
        }
        setState(() {
          _products = list;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ── Create & Update Modal (Full Form) ──────────────────────────────────────
  void _showAddEditProductDialog({Product? product}) {
    final isEditing = product != null;
    final nameController = TextEditingController(text: product?.name ?? '');
    final urduNameController = TextEditingController(text: product?.urduName ?? '');
    final buyingPriceController = TextEditingController(
      text: product != null ? product.buyingPrice.toStringAsFixed(0) : '',
    );
    final sellingPriceController = TextEditingController(
      text: product != null ? product.sellingPrice.toStringAsFixed(0) : '',
    );
    final stockController = TextEditingController(
      text: product != null ? product.currentStock.toString() : '10',
    );
    final thresholdController = TextEditingController(
      text: product != null ? product.lowStockThreshold.toString() : '5',
    );

    String selectedCat = product?.category ?? 'Grocery';
    // Match dropdown option
    String matchedCategoryOption = _categories.firstWhere(
      (c) => c.toLowerCase().startsWith(selectedCat.toLowerCase()),
      orElse: () => 'Grocery (کریانہ)',
    );

    String selectedUnit = product?.unit ?? 'kg';
    if (!_units.contains(selectedUnit)) selectedUnit = 'kg';

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
                        isEditing ? 'Edit Product / پروڈکٹ تبدیل کریں' : 'Add Product / نیا مال شامل کریں',
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

                  // 1. English Name
                  Text('Product Name (English) *', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Basmati Rice Super Kernal',
                      prefixIcon: Icon(Icons.shopping_bag_outlined, color: AppConstants.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Urdu Name
                  Text('Urdu / Punjabi Name (اردو نام)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: urduNameController,
                    decoration: const InputDecoration(
                      hintText: 'مثال: سپر باسمتی چاول',
                      prefixIcon: Icon(Icons.translate, color: AppConstants.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Category & Unit Row
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Category *', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              initialValue: matchedCategoryOption,
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                              items: _categories
                                  .where((c) => c != 'All Categories')
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.inter(fontSize: 13))))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => matchedCategoryOption = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Unit *', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              initialValue: selectedUnit,
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                              items: _units
                                  .map((u) => DropdownMenuItem(value: u, child: Text(u, style: GoogleFonts.inter(fontSize: 13))))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedUnit = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 4. Prices Row (Cost vs Selling)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Buying Cost (PKR)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: buyingPriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(hintText: 'e.g. 280'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Selling Price (PKR) *', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: sellingPriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(hintText: 'e.g. 320'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 5. Stock & Alert Threshold
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Stock *', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: stockController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(hintText: 'e.g. 50'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Low Stock Alert *', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: thresholdController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(hintText: 'e.g. 5'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
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
                              final sellPrice = double.tryParse(sellingPriceController.text.trim());
                              final buyPrice = double.tryParse(buyingPriceController.text.trim()) ?? (sellPrice != null ? sellPrice * 0.85 : 0.0);
                              final stock = double.tryParse(stockController.text.trim()) ?? 0.0;
                              final threshold = double.tryParse(thresholdController.text.trim()) ?? 5.0;

                              if (name.isEmpty || sellPrice == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter valid product name and selling price'),
                                    backgroundColor: AppConstants.alertRed,
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              try {
                                final client = ApiClient();
                                final categoryClean = matchedCategoryOption.split(' (')[0];
                                final payload = {
                                  'name': name,
                                  'urdu_name': urduNameController.text.trim().isNotEmpty ? urduNameController.text.trim() : name,
                                  'category': categoryClean,
                                  'unit': selectedUnit,
                                  'buying_price': buyPrice,
                                  'selling_price': sellPrice,
                                  'current_stock': stock,
                                  'low_stock_threshold': threshold,
                                };

                                if (isEditing) {
                                  await client.put('/products/${product.id}', payload);
                                } else {
                                  await client.post('/products', payload);
                                }

                                if (ctx.mounted) Navigator.pop(ctx);
                                _fetchProducts();

                                if (mounted) {
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text(isEditing ? '✅ Product updated successfully!' : '✅ Product added to catalog!'),
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
                              isEditing ? 'UPDATE PRODUCT (محفوظ کریں)' : 'SAVE PRODUCT (نیا مال درج کریں)',
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

  // ── Product Action Menu Bottom Sheet ───────────────────────────────────────
  void _showProductActionsBottomSheet(Product product) {
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppConstants.creamBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: AppConstants.deepEmerald, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppConstants.charcoal),
                      ),
                      Text(
                        'Category: ${product.category} • Current Stock: ${product.currentStock} ${product.unit}',
                        style: GoogleFonts.inter(color: AppConstants.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.creamBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat('Cost Price', 'PKR ${product.buyingPrice.toStringAsFixed(0)}'),
                  Container(height: 24, width: 1, color: AppConstants.softBorder),
                  _buildMiniStat('Sell Price', 'PKR ${product.sellingPrice.toStringAsFixed(0)}'),
                  Container(height: 24, width: 1, color: AppConstants.softBorder),
                  _buildMiniStat('Margin', '${((product.sellingPrice - product.buyingPrice) / (product.sellingPrice > 0 ? product.sellingPrice : 1) * 100).toStringAsFixed(0)}%'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Option 1: Quick Adjust Stock
            ListTile(
              leading: const Icon(Icons.swap_vert_circle_outlined, color: AppConstants.deepEmerald),
              title: Text('Adjust Stock / مال میں کمی بیشی', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('Add incoming inventory or write off wastage', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                _showStockAdjustmentDialog(product);
              },
            ),

            // Option 2: Edit Details
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
              title: Text('Edit Product Details / معلومات تبدیل کریں', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('Change name, prices, category or alert limit', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEditProductDialog(product: product);
              },
            ),

            // Option 3: Delete Product
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppConstants.alertRed),
              title: Text('Delete Product / مال ڈیلیٹ کریں', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: AppConstants.alertRed)),
              subtitle: Text('Permanently remove this item from store', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteProduct(product);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(color: AppConstants.textMuted, fontSize: 11)),
        Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.charcoal)),
      ],
    );
  }

  // ── Delete Confirmation ───────────────────────────────────────────────────
  void _confirmDeleteProduct(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Product?',
          style: GoogleFonts.instrumentSerif(color: AppConstants.alertRed, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${product.name}"? This action cannot be undone.',
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
                await client.delete('/products/${product.id}');
                if (ctx.mounted) Navigator.pop(ctx);
                _fetchProducts();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('🗑️ ${product.name} deleted'), backgroundColor: AppConstants.charcoal),
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

  // ── Quick Stock Adjustment ─────────────────────────────────────────────────
  void _showStockAdjustmentDialog(Product product) {
    final qtyController = TextEditingController();
    String adjustmentType = 'add'; // add or deduct

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppConstants.surfaceWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Adjust Stock: ${product.name}',
              style: GoogleFonts.instrumentSerif(color: AppConstants.charcoal, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Stock: ${product.currentStock} ${product.unit}',
                  style: GoogleFonts.inter(color: AppConstants.deepEmerald, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text('➕ Add Stock', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        selected: adjustmentType == 'add',
                        selectedColor: AppConstants.softGreenChip,
                        onSelected: (selected) {
                          if (selected) setDialogState(() => adjustmentType = 'add');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Text('➖ Deduct / Wastage', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        selected: adjustmentType == 'deduct',
                        selectedColor: AppConstants.softRedChip,
                        onSelected: (selected) {
                          if (selected) setDialogState(() => adjustmentType = 'deduct');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(color: AppConstants.charcoal, fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: adjustmentType == 'add' ? 'Quantity to Add (${product.unit})' : 'Quantity to Deduct (${product.unit})',
                    hintText: 'e.g. 10',
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
                  final rawVal = double.tryParse(qtyController.text.trim());
                  if (rawVal == null || rawVal <= 0) return;
                  final change = adjustmentType == 'add' ? rawVal : -rawVal;
                  try {
                    final client = ApiClient();
                    await client.post('/products/adjust-stock', {
                      'product_id': product.id,
                      'quantity_change': change,
                      'reason': adjustmentType == 'add' ? 'purchase_restock' : 'wastage_correction',
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    _fetchProducts();
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('✅ Stock updated for ${product.name}'), backgroundColor: AppConstants.deepEmerald),
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
                child: Text('SAVE ADJUSTMENT', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Category Filter Dialog ─────────────────────────────────────────────────
  void _showCategoryFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Filter by Category', style: GoogleFonts.instrumentSerif(fontSize: 22, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _categories.length,
            itemBuilder: (c, idx) {
              final cat = _categories[idx];
              final isSelected = (_selectedCategory ?? 'All Categories') == cat;
              return ListTile(
                title: Text(cat, style: GoogleFonts.inter(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                trailing: isSelected ? const Icon(Icons.check, color: AppConstants.deepEmerald) : null,
                onTap: () {
                  setState(() => _selectedCategory = cat == 'All Categories' ? null : cat);
                  Navigator.pop(ctx);
                  _fetchProducts();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int lowStockCount = _products.where((p) => p.currentStock <= p.lowStockThreshold && p.currentStock > 0).length;
    int outOfStockCount = _products.where((p) => p.currentStock <= 0).length;

    double totalStockValuation = _products.fold(0.0, (sum, p) => sum + (p.currentStock * p.sellingPrice));
    String valDisplay = totalStockValuation >= 100000
        ? '${(totalStockValuation / 100000).toStringAsFixed(1)}L'
        : '${(totalStockValuation / 1000).toStringAsFixed(1)}k';

    return Scaffold(
      backgroundColor: AppConstants.creamBg,
      appBar: AppBar(
        backgroundColor: AppConstants.creamBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppConstants.charcoal),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Inventory',
          style: GoogleFonts.instrumentSerif(
            color: AppConstants.charcoal,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: _selectedCategory != null ? AppConstants.deepEmerald : AppConstants.charcoal,
            ),
            tooltip: 'Filter Category',
            onPressed: _showCategoryFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppConstants.deepEmerald, size: 28),
            tooltip: 'Add Product',
            onPressed: () => _showAddEditProductDialog(),
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
              onChanged: (_) => _fetchProducts(),
              style: GoogleFonts.inter(color: AppConstants.charcoal, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search products in Urdu or English',
                hintStyle: GoogleFonts.inter(color: AppConstants.textMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: AppConstants.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _fetchProducts();
                        },
                      )
                    : null,
              ),
            ),
          ),

          // 2. Filter Chips Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All (${_products.length})', 0),
                  const SizedBox(width: 8),
                  _buildFilterChip('Low stock ($lowStockCount)', 1),
                  const SizedBox(width: 8),
                  _buildFilterChip('Out of stock ($outOfStockCount)', 2),
                  if (_selectedCategory != null) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(_selectedCategory!.split(' (')[0], style: GoogleFonts.inter(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() => _selectedCategory = null);
                        _fetchProducts();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 3. Stock Summary Metric Banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: AppConstants.surfaceWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppConstants.softBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat('${_products.length}', 'Products'),
                Container(height: 28, width: 1, color: AppConstants.softBorder),
                _buildSummaryStat('$lowStockCount', 'Low stock', isAlert: lowStockCount > 0),
                Container(height: 28, width: 1, color: AppConstants.softBorder),
                _buildSummaryStat('PKR $valDisplay', 'Stock value'),
              ],
            ),
          ),

          // 4. Products List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppConstants.deepEmerald))
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 64, color: AppConstants.textMuted),
                            const SizedBox(height: 12),
                            Text('No products found', style: GoogleFonts.inter(color: AppConstants.textMuted, fontSize: 16)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.deepEmerald),
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text('Add First Product', style: TextStyle(color: Colors.white)),
                              onPressed: () => _showAddEditProductDialog(),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: _products.length,
                        itemBuilder: (ctx, idx) {
                          final p = _products[idx];
                          final isOut = p.currentStock <= 0;
                          final isLow = p.currentStock <= p.lowStockThreshold && !isOut;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppConstants.surfaceWhite,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isOut ? AppConstants.alertRed.withValues(alpha: 0.4) : AppConstants.softBorder),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isOut
                                      ? AppConstants.softRedChip
                                      : (isLow ? const Color(0xFFFFF7ED) : AppConstants.creamBg),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  color: isOut ? AppConstants.alertRed : (isLow ? Colors.orange : AppConstants.deepEmerald),
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                p.name,
                                style: GoogleFonts.inter(
                                  color: AppConstants.charcoal,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                'PKR ${p.sellingPrice.toStringAsFixed(0)} / ${p.unit} • ${p.category}',
                                style: GoogleFonts.inter(
                                  color: AppConstants.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${p.currentStock} ${p.unit}',
                                        style: GoogleFonts.inter(
                                          color: isOut || isLow ? AppConstants.alertRed : AppConstants.charcoal,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isOut ? 'Out of stock' : (isLow ? 'Low stock' : 'In stock'),
                                        style: GoogleFonts.inter(
                                          color: isOut || isLow ? AppConstants.alertRed : AppConstants.deepEmerald,
                                          fontSize: 11,
                                          fontWeight: isOut || isLow ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right, color: AppConstants.textMuted, size: 20),
                                ],
                              ),
                              onTap: () => _showProductActionsBottomSheet(p),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditProductDialog(),
        backgroundColor: AppConstants.deepEmerald,
        elevation: 3,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _activeFilterIndex == index;
    Color bg = isSelected
        ? (index == 1 || index == 2 ? AppConstants.softRedChip : AppConstants.deepEmerald)
        : AppConstants.surfaceWhite;
    Color textColor = isSelected
        ? (index == 1 || index == 2 ? AppConstants.alertRed : Colors.white)
        : AppConstants.charcoal;

    return GestureDetector(
      onTap: () {
        setState(() => _activeFilterIndex = index);
        _fetchProducts();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? (index == 1 || index == 2 ? AppConstants.alertRed : AppConstants.deepEmerald) : AppConstants.softBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: textColor,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String value, String label, {bool isAlert = false}) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.instrumentSerif(
            color: isAlert ? AppConstants.alertRed : AppConstants.charcoal,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppConstants.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
