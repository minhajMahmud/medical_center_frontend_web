import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:backend_client/backend_client.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../utils/csv_exporter.dart';
import '../../widgets/common/dashboard_shell.dart';

class AdminInventoryPage extends StatefulWidget {
  const AdminInventoryPage({super.key});

  @override
  State<AdminInventoryPage> createState() => _AdminInventoryPageState();
}

class _AdminInventoryPageState extends State<AdminInventoryPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _activeTab = 'ALL';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<RoleDashboardController>().loadAdminInventoryOnly();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showAddInventoryDialog(
    BuildContext context,
    RoleDashboardController controller,
  ) async {
    final itemNameCtrl = TextEditingController();
    final minStockCtrl = TextEditingController(text: '0');
    final initialStockCtrl = TextEditingController(text: '0');
    final newCategoryCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();

    var dialogTab = 'item';
    var selectedCategoryId = controller.adminInventoryCategories.isNotEmpty
        ? controller.adminInventoryCategories.first.categoryId
        : null;
    var selectedUnit = 'Units';
    var selectedType = 'Medicine';
    var canRestockByDispenser = true;
    var submitting = false;

    Future<void> submitItem(
      StateSetter setDialogState,
      BuildContext dialogContext,
    ) async {
      final messenger = ScaffoldMessenger.of(context);
      final itemName = itemNameCtrl.text.trim();
      final minStock = int.tryParse(minStockCtrl.text.trim()) ?? -1;
      final initialStock = int.tryParse(initialStockCtrl.text.trim()) ?? -1;

      if (itemName.isEmpty || selectedCategoryId == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Item name and category are required.')),
        );
        return;
      }
      if (minStock < 0 || initialStock < 0) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Minimum and initial stock must be 0 or more.'),
          ),
        );
        return;
      }

      setDialogState(() => submitting = true);
      final ok = await controller.addAdminInventoryItem(
        categoryId: selectedCategoryId!,
        itemName: itemName,
        unit: selectedUnit,
        minimumStock: minStock,
        initialStock: initialStock,
        canRestockDispenser: canRestockByDispenser,
      );

      if (!mounted) return;
      setDialogState(() => submitting = false);

      if (ok) {
        if (!dialogContext.mounted) return;
        Navigator.of(dialogContext).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text('$selectedType item "$itemName" added successfully.'),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(controller.error ?? 'Failed to save inventory item.'),
          ),
        );
      }
    }

    Future<void> submitCategory(
      StateSetter setDialogState,
      BuildContext dialogContext,
    ) async {
      final messenger = ScaffoldMessenger.of(context);
      final name = newCategoryCtrl.text.trim();
      final desc = descriptionCtrl.text.trim();

      if (name.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Category name is required.')),
        );
        return;
      }

      setDialogState(() => submitting = true);
      final ok = await controller.addAdminInventoryCategory(
        name: name,
        description: desc.isEmpty ? null : desc,
      );

      if (!mounted) return;
      setDialogState(() => submitting = false);

      if (ok) {
        if (!dialogContext.mounted) return;
        Navigator.of(dialogContext).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category "$name" created successfully.')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(controller.error ?? 'Failed to create category.'),
          ),
        );
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: !submitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 720,
            padding: const EdgeInsets.all(0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 14, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Inventory Entry',
                              style: Theme.of(ctx).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Create a new medicine record or define a storage category.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: submitting
                            ? null
                            : () => Navigator.of(ctx).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                  child: Row(
                    children: [
                      _DialogTabButton(
                        label: 'New Item',
                        selected: dialogTab == 'item',
                        icon: Icons.local_hospital_outlined,
                        onTap: () => setDialogState(() => dialogTab = 'item'),
                      ),
                      const SizedBox(width: 10),
                      _DialogTabButton(
                        label: 'New Category',
                        selected: dialogTab == 'category',
                        icon: Icons.category_outlined,
                        onTap: () =>
                            setDialogState(() => dialogTab = 'category'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: dialogTab == 'item'
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _DialogFieldLabel('Item Name'),
                              TextField(
                                controller: itemNameCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. Paracetamol 500mg',
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _DialogFieldLabel('Category'),
                                        DropdownButtonFormField<int>(
                                          initialValue: selectedCategoryId,
                                          isExpanded: true,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                          ),
                                          items: controller
                                              .adminInventoryCategories
                                              .where(
                                                (c) => c.categoryId != null,
                                              )
                                              .map(
                                                (c) => DropdownMenuItem<int>(
                                                  value: c.categoryId,
                                                  child: Text(c.categoryName),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: submitting
                                              ? null
                                              : (value) => setDialogState(
                                                  () => selectedCategoryId =
                                                      value,
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _DialogFieldLabel(
                                          'Type of Medicine',
                                        ),
                                        DropdownButtonFormField<String>(
                                          initialValue: selectedType,
                                          isExpanded: true,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Medicine',
                                              child: Text('Medicine'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Equipment',
                                              child: Text('Equipment'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Disposable',
                                              child: Text('Disposable'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Supply',
                                              child: Text('Supply'),
                                            ),
                                          ],
                                          onChanged: submitting
                                              ? null
                                              : (value) => setDialogState(
                                                  () => selectedType =
                                                      value ?? 'Medicine',
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _DialogFieldLabel(
                                          'Minimum Stock Level',
                                        ),
                                        TextField(
                                          controller: minStockCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            hintText: '0',
                                            isDense: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _DialogFieldLabel(
                                          'Initial Stock',
                                        ),
                                        TextField(
                                          controller: initialStockCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            hintText: '0',
                                            isDense: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _DialogFieldLabel('Unit'),
                                        DropdownButtonFormField<String>(
                                          initialValue: selectedUnit,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Units',
                                              child: Text('Units'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Boxes',
                                              child: Text('Boxes'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Sets',
                                              child: Text('Sets'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Bags',
                                              child: Text('Bags'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Vials',
                                              child: Text('Vials'),
                                            ),
                                          ],
                                          onChanged: submitting
                                              ? null
                                              : (value) => setDialogState(
                                                  () => selectedUnit =
                                                      value ?? 'Units',
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: CheckboxListTile(
                                      value: canRestockByDispenser,
                                      onChanged: submitting
                                          ? null
                                          : (value) => setDialogState(
                                              () => canRestockByDispenser =
                                                  value ?? true,
                                            ),
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      title: const Text(
                                        'Dispenser can restock',
                                      ),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                    ),
                                  ),
                                ],
                              ),
                              if (controller.adminInventoryCategories.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(
                                    'No categories found. Please create a category first.',
                                    style: TextStyle(
                                      color: Color(0xFFB45309),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _DialogFieldLabel('New Category Name'),
                              TextField(
                                controller: newCategoryCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Create category on the fly',
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const _DialogFieldLabel('Description'),
                              TextField(
                                controller: descriptionCtrl,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Category usage and storage requirements...',
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: submitting
                            ? null
                            : () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 170,
                        child: FilledButton.icon(
                          onPressed: submitting
                              ? null
                              : () {
                                  if (dialogTab == 'item') {
                                    submitItem(setDialogState, ctx);
                                  } else {
                                    submitCategory(setDialogState, ctx);
                                  }
                                },
                          icon: submitting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined, size: 16),
                          label: Text(
                            dialogTab == 'item'
                                ? 'Save Inventory Item'
                                : 'Save Category',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRestock(
    RoleDashboardController controller,
    InventoryItemInfo item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final qtyCtrl = TextEditingController(text: '1');
    var mode = 'IN';
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('Update Stock • ${item.itemName}'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current: ${item.currentQuantity} ${item.unit}',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(
                    labelText: 'Transaction Type',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'IN', child: Text('Stock In')),
                    DropdownMenuItem(value: 'OUT', child: Text('Stock Out')),
                  ],
                  onChanged: submitting
                      ? null
                      : (v) => setStateDialog(() => mode = v ?? 'IN'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final qty = int.tryParse(qtyCtrl.text.trim()) ?? -1;
                      if (qty <= 0) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid quantity.'),
                          ),
                        );
                        return;
                      }
                      setStateDialog(() => submitting = true);
                      final ok = await controller.updateAdminInventoryStock(
                        itemId: item.itemId,
                        quantity: qty,
                        type: mode,
                      );
                      if (!mounted) return;
                      setStateDialog(() => submitting = false);
                      if (ok) {
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Stock ${mode == 'IN' ? 'added' : 'removed'} successfully.',
                            ),
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              controller.error ?? 'Failed to update stock.',
                            ),
                          ),
                        );
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleThreshold(
    RoleDashboardController controller,
    InventoryItemInfo item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final thresholdCtrl = TextEditingController(
      text: item.minimumStock.toString(),
    );
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('Update Threshold • ${item.itemName}'),
          content: SizedBox(
            width: 360,
            child: TextField(
              controller: thresholdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minimum Stock Level',
                isDense: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final threshold =
                          int.tryParse(thresholdCtrl.text.trim()) ?? -1;
                      if (threshold < 0) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Threshold must be 0 or greater.'),
                          ),
                        );
                        return;
                      }
                      setStateDialog(() => submitting = true);
                      final ok = await controller.updateAdminMinimumThreshold(
                        itemId: item.itemId,
                        newThreshold: threshold,
                      );
                      if (!mounted) return;
                      setStateDialog(() => submitting = false);
                      if (ok) {
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Threshold updated successfully.'),
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              controller.error ?? 'Failed to update threshold.',
                            ),
                          ),
                        );
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTogglePermission(
    RoleDashboardController controller,
    InventoryItemInfo item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final next = !item.canRestockDispenser;
    final ok = await controller.updateAdminDispenserRestockFlag(
      itemId: item.itemId,
      canRestock: next,
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (next
                    ? 'Dispenser restock enabled.'
                    : 'Dispenser restock disabled.')
              : (controller.error ?? 'Failed to update restock permission.'),
        ),
      ),
    );
  }

  String _statusOf(InventoryItemInfo item) {
    if (item.currentQuantity <= 0) return 'Out of Stock';
    if (item.currentQuantity <= item.minimumStock) return 'Low Stock';
    return 'In Stock';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'In Stock':
        return const Color(0xFF16A34A);
      case 'Low Stock':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFFDC2626);
    }
  }

  void _downloadBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  String _buildInventoryCsv(List<InventoryItemInfo> items) {
    final rows = <List<String>>[
      const [
        'Item Name',
        'Category',
        'Current Quantity',
        'Unit',
        'Minimum Stock',
        'Status',
        'Dispenser Restock',
      ],
      ...items.map(
        (item) => [
          item.itemName,
          item.categoryName,
          item.currentQuantity.toString(),
          item.unit,
          item.minimumStock.toString(),
          _statusOf(item),
          item.canRestockDispenser ? 'Allowed' : 'Restricted',
        ],
      ),
    ];

    return rows.map((row) => row.map(_csvCell).join(',')).join('\n');
  }

  Future<void> _exportInventoryCsv({
    required List<InventoryItemInfo> items,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final fileDate = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await exportCsvFile(
        fileName: 'inventory_report_$fileDate.csv',
        csvContent: _buildInventoryCsv(items),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Inventory CSV exported successfully.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to export inventory CSV: $e')),
      );
    }
  }

  bool _matchesTab(InventoryItemInfo item, String tab) {
    if (tab == 'ALL') return true;
    final c = item.categoryName.toLowerCase();
    if (tab == 'MEDICINES') {
      return c.contains('medicine') ||
          c.contains('drug') ||
          c.contains('pharma');
    }
    if (tab == 'EQUIPMENT') {
      return c.contains('equipment') ||
          c.contains('device') ||
          c.contains('instrument');
    }
    if (tab == 'DISPOSABLES') {
      return c.contains('disposable') ||
          c.contains('supply') ||
          c.contains('consumable');
    }
    return true;
  }

  Future<void> _exportInventoryPdf({
    required List<InventoryItemInfo> items,
    required String activeTab,
    required String query,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final doc = pw.Document();
      final exportedAt = DateTime.now();
      final fileDate = DateFormat('yyyyMMdd_HHmm').format(exportedAt);
      final logoBytes = (await rootBundle.load(
        'assets/images/nstu_logo.jpg',
      )).buffer.asUint8List();
      final logoImage = pw.MemoryImage(logoBytes);

      final totalUnits = items.fold<int>(
        0,
        (sum, i) => sum + i.currentQuantity,
      );
      final inStock = items
          .where((i) => i.currentQuantity > i.minimumStock)
          .length;
      final lowStock = items
          .where(
            (i) => i.currentQuantity > 0 && i.currentQuantity <= i.minimumStock,
          )
          .length;
      final outOfStock = items.where((i) => i.currentQuantity <= 0).length;
      final filterLabel = switch (activeTab) {
        'MEDICINES' => 'Medicines',
        'EQUIPMENT' => 'Equipment',
        'DISPOSABLES' => 'Disposables',
        _ => 'All Items',
      };

      pw.Widget buildSummaryCard(String title, String value, String subtitle) {
        return pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8FAFC'),
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromHex('#64748B'),
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 18,
                    color: PdfColor.fromHex('#0F172A'),
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  subtitle,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromHex('#64748B'),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      doc.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.all(28),
            theme: pw.ThemeData.withFont(
              base: pw.Font.helvetica(),
              bold: pw.Font.helveticaBold(),
            ),
          ),
          build: (_) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#0F766E'),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 76,
                    height: 76,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(14),
                    ),
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'NSTU Medical Center',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Inventory Status Report',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(exportedAt)}',
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('#D1FAE5'),
                            fontSize: 11,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Noakhali Science and Technology University',
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('#CCFBF1'),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'Filter: $filterLabel',
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColor.fromHex('#334155'),
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      query.isEmpty ? 'Search: None' : 'Search: $query',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColor.fromHex('#334155'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              children: [
                buildSummaryCard(
                  'Items in Report',
                  items.length.toString(),
                  'Filtered records',
                ),
                pw.SizedBox(width: 10),
                buildSummaryCard(
                  'Total Units',
                  totalUnits.toString(),
                  'Current stock quantity',
                ),
                pw.SizedBox(width: 10),
                buildSummaryCard(
                  'Low / Out',
                  '$lowStock / $outOfStock',
                  'Needs replenishment attention',
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                buildSummaryCard(
                  'In Stock',
                  inStock.toString(),
                  'Above minimum threshold',
                ),
                pw.SizedBox(width: 10),
                buildSummaryCard(
                  'Low Stock',
                  lowStock.toString(),
                  'At or below minimum',
                ),
                pw.SizedBox(width: 10),
                buildSummaryCard(
                  'Out of Stock',
                  outOfStock.toString(),
                  'No units currently available',
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: PdfColor.fromHex('#DDE5EE')),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Detailed Inventory List',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#0F172A'),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  if (items.isEmpty)
                    pw.Text(
                      'No inventory items match the current filters.',
                      style: pw.TextStyle(color: PdfColor.fromHex('#64748B')),
                    )
                  else
                    pw.TableHelper.fromTextArray(
                      headerStyle: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#334155'),
                        fontSize: 9,
                      ),
                      headerDecoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                      ),
                      cellStyle: const pw.TextStyle(fontSize: 9),
                      cellPadding: const pw.EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      border: pw.TableBorder.all(
                        color: PdfColor.fromHex('#E2E8F0'),
                        width: 0.6,
                      ),
                      headers: const [
                        'Item',
                        'Category',
                        'Stock',
                        'Minimum',
                        'Status',
                        'Dispenser Restock',
                      ],
                      data: items.map((item) {
                        final status = _statusOf(item);
                        return [
                          item.itemName,
                          item.categoryName,
                          '${item.currentQuantity} ${item.unit}',
                          item.minimumStock.toString(),
                          status,
                          item.canRestockDispenser ? 'Allowed' : 'Restricted',
                        ];
                      }).toList(),
                      cellAlignments: {
                        2: pw.Alignment.centerLeft,
                        3: pw.Alignment.center,
                        4: pw.Alignment.center,
                        5: pw.Alignment.center,
                      },
                      rowDecoration: pw.BoxDecoration(color: PdfColors.white),
                      oddRowDecoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#FCFDFE'),
                      ),
                    ),
                ],
              ),
            ),
            if (items.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                'Report generated from the currently filtered inventory view in the admin dashboard.',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColor.fromHex('#64748B'),
                ),
              ),
            ],
          ],
        ),
      );

      final bytes = await doc.save();
      _downloadBytes(
        bytes: bytes,
        fileName: 'inventory_report_$fileDate.pdf',
        mimeType: 'application/pdf',
      );

      messenger.showSnackBar(
        const SnackBar(content: Text('Inventory PDF exported successfully.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to export inventory PDF: $e')),
      );
    }
  }

  Widget _buildKpiCard({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String value,
    required String chip,
    required Color chipColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: chipColor),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chip,
                  style: TextStyle(
                    color: chipColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 34,
              height: 1,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();
    final routeQuery =
        (GoRouterState.of(context).uri.queryParameters['q'] ?? '').trim();
    if (_searchCtrl.text.isEmpty && routeQuery.isNotEmpty) {
      _searchCtrl.text = routeQuery;
    }

    final query = _searchCtrl.text.trim().toLowerCase();

    final tabFiltered = c.adminInventory
        .where((i) => _matchesTab(i, _activeTab))
        .toList();

    final filteredInventory = query.isEmpty
        ? tabFiltered
        : tabFiltered.where((i) {
            final haystack =
                '${i.itemName} ${i.categoryName} ${i.unit} ${i.currentQuantity} ${i.minimumStock} ${_statusOf(i)}'
                    .toLowerCase();
            return haystack.contains(query);
          }).toList();

    final totalUnits = c.adminInventory.fold<int>(
      0,
      (sum, i) => sum + i.currentQuantity,
    );
    final inStock = c.adminInventory
        .where((i) => i.currentQuantity > i.minimumStock)
        .length;
    final lowStock = c.adminInventory
        .where(
          (i) => i.currentQuantity > 0 && i.currentQuantity <= i.minimumStock,
        )
        .length;
    final outOfStock = c.adminInventory
        .where((i) => i.currentQuantity <= 0)
        .length;

    const tabs = [
      ('ALL', 'All Items'),
      ('MEDICINES', 'Medicines'),
      ('EQUIPMENT', 'Equipment'),
      ('DISPOSABLES', 'Disposables'),
    ];

    return DashboardShell(
      child: c.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inventory Overview',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Real-time status of Medical Center central supplies',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _exportInventoryPdf(
                        items: filteredInventory,
                        activeTab: _activeTab,
                        query: query,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('Export PDF'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _exportInventoryCsv(items: filteredInventory),
                      icon: const Icon(Icons.table_view_rounded, size: 18),
                      label: const Text('Export CSV'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () => _showAddInventoryDialog(context, c),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add New Item'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: [
                    _buildKpiCard(
                      icon: Icons.inventory_2_outlined,
                      iconBg: const Color(0xFFE8F1FF),
                      title: 'Total Items',
                      value: totalUnits.toString(),
                      chip: '+2.4%',
                      chipColor: const Color(0xFF16A34A),
                    ),
                    _buildKpiCard(
                      icon: Icons.check_circle_outline_rounded,
                      iconBg: const Color(0xFFEAFBF1),
                      title: 'In Stock',
                      value: inStock.toString(),
                      chip: 'Stable',
                      chipColor: const Color(0xFF16A34A),
                    ),
                    _buildKpiCard(
                      icon: Icons.warning_amber_rounded,
                      iconBg: const Color(0xFFFFF7ED),
                      title: 'Low Stock',
                      value: lowStock.toString(),
                      chip: '-5.0%',
                      chipColor: const Color(0xFFD97706),
                    ),
                    _buildKpiCard(
                      icon: Icons.cancel_outlined,
                      iconBg: const Color(0xFFFEF2F2),
                      title: 'Out of Stock',
                      value: outOfStock.toString(),
                      chip: 'Alert',
                      chipColor: const Color(0xFFDC2626),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final tab in tabs)
                                    _InventoryTabButton(
                                      label: tab.$2,
                                      selected: _activeTab == tab.$1,
                                      onTap: () {
                                        setState(() => _activeTab = tab.$1);
                                      },
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sort by:',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Recently Added',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 240,
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: 'Search items...',
                                  prefixIcon: Icon(Icons.search_rounded),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      const _InventoryTableHeader(),
                      const Divider(height: 1),
                      if (filteredInventory.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No inventory items found for current filters.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        )
                      else
                        ...filteredInventory.take(12).toList().asMap().entries.map((
                          entry,
                        ) {
                          final index = entry.key;
                          final i = entry.value;
                          final status = _statusOf(i);
                          final statusColor = _statusColor(status);
                          return Column(
                            children: [
                              _InventoryRow(
                                itemName: i.itemName,
                                sku:
                                    'SKU: INV-${i.itemId.toString().padLeft(4, '0')}',
                                category: i.categoryName,
                                stock: '${i.currentQuantity} ${i.unit}',
                                status: status,
                                statusColor: statusColor,
                                expiry: 'N/A',
                                canRestock: i.canRestockDispenser,
                                onRestock: () => _handleRestock(c, i),
                                onThreshold: () => _handleThreshold(c, i),
                                onTogglePermission: () =>
                                    _handleTogglePermission(c, i),
                              ),
                              if (index !=
                                  filteredInventory.take(12).length - 1)
                                const Divider(height: 1),
                            ],
                          );
                        }),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                        child: Row(
                          children: [
                            Text(
                              'Showing 1 to ${filteredInventory.isEmpty ? 0 : filteredInventory.take(12).length} of ${filteredInventory.length} results',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            const _PageButton(icon: Icons.chevron_left_rounded),
                            const SizedBox(width: 6),
                            const _PageNumberButton(label: '1', selected: true),
                            const SizedBox(width: 6),
                            const _PageNumberButton(label: '2'),
                            const SizedBox(width: 6),
                            const _PageNumberButton(label: '3'),
                            const SizedBox(width: 6),
                            const _PageButton(
                              icon: Icons.chevron_right_rounded,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Showing ${filteredInventory.length} result(s) for "$query"',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _InventoryTabButton extends StatelessWidget {
  const _InventoryTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? const Color(0xFF2563EB) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _InventoryTableHeader extends StatelessWidget {
  const _InventoryTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 12,
      color: Color(0xFF94A3B8),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('MEDICINE/ITEM NAME', style: style)),
          Expanded(flex: 2, child: Text('CATEGORY', style: style)),
          Expanded(flex: 2, child: Text('STOCK LEVEL', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          Expanded(flex: 1, child: Text('EXPIRY', style: style)),
          SizedBox(width: 68, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({
    required this.itemName,
    required this.sku,
    required this.category,
    required this.stock,
    required this.status,
    required this.statusColor,
    required this.expiry,
    required this.canRestock,
    required this.onRestock,
    required this.onThreshold,
    required this.onTogglePermission,
  });

  final String itemName;
  final String sku;
  final String category;
  final String stock;
  final String status;
  final Color statusColor;
  final String expiry;
  final bool canRestock;
  final VoidCallback onRestock;
  final VoidCallback onThreshold;
  final VoidCallback onTogglePermission;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sku,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  category,
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              stock,
              style: const TextStyle(color: Color(0xFF334155)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(width: 6),
                Text(status, style: const TextStyle(color: Color(0xFF334155))),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              expiry,
              style: const TextStyle(color: Color(0xFF334155)),
            ),
          ),
          SizedBox(
            width: 68,
            child: PopupMenuButton<String>(
              tooltip: 'Actions',
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'restock', child: Text('Restock')),
                const PopupMenuItem(
                  value: 'threshold',
                  child: Text('Update minimum threshold'),
                ),
                PopupMenuItem(
                  value: 'permission',
                  child: Text(
                    canRestock
                        ? 'Disable dispenser restock'
                        : 'Enable dispenser restock',
                  ),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'restock':
                    onRestock();
                    break;
                  case 'threshold':
                    onThreshold();
                    break;
                  case 'permission':
                    onTogglePermission();
                    break;
                }
              },
              child: const Icon(Icons.more_vert_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogFieldLabel extends StatelessWidget {
  const _DialogFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }
}

class _DialogTabButton extends StatelessWidget {
  const _DialogTabButton({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? const Color(0xFF2563EB) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF64748B),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: const Color(0xFF64748B)),
    );
  }
}

class _PageNumberButton extends StatelessWidget {
  const _PageNumberButton({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF2563EB) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : const Color(0xFF334155),
        ),
      ),
    );
  }
}
