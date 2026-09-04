import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/coach/coach_context_builder.dart';
import '../../core/coach/coach_context_source.dart';
import '../../core/coach/http_coach_gateway.dart';
import '../../core/local/database.dart';
import '../../core/smart_backend_availability.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/coach_provider.dart';
import '../../repositories/coach_repository.dart';
import '../../repositories/gamification_repository.dart';
import '../../repositories/goal_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/recovery_repository.dart';
import '../../repositories/social_repository.dart';
import '../../repositories/stats_repository.dart';
import '../../widgets/coming_soon_view.dart';

class CoachChatScreen extends StatefulWidget {
  const CoachChatScreen({super.key});

  @override
  State<CoachChatScreen> createState() => _CoachChatScreenState();
}

class _CoachChatScreenState extends State<CoachChatScreen> {
  CoachProvider? _coachProvider;

  @override
  void initState() {
    super.initState();
    if (SmartBackendAvailability.isConfigured) {
      _coachProvider = CoachProvider(_buildRepository(context));
    }
  }

  /// El backend inteligente es completamente stateless (docs/FASE_4_DISENO.md)
  /// -- esta pantalla solo arma sus dependencias con lo que ya provee
  /// `main.dart` desde las Fases 2/3, sin ningún wiring nuevo ahí.
  CoachRepository _buildRepository(BuildContext context) {
    final userId = context.read<AuthProvider>().user!.id;
    final source = DefaultCoachContextSource(
      db: context.read<AppDatabase>(),
      userId: userId,
      profileRepository: context.read<ProfileRepository>(),
      goalRepository: context.read<GoalRepository>(),
      recoveryRepository: context.read<RecoveryRepository>(),
      statsRepository: context.read<StatsRepository>(),
      gamificationRepository: context.read<GamificationRepository>(),
      socialAvailable: context.read<SocialRepository?>() != null,
    );
    return CoachRepository(
      contextBuilder: CoachContextBuilder(source: source),
      gateway: HttpCoachGateway(baseUrl: SmartBackendAvailability.baseUrl!),
      accessTokenProvider: () =>
          sb.Supabase.instance.client.auth.currentSession?.accessToken,
    );
  }

  @override
  void dispose() {
    _coachProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _coachProvider;
    if (provider == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: ComingSoonView()),
      );
    }
    return ChangeNotifierProvider<CoachProvider>.value(
      value: provider,
      child: const _CoachChatBody(),
    );
  }
}

class _CoachChatBody extends StatefulWidget {
  const _CoachChatBody();

  @override
  State<_CoachChatBody> createState() => _CoachChatBodyState();
}

class _CoachChatBodyState extends State<_CoachChatBody> {
  final _controller = TextEditingController();

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    await context.read<CoachProvider>().sendMessage(text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coach = context.watch<CoachProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    AppColors.primaryContainer,
                    AppColors.tertiaryContainer,
                  ],
                ),
                boxShadow: AppGlow.primary,
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gemelo Digital'),
                Text(
                  'Tu Coach IA',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (coach.llmUnavailable)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              decoration: BoxDecoration(
                color: AppColors.dangerContainer.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.dangerContainer.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'El chat con IA todavía no está activado en este servidor (falta configurar la clave del proveedor de IA).',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: coach.messages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        'Hoy',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }
                final message = coach.messages[index - 1];
                return _ChatBubble(message: message);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Escribí tu pregunta...',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Material(
                    color: AppColors.primaryContainer,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: coach.sending ? null : _send,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: coach.sending
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onPrimaryContainer,
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color: AppColors.onPrimaryContainer,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final CoachChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.fromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: message.fromUser
              ? AppColors.primaryContainer
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Text(
          message.text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: message.fromUser
                ? AppColors.onPrimaryContainer
                : AppColors.onBackground,
          ),
        ),
      ),
    );
  }
}
