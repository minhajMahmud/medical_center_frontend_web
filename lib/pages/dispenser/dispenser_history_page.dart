import 'package:backend_client/backend_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../widgets/common/dashboard_shell.dart';

class DispenserHistoryPage extends StatefulWidget {
  const DispenserHistoryPage({super.key});

  @override
  State<DispenserHistoryPage> createState() => _DispenserHistoryPageState();
}

enum _DispenseTab { all, urgent, followUp }

class _DispenserHistoryPageState extends State<DispenserHistoryPage> {
  final _searchCtrl = TextEditingController();
  _DispenseTab _tab = _DispenseTab.all;
  int? _selectedPrescriptionId;
  List<_DispenseDraftItem> _draftItems = [];
  final Map<int, List<InventoryItemInfo>> _suggestions =
      <int, List<InventoryItemInfo>>{};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<RoleDashboardController>().loadDispenser();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final d in _draftItems) {
      d.searchCtrl.dispose();
      d.qtyCtrl.dispose();
    }
    super.dispose();
  }

  int _doseToInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;

    if (s.contains('+')) {
      final parts = s.split('+').map((p) => p.trim()).toList();
      if (parts.isNotEmpty && parts.every((p) => p == '0' || p == '1')) {
        return parts.fold<int>(0, (sum, p) => sum + (p == '1' ? 1 : 0));
      }
    }

    final lower = s.toLowerCase();
    var count = 0;
    if (lower.contains('morning') || lower.contains('সকাল')) count++;
    if (lower.contains('noon') || lower.contains('দুপুর')) count++;
    if (lower.contains('night') || lower.contains('রাত')) count++;
    if (count > 0) return count;

    final m = RegExp(r'\d+').firstMatch(s);
    if (m != null) return int.tryParse(m.group(0)!) ?? 0;
    return 0;
  }

  List<InventoryItemInfo> _rankInventoryMatches(
    List<InventoryItemInfo> rows,
    String prescribedName,
  ) {
    final normalizedPrescription = prescribedName.trim().toLowerCase();

    final availableOnly = rows.where((r) => r.currentQuantity > 0).toList();
    availableOnly.sort((a, b) {
      final aName = a.itemName.toLowerCase();
      final bName = b.itemName.toLowerCase();

      int score(String n) {
        if (n == normalizedPrescription) return 0;
        if (n.startsWith(normalizedPrescription)) return 1;
        if (n.contains(normalizedPrescription)) return 2;
        return 3;
      }

      final s = score(aName).compareTo(score(bName));
      if (s != 0) return s;

      final stockCompare = b.currentQuantity.compareTo(a.currentQuantity);
      if (stockCompare != 0) return stockCompare;

      return aName.compareTo(bName);
    });

    return availableOnly;
  }

  String _extractMedicineKeyword(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return '';

    final words = normalized
        .replaceAll(RegExp(r'[^a-z0-9\s\-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';

    const stopWords = {
      'alt',
      'alternative',
      'alternatives',
      'to',
      'for',
      'of',
      'the',
      'medicine',
      'medicines',
      'drug',
      'drugs',
      'tab',
      'tablet',
      'cap',
      'capsule',
      'syrup',
      'injection',
    };

    final candidates = words
        .where((w) => w.length >= 3 && !stopWords.contains(w))
        .toList();
    if (candidates.isEmpty) return words.first;

    candidates.sort((a, b) => b.length.compareTo(a.length));
    return candidates.first;
  }

  List<InventoryItemInfo> _fallbackFromLoadedStock(
    RoleDashboardController c,
    String query,
  ) {
    final key = _extractMedicineKeyword(query);
    if (key.isEmpty) return const [];

    final keyLower = key.toLowerCase();
    final rows = c.dispenserStock.where((item) {
      if (item.currentQuantity <= 0) return false;
      return item.itemName.toLowerCase().contains(keyLower);
    }).toList();

    rows.sort((a, b) {
      final aName = a.itemName.toLowerCase();
      final bName = b.itemName.toLowerCase();
      final aExact = aName == keyLower;
      final bExact = bName == keyLower;
      if (aExact != bExact) return aExact ? -1 : 1;

      final aPrefix = aName.startsWith(keyLower);
      final bPrefix = bName.startsWith(keyLower);
      if (aPrefix != bPrefix) return aPrefix ? -1 : 1;

      final stockCompare = b.currentQuantity.compareTo(a.currentQuantity);
      if (stockCompare != 0) return stockCompare;
      return aName.compareTo(bName);
    });

    return rows;
  }

  Future<Map<int, List<InventoryItemInfo>>> _preloadSuggestionsForDrafts(
    List<_DispenseDraftItem> drafts,
  ) async {
    final c = context.read<RoleDashboardController>();
    final loaded = <int, List<InventoryItemInfo>>{};

    for (var i = 0; i < drafts.length; i++) {
      final query = drafts[i].prescribedName.trim();
      if (query.isEmpty) {
        loaded[i] = const [];
        continue;
      }

      var rows = await c.searchDispenserInventoryItems(query);
      if (rows.isEmpty) {
        rows = _fallbackFromLoadedStock(c, query);
      }
      loaded[i] = _rankInventoryMatches(rows, drafts[i].prescribedName);
    }

    return loaded;
  }

  Future<void> _openPrescription(Prescription p) async {
    final id = p.id;
    if (id == null) return;

    final c = context.read<RoleDashboardController>();
    final detail = await c.loadDispenserPrescriptionDetail(id);
    if (!mounted) return;

    if (detail == null || detail.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No prescription items found.')),
      );
      return;
    }

    for (final d in _draftItems) {
      d.searchCtrl.dispose();
      d.qtyCtrl.dispose();
    }

    final items = detail.items.map((it) {
      final dose = _doseToInt(it.dosageTimes);
      final duration = _doseToInt(it.duration);
      final total = (dose > 0 && duration > 0) ? dose * duration : 1;
      return _DispenseDraftItem(
        originalItemId: it.itemId,
        prescribedName: it.medicineName,
        selectedItemId: it.itemId,
        selectedName: it.medicineName,
        originalStock: it.stock ?? 0,
        selectedStock: it.stock ?? 0,
        dosageTimes: it.dosageTimes,
        duration: it.duration,
        isAlternative: false,
        searchCtrl: TextEditingController(text: it.medicineName),
        qtyCtrl: TextEditingController(text: total.toString()),
      );
    }).toList();

    setState(() {
      _selectedPrescriptionId = id;
      _draftItems = items;
      _suggestions.clear();
    });

    final preloaded = await _preloadSuggestionsForDrafts(items);
    if (!mounted || _selectedPrescriptionId != id) return;

    setState(() {
      _suggestions
        ..clear()
        ..addAll(preloaded);
    });
  }

  Future<void> _searchAlternative(int index, String query) async {
    if (index < 0 || index >= _draftItems.length) return;

    final q = query.trim();
    final fallback = _draftItems[index].prescribedName.trim();
    final effectiveQuery = q.length >= 2 ? q : fallback;

    if (effectiveQuery.isEmpty) {
      setState(() => _suggestions[index] = const []);
      return;
    }

    final c = context.read<RoleDashboardController>();
    var rows = await c.searchDispenserInventoryItems(effectiveQuery);
    if (rows.isEmpty) {
      rows = _fallbackFromLoadedStock(c, effectiveQuery);
    }
    if (!mounted) return;

    final ranked = _rankInventoryMatches(
      rows,
      _draftItems[index].prescribedName,
    );
    final normalizedTyped = q.toLowerCase();

    InventoryItemInfo? preferred;
    if (normalizedTyped.length >= 2) {
      for (final item in ranked) {
        if (item.itemName.toLowerCase() == normalizedTyped) {
          preferred = item;
          break;
        }
      }
      preferred ??= ranked.cast<InventoryItemInfo?>().firstWhere(
        (item) => item!.itemName.toLowerCase().startsWith(normalizedTyped),
        orElse: () => null,
      );
    }

    setState(() {
      _suggestions[index] = ranked;

      if (preferred != null) {
        final d = _draftItems[index];
        d.selectedItemId = preferred.itemId;
        d.selectedName = preferred.itemName;
        d.selectedStock = preferred.currentQuantity;
        d.isAlternative =
            d.prescribedName.toLowerCase() != preferred.itemName.toLowerCase();

        final typedQty = int.tryParse(d.qtyCtrl.text.trim()) ?? 0;
        if (typedQty > d.selectedStock && d.selectedStock > 0) {
          d.qtyCtrl.text = d.selectedStock.toString();
        }
      }
    });
  }

  void _pickAlternative(int index, InventoryItemInfo item) {
    setState(() {
      final d = _draftItems[index];
      d.selectedItemId = item.itemId;
      d.selectedName = item.itemName;
      d.selectedStock = item.currentQuantity;
      d.isAlternative =
          d.prescribedName.toLowerCase() != item.itemName.toLowerCase();
      d.searchCtrl.text = item.itemName;

      final typedQty = int.tryParse(d.qtyCtrl.text.trim()) ?? 0;
      if (typedQty > d.selectedStock && d.selectedStock > 0) {
        d.qtyCtrl.text = d.selectedStock.toString();
      }
    });
  }

  Future<void> _dispenseNow() async {
    if (_selectedPrescriptionId == null) return;

    final issues = <String>[];
    final payload = <DispenseItemRequest>[];

    for (final d in _draftItems) {
      final qty = int.tryParse(d.qtyCtrl.text.trim()) ?? 0;
      if (qty <= 0) continue;
      if (d.selectedItemId == null) {
        issues.add('No inventory item selected for ${d.prescribedName}.');
        continue;
      }
      if (d.selectedStock < qty) {
        issues.add(
          'Insufficient stock for ${d.selectedName} (available ${d.selectedStock}, need $qty).',
        );
        continue;
      }

      payload.add(
        DispenseItemRequest(
          itemId: d.selectedItemId!,
          medicineName: d.selectedName,
          quantity: qty,
          isAlternative: d.isAlternative,
          originalMedicineId: d.originalItemId,
        ),
      );
    }

    if (issues.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(issues.first)));
      return;
    }

    if (payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid medicines selected to dispense.'),
        ),
      );
      return;
    }

    final c = context.read<RoleDashboardController>();
    final ok = await c.dispenseDispenserPrescription(
      prescriptionId: _selectedPrescriptionId!,
      items: payload,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription dispensed successfully.')),
      );
      for (final d in _draftItems) {
        d.searchCtrl.dispose();
        d.qtyCtrl.dispose();
      }
      setState(() {
        _selectedPrescriptionId = null;
        _draftItems = [];
        _suggestions.clear();
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(c.error ?? 'Dispense failed.')));
    }
  }

  List<Prescription> _filtered(List<Prescription> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final now = DateTime.now();
    final urgentCutoff = now.subtract(const Duration(days: 2));

    final base = all.where((p) {
      if (q.isEmpty) return true;
      return (p.name ?? '').toLowerCase().contains(q) ||
          (p.mobileNumber ?? '').toLowerCase().contains(q) ||
          (p.id?.toString() ?? '').contains(q);
    });

    switch (_tab) {
      case _DispenseTab.all:
        return base.toList();
      case _DispenseTab.urgent:
        return base
            .where(
              (p) =>
                  (p.prescriptionDate ?? p.createdAt)?.isBefore(urgentCutoff) ??
                  false,
            )
            .toList();
      case _DispenseTab.followUp:
        return base
            .where(
              (p) =>
                  !((p.prescriptionDate ?? p.createdAt)?.isBefore(
                        urgentCutoff,
                      ) ??
                      false),
            )
            .toList();
    }
  }

  Widget _buildTabs(List<Prescription> all) {
    final now = DateTime.now();
    final urgentCutoff = now.subtract(const Duration(days: 2));
    final urgent = all
        .where(
          (p) =>
              (p.prescriptionDate ?? p.createdAt)?.isBefore(urgentCutoff) ??
              false,
        )
        .length;
    final follow = all.length - urgent;

    Widget tab(_DispenseTab value, String text, IconData icon) {
      final active = _tab == value;
      return ChoiceChip(
        selected: active,
        onSelected: (_) => setState(() => _tab = value),
        avatar: Icon(
          icon,
          size: 16,
          color: active ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
        ),
        label: Text(
          text,
          style: TextStyle(
            color: active ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
        selectedColor: const Color(0xFFEAF1FF),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        tab(_DispenseTab.all, 'All Pending (${all.length})', Icons.list_alt),
        tab(_DispenseTab.urgent, 'Urgent ($urgent)', Icons.priority_high),
        tab(_DispenseTab.followUp, 'Follow-up ($follow)', Icons.update),
      ],
    );
  }

  Widget _buildPrescriptionList(RoleDashboardController c) {
    final all = c.dispenserPendingPrescriptions;
    final rows = _filtered(all);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pending Prescriptions',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${rows.length} visible',
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Review and dispense medications for checked-in patients.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          _buildTabs(all),
          const SizedBox(height: 6),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No pending prescriptions found.'),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: const WidgetStatePropertyAll(
                  Color(0xFFF8FAFC),
                ),
                headingTextStyle: const TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
                dividerThickness: 0.6,
                dataRowMinHeight: 62,
                dataRowMaxHeight: 74,
                columnSpacing: 28,
                columns: const [
                  DataColumn(label: Text('Patient Name')),
                  DataColumn(label: Text('Mobile')),
                  DataColumn(label: Text('Prescription ID')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Action')),
                ],
                rows: rows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final p = entry.value;
                  final name = (p.name ?? '').trim();
                  final initials = name.isEmpty
                      ? 'NA'
                      : name
                            .split(RegExp(r'\s+'))
                            .where((e) => e.isNotEmpty)
                            .take(2)
                            .map((e) => e[0].toUpperCase())
                            .join();

                  return DataRow(
                    color: WidgetStatePropertyAll(
                      index.isOdd ? const Color(0xFFFCFDFF) : Colors.white,
                    ),
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: const Color(0xFFE2E8F0),
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              p.name ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          p.mobileNumber ?? '-',
                          style: const TextStyle(color: Color(0xFF475569)),
                        ),
                      ),
                      DataCell(
                        Text(
                          'RX-${p.id ?? '-'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(
                        Text(
                          p.prescriptionDate == null
                              ? '-'
                              : DateFormat(
                                  'MMM d, yyyy',
                                ).format(p.prescriptionDate!),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Pending',
                            style: TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        TextButton(
                          onPressed: () => _openPrescription(p),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF1D4ED8),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Open & Dispense'),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionDetail(RoleDashboardController c) {
    final detail = c.dispenserPrescriptionDetail;
    if (detail == null) {
      return const SizedBox.shrink();
    }

    final createdAt = detail.prescription.prescriptionDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedPrescriptionId = null;
                  _suggestions.clear();
                });
              },
              icon: const Icon(Icons.arrow_back),
            ),
            Text(
              'Prescription RX-${detail.prescription.id ?? '-'}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Pending Dispense',
                style: TextStyle(
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            if (createdAt != null)
              Text(
                DateFormat('MMM d, yyyy • hh:mm a').format(createdAt),
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final left = Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Patient Information',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Text('Name: ${detail.prescription.name ?? '-'}'),
                  Text('Mobile: ${detail.prescription.mobileNumber ?? '-'}'),
                  Text('Gender: ${detail.prescription.gender ?? '-'}'),
                  Text('Age: ${detail.prescription.age?.toString() ?? '-'}'),
                  const SizedBox(height: 6),
                  Text(
                    'Doctor: ${detail.doctorName ?? detail.prescription.doctorName ?? '-'}',
                  ),
                ],
              ),
            );

            final right = Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Medicines to Dispense',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  ..._draftItems.asMap().entries.map((entry) {
                    final i = entry.key;
                    final d = entry.value;
                    final hasStock = d.selectedStock > 0;
                    final candidates = _suggestions[i] ?? const [];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDDE5F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  d.prescribedName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (!hasStock)
                                const Text(
                                  'Not in inventory',
                                  style: TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dose: ${d.dosageTimes ?? '-'}   •   Duration: ${d.duration ?? '-'} day(s)   •   Available: ${d.selectedStock}',
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: d.searchCtrl,
                                  onChanged: (v) => _searchAlternative(i, v),
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Search medicine (alternatives auto-loaded)',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 120,
                                child: TextField(
                                  controller: d.qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Qty',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            d.isAlternative
                                ? 'Using alternative: ${d.selectedName}. Click another option below to switch.'
                                : 'Using prescribed medicine. Click any available medicine below to use it.',
                            style: const TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (candidates.isEmpty)
                            const Text(
                              'No available inventory match right now. Search another name to find alternatives.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: candidates
                                  .map(
                                    (s) => ActionChip(
                                      backgroundColor:
                                          d.selectedItemId == s.itemId
                                          ? const Color(0xFFEAF1FF)
                                          : Colors.white,
                                      side: BorderSide(
                                        color: d.selectedItemId == s.itemId
                                            ? const Color(0xFF1D4ED8)
                                            : const Color(0xFFD1D5DB),
                                      ),
                                      label: Text(
                                        '${s.itemName} • ${s.currentQuantity} in stock',
                                      ),
                                      onPressed: () => _pickAlternative(i, s),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () =>
                            setState(() => _selectedPrescriptionId = null),
                        child: const Text('Put on Hold'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: c.isLoading ? null : _dispenseNow,
                        icon: const Icon(Icons.verified_rounded),
                        label: const Text('Dispense Prescription'),
                      ),
                    ],
                  ),
                ],
              ),
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: left),
                  const SizedBox(width: 12),
                  Expanded(flex: 8, child: right),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [left, const SizedBox(height: 12), right],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();

    return DashboardShell(
      child: c.isLoading && _selectedPrescriptionId == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Text(
                  'Dispense Workspace',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Professional dispensing flow with prescription safety checks and live stock support.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText:
                              'Search prescriptions by patient name, ID, or phone...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () => context
                          .read<RoleDashboardController>()
                          .loadDispenser(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh Data'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_selectedPrescriptionId == null)
                  _buildPrescriptionList(c)
                else
                  _buildPrescriptionDetail(c),
                if (c.error != null && c.error!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    c.error!,
                    style: const TextStyle(color: Color(0xFFB91C1C)),
                  ),
                ],
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 980;
                    return GridView.count(
                      crossAxisCount: wide ? 3 : 1,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: wide ? 2.4 : 3.0,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        const _MetricCard(
                          title: 'Avg Wait Time',
                          value: '12.4 min',
                          note: 'Operational benchmark',
                        ),
                        _MetricCard(
                          title: 'Dispensed Today',
                          value: c.dispenserHistory
                              .where((h) {
                                final n = DateTime.now();
                                return h.dispensedAt.year == n.year &&
                                    h.dispensedAt.month == n.month &&
                                    h.dispensedAt.day == n.day;
                              })
                              .length
                              .toString(),
                          note: 'From backend dispense history',
                        ),
                        _MetricCard(
                          title: 'Low Stock Alerts',
                          value: c.dispenserStock
                              .where((s) => s.currentQuantity <= s.minimumStock)
                              .length
                              .toString(),
                          note: 'Inventory threshold watcher',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _DispenseDraftItem {
  _DispenseDraftItem({
    required this.originalItemId,
    required this.prescribedName,
    required this.selectedItemId,
    required this.selectedName,
    required this.originalStock,
    required this.selectedStock,
    required this.dosageTimes,
    required this.duration,
    required this.isAlternative,
    required this.searchCtrl,
    required this.qtyCtrl,
  });

  int? originalItemId;
  final String prescribedName;
  int? selectedItemId;
  String selectedName;
  final int originalStock;
  int selectedStock;
  final String? dosageTimes;
  final int? duration;
  bool isAlternative;
  final TextEditingController searchCtrl;
  final TextEditingController qtyCtrl;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.note,
  });

  final String title;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            note,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
