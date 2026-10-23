/// Shared client-side pricing for AI replies.
///
/// The server independently applies the same rules; this helper is used only
/// to show the expected cost in the app before a request is submitted.
class CoinPricing {
  static int wordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  static int costForTier(String tier, String text) {
    final words = wordCount(text);
    final blocks = words == 0 ? 1 : (words + 19) ~/ 20;

    final baseCost = switch (tier) {
      'basic' => 1,
      'smart' => 3,
      'premium' => 6,
      _ => 1,
    };

    final extraBlockCost = switch (tier) {
      'basic' => 1,
      'smart' => 2,
      'premium' => 4,
      _ => 1,
    };

    return baseCost + (blocks - 1) * extraBlockCost;
  }
}
