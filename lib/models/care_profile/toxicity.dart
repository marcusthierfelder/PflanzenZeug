/// Giftigkeitsinformationen einer Pflanze.
class Toxicity {
  final bool isToxic;
  final List<String> affected;
  final String detail;

  const Toxicity({
    required this.isToxic,
    required this.affected,
    required this.detail,
  });

  factory Toxicity.safe() => const Toxicity(
        isToxic: false,
        affected: [],
        detail: '',
      );

  factory Toxicity.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Toxicity.safe();
    return Toxicity(
      isToxic: json['is_toxic'] as bool? ?? false,
      affected: (json['affected'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      detail: json['detail'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'is_toxic': isToxic,
        'affected': affected,
        'detail': detail,
      };
}
