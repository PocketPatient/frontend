/// Mirrors backend's ClassSummary (GET /analytics/professor/class-summary).
class UnitCompletion {
  final String unitLabel;
  final int totalDiseases;
  final int totalCasesStarted;
  final int totalDiagnosed;
  final double? avgScore;

  const UnitCompletion({
    required this.unitLabel,
    required this.totalDiseases,
    required this.totalCasesStarted,
    required this.totalDiagnosed,
    this.avgScore,
  });

  factory UnitCompletion.fromJson(Map<String, dynamic> json) => UnitCompletion(
        unitLabel: json['unit_label'] as String,
        totalDiseases: json['total_diseases'] as int,
        totalCasesStarted: json['total_cases_started'] as int,
        totalDiagnosed: json['total_diagnosed'] as int,
        avgScore: (json['avg_score'] as num?)?.toDouble(),
      );
}

class ScoreBucket {
  final String range;
  final int count;

  const ScoreBucket({required this.range, required this.count});

  factory ScoreBucket.fromJson(Map<String, dynamic> json) => ScoreBucket(
        range: json['range'] as String,
        count: json['count'] as int,
      );
}

class CategoryHeatmap {
  final List<String> students;
  final List<String> categories;
  /// scores[studentIndex][categoryIndex], null = no data for that cell.
  final List<List<double?>> scores;

  const CategoryHeatmap({
    required this.students,
    required this.categories,
    required this.scores,
  });

  factory CategoryHeatmap.fromJson(Map<String, dynamic> json) => CategoryHeatmap(
        students: (json['students'] as List).map((e) => e as String).toList(),
        categories: (json['categories'] as List).map((e) => e as String).toList(),
        scores: (json['scores'] as List)
            .map((row) => (row as List).map((v) => (v as num?)?.toDouble()).toList())
            .toList(),
      );
}

class FlaggedStudent {
  final String email;
  final double avgScore;
  final int completedCases;

  const FlaggedStudent({
    required this.email,
    required this.avgScore,
    required this.completedCases,
  });

  factory FlaggedStudent.fromJson(Map<String, dynamic> json) => FlaggedStudent(
        email: json['email'] as String,
        avgScore: (json['avg_score'] as num).toDouble(),
        completedCases: json['completed_cases'] as int,
      );
}

class ClassSummary {
  final int enrolledStudents;
  final int studentsWithActiveCase;
  final int totalCompletedCases;
  final double? avgClassScore;
  final List<UnitCompletion> completionByUnit;
  final List<ScoreBucket> scoreDistribution;
  final CategoryHeatmap categoryHeatmap;
  final List<FlaggedStudent> flaggedStudents;

  const ClassSummary({
    required this.enrolledStudents,
    required this.studentsWithActiveCase,
    required this.totalCompletedCases,
    this.avgClassScore,
    required this.completionByUnit,
    required this.scoreDistribution,
    required this.categoryHeatmap,
    required this.flaggedStudents,
  });

  factory ClassSummary.fromJson(Map<String, dynamic> json) => ClassSummary(
        enrolledStudents: json['enrolled_students'] as int,
        studentsWithActiveCase: json['students_with_active_case'] as int,
        totalCompletedCases: json['total_completed_cases'] as int,
        avgClassScore: (json['avg_class_score'] as num?)?.toDouble(),
        completionByUnit: (json['completion_by_unit'] as List)
            .map((e) => UnitCompletion.fromJson(e as Map<String, dynamic>))
            .toList(),
        scoreDistribution: (json['score_distribution'] as List)
            .map((e) => ScoreBucket.fromJson(e as Map<String, dynamic>))
            .toList(),
        categoryHeatmap:
            CategoryHeatmap.fromJson(json['category_heatmap'] as Map<String, dynamic>),
        flaggedStudents: (json['flagged_students'] as List)
            .map((e) => FlaggedStudent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
