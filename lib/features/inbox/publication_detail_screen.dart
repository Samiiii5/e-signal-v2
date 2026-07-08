import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/session_service.dart';
import '../../shared/mock/publications_mock.dart';
import '../../shared/services/comments_service.dart';

class PublicationDetailScreen extends StatefulWidget {
  final Publication publication;
  final String? apiPostId;
  const PublicationDetailScreen({super.key, required this.publication, this.apiPostId});

  @override
  State<PublicationDetailScreen> createState() => _PublicationDetailScreenState();
}

class _PublicationDetailScreenState extends State<PublicationDetailScreen> {
  final _replyCtrl = TextEditingController();
  final _focusNode = FocusNode();
  late List<PublicationComment> _comments;
  PublicationComment? _replyTarget;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.publication.comments);
    if (widget.apiPostId != null) {
      _loadComments();
    }
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startReply(PublicationComment comment) {
    setState(() => _replyTarget = comment);
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyTarget = null);
  }

  Future<void> _loadComments() async {
    if (!mounted || widget.apiPostId == null) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final raw = await commentsService.getComments(postId: widget.apiPostId);
      if (!mounted) return;
      // Sort newest first
      raw.sort((a, b) {
        final da = DateTime.tryParse((a['created_at'] ?? a['sent_at'] ?? '').toString()) ?? DateTime(0);
        final db = DateTime.tryParse((b['created_at'] ?? b['sent_at'] ?? '').toString()) ?? DateTime(0);
        return db.compareTo(da);
      });
      final mapped = raw.map((c) {
        final authorName = (c['author_name'] ?? c['authorName'] ?? c['author'] ?? 'Inconnu').toString();
        final initials = authorName.trim().isNotEmpty
            ? authorName.trim().split(RegExp(r'\s+')).map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').take(2).join()
            : '?';
        final sentAtRaw = c['created_at'] ?? c['sent_at'] ?? c['sentAt'];
        final sentAt = sentAtRaw != null ? (DateTime.tryParse(sentAtRaw.toString()) ?? DateTime.now()) : DateTime.now();
        return PublicationComment(
          id: (c['id'] ?? '').toString(),
          authorName: authorName,
          initials: initials,
          text: (c['text'] ?? c['content'] ?? c['body'] ?? '').toString(),
          sentAt: sentAt,
          replyToCommentId: c['reply_to_comment_id']?.toString() ?? c['replyToCommentId']?.toString(),
          replyToName: c['reply_to_name']?.toString() ?? c['replyToName']?.toString(),
        );
      }).toList();

      setState(() {
        _comments = mapped.isNotEmpty ? mapped : List.from(widget.publication.comments);
        _isLoading = false;
      });

      // Mark all new comments as read (fire & forget)
      for (final c in raw.where((c) => (c['status'] ?? '') == 'new')) {
        commentsService.updateCommentStatus(
          commentId: (c['id'] ?? '').toString(),
          status: 'read',
        ).ignore();
      }
    } on CommentsUnauthorizedException {
      if (!mounted) return;
      SessionService.logout();
      context.go('/login');
    } on CommentsUnavailableException {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = 'Service temporairement indisponible.'; });
    } on CommentsNetworkException {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = 'Vérifiez votre connexion internet.'; });
    } catch (_) {
      if (!mounted) return;
      // Fallback silencieux : garder les commentaires mock
      setState(() { _isLoading = false; });
    }
  }

  void _sendReply() {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;

    final newComment = PublicationComment(
      id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
      authorName: 'Vous',
      initials: 'V',
      text: text,
      sentAt: DateTime.now(),
      replyToCommentId: _replyTarget?.id,
      replyToName: _replyTarget?.authorName,
    );

    // Appel API si on a un vrai ID de commentaire cible
    if (_replyTarget != null && widget.apiPostId != null) {
      final channel = widget.publication.network;
      commentsService.replyToComment(
        commentId: _replyTarget!.id,
        message: text,
        provider: channel,
      ).ignore();
    }

    setState(() {
      if (_replyTarget != null) {
        // Insert just after the parent comment
        final parentId = _replyTarget!.id;
        int insertIndex = _comments.length;
        int parentIndex = _comments.indexWhere((c) => c.id == parentId);
        if (parentIndex != -1) {
          int idx = parentIndex + 1;
          while (idx < _comments.length && _comments[idx].replyToCommentId == parentId) {
            idx++;
          }
          insertIndex = idx;
        }
        _comments.insert(insertIndex, newComment);
      } else {
        _comments.insert(0, newComment);
      }
      _replyTarget = null;
    });
    _replyCtrl.clear();
  }

  /// Build the flat list with indentation for replies
  List<Widget> _buildCommentWidgets() {
    final widgets = <Widget>[];
    for (int i = 0; i < _comments.length; i++) {
      final comment = _comments[i];
      final isReply = comment.replyToCommentId != null;
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: isReply ? 40.0 : 0.0),
          child: _CommentTile(
            comment: comment,
            onReply: () => _startReply(comment),
          ),
        ),
      );
      if (i < _comments.length - 1) {
        widgets.add(const SizedBox(height: 10));
      }
    }
    return widgets;
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
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFF92400E)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
                    GestureDetector(onTap: _loadComments, child: const Icon(Icons.refresh, size: 16, color: Color(0xFF92400E))),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : RefreshIndicator(
                    onRefresh: _loadComments,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: _buildCommentWidgets(),
                    ),
                  ),
          ),
          // Reply target bar
          if (_replyTarget != null)
            Container(
              color: AppColors.backgroundPage,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Réponse à ${_replyTarget!.authorName}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          // Reply input
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: _replyTarget != null ? AppColors.borderLight : AppColors.borderLight, width: 0.5)),
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
                      focusNode: _focusNode,
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: _replyTarget != null
                            ? 'Répondre à ${_replyTarget!.authorName}...'
                            : 'Répondre au commentaire...',
                        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
  final VoidCallback onReply;
  const _CommentTile({required this.comment, required this.onReply});

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
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Text(comment.text, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4)),
              ),
              // Reply button
              TextButton.icon(
                onPressed: onReply,
                icon: const Icon(Icons.reply, size: 14, color: AppColors.textSecondary),
                label: const Text('Répondre', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
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
