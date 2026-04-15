import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/clothing_item.dart';

class FirebaseService {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn.instance;

  User?   get currentUser      => _auth.currentUser;
  String? get uid              => _auth.currentUser?.uid;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── SAFE REFERENCE GETTERS ──────────────────────────────
  // These return null if no user is logged in, preventing the "Null Check" crash.

  CollectionReference? get _clothesRef {
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('clothes');
  }

  DocumentReference? get _profileRef {
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  // ── AUTH ────────────────────────────────────────────────

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize();
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      final GoogleSignInClientAuthorization authorization = await googleUser
          .authorizationClient
          .authorizeScopes(['email', 'profile']);

      final String? accessToken = authorization.accessToken;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final UserCredential cred = await _auth.signInWithCredential(credential);

      // Sync user data to Firestore if new
      if (cred.additionalUserInfo?.isNewUser ?? false) {
        await _db.collection('users').doc(cred.user!.uid).set({
          'displayName': cred.user!.displayName ?? 'New User',
          'email': cred.user!.email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return cred;
    } catch (e) {
      debugPrint('Google Auth Error: $e');
      rethrow;
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await _db.collection('users').doc(cred.user!.uid).set({
      'displayName': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await cred.user!.updateDisplayName(name);
  }

  Future<void> signIn({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> resetPassword({required String email}) =>
      _auth.sendPasswordResetEmail(email: email);

  // ── PROFILE ─────────────────────────────────────────────

  // Return an empty stream if no user is found to prevent UI crashes
  Stream<DocumentSnapshot> profileStream() {
    return _profileRef?.snapshots() ?? const Stream.empty();
  }

  Future<void> updateDisplayName(String name) async {
    if (_profileRef == null) return;
    await _profileRef!.update({'displayName': name});
    await currentUser?.updateDisplayName(name);
  }

  // ── CLOTHES ─────────────────────────────────────────────

  Stream<QuerySnapshot> clothesStream() {
    return _clothesRef?.orderBy('addedAt', descending: true).snapshots() ?? const Stream.empty();
  }

  Future<void> addItem({
    required String name,
    required String imageUrl,
    required String category,
    required String type,
    String colour = '',
  }) async {
    if (_clothesRef == null) return;
    await _clothesRef!.add({
      'name':      name,
      'imageUrl':  imageUrl,
      'category':  category,
      'type':      type,
      'colour':    colour,
      'status':    'available',
      'addedAt':   FieldValue.serverTimestamp(),
      'lastWashed': null,
    });
  }

  Future<void> toggleStatus(String itemId, String current) async {
    if (_clothesRef == null) return;
    final next = current == 'available' ? 'laundry' : 'available';
    final update = <String, dynamic>{'status': next};
    if (next == 'available') {
      update['lastWashed'] = FieldValue.serverTimestamp();
    }
    await _clothesRef!.doc(itemId).update(update);
  }

  Future<void> deleteItem(ClothingItem item) async {
    if (_clothesRef == null) return;
    await _clothesRef!.doc(item.id).delete();
  }

  Future<List<Map<String, dynamic>>> wardrobeSnapshot() async {
    if (_clothesRef == null) return [];
    final snap = await _clothesRef!.get();
    return snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList();
  }

  // ── IMAGE UPLOAD ────────────────────────────────────────
  Future<String> uploadImage(File imageFile, {void Function(double)? onProgress}) async {
    final cloudinary = CloudinaryPublic(
        dotenv.env['CLOUDINARY_API_KEY'] ?? '',
        dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '',
        cache: false
    );
    try {
      Uint8List imageBytes;
      if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        imageBytes = await imageFile.readAsBytes();
      } else {
        final compressed = await FlutterImageCompress.compressWithFile(
          imageFile.absolute.path,
          minWidth: 600, minHeight: 600,
          quality: 65, format: CompressFormat.jpeg,
        );
        if (compressed == null) throw Exception('Compression failed');
        imageBytes = compressed;
      }

      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromBytesData(
          imageBytes,
          identifier: 'closet_item_${DateTime.now().millisecondsSinceEpoch}',
          resourceType: CloudinaryResourceType.Image,
        ),
        onProgress: (count, total) => onProgress?.call(count / total),
      );
      return response.secureUrl;
    } catch (e) {
      rethrow;
    }
  }
}