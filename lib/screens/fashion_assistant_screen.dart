import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../main.dart';
import '../services/firebase_service.dart';
import '../services/gemini_service.dart';

class FashionAssistantScreen extends StatefulWidget {
  final FirebaseService service;
  const FashionAssistantScreen({super.key, required this.service});
  @override State<FashionAssistantScreen> createState() =>
      _FashionAssistantScreenState();
}

class _FashionAssistantScreenState
    extends State<FashionAssistantScreen> {
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();

  ChatSession? _session;
  final List<_Msg> _messages = [];
  bool _loading = true;
  bool _sending = false;

  static const _suggestions = [
    'What should I wear today?',
    'Outfit for a job interview',
    'What goes with my jeans?',
    'Smart casual ideas',
    'What am I missing?',
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final wardrobe = await widget.service.wardrobeSnapshot();
    _session = GeminiService.instance.startFashionChat(wardrobe);
    setState(() => _loading = false);
    _addMsg(
      "Hey! 👋 I've scanned your closet. Ask me anything — outfit ideas, what pairs with a specific item, or what to wear for any occasion.",
      false,
    );
  }

  void _addMsg(String text, bool isUser) {
    setState(() => _messages.add(_Msg(text: text, isUser: isUser)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _session == null || _sending) return;
    _inputCtrl.clear();
    _addMsg(msg, true);
    setState(() => _sending = true);
    final reply = await GeminiService.instance.chat(_session!, msg);
    _addMsg(reply, false);
    setState(() => _sending = false);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Style Assistant')),
        body: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: AppColors.accent),
            SizedBox(height: 16),
            Text('Loading your wardrobe…',
                style: TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(children: [
          Text('✨', style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Text('Style Assistant'),
        ]),
      ),
      body: Column(children: [

        // ── Message list ────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            itemCount: _messages.length,
            itemBuilder: (_, i) => _BubbleWidget(msg: _messages[i]),
          ),
        ),

        // ── Typing indicator ────────────────────────────
        if (_sending)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(children: [
              const _TypingDots(),
              const SizedBox(width: 10),
              Text('Styling…',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontStyle: FontStyle.italic)),
            ]),
          ),

        // ── Suggestion chips (visible until user sends first msg) ──
        if (_messages.length <= 1 && !_sending)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                label: Text(_suggestions[i],
                    style: const TextStyle(
                        color: AppColors.accentLight, fontSize: 12)),
                backgroundColor:
                    AppColors.accent.withOpacity(0.12),
                side: BorderSide(
                    color: AppColors.accent.withOpacity(0.3)),
                onPressed: () => _send(_suggestions[i]),
              ),
            ),
          ),

        const SizedBox(height: 4),

        // ── Input bar ───────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  onSubmitted: _send,
                  decoration: InputDecoration(
                    hintText: 'Ask your stylist…',
                    hintStyle:
                        const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.card,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                            color: AppColors.accent, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _sending ? null : () => _send(_inputCtrl.text),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _sending ? AppColors.border : AppColors.accent,
                  ),
                  child: Icon(
                    _sending
                        ? Icons.hourglass_empty
                        : Icons.send_rounded,
                    color: Colors.white, size: 20,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Data class ──────────────────────────────────────────────
class _Msg {
  final String text;
  final bool isUser;
  const _Msg({required this.text, required this.isUser});
}

// ── Chat bubble ─────────────────────────────────────────────
class _BubbleWidget extends StatelessWidget {
  final _Msg msg;
  const _BubbleWidget({required this.msg, super.key});

  @override Widget build(BuildContext context) {
    return Align(
      alignment:
          msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: msg.isUser ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(18),
            topRight:    const Radius.circular(18),
            bottomLeft:  Radius.circular(msg.isUser ? 18 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 18),
          ),
          border: msg.isUser
              ? null
              : Border.all(color: AppColors.border),
        ),
        child: Text(msg.text,
            style: TextStyle(
              color: msg.isUser ? Colors.white : AppColors.textPrimary,
              fontSize: 14,
              height: 1.45,
            )),
      ),
    );
  }
}

// ── Animated typing dots ─────────────────────────────────────
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_ctrl.value - i * 0.15).clamp(0.0, 1.0);
          final opacity =
              (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withOpacity(opacity),
            ),
          );
        }),
      ),
    );
  }
}
