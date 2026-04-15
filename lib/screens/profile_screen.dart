import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../main.dart';
import '../models/clothing_item.dart';
import '../services/firebase_service.dart';
import '../screens/auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final FirebaseService service;
  const ProfileScreen({super.key, required this.service});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editingName = false;
  bool _uploadingPhoto = false;
  bool _isSigningOut = false; // <-- Added to prevent double clicks
  final _nameCtrl = TextEditingController();

  // ── Profile photo: compress → Base64 → save to Firestore ──────
  Future<void> _pickAndUploadPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (file == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final compressed = await FlutterImageCompress.compressWithFile(
        File(file.path).absolute.path,
        minWidth: 400,
        minHeight: 400,
        quality: 70,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) throw Exception('Compression failed');

      final base64String = 'data:image/jpeg;base64,${base64Encode(compressed)}';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.service.uid)
          .update({'photoBase64': base64String});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    await widget.service.updateDisplayName(name);
    if (mounted) setState(() => _editingName = false);
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true); // Triggers the safe loading UI

    try {
      await widget.service.signOut();

      // Force the app to clear the entire navigation stack
      // and physically push the user to the Login screen.
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      // If something goes wrong, turn off the loading spinner
      if (mounted) {
        setState(() => _isSigningOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }
  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: widget.service.profileStream(),
        builder: (context, profileSnap) {

          // ── BULLETPROOF GUARD 1 ──────────────────────
          // If user signs out, stop building UI instantly
          if (widget.service.uid == null || _isSigningOut) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: widget.service.clothesStream(),
            builder: (context, clothesSnap) {

              // ── BULLETPROOF GUARD 2 ──────────────────────
              if (widget.service.uid == null) {
                return const SizedBox.shrink();
              }

              // ── Pull profile data ──────────────────────
              final profile = profileSnap.data?.data() as Map<String, dynamic>?;
              final displayName  = profile?['displayName'] ?? 'User';
              final email        = profile?['email']       ?? '';
              final photoBase64  = profile?['photoBase64'] ?? '';

              // ── Compute wardrobe stats ─────────────────
              final allItems = (clothesSnap.data?.docs ?? [])
                  .map((d) => ClothingItem.fromDoc(d))
                  .toList();
              final total     = allItems.length;
              final laundry   = allItems.where((i) => i.isLaundry).length;
              final available = total - laundry;

              // Category breakdown
              final Map<String, int> catCounts = {};
              for (final item in allItems) {
                catCounts[item.category] = (catCounts[item.category] ?? 0) + 1;
              }
              final sortedCats = catCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [

                  // ── Avatar ────────────────────────────
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                          child: Container(
                            width: 108,
                            height: 108,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.accent, width: 2),
                              color: AppColors.surface,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _uploadingPhoto
                                ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.accent,
                                strokeWidth: 2,
                              ),
                            )
                                : photoBase64.isNotEmpty
                                ? Image.memory(
                              base64Decode(photoBase64.split(',').last),
                              fit: BoxFit.cover,
                            )
                                : Center(
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 40,
                                  color: AppColors.accentLight,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Editable Name ──────────────────────
                  Center(
                    child: _editingName
                        ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _nameCtrl,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 6),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppColors.accent),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_circle,
                              color: AppColors.available),
                          onPressed: _saveName,
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel_outlined,
                              color: AppColors.textMuted),
                          onPressed: () =>
                              setState(() => _editingName = false),
                        ),
                      ],
                    )
                        : GestureDetector(
                      onTap: () {
                        _nameCtrl.text = displayName;
                        setState(() => _editingName = true);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.edit_outlined,
                              size: 16, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      email,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Tap name to edit  ·  Tap photo to change',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Stats Row ──────────────────────────
                  _sectionLabel('WARDROBE STATS'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatCard(value: '$total',     label: 'Total',     emoji: '👗'),
                      const SizedBox(width: 10),
                      _StatCard(value: '$available', label: 'Available', emoji: '✅'),
                      const SizedBox(width: 10),
                      _StatCard(value: '$laundry',   label: 'Laundry',  emoji: '🧺'),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── Category Breakdown ─────────────────
                  if (sortedCats.isNotEmpty) ...[
                    _sectionLabel('CATEGORY BREAKDOWN'),
                    const SizedBox(height: 14),
                    ...sortedCats.map((entry) => _CategoryBar(
                      category: entry.key,
                      count: entry.value,
                      total: total,
                    )),
                    const SizedBox(height: 32),
                  ],

                  // ── Laundry Summary ────────────────────
                  if (laundry > 0) ...[
                    _sectionLabel('NEEDS WASHING'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.laundry.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.laundry.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          const Text('🧺', style: TextStyle(fontSize: 28)),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$laundry item${laundry > 1 ? 's' : ''} in the laundry pile',
                                style: const TextStyle(
                                  color: AppColors.laundry,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Tap any item in your closet to mark it clean.',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // ── Sign Out ───────────────────────────
                  OutlinedButton.icon(
                    onPressed: _isSigningOut ? null : _signOut,
                    icon: _isSigningOut
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
                        : const Icon(Icons.logout, size: 18),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    ),
  );
}

class _StatCard extends StatelessWidget {
  final String value, label, emoji;
  const _StatCard({required this.value, required this.label, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style:
              const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String category;
  final int count, total;
  const _CategoryBar({required this.category, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Text(ClothingCategories.emojiFor(category), style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(category, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
              Text(
                '$count item${count > 1 ? 's' : ''}',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.surface,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}