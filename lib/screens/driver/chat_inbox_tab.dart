import 'package:flutter/material.dart';

import '../../models/chat_models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/network_avatar.dart';
import 'chat_thread_screen.dart';

/// Driver bottom-nav Chat tab — active ride + recent inbox.
class ChatInboxTab extends StatelessWidget {
  const ChatInboxTab({super.key, this.threads});

  /// Defaults to demo seed when null (no chat API yet).
  final List<ChatThread>? threads;

  static const Color _pageBg = Color(0xFFFAFAFA);

  void _openThread(BuildContext context, ChatThread thread) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: ChatThreadScreen.routeName),
        builder: (_) => ChatThreadScreen(thread: thread),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = threads ?? ChatSeed.demoThreads();
    final active = all.where((t) => t.isActiveRide).toList();
    final recent = all.where((t) => !t.isActiveRide).toList();
    final tt = Theme.of(context).textTheme;

    return ColoredBox(
      color: _pageBg,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Chat',
                style: tt.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (active.isNotEmpty) ...[
                    _SectionLabel(label: 'ACTIVE RIDE'),
                    const SizedBox(height: 10),
                    for (final t in active)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ActiveRideCard(
                          thread: t,
                          onTap: () => _openThread(context, t),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                  _SectionLabel(label: 'RECENT'),
                  const SizedBox(height: 10),
                  if (recent.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 44,
                            color: AppColors.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No conversations yet',
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chats appear when you start a ride.',
                            style: tt.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppColors.ambientShadow,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < recent.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                indent: 72,
                                endIndent: 16,
                                color: AppColors.outlineVariant.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            _RecentTile(
                              thread: recent[i],
                              onTap: () => _openThread(context, recent[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
    );
  }
}

class _ActiveRideCard extends StatelessWidget {
  const _ActiveRideCard({required this.thread, required this.onTap});

  final ChatThread thread;
  final VoidCallback onTap;

  static const Color _brandBlue = Color(0xFF2954E5);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Material(
      color: AppColors.surfaceTint,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NetworkAvatar(
                    name: thread.peerName,
                    photoUrl: thread.peerPhotoUrl,
                    radius: 24,
                    foregroundColor: _brandBlue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          thread.peerName,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: _brandBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                thread.statusLabel ?? 'Active ride',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.labelMedium?.copyWith(
                                  color: _brandBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    thread.timeLabel,
                    style: tt.labelSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  thread.lastMessage,
                  style: tt.bodyMedium?.copyWith(
                    color: AppColors.onSurface,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.thread, required this.onTap});

  final ChatThread thread;
  final VoidCallback onTap;

  static const Color _brandBlue = Color(0xFF2954E5);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NetworkAvatar(
              name: thread.peerName,
              photoUrl: thread.peerPhotoUrl,
              radius: 24,
              foregroundColor: _brandBlue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.peerName,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    thread.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              thread.timeLabel,
              style: tt.labelSmall?.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
