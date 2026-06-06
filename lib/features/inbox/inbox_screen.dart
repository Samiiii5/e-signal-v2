import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/mock/threads_mock.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _Filter _activeFilter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Thread> get _filtered {
    var list = List<Thread>.from(mockThreads);

    // Filtre canal / non-lus
    switch (_activeFilter) {
      case _Filter.whatsapp:
        list = list.where((t) => t.channel == Channel.whatsapp).toList();
      case _Filter.sms:
        list = list.where((t) => t.channel == Channel.sms).toList();
      case _Filter.email:
        list = list.where((t) => t.channel == Channel.email).toList();
      case _Filter.unread:
        list = list.where((t) => t.unreadCount > 0).toList();
      case _Filter.all:
        break;
    }

    // Filtre recherche
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((t) =>
              t.contactName.toLowerCase().contains(_searchQuery) ||
              t.lastMessage.toLowerCase().contains(_searchQuery))
          .toList();
    }

    return list;
  }

  int get _totalUnread =>
      mockThreads.fold(0, (sum, t) => sum + t.unreadCount);

  @override
  Widget build(BuildContext context) {
    final threads = _filtered;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Text('Inbox', style: AppTextStyles.h1),
                  const SizedBox(width: 10),
                  if (_totalUnread > 0) _UnreadBadge(count: _totalUnread),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Barre de recherche ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SearchBar(controller: _searchController),
            ),

            const SizedBox(height: 14),

            // ── Chips de filtre ───────────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _Filter.values.map((f) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      filter: f,
                      isActive: _activeFilter == f,
                      onTap: () => setState(() => _activeFilter = f),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            // ── Liste des conversations ───────────────────────────────
            Expanded(
              child: threads.isEmpty
                  ? _EmptyState(query: _searchQuery)
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                      itemCount: threads.length,
                      separatorBuilder: (_, __) => const Divider(
                        indent: 76,
                        endIndent: 0,
                        height: 0,
                        thickness: 0.5,
                        color: AppColors.borderLight,
                      ),
                      itemBuilder: (_, i) => _ThreadTile(thread: threads[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sous-composants ──────────────────────────────────────────────────────────

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppTextStyles.tinySemiBold,
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundPage,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        style: AppTextStyles.body,
        decoration: const InputDecoration(
          hintText: 'Rechercher une conversation…',
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: AppColors.textHint, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ── Filtres ───────────────────────────────────────────────────────────────────

enum _Filter { all, whatsapp, sms, email, unread }

extension _FilterLabel on _Filter {
  String get label {
    switch (this) {
      case _Filter.all: return 'Tous';
      case _Filter.whatsapp: return 'WhatsApp';
      case _Filter.sms: return 'SMS';
      case _Filter.email: return 'Email';
      case _Filter.unread: return 'Non lus';
    }
  }
}

class _FilterChip extends StatelessWidget {
  final _Filter filter;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({required this.filter, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = filter == _Filter.unread;

    final bgActive = isUnread ? AppColors.purpleLight : AppColors.green;
    final textActive = isUnread ? AppColors.purple : AppColors.white;
    final bgInactive = AppColors.backgroundStatus;
    const textInactive = AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? bgActive : bgInactive,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          filter.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? textActive : textInactive,
          ),
        ),
      ),
    );
  }
}

// ── Tuile de conversation ─────────────────────────────────────────────────────

class _ThreadTile extends StatelessWidget {
  final Thread thread;
  const _ThreadTile({required this.thread});

  @override
  Widget build(BuildContext context) {
    final hasUnread = thread.unreadCount > 0;

    return InkWell(
      onTap: () => context.push('/inbox/${thread.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar + badge canal
            _ContactAvatar(
              initials: thread.contactInitials,
              channel: thread.channel,
            ),

            const SizedBox(width: 12),

            // Contenu texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.contactName,
                          style: AppTextStyles.label.copyWith(
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(thread.lastMessageAt),
                        style: AppTextStyles.tiny.copyWith(
                          color: hasUnread ? AppColors.green : AppColors.textHint,
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.lastMessage,
                          style: AppTextStyles.small.copyWith(
                            color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        _UnreadPill(count: thread.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Hier';
    return '${dt.day}/${dt.month}';
  }
}

// ── Avatar + badge canal ──────────────────────────────────────────────────────

class _ContactAvatar extends StatelessWidget {
  final String initials;
  final Channel channel;
  const _ContactAvatar({required this.initials, required this.channel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Cercle initiales
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.backgroundPage,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          // Badge canal — petit cercle en bas à droite
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: _channelColor(channel),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 1.5),
              ),
              child: Center(
                child: Text(
                  _channelEmoji(channel),
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _channelColor(Channel ch) {
    switch (ch) {
      case Channel.whatsapp: return const Color(0xFF25D366);
      case Channel.facebook: return const Color(0xFF1877F2);
      case Channel.sms:      return const Color(0xFF5C6BC0);
      case Channel.tiktok:   return const Color(0xFF010101);
      case Channel.email:    return const Color(0xFFEA4335);
    }
  }

  String _channelEmoji(Channel ch) {
    switch (ch) {
      case Channel.whatsapp: return 'W';
      case Channel.facebook: return 'f';
      case Channel.sms:      return 'S';
      case Channel.tiktok:   return 'T';
      case Channel.email:    return '@';
    }
  }
}

// ── Badge non-lus ─────────────────────────────────────────────────────────────

class _UnreadPill extends StatelessWidget {
  final int count;
  const _UnreadPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppTextStyles.tinySemiBold,
      ),
    );
  }
}

// ── État vide ─────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: AppColors.borderLight),
          const SizedBox(height: 12),
          Text(
            query.isNotEmpty
                ? 'Aucun résultat pour "$query"'
                : 'Aucune conversation',
            style: AppTextStyles.bodySecondary,
          ),
        ],
      ),
    );
  }
}
