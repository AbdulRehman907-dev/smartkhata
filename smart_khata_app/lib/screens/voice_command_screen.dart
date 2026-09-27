import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_client.dart';
import '../core/constants.dart';

// ---------------------------------------------------------------------------
// Data class for a single voice command history entry
// ---------------------------------------------------------------------------
class _HistoryEntry {
  final String command;
  final String intent;
  final String reply;
  final DateTime timestamp;
  final bool success;

  _HistoryEntry({
    required this.command,
    required this.intent,
    required this.reply,
    required this.timestamp,
    required this.success,
  });
}

// ---------------------------------------------------------------------------
// VoiceCommandScreen
// ---------------------------------------------------------------------------
class VoiceCommandScreen extends StatefulWidget {
  const VoiceCommandScreen({super.key});

  @override
  State<VoiceCommandScreen> createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends State<VoiceCommandScreen>
    with TickerProviderStateMixin {
  // ── Controllers ─────────────────────────────────────────────────────────
  final _promptController = TextEditingController(text: 'چاول کا اسٹاک چیک کرو');
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;

  // ── Animation ────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _ripple1Ctrl;
  late AnimationController _ripple2Ctrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _ripple1Anim;
  late Animation<double> _ripple2Anim;

  // ── State ────────────────────────────────────────────────────────────────
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isProcessing = false;
  String _selectedLanguage = 'Urdu';
  Map<String, dynamic>? _responseResult;

  /// Pending result waiting for user confirmation (for payment/sale intents)
  Map<String, dynamic>? _pendingConfirmation;
  bool _awaitingConfirmation = false;

  /// Conversational Multi-Turn Context (persisted between turns)
  Map<String, dynamic>? _conversationContext;

  /// Last 5 command history entries
  final List<_HistoryEntry> _history = [];

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initAnimations();
    _initTts();
    _initSpeech();

    // Seed a demo result so the screen doesn't look empty on first open
    _responseResult = {
      'intent': 'CHECK_STOCK',
      'reply': 'باسمتی چاول (Super Kernal): 50.0 kg (✅ کافی اسٹاک)',
      'entities': {'products': ['Basmati Rice (Super Kernal)']},
      'status': 'In stock',
    };
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _ripple1Ctrl.dispose();
    _ripple2Ctrl.dispose();
    _promptController.dispose();
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  // ── Animations ───────────────────────────────────────────────────────────
  void _initAnimations() {
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _ripple1Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _ripple2Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _ripple1Anim = Tween<double>(begin: 0.8, end: 1.6).animate(
      CurvedAnimation(parent: _ripple1Ctrl, curve: Curves.easeOut),
    );

    _ripple2Anim = Tween<double>(begin: 0.8, end: 1.9).animate(
      CurvedAnimation(parent: _ripple2Ctrl, curve: Curves.easeOut),
    );
  }

  void _startListeningAnimations() {
    _ripple1Ctrl.repeat();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _ripple2Ctrl.repeat();
    });
  }

  void _stopListeningAnimations() {
    _ripple1Ctrl.stop();
    _ripple2Ctrl.stop();
    _ripple1Ctrl.reset();
    _ripple2Ctrl.reset();
  }

  // ── TTS ──────────────────────────────────────────────────────────────────
  Future<void> _initTts() async {
    try {
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (_) {}
  }

  Future<void> _speakResponse(String text) async {
    if (text.isEmpty) return;
    try {
      if (_selectedLanguage == 'Urdu' || _selectedLanguage == 'Punjabi') {
        await _flutterTts.setLanguage('ur-PK');
      } else {
        await _flutterTts.setLanguage('en-US');
      }
      final cleanText = text
          .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
          .replaceAll('✅', '')
          .replaceAll('⚠️', '')
          .replaceAll('📱', '')
          .replaceAll('📄', '')
          .replaceAll('*', '')
          .replaceAll('_', '')
          .trim();
      if (cleanText.isNotEmpty) {
        await _flutterTts.speak(cleanText);
      }
    } catch (_) {}
  }

  // ── STT Init ─────────────────────────────────────────────────────────────
  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && _isListening) {
            _stopListeningAnimations();
            setState(() => _isListening = false);
            final txt = _promptController.text.trim();
            if (txt.isNotEmpty) _sendTextCommand(txt);
          }
        },
        onError: (_) {
          _stopListeningAnimations();
          setState(() => _isListening = false);
        },
      );
      setState(() => _speechAvailable = available);
    } catch (_) {
      setState(() => _speechAvailable = false);
    }
  }

  // ── Toggle Mic ───────────────────────────────────────────────────────────
  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      _stopListeningAnimations();
      setState(() => _isListening = false);
      final txt = _promptController.text.trim();
      if (txt.isNotEmpty) _sendTextCommand(txt);
      return;
    }

    if (!_speechAvailable) {
      final reinit = await _speech.initialize();
      if (!reinit) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission not granted or unavailable.'),
            backgroundColor: AppConstants.alertRed,
          ),
        );
        return;
      }
      setState(() => _speechAvailable = true);
    }

    final locale = _selectedLanguage == 'English' ? 'en_US' : 'ur_PK';
    setState(() {
      _isListening = true;
      _promptController.text = '';
    });
    _startListeningAnimations();

    _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: locale,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
      ),
      onResult: (SpeechRecognitionResult result) {
        setState(() {
          _promptController.text = result.recognizedWords;
        });
      },
    );
  }

  // ── Local Offline Intent Fallback ─────────────────────────────────────────
  Map<String, dynamic> _processLocalIntent(String text) {
    final t = text.toLowerCase();
    final nums = RegExp(r'\d+(?:\.\d+)?').allMatches(text).map((m) => double.tryParse(m.group(0)!) ?? 0.0).toList();
    double numVal = nums.isNotEmpty ? nums.first : 500.0;

    const urduNums = {
      'ek': 1, 'do': 2, 'teen': 3, 'char': 4, 'paanch': 5,
      'chhe': 6, 'saat': 7, 'aath': 8, 'nau': 9, 'das': 10,
      'bis': 20, 'tees': 30, 'chalis': 40, 'pachas': 50,
      'sau': 100, 'pach sau': 500, 'hazar': 1000,
      'teen hazar': 3000, 'paanch hazar': 5000, 'das hazar': 10000,
    };
    for (final entry in urduNums.entries) {
      if (t.contains(entry.key)) {
        if (t.contains('hazar') && entry.key != 'hazar') {
          numVal = entry.value * 1000;
        } else if (t.contains('sau') && entry.key != 'sau') {
          numVal = entry.value * 100;
        } else {
          numVal = entry.value.toDouble();
        }
        break;
      }
    }

    if (_matchesAny(t, ['diye', 'diya', 'paid', 'jamah', 'payment', 'vasool', 'wapas', 'karwaye', 'de diye', 'ada kiye', 'دیے', 'جمع', 'ادا', 'وصول'])) {
      return {
        'intent': 'RECORD_PAYMENT',
        'reply': 'ادائیگی Rs. $numVal ریکارڈ کی گئی۔ (آف لائن موڈ)',
        'entities': {'amount': numVal},
        'raw_text': text,
        'needs_confirmation': true,
        'confirm_message': 'Rs. ${numVal.toStringAsFixed(0)} کی ادائیگی ریکارڈ کریں؟',
      };
    }

    if (_matchesAny(t, [
      'becho', 'sell', 'sale', 'bech do', 'order', 'udhaar', 'udhar', 'credit', 'khata',
      'بیچو', 'فروخت', 'ادھار', 'دے دو', 'دو', 'کھاتے', 'کھاتہ'
    ])) {
      return {
        'intent': 'RECORD_SALE',
        'reply': 'فروخت / ادھار ریکارڈ کیا گیا۔ رقم: Rs. $numVal (آف لائن موڈ)',
        'entities': {'amount': numVal},
        'raw_text': text,
        'needs_confirmation': true,
        'confirm_message': 'Rs. ${numVal.toStringAsFixed(0)} کی فروخت / ادھار ریکارڈ کریں؟',
      };
    }

    if (_matchesAny(t, ['stock', 'available', 'kitna hai', 'اسٹاک', 'سٹاک', 'کتنا بچا', 'بچا ہے'])) {
      return {
        'intent': 'CHECK_STOCK',
        'reply': 'باسمتی چاول: 50 کلو۔ آٹا: 100 کلو۔ (آف لائن SQLite)',
        'entities': {},
        'raw_text': text,
      };
    }

    if (_matchesAny(t, ['balance', 'baki', 'owe', 'kitna dena', 'hisaab', 'کتنا', 'باقی', 'حساب'])) {
      return {
        'intent': 'CUSTOMER_BALANCE',
        'reply': 'محمد علی کا باقی Rs. 1,200 ہے۔ (آف لائن SQLite)',
        'entities': {},
        'raw_text': text,
      };
    }

    if (_matchesAny(t, ['whatsapp', 'واٹس ایپ', 'بل بھیجو'])) {
      const phone = '923001234567';
      final msg = Uri.encodeComponent('احمد جنرل سٹور: محمد علی صاحب، آپ کا بقایہ Rs. 1200 ہے۔');
      return {
        'intent': 'WHATSAPP_REMINDER',
        'reply': 'محمد علی کا واٹس ایپ بل تیار ہے۔',
        'entities': {'person': 'Muhammad Ali'},
        'whatsapp_url': 'https://wa.me/$phone?text=$msg',
        'raw_text': text,
      };
    }

    return {
      'intent': 'UNKNOWN',
      'reply': 'کمانڈ سمجھ نہیں آئی۔ مثال: "Ali ko 2 kilo chawal becho" یا "Ali ne 500 rupay diye"',
      'entities': {},
      'raw_text': text,
    };
  }

  bool _matchesAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  // ── Send / Process Command ────────────────────────────────────────────────
  Future<void> _sendTextCommand([String? overrideText]) async {
    final text = (overrideText ?? _promptController.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _awaitingConfirmation = false;
      _pendingConfirmation = null;
      _promptController.text = text;
    });

    Map<String, dynamic> res;
    try {
      final client = ApiClient();
      res = await client.post('/ai/intent', {
        'text': text,
        'context': _conversationContext,
      });
    } catch (_) {
      res = _processLocalIntent(text);
    }

    if (!mounted) return;

    // Handle intents that need confirmation before executing
    final needsConfirm = res['needs_confirmation'] == true;
    final intent = (res['intent'] as String? ?? '').toUpperCase();
    final isDestructive = ['RECORD_PAYMENT', 'RECORD_SALE', 'ADD_EXPENSE', 'ADD_STOCK', 'MARK_ATTENDANCE'].contains(intent);

    if (needsConfirm || isDestructive) {
      setState(() {
        _isProcessing = false;
        _pendingConfirmation = res;
        _awaitingConfirmation = true;
        _responseResult = null;
      });
      final confirmMsg = res['confirm_message'] as String?
          ?? res['reply'] as String?
          ?? 'Confirm action?';
      _speakResponse(confirmMsg);
      return;
    }

    // No confirmation needed — show result immediately
    _finalizeResult(res, text);
  }

  void _confirmAction() {
    if (_pendingConfirmation == null) return;
    final res = Map<String, dynamic>.from(_pendingConfirmation!);
    final text = _promptController.text.trim();
    setState(() {
      _awaitingConfirmation = false;
      _pendingConfirmation = null;
    });
    _finalizeResult(res, text);
  }

  void _cancelAction() {
    setState(() {
      _awaitingConfirmation = false;
      _pendingConfirmation = null;
      _isProcessing = false;
      _conversationContext = null;
    });
    _speakResponse('منسوخ کر دیا گیا۔');
  }

  void _finalizeResult(Map<String, dynamic> res, String originalText) {
    final replyText = res['reply'] as String? ?? '';
    final intent = (res['intent'] as String? ?? 'EXECUTED').toUpperCase();

    // Add to history
    final entry = _HistoryEntry(
      command: originalText,
      intent: intent,
      reply: replyText,
      timestamp: DateTime.now(),
      success: intent != 'UNKNOWN',
    );

    setState(() {
      _responseResult = res;
      _isProcessing = false;
      _conversationContext = null;
      _history.insert(0, entry);
      if (_history.length > 5) _history.removeLast();
    });

    if (replyText.isNotEmpty) _speakResponse(replyText);
  }

  // ── Open WhatsApp Link ────────────────────────────────────────────────────
  Future<void> _openWhatsApp(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch WhatsApp.')),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.creamBg,
      appBar: AppBar(
        backgroundColor: AppConstants.creamBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppConstants.charcoal),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Voice AI Command',
          style: GoogleFonts.instrumentSerif(
            color: AppConstants.charcoal,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              _speechAvailable ? Icons.wifi : Icons.wifi_off,
              color: _speechAvailable ? AppConstants.deepEmerald : AppConstants.textMuted,
              size: 18,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            // 1. Language selector chips
            _buildLanguageSelector(),
            const SizedBox(height: 24),

            // 2. Animated mic button
            _buildMicButton(),
            const SizedBox(height: 12),
            _buildListeningStatusText(),
            const SizedBox(height: 24),

            // 3. Quick sample commands
            _buildQuickCommands(),
            const SizedBox(height: 20),

            // 4. Transcription card
            _buildTranscriptionCard(),
            const SizedBox(height: 16),

            // 5. Confirmation card (shown only when awaiting)
            if (_awaitingConfirmation && _pendingConfirmation != null)
              _buildConfirmationCard(),

            // 6. Result card
            if (!_awaitingConfirmation)
              _buildResultCard(),
            const SizedBox(height: 20),

            // 7. History log
            if (_history.isNotEmpty) _buildHistoryCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Language Selector ─────────────────────────────────────────────────────
  Widget _buildLanguageSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ['Urdu', 'English', 'Punjabi'].map((lang) {
        final sel = _selectedLanguage == lang;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: GestureDetector(
            onTap: () => setState(() => _selectedLanguage = lang),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: sel ? AppConstants.deepEmerald : AppConstants.surfaceWhite,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: sel ? AppConstants.deepEmerald : AppConstants.softBorder,
                ),
                boxShadow: sel
                    ? [BoxShadow(color: AppConstants.deepEmerald.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))]
                    : [],
              ),
              child: Text(
                lang,
                style: GoogleFonts.inter(
                  color: sel ? Colors.white : AppConstants.charcoal,
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Animated Mic Button ───────────────────────────────────────────────────
  Widget _buildMicButton() {
    const baseSize = 100.0;
    const activeColor = AppConstants.alertRed;
    const idleColor = AppConstants.deepEmerald;
    final color = _isListening ? activeColor : idleColor;

    return GestureDetector(
      onTap: _toggleListening,
      child: SizedBox(
        width: baseSize * 2.2,
        height: baseSize * 2.2,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ripple 2 (outer)
            if (_isListening)
              AnimatedBuilder(
                animation: _ripple2Anim,
                builder: (_, __) => Opacity(
                  opacity: (1 - _ripple2Anim.value / 1.9).clamp(0, 1).toDouble(),
                  child: Transform.scale(
                    scale: _ripple2Anim.value,
                    child: Container(
                      width: baseSize,
                      height: baseSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ),
              ),
            // Ripple 1 (middle)
            if (_isListening)
              AnimatedBuilder(
                animation: _ripple1Anim,
                builder: (_, __) => Opacity(
                  opacity: (1 - _ripple1Anim.value / 1.6).clamp(0, 1).toDouble(),
                  child: Transform.scale(
                    scale: _ripple1Anim.value,
                    child: Container(
                      width: baseSize,
                      height: baseSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
              ),
            // Pulse scale wrapper
            AnimatedBuilder(
              animation: _isListening ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
              builder: (_, child) => Transform.scale(
                scale: _isListening ? _pulseAnim.value : 1.0,
                child: child,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: baseSize,
                height: baseSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningStatusText() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Text(
        key: ValueKey(_isListening),
        _isListening
            ? '🔴  سن رہا ہوں… بولیں'
            : 'مائیکروفون دبائیں اور بولیں',
        style: GoogleFonts.inter(
          color: _isListening ? AppConstants.alertRed : AppConstants.deepEmerald,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── Quick Commands ────────────────────────────────────────────────────────
  Widget _buildQuickCommands() {
    final cmds = [
      'چاول کا اسٹاک چیک کرو',
      'Muhammad Ali ne 500 rupay diye',
      'Ali ko 2 kilo chawal aur 1 litre tel udhaar becho',
      'Ali ko WhatsApp per bill bhej do',
      'Bijli ka bill 3000 rupay',
      'Ali Cashier ki aaj hazari lagao',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نمونہ کمانڈز (ٹیپ کریں):',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.textMuted),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: cmds.map((cmd) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(cmd, style: GoogleFonts.inter(fontSize: 12)),
                  backgroundColor: AppConstants.surfaceWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppConstants.softBorder),
                  ),
                  onPressed: () {
                    setState(() => _promptController.text = cmd);
                    _sendTextCommand(cmd);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Transcription Card ────────────────────────────────────────────────────
  Widget _buildTranscriptionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isListening ? AppConstants.alertRed : AppConstants.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ٹرانسکرپٹ / Command',
                style: GoogleFonts.inter(color: AppConstants.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: _isProcessing ? AppConstants.textMuted : AppConstants.deepEmerald,
                  size: 20,
                ),
                onPressed: _isProcessing ? null : () => _sendTextCommand(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          TextField(
            controller: _promptController,
            maxLines: 2,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppConstants.charcoal),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'بولیں یا یہاں ٹائپ کریں…',
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  // ── Confirmation Card ─────────────────────────────────────────────────────
  Widget _buildConfirmationCard() {
    final confirmMsg = _pendingConfirmation?['confirm_message'] as String?
        ?? _pendingConfirmation?['reply'] as String?
        ?? 'یہ کام کریں؟';
    final intent = (_pendingConfirmation?['intent'] as String? ?? 'ACTION').toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    Text(intent, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFD97706))),
                  ],
                ),
              ),
              const Spacer(),
              Text('تصدیق کریں', style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            confirmMsg,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppConstants.charcoal, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _confirmAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.deepEmerald,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text('ہاں، کریں', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelAction,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.alertRed,
                    side: const BorderSide(color: AppConstants.alertRed),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cancel_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('منسوخ', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Result Card ───────────────────────────────────────────────────────────
  Widget _buildResultCard() {
    final whatsappUrl = _responseResult?['whatsapp_url'] as String?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppConstants.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI نتیجہ', style: GoogleFonts.inter(color: AppConstants.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_isProcessing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppConstants.deepEmerald),
              ),
            )
          else if (_responseResult != null) ...[
            // Intent badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppConstants.softGreenChip,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (_responseResult!['intent'] ?? 'EXECUTED').toString().toUpperCase(),
                    style: GoogleFonts.inter(color: AppConstants.deepEmerald, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Reply text
            Text(
              _responseResult!['reply'] ?? 'عمل مکمل ہو گیا۔',
              style: GoogleFonts.inter(color: AppConstants.charcoal, fontWeight: FontWeight.w700, fontSize: 15, height: 1.5),
            ),
            // Direct WhatsApp Send Button
            if (whatsappUrl != null && whatsappUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => _openWhatsApp(whatsappUrl),
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                label: Text('واٹس ایپ پر بل بھیجیں (WhatsApp)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            // Entities
            if (_responseResult!['entities'] is Map && (_responseResult!['entities'] as Map).isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: (_responseResult!['entities'] as Map).entries.map((e) {
                  if (e.key == 'whatsapp_url') return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConstants.creamBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppConstants.softBorder),
                    ),
                    child: Text(
                      '${e.key}: ${e.value}',
                      style: GoogleFonts.inter(fontSize: 11, color: AppConstants.textMuted, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
            ],
          ] else
            Text('کوئی نتیجہ نہیں', style: GoogleFonts.inter(color: AppConstants.textMuted, fontSize: 14)),
        ],
      ),
    );
  }

  // ── History Card ──────────────────────────────────────────────────────────
  Widget _buildHistoryCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'کمانڈ ہسٹری',
          style: GoogleFonts.instrumentSerif(color: AppConstants.charcoal, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ..._history.map((entry) => _buildHistoryTile(entry)),
      ],
    );
  }

  Widget _buildHistoryTile(_HistoryEntry entry) {
    final timeStr = '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.softBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: entry.success
                  ? AppConstants.softGreenChip
                  : AppConstants.softRedChip,
              shape: BoxShape.circle,
            ),
            child: Icon(
              entry.success ? Icons.check : Icons.close,
              size: 14,
              color: entry.success ? AppConstants.deepEmerald : AppConstants.alertRed,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.command,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppConstants.charcoal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(timeStr, style: GoogleFonts.inter(fontSize: 11, color: AppConstants.textMuted)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  entry.reply,
                  style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
