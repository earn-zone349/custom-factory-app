/// Controls whether the factory panel can be opened from the Profile tab.
///
/// TEMPORARY: this is a plain switch while the app has no real login. When
/// Supabase login is added, each factory signs in with its own account and
/// the server only returns that factory's orders.
class FactoryAccess {
  const FactoryAccess._();

  static const bool isEnabled = true;
}
