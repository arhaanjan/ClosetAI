import 'dart:io';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ClothingAnalysis {
  final String name;
  final String category;
  final String type;
  final String colour;

  const ClothingAnalysis({
    required this.name,
    required this.category,
    required this.type,
    required this.colour,
  });

  factory ClothingAnalysis.fromJson(Map<String, dynamic> j) =>
      ClothingAnalysis(
        name:     (j['name']     as String? ?? '').trim(),
        category: (j['category'] as String? ?? '').trim(),
        type:     (j['type']     as String? ?? '').trim(),
        colour:   (j['colour']   as String? ?? '').trim(),
      );
}

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();


  static final _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  static const _categoriesHint = '''
Tops: T-Shirt, Shirt, Polo, Tank Top, Hoodie, Sweater, Jacket, Blazer, Coat
Bottoms: Jeans, Pants, Shorts, Joggers, Chinos, Skirt, Leggings
Full Body: Dress, Suit, Jumpsuit, Kurta, Sherwani
Footwear: Sneakers, Formal Shoes, Sandals, Boots, Loafers, Slippers
Accessories: Belt, Watch, Cap, Bag, Scarf, Tie, Sunglasses
Innerwear: Undershirt, Socks, Boxers, Sports Bra
Sleepwear: Pajamas, Night Suit, Robe''';

  // ── Feature 1: Auto-tag from image ─────────────────────
  Future<ClothingAnalysis?> analyseClothing(XFile imageFile) async {
    // 1. Force the model to return perfect JSON natively
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    // 2. Dynamically get the correct image type so PNGs don't crash the app
    final ext = imageFile.path.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');

    final bytes = await imageFile.readAsBytes();

    final prompt = '''
Pick category and type from this list (use exact spelling):
$_categoriesHint

Return exactly this JSON shape:
{
  "name": "short human-readable name",
  "category": "one of the categories above",
  "type": "one of the types for that category",
  "colour": "dominant colour as plain English"
}
''';

    try {
      final response = await model.generateContent([
        Content.multi([
          DataPart(mimeType, bytes),
          TextPart(prompt),
        ])
      ]);

      final raw = response.text ?? '{}';
      print("✅ AI JSON Output: $raw"); // Prints to your debug console

      return ClothingAnalysis.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    } catch (e) {
      print("❌ Gemini Analysis Error: $e");
      return null;
    }
  }

  // ── Feature 2: Fashion assistant ───────────────────────
  ChatSession startFashionChat(List<Map<String, dynamic>> wardrobe) {
    final available = wardrobe
        .where((i) => (i['status'] ?? 'available') != 'laundry')
        .toList();

    final wardrobeJson = jsonEncode(available
        .map((i) => {
      'name':     i['name']     ?? '',
      'category': i['category'] ?? '',
      'type':     i['type']     ?? '',
      'colour':   i['colour']   ?? '',
    })
        .toList());

    final systemInstruction = Content.system('''
You are a concise, friendly personal stylist inside ClosetAI.
The user's currently available (clean) wardrobe is:
$wardrobeJson

Rules:
1. ONLY recommend items from the wardrobe above — never invent items.
2. Always reference items by their exact "name" field.
3. Keep every reply to 4-7 sentences.
''');

    final chatModel = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      systemInstruction: systemInstruction,
    );
    return chatModel.startChat();
  }

  Future<String> chat(ChatSession session, String message) async {
    try {
      final response = await session.sendMessage(Content.text(message));
      return response.text ?? "Sorry, I couldn't get a response.";
    } catch (e) {
      print("❌ Gemini Chat Error: $e");
      // Instead of silently failing, push the exact error to the UI chat bubble
      return '⚠️ API Error: ${e.toString().split('\n').first}\n(Check your API Key!)';
    }
  }
}