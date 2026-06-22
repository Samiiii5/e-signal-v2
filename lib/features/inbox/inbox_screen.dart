import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shimmer_box.dart';
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
  bool _isLoading = true;
  List<Thread> _threads = [];

  // Filtres du bottom sheet
  Channel? _bsChannelFilter;
  bool _bsUnreadOnly = false;

  bool get _hasActiveSheetFilter => _bsChannelFilter != null || _bsUnreadOnly;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.toLowerCase()));
    _loadThreads();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadThreads() async {
    if (!_isLoading) setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _threads = List.from(mockThreads);
      _isLoading = false;
    });
  }

  List<Thread> get _filtered {
    var list = List<Thread>.from(_threads);
    switch (_activeFilter) {
      case _Filter.whatsapp: list = list.where((t) => t.channel == Channel.whatsapp).toList();
      case _Filter.sms: list = list.where((t) => t.channel == Channel.sms).toList();
      case _Filter.email: list = list.where((t) => t.channel == Channel.email).toList();
      case _Filter.unread: list = list.where((t) => t.unreadCount > 0).toList();
      case _Filter.all: break;
    }
    if (_bsChannelFilter != null) {
      list = list.where((t) => t.channel == _bsChannelFilter).toList();
    }
    if (_bsUnreadOnly) {
      list = list.where((t) => t.unreadCount > 0).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((t) => t.contactName.toLowerCase().contains(_searchQuery) || t.lastMessage.toLowerCase().contains(_searchQuery)).toList();
    }
    return list;
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        initialChannel: _bsChannelFilter,
        initialUnreadOnly: _bsUnreadOnly,
        onApply: (channel, unreadOnly) {
          setState(() {
            _bsChannelFilter = channel;
            _bsUnreadOnly = unreadOnly;
            if (channel != null) _activeFilter = _Filter.all;
          });
        },
        onReset: () => setState(() {
          _bsChannelFilter = null;
          _bsUnreadOnly = false;
          _activeFilter = _Filter.all;
        }),
      ),
    );
  }

  int get _totalUnread => _threads.fold(0, (sum, t) => sum + t.unreadCount);

  @override
  Widget build(BuildContext context) {
    final threads = _filtered;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Image.asset('design/logo_onboarding.png', height: 45, fit: BoxFit.contain),
                  const Spacer(),
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(Icons.tune, color: _hasActiveSheetFilter ? AppColors.green : AppColors.textSecondary),
                        onPressed: _openFilterSheet,
                      ),
                      if (_hasActiveSheetFilter)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                decoration: BoxDecoration(color: AppColors.backgroundPage, borderRadius: BorderRadius.circular(14)),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un contact ou un message...',
                    hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: AppColors.textHint, size: 18),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Filter chips
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _Filter.values.map((f) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    filter: f,
                    isActive: _activeFilter == f,
                    unreadCount: f == _Filter.all ? _totalUnread : 0,
                    onTap: () => setState(() => _activeFilter = f),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 8),
            // List
            Expanded(
              child: _isLoading
                  ? const _InboxSkeleton()
                  : threads.isEmpty
                      ? _EmptyState(query: _searchQuery)
                      : RefreshIndicator(
                          onRefresh: _loadThreads,
                          color: AppColors.green,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(top: 4, bottom: 16),
                            itemCount: threads.length,
                            separatorBuilder: (_, __) => const Divider(indent: 76, height: 0, thickness: 0.5, color: AppColors.borderLight),
                            itemBuilder: (_, i) => _ThreadTile(thread: threads[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 7,
      separatorBuilder: (_, __) => const Divider(indent: 76, height: 0, thickness: 0.5, color: AppColors.borderLight),
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(children: [
          ShimmerBox(width: 48, height: 48, borderRadius: BorderRadius.circular(24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ShimmerBox(width: 130, height: 13, borderRadius: BorderRadius.circular(6)),
              const Spacer(),
              ShimmerBox(width: 32, height: 11, borderRadius: BorderRadius.circular(5)),
            ]),
            const SizedBox(height: 8),
            ShimmerBox(width: double.infinity, height: 11, borderRadius: BorderRadius.circular(5)),
          ])),
        ]),
      ),
    );
  }
}

// ── Filtres ───────────────────────────────────────────────────────────────────

enum _Filter { all, whatsapp, sms, email, unread }

extension _FilterLabel on _Filter {
  String get label => switch (this) {
    _Filter.all => 'Tous',
    _Filter.whatsapp => 'WhatsApp',
    _Filter.sms => 'SMS',
    _Filter.email => 'Email',
    _Filter.unread => 'Non lus',
  };
}

