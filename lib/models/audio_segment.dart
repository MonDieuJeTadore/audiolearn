// lib/models/audio_segment.dart
class AudioSegment {
  final double startPosition;
  final double endPosition;
  final double playSpeed;
  final double silenceDuration;
  final double fadeInDuration;
  final double soundReductionPosition;
  final double soundReductionDuration;
  final double volume; // NEW: linear volume multiplier applied to the portion
  final String commentId;
  final String commentTitle;
  bool deleted;

  AudioSegment({
    required this.startPosition,
    required this.endPosition,
    this.playSpeed = 1.0,
    this.silenceDuration = 0.0,
    this.fadeInDuration = 0.0,
    this.soundReductionPosition = 0.0,
    this.soundReductionDuration = 0.0,
    this.volume = 1.0, // NEW: default = no change
    required this.commentId,
    required this.commentTitle,
    this.deleted = false,
  });

  double get duration => endPosition - startPosition;

  AudioSegment copyWith({
    double? startPosition,
    double? endPosition,
    double? playSpeed,
    double? silenceDuration,
    double? fadeInDuration,
    double? soundReductionPosition,
    double? soundReductionDuration,
    double? volume, // NEW
    String? commentId,
    String? commentTitle,
    bool? deleted,
  }) {
    return AudioSegment(
      startPosition: startPosition ?? this.startPosition,
      endPosition: endPosition ?? this.endPosition,
      playSpeed: playSpeed ?? this.playSpeed,
      silenceDuration: silenceDuration ?? this.silenceDuration,
      fadeInDuration: fadeInDuration ?? this.fadeInDuration,
      soundReductionPosition:
          soundReductionPosition ?? this.soundReductionPosition,
      soundReductionDuration:
          soundReductionDuration ?? this.soundReductionDuration,
      volume: volume ?? this.volume, // NEW
      commentId: commentId ?? this.commentId,
      commentTitle: commentTitle ?? this.commentTitle,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'startPosition': startPosition,
        'endPosition': endPosition,
        'playSpeed': playSpeed,
        'silenceDuration': silenceDuration,
        'fadeInDuration': fadeInDuration,
        'soundReductionPosition': soundReductionPosition,
        'soundReductionDuration': soundReductionDuration,
        'volume': volume, // NEW
        'commentId': commentId,
        'commentTitle': commentTitle,
        'deleted': deleted,
      };

  factory AudioSegment.fromMap(Map<String, dynamic> map) {
    return AudioSegment(
      startPosition: (map['startPosition'] as num).toDouble(),
      endPosition: (map['endPosition'] as num).toDouble(),
      playSpeed: (map['playSpeed'] as num?)?.toDouble() ?? 1.0,
      silenceDuration: (map['silenceDuration'] as num?)?.toDouble() ?? 0.0,
      fadeInDuration: (map['fadeInDuration'] as num?)?.toDouble() ?? 0.0,
      soundReductionPosition:
          (map['soundReductionPosition'] as num?)?.toDouble() ?? 0.0,
      soundReductionDuration:
          (map['soundReductionDuration'] as num?)?.toDouble() ?? 0.0,
      volume: (map['volume'] as num?)?.toDouble() ?? 1.0, // NEW
      commentId: (map['commentId'] as String?)?.trim().isNotEmpty == true
          ? (map['commentId'] as String).trim()
          : 'Untitled segment',
      commentTitle: (map['commentTitle'] as String?)?.trim().isNotEmpty == true
          ? (map['commentTitle'] as String).trim()
          : 'Untitled segment',
      deleted: (map['deleted'] as bool?) ?? false,
    );
  }
}