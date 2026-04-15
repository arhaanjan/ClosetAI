import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../models/clothing_item.dart';
import '../services/firebase_service.dart';
import '../services/gemini_service.dart';

class AddItemScreen extends StatefulWidget {
  final FirebaseService service;
  const AddItemScreen({super.key, required this.service});
  @override State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _colourCtrl = TextEditingController();

  File?   _image;
  String  _cat       = ClothingCategories.categories.first;
  String  _type      = ClothingCategories.typesFor(ClothingCategories.categories.first).first;
  bool    _uploading = false;
  bool    _analysing = false;
  double  _progress  = 0;

  // ── Pick image & immediately trigger AI analysis ────────
  Future<void> _pick(ImageSource src) async {
    final XFile? f = await ImagePicker().pickImage(
        source: src,
        imageQuality: 90,
        maxWidth: 1200
    );

    if (f == null) return;

    setState(() => _image = File(f.path));

    // Pass the XFile (f) to the analyzer instead of File
    _analyseImage(f);
  }

  void _sourceSheet() => showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.accent),
              title: const Text('Gallery',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.accent),
              title: const Text('Camera',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.camera);
              },
            ),
          ]),
        ),
      );

  // ── AI auto-fill ────────────────────────────────────────
  Future<void> _analyseImage(XFile file) async {
    setState(() => _analysing = true);

    final result = await GeminiService.instance.analyseClothing(file);
    if (!mounted) return;

    if (result != null) {
      // Validate against the actual category/type lists
      final validCat = ClothingCategories.categories.contains(result.category)
          ? result.category
          : _cat;
      final validTypes = ClothingCategories.typesFor(validCat);
      final validType =
      validTypes.contains(result.type) ? result.type : validTypes.first;

      setState(() {
        _nameCtrl.text   = result.name;
        _colourCtrl.text = result.colour;
        _cat             = validCat;
        _type            = validType;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✨ AI autofill complete!'), backgroundColor: AppColors.accent),
      );
    } else {
      // ALERT THE USER IF IT FAILS
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ AI couldn\'t analyse the image. Please fill manually.'), backgroundColor: Colors.redAccent),
      );
    }

    setState(() => _analysing = false);
  }

  // ── Save to Firestore ───────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add a photo.')));
      return;
    }
    setState(() {
      _uploading = true;
      _progress  = 0;
    });
    try {
      final url = await widget.service.uploadImage(_image!,
          onProgress: (p) => setState(() => _progress = p));

      await widget.service.addItem(
        name:     _nameCtrl.text.trim(),
        imageUrl: url,
        category: _cat,
        type:     _type,
        colour:   _colourCtrl.text.trim(), // ← new field
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Item added!'),
            backgroundColor: Color(0xFF059669)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _colourCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Clothing Item')),
      body: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ── Image picker ──────────────────────────
                GestureDetector(
                  onTap: (_uploading || _analysing) ? null : _sourceSheet,
                  child: Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _image != null
                            ? AppColors.accent
                            : AppColors.border,
                        width: _image != null ? 1.5 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _image != null
                        ? Stack(fit: StackFit.expand, children: [
                            kIsWeb
                                ? Image.network(_image!.path,
                                    fit: BoxFit.cover)
                                : Image.file(_image!, fit: BoxFit.cover),
                            // Overlay while AI analyses
                            if (_analysing)
                              Container(
                                color: Colors.black.withOpacity(0.55),
                                child: const Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 32, height: 32,
                                      child: CircularProgressIndicator(
                                          color: AppColors.accent,
                                          strokeWidth: 2.5),
                                    ),
                                    SizedBox(height: 12),
                                    Text('AI is analysing…',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ],
                                ),
                              ),
                          ])
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 48, color: AppColors.textMuted),
                              SizedBox(height: 10),
                              Text('Add Photo',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600)),
                              Text('AI will auto-fill details',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12)),
                            ],
                          ),
                  ),
                ),

                // AI badge shown after analysis
                if (_image != null && !_analysing) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.accent.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome,
                              size: 12, color: AppColors.accentLight),
                          SizedBox(width: 5),
                          Text('AI-filled · edit if needed',
                              style: TextStyle(
                                color: AppColors.accentLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // ── Name ─────────────────────────────────
                TextFormField(
                  controller: _nameCtrl,
                  enabled: !_analysing,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    hintText: 'e.g. Navy Slim Chinos',
                    prefixIcon: Icon(Icons.label_outline,
                        color: AppColors.textMuted, size: 20),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name required' : null,
                ),

                const SizedBox(height: 16),

                // ── Colour ───────────────────────────────
                const Text('COLOUR',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
                const SizedBox(height: 10),
                _ColourField(
                    controller: _colourCtrl, enabled: !_analysing),

                const SizedBox(height: 20),

                // ── Category ─────────────────────────────
                const Text('CATEGORY',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: ClothingCategories.categories.length,
                  itemBuilder: (_, i) {
                    final c = ClothingCategories.categories[i];
                    final sel = c == _cat;
                    return GestureDetector(
                      onTap: _analysing
                          ? null
                          : () => setState(() {
                                _cat  = c;
                                _type = ClothingCategories.typesFor(c).first;
                              }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.accent.withOpacity(0.2)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: sel
                                ? AppColors.accent
                                : AppColors.border,
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(ClothingCategories.emojiFor(c),
                                style: const TextStyle(fontSize: 22)),
                            const SizedBox(height: 4),
                            Text(c,
                                style: TextStyle(
                                  color: sel
                                      ? AppColors.accentLight
                                      : AppColors.textMuted,
                                  fontSize: 9,
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // ── Type ─────────────────────────────────
                const Text('TYPE',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: ClothingCategories.typesFor(_cat).map((t) {
                    final sel = t == _type;
                    return GestureDetector(
                      onTap: _analysing
                          ? null
                          : () => setState(() => _type = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.accent.withOpacity(0.18)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel
                                ? AppColors.accent
                                : AppColors.border,
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Text(t,
                            style: TextStyle(
                              color: sel
                                  ? AppColors.accentLight
                                  : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            )),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: (_uploading || _analysing) ? null : _submit,
                  child: const Text('Save to Closet'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),

        // ── Upload progress overlay ───────────────────────
        if (_uploading)
          Container(
            color: Colors.black.withOpacity(0.72),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 80, height: 80,
                    child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 6,
                        color: AppColors.accent,
                        backgroundColor: AppColors.border),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${(_progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text('Compressing & saving…',
                      style:
                          TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Colour field with live preview dot ─────────────────────
class _ColourField extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  const _ColourField({required this.controller, this.enabled = true});
  @override State<_ColourField> createState() => _ColourFieldState();
}

class _ColourFieldState extends State<_ColourField> {
  static const _map = <String, Color>{
    'white':       Color(0xFFFAFAFA),
    'off-white':   Color(0xFFF5F5EE),
    'off white':   Color(0xFFF5F5EE),
    'cream':       Color(0xFFFFFDD0),
    'black':       Color(0xFF1A1A1A),
    'charcoal':    Color(0xFF36454F),
    'grey':        Color(0xFF9E9E9E),
    'gray':        Color(0xFF9E9E9E),
    'light grey':  Color(0xFFD3D3D3),
    'dark grey':   Color(0xFF4A4A4A),
    'red':         Color(0xFFE53935),
    'crimson':     Color(0xFFDC143C),
    'burgundy':    Color(0xFF800020),
    'maroon':      Color(0xFF800000),
    'pink':        Color(0xFFF48FB1),
    'hot pink':    Color(0xFFFF69B4),
    'orange':      Color(0xFFFF7043),
    'peach':       Color(0xFFFFCBA4),
    'yellow':      Color(0xFFFFEE58),
    'mustard':     Color(0xFFFFDB58),
    'gold':        Color(0xFFFFD700),
    'green':       Color(0xFF43A047),
    'olive':       Color(0xFF808000),
    'olive green': Color(0xFF6B6E2A),
    'mint':        Color(0xFF98FF98),
    'teal':        Color(0xFF008080),
    'blue':        Color(0xFF1E88E5),
    'navy':        Color(0xFF001F5B),
    'navy blue':   Color(0xFF001F5B),
    'sky blue':    Color(0xFF87CEEB),
    'royal blue':  Color(0xFF4169E1),
    'cobalt':      Color(0xFF0047AB),
    'purple':      Color(0xFF8E24AA),
    'lavender':    Color(0xFFE6E6FA),
    'violet':      Color(0xFFEE82EE),
    'brown':       Color(0xFF795548),
    'tan':         Color(0xFFD2B48C),
    'beige':       Color(0xFFF5F5DC),
    'camel':       Color(0xFFC19A6B),
    'khaki':       Color(0xFFC3B091),
    'denim':       Color(0xFF1560BD),
  };

  Color? _resolve(String text) {
    final key = text.toLowerCase().trim();
    if (_map.containsKey(key)) return _map[key];
    for (final e in _map.entries) {
      if (key.contains(e.key) || e.key.contains(key)) return e.value;
    }
    return null;
  }

  @override Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (_, val, __) {
        final colour = _resolve(val.text);
        return TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. Navy Blue, Olive Green, Charcoal',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(13),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colour ?? Colors.transparent,
                  border: Border.all(
                    color: colour != null
                        ? AppColors.accent.withOpacity(0.5)
                        : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: colour == null
                    ? const Icon(Icons.palette_outlined,
                        size: 13, color: AppColors.textMuted)
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
