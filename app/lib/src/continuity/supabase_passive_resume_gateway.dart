import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_learner_auth.dart';
import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../domain/passive_resume.dart';
import 'passive_resume_gateway.dart';

class SupabasePassiveResumeGateway implements PassiveResumeGateway {
  const SupabasePassiveResumeGateway();

  @override
  Future<List<PassiveResumeRemoteState>> read({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) async {
    try {
      final client = await _clientFor(learner);
      final rows = await client.rpc<List<dynamic>>(
        'read_passive_resume_continuity',
        params: {'p_client_material_id': materialId.value},
      );
      return rows.whereType<Map>().map((row) => _record(Map<String, dynamic>.from(row))).toList(growable: false);
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<PassiveResumeRemoteState> write({
    required AuthenticatedLearner learner,
    required PassiveResumeLocalState local,
    required int? expectedRevision,
    required String clientUpdateId,
  }) async {
    try {
      final client = await _clientFor(learner);
      final rows = await client.rpc<List<dynamic>>(
        'write_passive_resume_continuity',
        params: {
          'p_client_material_id': local.materialId.value,
          'p_client_source_id': local.sourceVersionId.value,
          'p_surface': local.surface.name,
          'p_reader_progress': local.readerProgress,
          'p_listen_chunk_index': local.listenChunkIndex,
          'p_expected_revision': expectedRevision,
          'p_client_update_id': clientUpdateId,
        },
      );
      if (rows.length != 1 || rows.first is! Map) {
        throw const PassiveResumeException(
          'Cloud resume write returned an invalid payload.',
          kind: PassiveResumeFailureKind.invalidPayload,
        );
      }
      return _record(Map<String, dynamic>.from(rows.first as Map));
    } on PassiveResumeException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapError(error);
    }
  }

  static Future<SupabaseClient> _clientFor(AuthenticatedLearner learner) async {
    if (!learner.isAuthenticated) {
      throw const PassiveResumeException(
        'Cross-device resume requires an authenticated learner.',
        kind: PassiveResumeFailureKind.authenticationRequired,
      );
    }
    final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
    final user = client.auth.currentSession?.user;
    if (user == null || user.id != learner.id.value) {
      throw const PassiveResumeException(
        'Cloud resume session does not match the learner.',
        kind: PassiveResumeFailureKind.authenticationRequired,
      );
    }
    return client;
  }

  static PassiveResumeRemoteState _record(Map<String, dynamic> row) {
    try {
      final surface = PassiveResumeSurface.values.byName(row['surface'] as String);
      final revision = (row['revision'] as num).toInt();
      final reader = (row['reader_progress'] as num?)?.toDouble();
      final listen = (row['listen_chunk_index'] as num?)?.toInt();
      if (revision < 1 ||
          (surface == PassiveResumeSurface.reader && (reader == null || listen != null || reader < 0 || reader > 1)) ||
          (surface == PassiveResumeSurface.listen && (listen == null || reader != null || listen < 0))) {
        throw const FormatException('invalid_resume_payload');
      }
      return PassiveResumeRemoteState(
        materialId: MaterialId(row['client_material_id'] as String),
        sourceVersionId: SourceVersionId(row['client_source_id'] as String),
        surface: surface,
        readerProgress: reader,
        listenChunkIndex: listen,
        revision: revision,
        updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
      );
    } catch (_) {
      throw const PassiveResumeException(
        'Cloud resume payload is malformed.',
        kind: PassiveResumeFailureKind.invalidPayload,
      );
    }
  }

  static PassiveResumeException _mapError(PostgrestException error) {
    final message = error.message;
    if (message.contains('resume_revision_conflict')) {
      return const PassiveResumeException(
        'Reader or Listen position changed on another device.',
        kind: PassiveResumeFailureKind.conflict,
      );
    }
    if (message.contains('resume_source')) {
      return const PassiveResumeException(
        'Reader or Listen position belongs to a stale source.',
        kind: PassiveResumeFailureKind.staleSource,
      );
    }
    return const PassiveResumeException(
      'Reader and Listen continuity is temporarily unavailable.',
      kind: PassiveResumeFailureKind.unavailable,
    );
  }
}
