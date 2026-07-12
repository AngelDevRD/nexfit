import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/social.dart';
import '../../repositories/social_repository.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final String challengeId;

  const ChallengeDetailScreen({super.key, required this.challengeId});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  SocialRepository? _repository;
  ChallengeDetail? _challenge;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository = context.read<SocialRepository?>();
    _load();
  }

  Future<void> _load() async {
    final repository = _repository;
    if (repository == null) {
      setState(() {
        _loading = false;
        _error = 'Servicio social no disponible en este momento.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await repository.detail(widget.challengeId);
      if (!mounted) return;
      setState(() {
        _challenge = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _confirmAndExit() async {
    final challenge = _challenge!;
    final isOwner = challenge.isOwner;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: Text(isOwner ? 'Eliminar reto' : 'Salir del reto'),
        content: Text(
          isOwner
              ? 'Sos el dueño. Se eliminará el reto para todos los participantes.'
              : 'Vas a salir de este reto. Podés volver con el código.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isOwner ? 'Eliminar' : 'Salir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (isOwner) {
        await _repository!.remove(challenge.id);
      } else {
        await _repository!.leave(challenge.id);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_challenge?.name ?? 'Reto'),
        actions: [
          if (_challenge != null)
            IconButton(
              tooltip: _challenge!.isOwner ? 'Eliminar reto' : 'Salir del reto',
              onPressed: _confirmAndExit,
              icon: Icon(
                _challenge!.isOwner ? Icons.delete_outline : Icons.logout,
                color: AppColors.danger,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(onRefresh: _load, child: _content(_challenge!)),
    );
  }

  Widget _content(ChallengeDetail c) {
    final unit = challengeMetricUnit(c.metric);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        _InviteCard(code: c.inviteCode),
        const SizedBox(height: AppSpacing.md),
        _MetaRow(
          metricLabel: challengeMetrics[c.metric] ?? c.metric,
          startsOn: c.startsOn,
          endsOn: c.endsOn,
          participants: c.participantCount,
        ),
        if (c.description != null && c.description!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(c.description!, style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Clasificación', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        for (final entry in c.leaderboard)
          _LeaderboardRow(entry: entry, unit: unit),
      ],
    );
  }
}

class _InviteCard extends StatelessWidget {
  final String code;

  const _InviteCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryContainer,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.qr_code_2, color: AppColors.onPrimaryContainer),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Código para invitar',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    code,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copiar',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Código copiado')));
              },
              icon: const Icon(Icons.copy, color: AppColors.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String metricLabel;
  final DateTime startsOn;
  final DateTime endsOn;
  final int participants;

  const _MetaRow({
    required this.metricLabel,
    required this.startsOn,
    required this.endsOn,
    required this.participants,
  });

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(context, Icons.emoji_events, metricLabel),
            const SizedBox(height: AppSpacing.sm),
            _line(
              context,
              Icons.date_range,
              'Del ${_d(startsOn)} al ${_d(endsOn)}',
            ),
            const SizedBox(height: AppSpacing.sm),
            _line(context, Icons.group, '$participants participante(s)'),
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final String unit;

  const _LeaderboardRow({required this.entry, required this.unit});

  Color get _rankColor => switch (entry.rank) {
    1 => AppColors.warning,
    2 => AppColors.onSurfaceVariant,
    3 => AppColors.tertiaryContainer,
    _ => AppColors.outline,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: entry.isMe
            ? AppColors.primaryContainer.withValues(alpha: 0.25)
            : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${entry.rank}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _rankColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  entry.isMe ? '${entry.name} (vos)' : entry.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: entry.isMe ? FontWeight.bold : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${entry.value.toStringAsFixed(0)} $unit',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
