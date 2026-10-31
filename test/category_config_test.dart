import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/customize/models/category_config.dart';
import 'package:custom_factory_app/features/home/models/product_category.dart';

void main() {
  test('Every home category has a customization config', () {
    for (final ProductCategory category in ProductCategory.defaults) {
      expect(
        CategoryConfig.byName(category.name),
        isNotNull,
        reason: 'Missing config for ${category.name}',
      );
    }
  });
}
