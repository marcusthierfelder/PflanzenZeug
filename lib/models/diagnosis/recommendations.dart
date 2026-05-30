/// Dünger-Empfehlung mit optionalem Produktvorschlag.
class FertilizerRecommendation {
  final String advice;
  final String? product;

  const FertilizerRecommendation({required this.advice, this.product});

  factory FertilizerRecommendation.fromJson(dynamic json) {
    if (json is String) {
      return FertilizerRecommendation(advice: json);
    }
    if (json is Map<String, dynamic>) {
      return FertilizerRecommendation(
        advice: json['advice'] as String? ?? '',
        product: json['product'] as String?,
      );
    }
    return FertilizerRecommendation(advice: json?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {
        'advice': advice,
        if (product != null) 'product': product,
      };

  @override
  String toString() =>
      product != null ? '$advice (Produkt: $product)' : advice;
}

/// Strukturierte Pflegeempfehlungen aus der Diagnose.
class Recommendations {
  final String watering;
  final FertilizerRecommendation fertilizer;
  final String location;
  final List<String> other;

  const Recommendations({
    required this.watering,
    required this.fertilizer,
    required this.location,
    this.other = const [],
  });

  factory Recommendations.fromJson(Map<String, dynamic> json) =>
      Recommendations(
        watering: json['watering'] as String? ?? '',
        fertilizer: FertilizerRecommendation.fromJson(
          json['fertilizer'] ?? '',
        ),
        location: json['location'] as String? ?? '',
        other: (json['other'] as List<dynamic>?)
                ?.map((e) => e?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'watering': watering,
        'fertilizer': fertilizer.toJson(),
        'location': location,
        'other': other,
      };
}
