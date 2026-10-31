import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../models/design_element.dart';
import '../models/design_template.dart';
import 'editor_text_style.dart';
import 'shape_painter.dart';

/// Shows the template gallery. Returns the chosen template or null.
Future<DesignTemplate?> showTemplatePicker(
  BuildContext context, {
  required Color baseColor,
}) {
  return showModalBottomSheet<DesignTemplate>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return _TemplatePickerSheet(baseColor: baseColor);
    },
  );
}

class _TemplatePickerSheet extends StatelessWidget {
  const _TemplatePickerSheet({required this.baseColor});

  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    final TemplateTheme theme = TemplateTheme.forBase(baseColor);
    final double height = MediaQuery.sizeOf(context).height * 0.7;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                'Templates',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: DesignTemplates.all.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final DesignTemplate template = DesignTemplates.all[index];
                  return _TemplateCard(
                    template: template,
                    theme: theme,
                    baseColor: baseColor,
                    onTap: () => Navigator.of(context).pop(template),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.theme,
    required this.baseColor,
    required this.onTap,
  });

  final DesignTemplate template;
  final TemplateTheme theme;
  final Color baseColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    int counter = 0;
    final List<DesignElement> elements =
        template.build(theme, () => 'preview_${counter++}');
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Center(
                  child: _TemplatePreview(
                    elements: elements,
                    baseColor: baseColor,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                template.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                template.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Non-interactive miniature of a template on the product color.
class _TemplatePreview extends StatelessWidget {
  const _TemplatePreview({required this.elements, required this.baseColor});

  final List<DesignElement> elements;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AspectRatio(
        aspectRatio: CanvasSpec.width / CanvasSpec.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: CanvasSpec.width,
                height: CanvasSpec.height,
                child: Stack(
                  children: <Widget>[
                    for (final DesignElement element in elements)
                      Positioned.fill(
                        child: Center(
                          child: Transform.translate(
                            offset: Offset(
                              element.x - CanvasSpec.width / 2,
                              element.y - CanvasSpec.height / 2,
                            ),
                            child: Transform.rotate(
                              angle: element.rotation,
                              child: Transform.scale(
                                scale: element.scale,
                                child: Opacity(
                                  opacity: element.opacity,
                                  child: _ElementContent(element: element),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ElementContent extends StatelessWidget {
  const _ElementContent({required this.element});

  final DesignElement element;

  @override
  Widget build(BuildContext context) {
    return switch (element) {
      TextElement t => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: CanvasSpec.width - 40),
          child: Text(
            t.text,
            textAlign: TextAlign.center,
            style: EditorTextStyle.resolve(t),
          ),
        ),
      ShapeElement s => SizedBox(
          width: s.width,
          height: s.height,
          child: CustomPaint(
            painter: ShapePainter(kind: s.kind, color: s.color),
          ),
        ),
      ImageElement i => SizedBox(
          width: i.width,
          height: i.height,
          child: Image.memory(i.bytes, fit: BoxFit.contain),
        ),
    };
  }
}
