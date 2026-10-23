import 'package:flutter_test/flutter_test.dart';
import 'package:dart_app/utils/coin_pricing.dart';

String words(int count) => List.filled(count, 'word').join(' ');

void main() {
  group('CoinPricing', () {
    test('Basic charges one coin per 20-word block', () {
      expect(CoinPricing.costForTier('basic', words(1)), 1);
      expect(CoinPricing.costForTier('basic', words(20)), 1);
      expect(CoinPricing.costForTier('basic', words(21)), 2);
      expect(CoinPricing.costForTier('basic', words(40)), 2);
      expect(CoinPricing.costForTier('basic', words(41)), 3);
      expect(CoinPricing.costForTier('basic', words(60)), 3);
    });

    test('Smart charges two extra coins per additional block', () {
      expect(CoinPricing.costForTier('smart', words(20)), 3);
      expect(CoinPricing.costForTier('smart', words(21)), 5);
      expect(CoinPricing.costForTier('smart', words(40)), 5);
      expect(CoinPricing.costForTier('smart', words(41)), 7);
      expect(CoinPricing.costForTier('smart', words(60)), 7);
    });

    test('Premium charges four extra coins per additional block', () {
      expect(CoinPricing.costForTier('premium', words(20)), 6);
      expect(CoinPricing.costForTier('premium', words(21)), 10);
      expect(CoinPricing.costForTier('premium', words(40)), 10);
      expect(CoinPricing.costForTier('premium', words(41)), 14);
      expect(CoinPricing.costForTier('premium', words(60)), 14);
    });

    test('whitespace and empty input are handled safely', () {
      expect(CoinPricing.wordCount('  one   two\nthree '), 3);
      expect(CoinPricing.wordCount('   '), 0);
      expect(CoinPricing.costForTier('basic', ''), 1);
      expect(CoinPricing.costForTier('smart', ''), 3);
      expect(CoinPricing.costForTier('premium', ''), 6);
    });
  });
}
