import '../utils/date_time_util.dart';

// lib/models/comment.dart
class Comment {
  String id;
  String title;
  String content;
  int commentStartPositionInTenthOfSeconds;
  int commentEndPositionInTenthOfSeconds;
  double silenceDuration;
  double playSpeed;
  double fadeInDuration;
  double soundReductionPosition;
  double soundReductionDuration;
  double volume; // NEW
  bool deleted;
  late DateTime creationDateTime;
  late DateTime lastUpdateDateTime;

  Comment({
    required this.title,
    required this.content,
    required this.commentStartPositionInTenthOfSeconds,
    this.commentEndPositionInTenthOfSeconds = 0,
    this.silenceDuration = 0.0,
    this.playSpeed = 1.0,
    this.fadeInDuration = 0.0,
    this.soundReductionPosition = 0.0,
    this.soundReductionDuration = 0.0,
    this.volume = 1.0, // NEW
    this.deleted = false,
  })  : id = "${title}_${DateTime.now().microsecondsSinceEpoch.toString()}",
        creationDateTime =
            DateTimeUtil.getDateTimeLimitedToSeconds(DateTime.now()) {
    lastUpdateDateTime = creationDateTime;
  }

  Comment.fullConstructor({
    required this.id,
    required this.title,
    required this.content,
    required this.commentStartPositionInTenthOfSeconds,
    required this.commentEndPositionInTenthOfSeconds,
    required this.silenceDuration,
    required this.playSpeed,
    required this.fadeInDuration,
    required this.soundReductionPosition,
    required this.soundReductionDuration,
    required this.volume, // NEW
    required this.creationDateTime,
    required this.lastUpdateDateTime,
    required this.deleted,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment.fullConstructor(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      commentStartPositionInTenthOfSeconds:
          json['commentStartPositionInTenthOfSeconds'] ?? 0,
      commentEndPositionInTenthOfSeconds:
          json['commentEndPositionInTenthOfSeconds'] ?? 0,
      silenceDuration: json['silenceDuration'] ?? 0.0,
      playSpeed: json['playSpeed'] ?? 1.0,
      fadeInDuration: json['fadeInDuration'] ?? 0.0,
      soundReductionPosition: json['soundReductionPosition'] ?? 0.0,
      soundReductionDuration: json['soundReductionDuration'] ?? 0.0,
      volume: json['volume'] ?? 1.0, // NEW — old files without the field default to 1.0
      deleted: json['deleted'] ?? false,
      creationDateTime: DateTime.parse(json['creationDateTime']),
      lastUpdateDateTime: DateTime.parse(json['lastUpdateDateTime']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'commentStartPositionInTenthOfSeconds':
          commentStartPositionInTenthOfSeconds,
      'commentEndPositionInTenthOfSeconds': commentEndPositionInTenthOfSeconds,
      'silenceDuration': silenceDuration,
      'playSpeed': playSpeed,
      'fadeInDuration': fadeInDuration,
      'soundReductionPosition': soundReductionPosition,
      'soundReductionDuration': soundReductionDuration,
      'volume': volume, // NEW
      'deleted': deleted,
      'creationDateTime': creationDateTime.toIso8601String(),
      'lastUpdateDateTime': lastUpdateDateTime.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Comment && other.id == id);

  @override
  int get hashCode => id.hashCode;
}