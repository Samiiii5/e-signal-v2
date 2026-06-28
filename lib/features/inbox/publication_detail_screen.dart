import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/mock/publications_mock.dart';

class PublicationDetailScreen extends StatefulWidget {
  final Publication publication;
  const PublicationDetailScreen({super.key, required this.publication});

  @override
  State<PublicationDetailScreen> createState() => _PublicationDetailScreenState();
}

class _PublicationDetailScreenState extends State<PublicationDetailScreen> {
  final _replyCtrl = TextEditingController();
  late List<PublicationComment> _comments;

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.publication.comments);
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  void _sendReply() {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _comments.insert(0, PublicationComment(
        id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
        authorName: 'Vous',
        initials: 'V',
        text: text,
        sentAt: DateTime.now(),
      ));
    });
    _replyCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final pub = widget.publication;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            _NetworkAvatar(network: pub.network, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                pub.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, color: AppColors.borderLight),
        ),
      ),
      body: Column(
        children: [
          // Publication card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.backgroundPage,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight, width: 0.5),
            ),
            child: Row(
              children: [
                _NetworkAvatar(network: pub.network, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pub.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        '${pub.commentCount} commentaires · ${_fmtDate(pub.publishedAt)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Commentaires', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(10)),
                  child: Text('${_comments.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.greenDark)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _comments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _CommentTile(comment: _comments[i]),
            ),
          ),
          // Reply input
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              border: const Border(top: BorderSide(color: AppColors.borderLight, width: 0.5)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.backgroundPage, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.borderLight)),
                    child: TextField(
                      controller: _replyCtrl,
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Répondre au commentaire...',
                        hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendReply(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendReply,
                  child: Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded, color: AppColors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    if (diff.inDays == 1) return 'hier';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _CommentTile extends StatelessWidget {
  final PublicationComment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final isMe = comment.authorName == 'Vous';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isMe ? AppColors.greenLight : AppColors.backgroundPage,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              comment.initials,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: isMe ? AppColors.greenDark : AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(comment.authorName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(width: 8),
                  Text(_fmtTime(comment.sentAt), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.greenLight : AppColors.backgroundPage,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(4),
                    topRight: const Radius.circular(14),
                    bottomLeft: const Radius.circular(14),
                    bottomRight: const Radius.circular(14),
                  ),
                ),
                child: Text(comment.text, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'hier';
    return '${dt.day}/${dt.month}';
  }
}

class _NetworkAvatar extends StatelessWidget {
  final String network;
  final double size;
  const _NetworkAvatar({required this.network, required this.size});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (network) {
      'facebook'  => (const Color(0xFF1877F2), 'f'),
      'instagram' => (const Color(0xFFE1306C), '📷'),
      'tiktok'    => (const Color(0xFF010101), '♪'),
      _           => (AppColors.textSecondary,  '?'),
    };
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(label, style: TextStyle(fontSize: size * 0.38, color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
