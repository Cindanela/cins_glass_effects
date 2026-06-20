/// How much GPU work the glass effect is allowed to spend.
enum GlassQuality {
  low(refractionSamples: 1, blurPasses: 1),
  medium(refractionSamples: 3, blurPasses: 2),
  high(refractionSamples: 5, blurPasses: 3);

  const GlassQuality({required this.refractionSamples, required this.blurPasses});

  final int refractionSamples;
  final int blurPasses;
}
