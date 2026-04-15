import 'package:cloud_firestore/cloud_firestore.dart';

class ClothingItem {
  final String id;
  final String name;
  final String imageUrl;
  final String category;
  final String type;
  final String colour;     // ← NEW
  final String status;     // "available" or "laundry"
  final DateTime addedAt;
  final DateTime? lastWashed;

  ClothingItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.category,
    required this.type,
    this.colour = '',       // ← NEW (optional so old docs still load fine)
    required this.status,
    required this.addedAt,
    this.lastWashed,
  });

  bool get isLaundry   => status == 'laundry';
  bool get isAvailable => status == 'available';

  factory ClothingItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ClothingItem(
      id:         doc.id,
      name:       d['name']       ?? '',
      imageUrl:   d['imageUrl']   ?? '',
      category:   d['category']   ?? '',
      type:       d['type']       ?? '',
      colour:     d['colour']     ?? '',  // ← NEW
      status:     d['status']     ?? 'available',
      addedAt:    (d['addedAt']   as Timestamp?)?.toDate() ?? DateTime.now(),
      lastWashed: (d['lastWashed'] as Timestamp?)?.toDate(),
    );
  }
}

// ── Preset Categories ──────────────────────────────────────
class ClothingCategories {
  static const Map<String, List<String>> data = {
    'Tops':       ['T-Shirt','Shirt','Polo','Tank Top','Hoodie','Sweater','Jacket','Blazer','Coat'],
    'Bottoms':    ['Jeans','Pants','Shorts','Joggers','Chinos','Skirt','Leggings'],
    'Full Body':  ['Dress','Suit','Jumpsuit','Kurta','Sherwani'],
    'Footwear':   ['Sneakers','Formal Shoes','Sandals','Boots','Loafers','Slippers'],
    'Accessories':['Belt','Watch','Cap','Bag','Scarf','Tie','Sunglasses'],
    'Innerwear':  ['Undershirt','Socks','Boxers','Sports Bra'],
    'Sleepwear':  ['Pajamas','Night Suit','Robe'],
  };

  static const Map<String, String> emojis = {
    'Tops': '👕', 'Bottoms': '👖', 'Full Body': '👗',
    'Footwear': '👟', 'Accessories': '💍',
    'Innerwear': '🩲', 'Sleepwear': '🌙',
  };

  static List<String> get categories => data.keys.toList();
  static List<String> typesFor(String cat) => data[cat] ?? [];
  static String emojiFor(String cat) => emojis[cat] ?? '👔';
}
