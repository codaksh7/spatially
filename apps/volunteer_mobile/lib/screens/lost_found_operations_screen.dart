import 'package:flutter/material.dart';
import '../models/lost_found_item.dart';
import '../repositories/incident_repository.dart';

class LostFoundOperationsScreen extends StatefulWidget {
  const LostFoundOperationsScreen({super.key});

  @override
  State<LostFoundOperationsScreen> createState() => _LostFoundOperationsScreenState();
}

class _LostFoundOperationsScreenState extends State<LostFoundOperationsScreen> {
  List<LostFoundItem> _items = [];
  bool _isLoading = true;
  String? _error;
  String _typeFilter = 'all'; // 'all', 'lost', 'found'
  String _statusFilter = 'all'; // 'all', 'open', 'matched', 'returned'

  @override
  void initState() {
    super.initState();
    _loadItems();
    IncidentRepository.instance.subscribeRealtime(
      onDataChanged: () {
        if (mounted) _loadItems(silent: true);
      },
    );
  }

  @override
  void dispose() {
    IncidentRepository.instance.unsubscribeRealtime();
    super.dispose();
  }

  Future<void> _loadItems({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final list = await IncidentRepository.instance.fetchLostFoundReports(forceRefresh: true);
      if (mounted) {
        setState(() {
          _items = list;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load Lost & Found items: $e';
        });
      }
    }
  }

  List<LostFoundItem> get _filteredItems {
    return _items.where((it) {
      if (_typeFilter != 'all' && it.reportType.toLowerCase() != _typeFilter) {
        return false;
      }
      if (_statusFilter != 'all' && it.status.toLowerCase() != _statusFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _updateStatusDialog(LostFoundItem item) async {
    String selectedStatus = item.status;
    final instructionsCtrl = TextEditingController(text: item.pickupInstructions ?? '');

    final allowedStatuses = [
      {'val': 'submitted', 'label': 'Submitted / Pending'},
      {'val': 'in_review', 'label': 'In Review'},
      {'val': 'open', 'label': 'Open / Searching'},
      {'val': 'matched', 'label': 'Matched'},
      {'val': 'returned', 'label': 'Returned to Owner'},
      {'val': 'resolved', 'label': 'Resolved'},
      {'val': 'expired', 'label': 'Expired / Unclaimed'},
    ];

    if (!allowedStatuses.any((s) => s['val'] == selectedStatus.toLowerCase())) {
      selectedStatus = 'submitted';
    } else {
      selectedStatus = selectedStatus.toLowerCase();
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Update "${item.title}"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                items: allowedStatuses.map((s) {
                  return DropdownMenuItem<String>(
                    value: s['val'],
                    child: Text(s['label']!),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedStatus = val);
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              const Text('Pickup / Handling Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: instructionsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g., Kept at Info Desk #2; owner can claim with ID',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await IncidentRepository.instance.updateLostFoundStatus(
          item.id,
          selectedStatus,
          pickupInstructions: instructionsCtrl.text.trim().isNotEmpty
              ? instructionsCtrl.text.trim()
              : null,
        );
        _loadItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status updated.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update status: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lost & Found Operations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadItems(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type filters
                Row(
                  children: [
                    const Text('Type:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    _buildFilterChip('All', _typeFilter == 'all', () => setState(() => _typeFilter = 'all')),
                    const SizedBox(width: 6),
                    _buildFilterChip('Lost Items', _typeFilter == 'lost', () => setState(() => _typeFilter = 'lost'), color: Colors.orange),
                    const SizedBox(width: 6),
                    _buildFilterChip('Found Items', _typeFilter == 'found', () => setState(() => _typeFilter = 'found'), color: Colors.blue),
                  ],
                ),
                const SizedBox(height: 8),
                // Status filters
                Row(
                  children: [
                    const Text('Status:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    _buildFilterChip('All', _statusFilter == 'all', () => setState(() => _statusFilter = 'all')),
                    const SizedBox(width: 6),
                    _buildFilterChip('Open', _statusFilter == 'open', () => setState(() => _statusFilter = 'open')),
                    const SizedBox(width: 6),
                    _buildFilterChip('Matched', _statusFilter == 'matched', () => setState(() => _statusFilter = 'matched'), color: Colors.purple),
                    const SizedBox(width: 6),
                    _buildFilterChip('Returned', _statusFilter == 'returned', () => setState(() => _statusFilter = 'returned'), color: Colors.green),
                  ],
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 40, color: Colors.red),
                            const SizedBox(height: 8),
                            Text(_error!),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => _loadItems(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredItems.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.4)),
                                  const SizedBox(height: 12),
                                  const Text('No Lost & Found reports match the criteria.', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadItems(),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredItems.length,
                              separatorBuilder: (context, i) => const SizedBox(height: 12),
                              itemBuilder: (ctx, index) {
                                final item = _filteredItems[index];
                                return _buildItemCard(item);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? (color ?? Theme.of(context).colorScheme.primary) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color ?? Colors.grey.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : (color ?? Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(LostFoundItem item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLost = item.isLost;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLost ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isLost ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)),
                  ),
                  child: Text(
                    isLost ? 'LOST ITEM' : 'FOUND ITEM',
                    style: TextStyle(
                      color: isLost ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.category.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ),
                const Spacer(),
                _buildStatusChip(item.status),
              ],
            ),
            const SizedBox(height: 10),

            // Item Title
            Text(
              item.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),

            // Description
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),

            // Location
            if (item.venueZoneName != null || item.specificLocation != null) ...[
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.specificLocation ?? item.venueZoneName ?? '',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Pickup instructions if set
            if (item.pickupInstructions != null && item.pickupInstructions!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Instructions: ${item.pickupInstructions}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Action row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _updateStatusDialog(item),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Update Status', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'open':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        break;
      case 'matched':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF9333EA);
        break;
      case 'returned':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        break;
      case 'expired':
      default:
        bg = const Color(0xFFF1F5F9);
        fg = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}
