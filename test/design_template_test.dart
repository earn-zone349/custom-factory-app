import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/editor/design_controller.dart';
import 'package:custom_factory_app/features/editor/models/design_element.dart';
import 'package:custom_factory_app/features/editor/models/design_template.dart';

void main() {
  final TemplateTheme theme = TemplateTheme.forBase(Colors.white);

  group('DesignTemplates', () {
    test('every template builds valid elements inside the canvas', () {
      for (final DesignTemplate template in DesignTemplates.all) {
        int counter = 0;
        final List<DesignElement> elements =
            template.build(theme, () => 'id_${counter++}');

        expect(elements, isNotEmpty, reason: template.name);
        final Set<String> ids =
            elements.map((DesignElement e) => e.id).toSet();
        expect(ids.length, elements.length, reason: template.name);
        for (final DesignElement element in elements) {
          expect(element.x, inInclusiveRange(0, CanvasSpec.width));
          expect(element.y, inInclusiveRange(0, CanvasSpec.height));
        }
      }
    });

    test('theme keeps text readable on dark products', () {
      final TemplateTheme dark = TemplateTheme.forBase(Colors.black);
      expect(dark.ink, Colors.white);
    });
  });

  group('DesignController templates', () {
    test('applying a template replaces the design and can be undone', () {
      final DesignController controller = DesignController()
        ..addText('Old');

      final bool applied =
          controller.applyTemplate(DesignTemplates.all.first, theme);

      expect(applied, isTrue);
      expect(controller.elements.length, greaterThan(1));

      controller.undo();
      expect(controller.elements.length, 1);
      expect((controller.elements.first as TextElement).text, 'Old');
    });
  });
}
