class Plant {
  final String id;
  String nickname;
  String? speciesName;
  String? scientificName;
  String location;
  String? identificationResult;
  String? diagnosisResult;
  final DateTime createdAt;
  DateTime updatedAt;

  Plant({
    required this.id,
    required this.nickname,
    this.speciesName,
    this.scientificName,
    this.location = '',
    this.identificationResult,
    this.diagnosisResult,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'speciesName': speciesName,
        'scientificName': scientificName,
        'location': location,
        'identificationResult': identificationResult,
        'diagnosisResult': diagnosisResult,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Plant.fromJson(Map<dynamic, dynamic> json) => Plant(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        speciesName: json['speciesName'] as String?,
        scientificName: json['scientificName'] as String?,
        location: json['location'] as String? ?? '',
        identificationResult: json['identificationResult'] as String?,
        diagnosisResult: json['diagnosisResult'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
