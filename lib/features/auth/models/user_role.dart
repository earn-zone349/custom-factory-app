/// The type of account a user can register as.
enum UserRole {
  customer('Customer'),
  designer('Designer'),
  factory('Factory');

  const UserRole(this.label);

  final String label;
}
