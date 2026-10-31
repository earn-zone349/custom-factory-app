/// Shared text formatting helpers.
class Formatters {
  const Formatters._();

  /// Formats an amount in Bangladeshi Taka, e.g. ৳350.
  static String price(double amount) => '৳${amount.toStringAsFixed(0)}';
}