class _FilterChip extends StatelessWidget {
  final _Filter filter;
  final bool isActive;
  final int unreadCount;
  final VoidCallback onTap;
  const _FilterChip({required this.filter, required this.isActive, required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.green : AppColors.backgroundPage,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(filter.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? AppColors.white : AppColors.textSecondary)),
            if (isActive && unreadCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                child: Text('$unreadCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Thread tile ───────────────────────────────────────────────────────────────

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
          children: [
            _ContactAvatar(initials: thread.contactInitials, channel: thread.channel),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(thread.contactName, style: TextStyle(fontSize: 14, fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Text(_formatTime(thread.lastMessageAt), style: TextStyle(fontSize: 11, color: hasUnread ? AppColors.green : AppColors.textHint, fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(child: Text(thread.lastMessage, style: TextStyle(fontSize: 13, color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (hasUnread) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                        child: Text('${thread.unreadCount > 99 ? "99+" : thread.unreadCount}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.white)),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Hier';
    return '${dt.day}/${dt.month}';
  }
}

class _ContactAvatar extends StatelessWidget {
  final String initials;
  final Channel channel;
  const _ContactAvatar({required this.initials, required this.channel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: AppColors.backgroundPage, shape: BoxShape.circle),
            child: Center(child: Text(initials, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(color: _channelColor(channel), shape: BoxShape.circle, border: Border.all(color: AppColors.white, width: 1.5)),
              child: Center(child: Text(_channelLabel(channel), style: const TextStyle(fontSize: 9, color: AppColors.white, fontWeight: FontWeight.w700))),
            ),
          ),
        ],
      ),
    );
  }

  Color _channelColor(Channel ch) => switch (ch) {
    Channel.whatsapp => const Color(0xFF25D366),
    Channel.facebook => const Color(0xFF1877F2),
    Channel.sms => const Color(0xFF5C6BC0),
    Channel.tiktok => const Color(0xFF010101),
    Channel.email => const Color(0xFFEA4335),
  };

  String _channelLabel(Channel ch) => switch (ch) {
    Channel.whatsapp => 'W',
    Channel.facebook => 'f',
    Channel.sms => 'S',
    Channel.tiktok => 'T',
    Channel.email => '@',
  };
}

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
          Text(query.isNotEmpty ? 'Aucun résultat pour "$query"' : 'Aucune conversation', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Bottom sheet filtres ──────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final Channel? initialChannel;
  final bool initialUnreadOnly;
  final void Function(Channel? channel, bool unreadOnly) onApply;
  final VoidCallback onReset;

  const _FilterSheet({
    required this.initialChannel,
    required this.initialUnreadOnly,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  Channel? _channel;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _channel = widget.initialChannel;
    _unreadOnly = widget.initialUnreadOnly;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poignée
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Titre
          const Text('Filtrer les conversations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 20),

          // Section Canal
          const Text('Canal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          _ChannelOption(label: 'Tous', value: null, groupValue: _channel, onChanged: (v) => setState(() => _channel = v)),
          _ChannelOption(label: 'WhatsApp', value: Channel.whatsapp, groupValue: _channel, onChanged: (v) => setState(() => _channel = v), color: const Color(0xFF25D366)),
          _ChannelOption(label: 'SMS', value: Channel.sms, groupValue: _channel, onChanged: (v) => setState(() => _channel = v), color: const Color(0xFF5C6BC0)),
          _ChannelOption(label: 'Email', value: Channel.email, groupValue: _channel, onChanged: (v) => setState(() => _channel = v), color: const Color(0xFFEA4335)),
          _ChannelOption(label: 'Facebook', value: Channel.facebook, groupValue: _channel, onChanged: (v) => setState(() => _channel = v), color: const Color(0xFF1877F2)),
          _ChannelOption(label: 'TikTok', value: Channel.tiktok, groupValue: _channel, onChanged: (v) => setState(() => _channel = v), color: const Color(0xFF010101)),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 16),

          // Section Statut
          const Text('Statut', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          _CheckOption(
            label: 'Tous les messages',
            checked: !_unreadOnly,
            onTap: () => setState(() => _unreadOnly = false),
          ),
          _CheckOption(
            label: 'Non lus seulement',
            checked: _unreadOnly,
            onTap: () => setState(() => _unreadOnly = true),
          ),

          const SizedBox(height: 24),

          // Boutons
          Row(
            children: [
              TextButton(
                onPressed: () {
                  widget.onReset();
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: const Text('Réinitialiser', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_channel, _unreadOnly);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E9E5E),
                    foregroundColor: AppColors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text('Appliquer les filtres', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChannelOption extends StatelessWidget {
  final String label;
  final Channel? value;
  final Channel? groupValue;
  final ValueChanged<Channel?> onChanged;
  final Color? color;

  const _ChannelOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            if (color != null) ...[
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? const Color(0xFF1E9E5E) : AppColors.borderLight, width: 2),
                color: selected ? const Color(0xFF1E9E5E) : AppColors.white,
              ),
              child: selected ? const Icon(Icons.check, size: 12, color: AppColors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckOption extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onTap;

  const _CheckOption({required this.label, required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: checked ? const Color(0xFF1E9E5E) : AppColors.borderLight, width: 2),
                color: checked ? const Color(0xFF1E9E5E) : AppColors.white,
              ),
              child: checked ? const Icon(Icons.check, size: 13, color: AppColors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}
