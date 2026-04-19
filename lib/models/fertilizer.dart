class Fertilizer {
  final String id;
  String name;
  String? brand;
  String? description;
  String? npkRatio;
  String? photoPath;
  final DateTime createdAt;

  Fertilizer({
    required this.id,
    required this.name,
    this.brand,
    this.description,
    this.npkRatio,
    this.photoPath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'description': description,
        'npkRatio': npkRatio,
        'photoPath': photoPath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Fertilizer.fromJson(Map<dynamic, dynamic> json) => Fertilizer(
        id: json['id'] as String,
        name: json['name'] as String,
        brand: json['brand'] as String?,
        description: json['description'] as String?,
        npkRatio: json['npkRatio'] as String?,
        photoPath: json['photoPath'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
