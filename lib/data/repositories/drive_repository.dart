import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../models/life_goal_model.dart';

/// Google Drive appDataFolder 접근 레이어 (Life Goal 전용)
class DriveRepository {
  final drive.DriveApi _api;
  static const String _goalFileName = 'life_goal.json';

  DriveRepository(http.Client client) : _api = drive.DriveApi(client);

  Future<LifeGoalModel?> fetchLifeGoal() async {
    final fileList = await _api.files.list(
      spaces: 'appDataFolder',
      q: "name='$_goalFileName'",
      $fields: 'files(id, name)',
    );
    final files = fileList.files ?? [];
    if (files.isEmpty) return null;

    final fileId = files.first.id!;
    return _readFile(fileId);
  }

  Future<LifeGoalModel> saveLifeGoal(String content) async {
    // 기존 파일 삭제 후 새로 작성 (덮어쓰기)
    final fileList = await _api.files.list(
      spaces: 'appDataFolder',
      q: "name='$_goalFileName'",
      $fields: 'files(id)',
    );
    for (final f in fileList.files ?? []) {
      await _api.files.delete(f.id!);
    }

    final now = DateTime.now();
    final payload = json.encode({
      'content': content,
      'savedAt': now.toIso8601String(),
    });
    final bytes = utf8.encode(payload);
    final media = drive.Media(Stream.value(bytes), bytes.length);
    final metadata = drive.File()
      ..name = _goalFileName
      ..parents = ['appDataFolder'];

    final created = await _api.files.create(metadata, uploadMedia: media);
    return LifeGoalModel(
      id: created.id ?? '',
      content: content,
      savedAt: now,
    );
  }

  Future<LifeGoalModel> _readFile(String fileId) async {
    final media = await _api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = await media.stream.expand((c) => c).toList();
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return LifeGoalModel.fromJson(fileId, json);
  }
}
