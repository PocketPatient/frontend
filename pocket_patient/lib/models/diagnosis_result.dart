class ScoreData {
  final String primaryDx;
  final List<String> differentials;
  final String? justification;
  final bool? isCorrect;
  final double? rubricScore;
  final double? responseTimeScore;
  final double? totalScore;
  final String? feedbackText;
  final DateTime? gradedAt;

  const ScoreData({
    required this.primaryDx,
    required this.differentials,
    this.justification,
    this.isCorrect,
    this.rubricScore,
    this.responseTimeScore,
    this.totalScore,
    this.feedbackText,
    this.gradedAt,
  });

  factory ScoreData.fromJson(Map<String, dynamic> json) => ScoreData(
        primaryDx: json['primary_dx'] as String,
        differentials: (json['differentials'] as List? ?? [])
            .map((e) => e as String)
            .toList(),
        justification: json['justification'] as String?,
        isCorrect: json['is_correct'] as bool?,
        rubricScore: (json['rubric_score'] as num?)?.toDouble(),
        responseTimeScore: (json['response_time_score'] as num?)?.toDouble(),
        totalScore: (json['total_score'] as num?)?.toDouble(),
        feedbackText: json['feedback_text'] as String?,
        gradedAt: json['graded_at'] != null
            ? DateTime.parse(json['graded_at'] as String)
            : null,
      );
}

class RevealData {
  final String diseaseName;
  final String? dsmCode;
  final String unitLabel;

  const RevealData({
    required this.diseaseName,
    this.dsmCode,
    required this.unitLabel,
  });

  factory RevealData.fromJson(Map<String, dynamic> json) => RevealData(
        diseaseName: json['disease_name'] as String,
        dsmCode: json['dsm_code'] as String?,
        unitLabel: json['unit_label'] as String,
      );
}

class DiagnosisResult {
  final bool correct;
  final ScoreData? score;
  final RevealData? reveal;
  final String? hint;

  const DiagnosisResult({
    required this.correct,
    this.score,
    this.reveal,
    this.hint,
  });

  factory DiagnosisResult.fromJson(Map<String, dynamic> json) =>
      DiagnosisResult(
        correct: json['correct'] as bool,
        score: json['score'] != null
            ? ScoreData.fromJson(json['score'] as Map<String, dynamic>)
            : null,
        reveal: json['reveal'] != null
            ? RevealData.fromJson(json['reveal'] as Map<String, dynamic>)
            : null,
        hint: json['hint'] as String?,
      );
}
