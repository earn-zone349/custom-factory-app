/// How the customer pays. Only cash on delivery is available for now.
enum PaymentMethod {
  cashOnDelivery('Cash on Delivery', 'Pay when you receive your order', true),
  bkash('bKash', 'Mobile payment', false),
  nagad('Nagad', 'Mobile payment', false);

  const PaymentMethod(this.label, this.description, this.isAvailable);

  final String label;
  final String description;

  /// False for methods that are shown but not usable yet.
  final bool isAvailable;
}
