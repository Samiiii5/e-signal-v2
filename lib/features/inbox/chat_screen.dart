import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/mock/messages_mock.dart';
import '../../shared/mock/threads_mock.dart';
import '../../shared/services/inbox_service.dart';

class ChatScreen extends StatefulWidget {
  final String threadId;
  const ChatScreen({super.key, required this.threadId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  List<Message> _messages = [];
  Thread? _thread;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final messages = await inboxService.getMessages(widget.threadId);
    final threads = await inboxService.getThreads();
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _thread = threads.where((t) => t.id == widget.threadId).firstOrNull;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    _controller.clear();
    setState(() => _isSending = true);
    try {
      await inboxService.sendMessage(widget.threadId, text);
      await _load();
      if (mounted) ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(AppSnackbar.success('Message envoyé'));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _ChatAppBar(thread: _thread),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _messages.isEmpty ? 1 : _messages.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) return const _SecurityBanner();
                final msg = _messages[i - 1];
                return msg.type == MessageType.paymentLink
                    ? _PaymentBubble(message: msg)
                    : _MessageBubble(message: msg);
              },
            ),
          ),
          _InputBar(
            controller: _controller,
            isSending: _isSending,
            onSend: _send,
            onPayment: () => ScaffoldMessenger.of(context).showSnackBar(AppSnackbar.success('Lien de paiement — bientôt disponible')),
          ),
        ],
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget {
  final Thread? thread;
  const _ChatAppBar({required this.thread});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 22, color: AppColors.textPrimary),
                onPressed: () => context.pop(),
              ),
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.backgroundPage,
                child: Text(
                  thread?.contactInitials ?? '?',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(thread?.contactName ?? '...', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(_channelLabel(thread?.channel), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.more_vert, color: AppColors.textSecondary), onPressed: () {}),
            ],
          ),
        ),
      ),
    );
  }

  String _channelLabel(Channel? ch) => switch (ch) {
    Channel.whatsapp => 'WhatsApp',
    Channel.facebook => 'Facebook',
    Channel.sms => 'SMS',
    Channel.tiktok => 'TikTok',
    Channel.email => 'Email',
    null => '...',
  };
}

// ── Bannière sécurité ─────────────────────────────────────────────────────────

class _SecurityBanner extends StatelessWidget {
  const _SecurityBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFECB3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, size: 14, color: Color(0xFFF59E0B)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Messages et appels chiffrés de bout en bout. Personne en dehors de cette conversation ne peut les lire ou les écouter.',
              style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bulle message ─────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Message message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final fromContact = message.isFromContact;
    return Align(
      alignment: fromContact ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromContact ? AppColors.white : AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(fromContact ? 4 : 18),
            bottomRight: Radius.circular(fromContact ? 18 : 4),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: fromContact ? 0.06 : 0.12), blurRadius: 6, offset: const Offset(0, 2))],
          border: fromContact ? Border.all(color: AppColors.borderLight, width: 0.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(message.content, style: TextStyle(fontSize: 14, color: fromContact ? AppColors.textPrimary : AppColors.white, height: 1.4)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_formatTime(message.sentAt), style: TextStyle(fontSize: 10, color: fromContact ? AppColors.textHint : AppColors.white.withValues(alpha: 0.65))),
                if (!fromContact) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.done_all, size: 12, color: AppColors.white.withValues(alpha: 0.65)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ── Bulle paiement ────────────────────────────────────────────────────────────

class _PaymentBubble extends StatelessWidget {
  final Message message;
  const _PaymentBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.greenLight, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header vert pâle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 14, color: AppColors.greenDark),
                  const SizedBox(width: 6),
                  const Text('Lien de paiement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.greenDark)),
                  const Spacer(),
                  if (message.paymentStatus != null) _PaymentStatusBadge(status: message.paymentStatus!),
                ],
              ),
            ),
            // Montant
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Text(
                '${message.paymentAmount ?? "0"} FCFA',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text('Valide 7 jours', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
            // Bouton
            if (message.paymentStatus != PaymentStatus.paid)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    child: const Text('Voir le lien', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentStatusBadge extends StatelessWidget {
  final PaymentStatus status;
  const _PaymentStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, text, label) = switch (status) {
      PaymentStatus.paid => (AppColors.statusPaidBg, AppColors.statusPaidText, 'Payé'),
      PaymentStatus.pending => (AppColors.statusPendingBg, AppColors.statusPendingText, 'En attente'),
      PaymentStatus.created => (AppColors.statusCreatedBg, AppColors.statusCreatedText, 'Créé'),
      PaymentStatus.expired => (AppColors.statusExpiredBg, AppColors.statusExpiredText, 'Expiré'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: text)),
    );
  }
}

// ── Barre de saisie ───────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onPayment;

  const _InputBar({required this.controller, required this.isSending, required this.onSend, required this.onPayment});

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: AppColors.backgroundPage, borderRadius: BorderRadius.circular(24)),
                  child: TextField(
                    controller: controller,
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Écrire un message...',
                      hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Mic ou Send
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: hasText
                    ? GestureDetector(
                        key: const ValueKey('send'),
                        onTap: isSending ? null : onSend,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                          child: isSending
                              ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                              : const Icon(Icons.send, color: AppColors.white, size: 20),
                        ),
                      )
                    : GestureDetector(
                        key: const ValueKey('mic'),
                        onTap: () {},
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.mic, color: AppColors.white, size: 20),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Bouton paiement
          GestureDetector(
            onTap: onPayment,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: AppColors.greenDark),
                  SizedBox(width: 6),
                  Text('Paiement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.greenDark)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
