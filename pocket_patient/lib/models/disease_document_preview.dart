class UnitPreview {
  final String label;
  final int diseaseCount;
  final List<String> diseases;

  const UnitPreview({
    required this.label,
    required this.diseaseCount,
    required this.diseases,
  });

  factory UnitPreview.fromJson(Map<String, dynamic> json) => UnitPreview(
        label: json['label'] as String,
        diseaseCount: json['disease_count'] as int,
        diseases: List<String>.from(json['diseases'] as List),
      );
}

class ParseError {
  final String location;
  final String message;

  const ParseError({required this.location, required this.message});

  factory ParseError.fromJson(Map<String, dynamic> json) => ParseError(
        location: json['location'] as String,
        message: json['message'] as String,
      );
}

class DiseaseDocumentPreview {
  final String documentId;
  final int version;
  final List<UnitPreview> units;
  final List<ParseError> errors;

  const DiseaseDocumentPreview({
    required this.documentId,
    required this.version,
    required this.units,
    required this.errors,
  });

  factory DiseaseDocumentPreview.fromJson(Map<String, dynamic> json) =>
      DiseaseDocumentPreview(
        documentId: json['document_id'] as String,
        version: json['version'] as int,
        units: (json['units'] as List)
            .map((e) => UnitPreview.fromJson(e as Map<String, dynamic>))
            .toList(),
        errors: (json['errors'] as List)
            .map((e) => ParseError.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DiseaseDocumentConfirmResult {
  final String documentId;
  final int version;
  final int unitsCreated;
  final int diseasesCreated;

  const DiseaseDocumentConfirmResult({
    required this.documentId,
    required this.version,
    required this.unitsCreated,
    required this.diseasesCreated,
  });

  factory DiseaseDocumentConfirmResult.fromJson(Map<String, dynamic> json) =>
      DiseaseDocumentConfirmResult(
        documentId: json['document_id'] as String,
        version: json['version'] as int,
        unitsCreated: json['units_created'] as int,
        diseasesCreated: json['diseases_created'] as int,
      );
}
