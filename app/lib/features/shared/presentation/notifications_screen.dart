import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/social_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';

/// Sino com contador de não lidas (usado nas home de cliente e profissional).
class UnreadBell extends StatefulWidget {
  const UnreadBell({
    super.key,
    required this.onOpenJob,
    @visibleForTesting this.notificationsStream,
    @visibleForTesting this.onMarkRead,
    @visibleForTesting this.onMarkAllRead,
  });

  /// Chamado quando o usuário toca em uma notificação ligada a uma demanda.
  final void Function(BuildContext context, String jobId) onOpenJob;

  @visibleForTesting
  final Stream<List<AppNotification>>? notificationsStream;

  @visibleForTesting
  final Future<void> Function(String id)? onMarkRead;

  @visibleForTesting
  final Future<void> Function()? onMarkAllRead;

  @override
  State<UnreadBell> createState() => _UnreadBellState();
}

class _UnreadBellState extends State<UnreadBell> {
  late final Stream<List<AppNotification>> _stream =
      widget.notificationsStream ?? SocialService().streamNotifications();
  StreamSubscription<void>? _localSub;

  @override
  void initState() {
    super.initState();
    _localSub = SocialService.onNotificationsChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _localSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: _stream,
      builder: (context, snap) {
        final items = (snap.data ?? const [])
            .map(SocialService.applyOptimisticRead)
            .toList();
        final unread = items.where((n) => n.unread).length;
        return BellButton(
          count: unread,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NotificationsScreen(
                onOpenJob: widget.onOpenJob,
                notificationsStream: widget.notificationsStream,
                onMarkRead: widget.onMarkRead,
                onMarkAllRead: widget.onMarkAllRead,
              ),
            ),
          ),
        );
      },
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.onOpenJob,
    @visibleForTesting this.notificationsStream,
    @visibleForTesting this.onMarkRead,
    @visibleForTesting this.onMarkAllRead,
  });

  final void Function(BuildContext context, String jobId) onOpenJob;

  @visibleForTesting
  final Stream<List<AppNotification>>? notificationsStream;

  @visibleForTesting
  final Future<void> Function(String id)? onMarkRead;

  @visibleForTesting
  final Future<void> Function()? onMarkAllRead;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Stream<List<AppNotification>> _stream =
      widget.notificationsStream ?? SocialService().streamNotifications();
  StreamSubscription<void>? _localSub;
  List<AppNotification> _latestItems = const [];

  @override
  void initState() {
    super.initState();
    _localSub = SocialService.onNotificationsChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _localSub?.cancel();
    super.dispose();
  }

  IconData _icon(String kind) => switch (kind) {
        'new_quote' => Icons.request_quote_rounded,
        'quote_accepted' => Icons.handshake_rounded,
        'quote_rejected' => Icons.thumb_down_alt_rounded,
        'payment_escrow' => Icons.lock_rounded,
        'payment_released' => Icons.payments_rounded,
        'new_invite' => Icons.notifications_active_rounded,
        'emergency_accepted' => Icons.bolt_rounded,
        'emergency_refunded' => Icons.undo_rounded,
        'job_completed' || 'job_finished' => Icons.check_circle_rounded,
        'job_canceled' || 'invite_declined' => Icons.cancel_rounded,
        _ => Icons.notifications_rounded,
      };

  void _handleMarkRead(AppNotification n) {
    SocialService.markOptimisticallyRead(n.id);
    final fn = widget.onMarkRead;
    if (fn != null) {
      unawaited(fn(n.id).catchError((Object _) {}));
    } else {
      try {
        unawaited(SocialService().markRead(n.id).catchError((Object _) {}));
      } catch (_) {}
    }
  }

  void _handleMarkAllRead() {
    SocialService.markAllOptimisticallyRead(_latestItems.map((e) => e.id));
    final fn = widget.onMarkAllRead;
    if (fn != null) {
      unawaited(fn().catchError((Object _) {}));
    } else {
      try {
        unawaited(SocialService().markAllRead().catchError((Object _) {}));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          TextButton(
            key: const ValueKey('notif-mark-all-read-btn'),
            onPressed: _handleMarkAllRead,
            child: const Text('Marcar lidas'),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const ErrorView(
              message: 'Não foi possível carregar as notificações.',
            );
          }
          if (!snap.hasData) return const LoadingView();
          final items = snap.data!
              .map(SocialService.applyOptimisticRead)
              .toList();
          _latestItems = items;
          if (items.isEmpty) {
            return const EmptyView(
              icon: Icons.notifications_off_outlined,
              title: 'Nada por aqui ainda',
              subtitle:
                  'Avisaremos sobre orçamentos, pagamentos e atualizações dos seus serviços.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = items[i];
              final accent = Theme.of(context).colorScheme.primary;
              final unread = n.unread;
              return ListTile(
                key: ValueKey('notif-tile-${n.id}'),
                tileColor: unread ? accent.withValues(alpha: 0.08) : null,
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      backgroundColor: unread
                          ? accent.withValues(alpha: 0.16)
                          : context.tk.surface,
                      child: Icon(
                        _icon(n.kind),
                        color: unread ? accent : context.tk.textMuted,
                      ),
                    ),
                    if (unread)
                      Positioned(
                        top: -1,
                        right: -1,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.tk.card,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.title,
                        style: TextStyle(
                          fontWeight:
                              unread ? FontWeight.w800 : FontWeight.w600,
                          color: unread ? context.tk.text : context.tk.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (unread)
                      Container(
                        key: ValueKey('notif-unread-badge-${n.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Nova',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      )
                    else
                      Row(
                        key: ValueKey('notif-read-badge-${n.id}'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.done_all_rounded,
                            size: 14,
                            color: context.tk.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Vista',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: context.tk.textMuted,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                subtitle: Text('${n.body ?? ''}\n${relativeTime(n.createdAt)}'),
                isThreeLine: true,
                onTap: () {
                  _handleMarkRead(n);
                  if (n.jobId != null) {
                    widget.onOpenJob(context, n.jobId!);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
