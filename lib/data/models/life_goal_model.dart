/// Drive appDataFolder에 저장하는 Life Goal 모델
class LifeGoalModel {
  final String id;        // Drive file ID
  final String content;   // 목표 텍스트 내용
  final DateTime savedAt;

  const LifeGoalModel({
    required this.id,
    required this.content,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'content': content,
        'savedAt': savedAt.toIso8601String(),
      };

  factory LifeGoalModel.fromJson(String id, Map<String, dynamic> json) =>
      LifeGoalModel(
        id: id,
        content: json['content'] as String,
        savedAt: DateTime.parse(json['savedAt'] as String),
      );
}
