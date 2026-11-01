import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/catalog/catalog_controller.dart';
import 'package:custom_factory_app/features/catalog/data/catalog_storage.dart';
import 'package:custom_factory_app/features/catalog/models/catalog_entry.dart';
import 'package:custom_factory_app/features/catalog/models/catalog_icons.dart';
import 'package:custom_factory_app/features/customize/models/category_config.dart';
import 'package:custom_factory_app/features/home/models/product_category.dart';

CatalogEntry _entry(
  String id,
  String name, {
  double price = 100,
  bool active = true,
}) {
  return CatalogEntry(
    id: id,
    name: name,
    subtitle: 'Sub',
    iconKey: 'box',
    styles: const <String>['A'],
    sizes: const <String>['M'],
    startingPrice: price,
    isActive: active,
  );
}

void main() {
  group('CatalogEntry', () {
    test('defaults mirror the home categories and their options', () {
      final List<CatalogEntry> defaults = CatalogEntry.defaults;

      expect(defaults.length, ProductCategory.defaults.length);
      expect(
        defaults.map((CatalogEntry e) => e.id).toSet().length,
        defaults.length,
      );
      for (int i = 0; i < defaults.length; i++) {
        final CatalogEntry entry = defaults[i];
        final CategoryConfig config = CategoryConfig.byName(entry.name)!;
        expect(entry.name, ProductCategory.defaults[i].name);
        expect(entry.startingPrice, config.startingPrice);
        expect(entry.styles, config.styles);
        expect(entry.sizes, config.sizes);
        expect(entry.isBuiltIn, isTrue);
        expect(entry.isActive, isTrue);
        expect(
          CatalogIcons.byKey(entry.iconKey).codePoint,
          ProductCategory.defaults[i].icon.codePoint,
          reason: entry.name,
        );
      }
    });

    test('survives a map round trip', () {
      final CatalogEntry restored =
          CatalogEntry.fromMap(_entry('a', 'Water Bottle', price: 250).toMap());

      expect(restored.name, 'Water Bottle');
      expect(restored.startingPrice, 250);
      expect(restored.styles, <String>['A']);
      expect(restored.isBuiltIn, isFalse);
    });

    test('rejects a negative price', () {
      final Map<String, dynamic> map =
          Map<String, dynamic>.of(_entry('a', 'Bottle').toMap())
            ..['startingPrice'] = -5;
      expect(() => CatalogEntry.fromMap(map), throwsFormatException);
    });
  });

  group('CatalogController', () {
    late Directory temp;
    late File file;
    late CatalogStorage storage;
    late CatalogController catalog;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('catalog_test');
      file = File('${temp.path}/catalog.json');
      storage = CatalogStorage(fileProvider: () async => file);
      catalog = CatalogController(storage: storage);
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('uses the defaults when nothing was saved', () async {
      await catalog.load();

      expect(catalog.isLoaded, isTrue);
      expect(catalog.entries.length, CatalogEntry.defaults.length);
    });

    test('a price change is saved and survives a restart', () async {
      final CatalogEntry mug = catalog.entries.firstWhere(
        (CatalogEntry e) => e.name == 'Mug',
      );
      await catalog.save(mug.copyWith(startingPrice: 777));

      final CatalogController reopened = CatalogController(storage: storage);
      await reopened.load();

      expect(reopened.configFor('Mug')?.startingPrice, 777);
    });

    test('adds a new product and shows it to customers', () async {
      await catalog.save(_entry('custom_1', 'Water Bottle'));

      expect(catalog.entries.length, CatalogEntry.defaults.length + 1);
      expect(
        catalog.activeCategories.map((ProductCategory c) => c.name),
        contains('Water Bottle'),
      );
    });

    test('rejects a duplicate name, ignoring letter case', () async {
      await expectLater(
        catalog.save(_entry('x', 'mug')),
        throwsA(isA<CatalogException>()),
      );
    });

    test('rejects invalid values', () async {
      await expectLater(
        catalog.save(_entry('x', 'A')),
        throwsA(isA<CatalogException>()),
      );
      await expectLater(
        catalog.save(_entry('x', 'Valid Name', price: -1)),
        throwsA(isA<CatalogException>()),
      );
      await expectLater(
        catalog.save(
          _entry('x', 'Valid Name').copyWith(
            styles: const <String>['Same', 'same'],
          ),
        ),
        throwsA(isA<CatalogException>()),
      );
    });

    test('a hidden product disappears for customers', () async {
      await catalog.setActive('mug', isActive: false);

      expect(
        catalog.activeCategories.map((ProductCategory c) => c.name),
        isNot(contains('Mug')),
      );
      expect(catalog.configFor('Mug'), isNull);
    });

    test('at least one product always stays visible', () async {
      final List<CatalogEntry> all = catalog.entries;
      for (final CatalogEntry entry in all.skip(1)) {
        await catalog.setActive(entry.id, isActive: false);
      }

      await expectLater(
        catalog.setActive(all.first.id, isActive: false),
        throwsA(isA<CatalogException>()),
      );
      expect(catalog.activeEntries.length, 1);
    });

    test('built-in products cannot be deleted, added ones can', () async {
      await catalog.save(_entry('custom_1', 'Water Bottle'));

      await expectLater(
        catalog.delete('mug'),
        throwsA(isA<CatalogException>()),
      );
      await catalog.delete('custom_1');
      expect(catalog.entries.length, CatalogEntry.defaults.length);
    });

    test('reset restores the defaults and removes the saved file', () async {
      await catalog.save(_entry('custom_1', 'Water Bottle'));
      expect(await file.exists(), isTrue);

      await catalog.resetToDefaults();

      expect(catalog.entries.length, CatalogEntry.defaults.length);
      expect(await file.exists(), isFalse);
    });

    test('an unreadable file is backed up and the defaults are used', () async {
      await file.writeAsString('not json');

      await catalog.load();

      expect(catalog.isLoaded, isTrue);
      expect(catalog.entries.length, CatalogEntry.defaults.length);
      expect(await File('${file.path}.corrupt').exists(), isTrue);
    });
  });
}
