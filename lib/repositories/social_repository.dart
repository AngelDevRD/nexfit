import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/social.dart';

/// Reemplaza a `SocialService` (FastAPI). Excepción explícita al patrón
/// offline-first del resto de la Fase 2 (ver docs/ARQUITECTURA_BACKEND.md):
/// el leaderboard agrega datos de OTROS usuarios, así que no hay forma
/// significativa de cachearlo localmente sin conexión -- Supabase es la
/// única fuente de verdad, siempre en vivo. `list`/`detail` guardan el
/// último resultado en memoria (`_lastMine`/`_lastDetail`) únicamente para
/// poder mostrar algo mientras se resuelve un refresh, no como almacenamiento
/// persistente.
///
/// El leaderboard y el join por código pasan por funciones `security
/// definer` en Postgres (`challenge_leaderboard`, `join_challenge_by_code`)
/// porque RLS bloquea -- a propósito -- que un usuario lea `workout_sets` o
/// `challenges` ajenos directamente.
class SocialRepository {
  final sb.SupabaseClient client;

  List<ChallengeSummary>? _lastMine;

  SocialRepository(this.client);

  List<ChallengeSummary>? get cachedMine => _lastMine;

  String get _userId => client.auth.currentUser!.id;

  Future<List<ChallengeSummary>> listMine() async {
    final rows = await client
        .from('challenges')
        .select('*, challenge_participants(count)')
        .order('created_at');

    final summaries = (rows as List)
        .map((r) => _toSummary(r as Map<String, dynamic>))
        .toList();
    _lastMine = summaries;
    return summaries;
  }

  Future<ChallengeDetail> detail(String id) async {
    final row = await client
        .from('challenges')
        .select('*, challenge_participants(count)')
        .eq('id', id)
        .single();

    final leaderboardRows = await client.rpc(
      'challenge_leaderboard',
      params: {'p_challenge_id': id},
    );

    final entries = <LeaderboardEntry>[];
    var rank = 1;
    for (final r in leaderboardRows as List) {
      final entryUserId = r['user_id'] as String;
      entries.add(
        LeaderboardEntry(
          userId: entryUserId,
          name: r['name'] as String,
          value: (r['value'] as num).toDouble(),
          rank: rank++,
          isMe: entryUserId == _userId,
        ),
      );
    }

    final summary = _toSummary(row);
    return ChallengeDetail(
      id: summary.id,
      name: summary.name,
      metric: summary.metric,
      startsOn: summary.startsOn,
      endsOn: summary.endsOn,
      inviteCode: summary.inviteCode,
      participantCount: summary.participantCount,
      isOwner: summary.isOwner,
      description: row['description'] as String?,
      leaderboard: entries,
    );
  }

  Future<ChallengeDetail> create({
    required String name,
    String? description,
    required String metric,
    required DateTime startsOn,
    required DateTime endsOn,
  }) async {
    final userId = _userId;
    final created = await client
        .from('challenges')
        .insert({
          'owner_id': userId,
          'name': name,
          'description': description,
          'metric': metric,
          'starts_on': _date(startsOn),
          'ends_on': _date(endsOn),
          'invite_code': _generateInviteCode(),
        })
        .select()
        .single();
    final challengeId = created['id'] as String;

    await client.from('challenge_participants').insert({
      'challenge_id': challengeId,
      'user_id': userId,
    });

    return detail(challengeId);
  }

  Future<String> join(String inviteCode) async {
    final challengeId = await client.rpc(
      'join_challenge_by_code',
      params: {'p_code': inviteCode},
    );
    return challengeId as String;
  }

  Future<void> leave(String id) => client
      .from('challenge_participants')
      .delete()
      .eq('challenge_id', id)
      .eq('user_id', _userId);

  Future<void> remove(String id) =>
      client.from('challenges').delete().eq('id', id);

  ChallengeSummary _toSummary(Map<String, dynamic> row) {
    final participants = row['challenge_participants'] as List?;
    final count = participants != null && participants.isNotEmpty
        ? (participants.first['count'] as num).toInt()
        : 0;
    return ChallengeSummary(
      id: row['id'] as String,
      name: row['name'] as String,
      metric: row['metric'] as String,
      startsOn: DateTime.parse(row['starts_on'] as String),
      endsOn: DateTime.parse(row['ends_on'] as String),
      inviteCode: row['invite_code'] as String,
      participantCount: count,
      isOwner: row['owner_id'] == _userId,
    );
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
