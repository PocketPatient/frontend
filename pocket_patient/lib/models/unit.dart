class DiseaseSummary {
  final String id;
  final String name;
  final String category;
  final int difficultyTier;

  const DiseaseSummary({
    required this.id,
    required this.name,
    required this.category,
    required this.difficultyTier,
  });

  factory DiseaseSummary.fromJson(Map<String, dynamic> json) => DiseaseSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        difficultyTier: json['difficulty_tier'] as int,
      );
}

class Unit {
  final String id;
  final String? courseId;
  final String label;
  final String status; // 'draft' | 'released' | 'closed'
  final int diseaseCount;
  final List<DiseaseSummary> diseases; // empty for student view
  final DateTime? releaseDate;

  const Unit({
    required this.id,
    this.courseId,
    required this.label,
    required this.status,
    required this.diseaseCount,
    this.diseases = const [],
    this.releaseDate,
  });

  bool get isDraft => status == 'draft';
  bool get isReleased => status == 'released';
  bool get isClosed => status == 'closed';

  factory Unit.fromJson(Map<String, dynamic> json) => Unit(
        id: json['id'] as String,
        courseId: json['course_id'] as String?,
        label: json['label'] as String,
        status: json['status'] as String,
        diseaseCount: json['disease_count'] as int? ?? 0,
        diseases: json['diseases'] != null
            ? (json['diseases'] as List)
                .map((e) =>
                    DiseaseSummary.fromJson(e as Map<String, dynamic>))
                .toList()
            : const [],
        releaseDate: json['release_date'] != null
            ? DateTime.parse(json['release_date'] as String)
            : null,
      );
}
