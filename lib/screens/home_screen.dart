import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../models/clothing_item.dart';
import '../services/firebase_service.dart';
import 'add_item_screen.dart';
import 'profile_screen.dart';
import 'fashion_assistant_screen.dart'; // ← NEW

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = FirebaseService();
  String _filter = 'All';
  static const _filters = [
    'All','Available','Laundry',
    'Tops','Bottoms','Full Body','Footwear',
    'Accessories','Innerwear','Sleepwear',
  ];

  List<ClothingItem> _apply(List<QueryDocumentSnapshot> docs) {
    final items = docs.map((d) => ClothingItem.fromDoc(d)).toList();
    switch (_filter) {
      case 'Available': return items.where((i) => i.isAvailable).toList();
      case 'Laundry':   return items.where((i) => i.isLaundry).toList();
      case 'All':       return items;
      default:          return items.where((i) => i.category == _filter).toList();
    }
  }

  Future<void> _laundrySheet(ClothingItem item) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Text(
              item.isLaundry
                  ? '✅ Mark as Clean?'
                  : '🧺 Send to Laundry?',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
              item.isLaundry
                  ? '"${item.name}" returns to your available closet.'
                  : '"${item.name}" will be marked dirty.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5)),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _service.toggleStatus(item.id, item.status);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: item.isLaundry
                        ? AppColors.available
                        : AppColors.laundry,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: Text(
                    item.isLaundry ? 'Mark Clean ✅' : 'It\'s Dirty 🧺'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _confirmDelete(ClothingItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Item?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text('"${item.name}" will be permanently removed.',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok == true) await _service.deleteItem(item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Closet'),
        actions: [
          // ── NEW: Fashion Assistant button ──────────────
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined,
                color: AppColors.accentLight),
            tooltip: 'Style Assistant',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    FashionAssistantScreen(service: _service),
              ),
            ),
          ),
          // ── Existing: Profile button ───────────────────
          IconButton(
            icon: const CircleAvatar(
                backgroundColor: AppColors.surface,
                child: Icon(Icons.person_outline,
                    size: 18, color: AppColors.textSecondary)),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => ProfileScreen(service: _service))),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => AddItemScreen(service: _service))),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _service.clothesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }
          final docs  = snapshot.data?.docs ?? [];
          final all   = docs.map((d) => ClothingItem.fromDoc(d)).toList();
          final shown = _apply(docs);
          return Column(children: [
            if (all.isNotEmpty) _SummaryBar(items: all),
            _FilterRow(
                filters: _filters,
                active: _filter,
                onSelect: (f) => setState(() => _filter = f)),
            Expanded(
              child: all.isEmpty
                  ? _EmptyState(
                      onAdd: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  AddItemScreen(service: _service))))
                  : shown.isEmpty
                      ? Center(
                          child: Text('No "$_filter" items',
                              style: const TextStyle(
                                  color: AppColors.textMuted)))
                      : GridView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(14, 8, 14, 100),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.72),
                          itemCount: shown.length,
                          itemBuilder: (_, i) => _Card(
                            item: shown[i],
                            onTap: () => _laundrySheet(shown[i]),
                            onLongPress: () => _confirmDelete(shown[i]),
                          ),
                        ),
            ),
          ]);
        },
      ),
    );
  }
}

// ── Summary Bar ────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final List<ClothingItem> items;
  const _SummaryBar({required this.items});
  @override Widget build(BuildContext context) {
    final laundry = items.where((i) => i.isLaundry).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      padding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        _Stat('${items.length}', 'Total', '👗'),
        Container(width: 1, height: 40, color: AppColors.border),
        _Stat('${items.length - laundry}', 'Available', '✅'),
        Container(width: 1, height: 40, color: AppColors.border),
        _Stat('$laundry', 'Laundry', '🧺'),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String v, label, emoji;
  const _Stat(this.v, this.label, this.emoji);
  @override Widget build(BuildContext context) =>
      Expanded(child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(v,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
      ]));
}

// ── Filter Row ─────────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  final List<String> filters;
  final String active;
  final void Function(String) onSelect;
  const _FilterRow(
      {required this.filters,
      required this.active,
      required this.onSelect});
  @override Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final f   = filters[i];
            final sel = active == f;
            return FilterChip(
                label: Text(f),
                selected: sel,
                onSelected: (_) => onSelect(f),
                showCheckmark: false,
                selectedColor: AppColors.accent.withOpacity(0.22),
                labelStyle: TextStyle(
                    color: sel
                        ? AppColors.accentLight
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: sel
                        ? FontWeight.w600
                        : FontWeight.normal),
                side: BorderSide(
                    color: sel
                        ? AppColors.accent.withOpacity(0.6)
                        : AppColors.border));
          },
        ),
      );
}

// ── Image helper ────────────────────────────────────────────
Widget _buildImg(String url) {
  if (url.isNotEmpty && url.startsWith('http')) {
    return Image.network(url,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
            progress == null
                ? child
                : const Center(child: CircularProgressIndicator()));
  }
  return const Icon(Icons.broken_image_outlined,
      color: AppColors.textMuted);
}

// ── Clothing Card ───────────────────────────────────────────
class _Card extends StatelessWidget {
  final ClothingItem item;
  final VoidCallback onTap, onLongPress;
  const _Card(
      {required this.item,
      required this.onTap,
      required this.onLongPress});

  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: item.isLaundry
                    ? AppColors.laundry.withOpacity(0.5)
                    : AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              _buildImg(item.imageUrl),
              if (item.isLaundry)
                Container(color: Colors.black.withOpacity(0.5)),
              if (item.isLaundry)
                const Center(
                    child: Text('🧺',
                        style: TextStyle(fontSize: 44))),
              Positioned(
                top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                      '${ClothingCategories.emojiFor(item.category)} ${item.category}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10)),
                ),
              ),
              Positioned(
                top: 8, right: 8,
                child: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.isLaundry
                          ? AppColors.laundry
                          : AppColors.available),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(item.name,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              // Show colour dot + type on the same row if colour exists
              Row(children: [
                if (item.colour.isNotEmpty) ...[
                  Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${item.colour} · ${item.type}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  Text(item.type,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
              ]),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: (item.isLaundry
                            ? AppColors.laundry
                            : AppColors.available)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(
                    item.isLaundry ? 'In Laundry' : 'Available',
                    style: TextStyle(
                        color: item.isLaundry
                            ? AppColors.laundry
                            : AppColors.available,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Empty State ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            const Text('👗', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            const Text('Your closet is empty',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Add your first item to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 28),
            ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add First Item')),
          ]),
        ),
      );
}
