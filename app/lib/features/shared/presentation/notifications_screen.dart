import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/social_service.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/design_system/design_system.dart';
import '../../../core/ui/widgets.dart' show BellButton;
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
            AppRoute<void>(
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
    final tk = context.tk;
    return AppScaffold(
      appBar: AppAppBar(
        title: 'Notificações',
        centerTitle: false,
        actions: [
          AppButton(
            key: const ValueKey('notif-mark-all-read-btn'),
            label: 'Marcar lidas',
            variant: AppButtonVariant.tertiary,
            expand: false,
            compact: true,
            onPressed: _handleMarkAllRead,
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const AppErrorState(
              message: 'Não foi possível carregar as notificações.',
            );
          }
          final loading = !snap.hasData;
          final items = (snap.data ?? const <AppNotification>[])
              .map(SocialService.applyOptimisticRead)
              .toList();
          if (!loading) _latestItems = items;

          final Widget content;
          if (!loading && items.isEmpty) {
            content = const AppEmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'Nada por aqui ainda',
              message:
                  'Avisaremos sobre orçamentos, pagamentos e atualizações dos seus serviços.',
            );
          } else {
            content = ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: context.layout.margin,
                vertical: AppSpace.s12,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.item),
              itemBuilder: (context, i) {
                final n = items[i];
                final unread = n.unread;
                return _NotificationCard(
                  notification: n,
                  icon: _icon(n.kind),
                  unread: unread,
                  onTap: () {
                    _handleMarkRead(n);
                    if (n.jobId != null) {
                      widget.onOpenJob(context, n.jobId!);
                    }
                  },
                );
              },
            );
          }

          return AppSkeletonSwitcher(
            loading: loading,
            skeleton: AppSkeletonList(
              count: 5,
              padding: EdgeInsets.symmetric(
                horizontal: context.layout.margin,
                vertical: AppSpace.s12,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(color: tk.background),
              child: content,
            ),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.icon,
    required this.unread,
    required this.onTap,
  });

  final AppNotification notification;
  final IconData icon;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final body = notification.body?.trim();
    return AppCard(
      key: ValueKey('notif-tile-${notification.id}'),
      variant: unread ? AppCardVariant.elevated : AppCardVariant.outlined,
      color: unread ? tk.accentSoft.withValues(alpha: tk.isDark ? 0.5 : 0.45) : null,
      borderColor: unread ? tk.accent.withValues(alpha: 0.35) : null,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: AppGeometry.iconTileSize,
                height: AppGeometry.iconTileSize,
                decoration: BoxDecoration(
                  color: unread ? tk.accentSoft : tk.surface,
                  borderRadius:
                      BorderRadius.circular(AppGeometry.iconTileRadius),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: unread ? tk.accentInk : tk.textMuted,
                ),
              ),
              if (unread)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: tk.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: tk.card, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      notification.title,
                      style: AppType.bodyStrong.copyWith(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                        color: unread ? tk.text : tk.textMuted,
                      ),
                    ),
                    if (unread)
                      AppStatusChip(
                        'Nova',
                        key: ValueKey('notif-unread-badge-${notification.id}'),
                        tone: AppTone.accent,
                      )
                    else
                      AppStatusChip(
                        'Vista',
                        key: ValueKey('notif-read-badge-${notification.id}'),
                        tone: AppTone.neutral,
                        icon: Icons.done_all_rounded,
                      ),
                  ],
                ),
                if (body != null && body.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    body,
                    style: AppType.bodySm.copyWith(color: tk.textMuted),
                  ),
                ],
                const SizedBox(height: AppSpace.s4),
                Text(
                  relativeTime(notification.createdAt),
                  style: AppType.tabular(AppType.caption)
                      .copyWith(color: tk.textMuted),
                ),
              ],
            ),
          ),
          if (notification.jobId != null) ...[
            const SizedBox(width: AppSpace.s8),
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s8),
              child: Icon(Icons.chevron_right_rounded, color: tk.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
