/// Controls whether the admin panel can be opened from the Profile tab.
///
/// TEMPORARY: this is a plain switch while the app has no real login.
/// When Supabase login is added, it is replaced by a role check enforced by
/// the server, so only real admins can see or change orders.
class AdminAccess {
  const AdminAccess._();

  static const bool isEnabled = true;
}
