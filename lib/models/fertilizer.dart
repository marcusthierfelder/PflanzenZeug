class Fertilizer {
  final String id;
  String name;
  String? brand;
  String? description;
  String? npkRatio;
  List<String> photoPaths;
  final DateTime createdAt;

  Fertilizer({
    required this.id,
    required this.name,
    this.brand,
    this.description,
    this.npkRatio,
    List<String>? photoPaths,
    required this.createdAt,
  }) : photoPaths = photoPaths ?? [];

  bool get isAnalyzed => description != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'description': description,
        'npkRatio': npkRatio,
        'photoPaths': photoPaths,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Fertilizer.fromJson(Map<dynamic, dynamic> json) {
    List<String> photoPaths = [];
    if (json['photoPaths'] != null) {
      photoPaths = (json['photoPaths'] as List).cast<String>();
    } else if (json['photoPath'] != null) {
      photoPaths = [json['photoPath'] as String];
    }
    return Fertilizer(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      description: json['description'] as String?,
      npkRatio: json['npkRatio'] as String?,
      photoPaths: photoPaths,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
