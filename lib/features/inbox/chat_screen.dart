import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/mock/messages_mock.dart';
import '../../shared/mock/threads_mock.dart';

class ChatScreen extends StatefulWidget {
  final String threadId;

  const ChatScreen({super.key, required this.threadId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  late List<Message> _messages;
  late Thread _thread;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _thread = mockThreads.firstWhere((t) => t.id == widget.threadId);
    _messages = widget.threadId == 'thread_001'
        ? List.from(mockMessagesThread001)
        : [];
    _inputController.addListener(() {
      final hasText = _inputController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animate: false));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(max,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _scrollController.jumpTo(max);
    }
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(Message(
        id: 'msg_new_${DateTime.now().millisecondsSinceEpoch}',
        threadId: widget.threadId,
        content: text,
        isFromContact: false,
        sentAt: DateTime.now(),
      ));
    });
    _inputController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(AppSnackbar.success('Message envoyé'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: _ChatAppBar(thread: _thread),
      body: Column(
        children: [
          // Liste des messages
          Expanded(
            child: _messages.isEmpty
                ? const _EmptyChat()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      final prev = i > 0 ? _messages[i - 1] : null;
                      final showTime = prev == null ||
                          msg.sentAt.difference(prev.sentAt).inMinutes > 15;
                      return Column(
                        children: [
                          if (showTime) _TimeStampDivider(time: msg.sentAt),
                          _MessageBubble(message: msg),
                        ],
                      );
                    },
                  ),
          ),

          // Zone de saisie
          _InputBar(
            controller: _inputController,
            hasText: _hasText,
            onSend: _sendMessage,
            onPayment: () {
              // TODO : ouvrir create_link_screen (Sprint suivant)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Création de lien de paiement — bientôt disponible',
                    style: AppTextStyles.small.copyWith(color: AppColors.white),
                  ),
                  backgroundColor: AppColors.purple,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── AppBar ───────────────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Thread thread;
  const _ChatAppBar({required this.thread});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      child: Row(
        children: [
          // Bouton retour
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),

          // Avatar
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.backgroundPage,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                thread.contactInitials,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Nom + statut
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread.contactName,
                  style: AppTextStyles.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'En ligne · ${_channelLabel(thread.channel)}',
                  style: AppTextStyles.tiny.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // Menu
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  String _channelLabel(Channel ch) {
    switch (ch) {
      case Channel.whatsapp: return 'WhatsApp';
      case Channel.facebook: return 'Facebook';
      case Channel.sms:      return 'SMS';
      case Channel.tiktok:   return 'TikTok';
      case Channel.email:    return 'Email';
    }
  }
}

// ─── Bulle de message ─────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Message message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.paymentLink) {
      return _PaymentBubble(message: message);
    }

    final isContact = message.isFromContact;

    return Align(
      alignment: isContact ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isContact ? AppColors.white : AppColors.green,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isContact ? 4 : 18),
              bottomRight: Radius.circular(isContact ? 18 : 4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            message.content,
            style: AppTextStyles.body.copyWith(
              color: isContact ? AppColors.textPrimary : AppColors.white,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Carte paiement ───────────────────────────────────────────────────────────

class _PaymentBubble extends StatelessWidget {
  final Message message;
  const _PaymentBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final status = message.paymentStatus ?? PaymentStatus.created;
    final provider = message.paymentProvider ?? 'wave';
    final amount = message.paymentAmount ?? '0';
    final currency = message.paymentCurrency ?? 'FCFA';

    return Align(
      alignment: message.isFromContact ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.purpleLight, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête violet
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppColors.purpleLight,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 16, color: AppColors.purple),
                    const SizedBox(width: 6),
                    Text(
                      'Lien de paiement · ${provider == 'wave' ? 'Wave' : 'Orange Money'}',
                      style: AppTextStyles.smallSemiBold.copyWith(color: AppColors.purple),
                    ),
                  ],
                ),
              ),

              // Montant + statut
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$amount $currency',
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message.content,
                      style: AppTextStyles.small,
                    ),
                    const SizedBox(height: 10),
                    _PaymentStatusBadge(status: status),
                  ],
                ),
              ),
            ],
          ),
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
    final (bg, textColor, label, icon) = switch (status) {
      PaymentStatus.paid    => (AppColors.statusPaidBg,    AppColors.statusPaidText,    'Payé',       Icons.check_circle_outline),
      PaymentStatus.pending => (AppColors.statusPendingBg, AppColors.statusPendingText, 'En attente', Icons.schedule),
      PaymentStatus.created => (AppColors.statusCreatedBg, AppColors.statusCreatedText, 'Créé',       Icons.radio_button_unchecked),
      PaymentStatus.expired => (AppColors.statusExpiredBg, AppColors.statusExpiredText, 'Expiré',     Icons.cancel_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.tiny.copyWith(color: textColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Séparateur horodatage ────────────────────────────────────────────────────

class _TimeStampDivider extends StatelessWidget {
  final DateTime time;
  const _TimeStampDivider({required this.time});

  String _label() {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inHours < 6) return _hm(time);
    if (diff.inDays < 1) return 'Aujourd\'hui ${_hm(time)}';
    if (diff.inDays < 2) return 'Hier ${_hm(time)}';
    return '${time.day}/${time.month} ${_hm(time)}';
  }

  String _hm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.borderLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _label(),
            style: AppTextStyles.tiny.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

// ─── Zone de saisie ───────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;
  final VoidCallback onSend;
  final VoidCallback onPayment;

  const _InputBar({
    required this.controller,
    required this.hasText,
    required this.onSend,
    required this.onPayment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight, width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(
        12, 10, 12, 10 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bouton paiement
          GestureDetector(
            onTap: onPayment,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.purpleLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.link, color: AppColors.purple, size: 20),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Input texte
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.backgroundPage,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: TextField(
                controller: controller,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.body,
                decoration: const InputDecoration(
                  hintText: 'Message…',
                  hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Bouton envoi
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: hasText ? AppColors.green : AppColors.backgroundPage,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: hasText ? onSend : null,
              icon: Icon(
                Icons.send_rounded,
                size: 18,
                color: hasText ? AppColors.white : AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── État vide ────────────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 40, color: AppColors.borderLight),
          const SizedBox(height: 10),
          Text('Aucun message', style: AppTextStyles.bodySecondary),
        ],
      ),
    );
  }
}
