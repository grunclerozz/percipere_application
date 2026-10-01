import 'package:flutter/material.dart';

import '../../app/theme/app_palette.dart';
import '../../config/constants.dart';
import '../gestures/gesture_surface.dart';
import 'bordered_panel.dart';
import 'fit_text.dart';

/// One row of a [BoxedList].
class BoxedListItem {
  /// Creates a row for action [id].
  const BoxedListItem(this.id, this.label);

  /// Action id (focus id).
  final String id;

  /// Row text.
  final String label;
}

/// A list of choices inside a fixed bordered box (security questions, setup
/// summary, old accounts). The box takes the space it is given and scrolls
/// inside, so the screen around it never grows; the focused row is kept in
/// view. Rows are at least 56 dp tall and their text shrinks to fit two
/// lines.
class BoxedList extends StatefulWidget {
  /// Creates the list.
  const BoxedList({
    super.key,
    required this.items,
    required this.focused,
    required this.onTap,
  });

  /// Rows, in focus order.
  final List<BoxedListItem> items;

  /// Id of the focused row, if any.
  final String? focused;

  /// A row was tapped.
  final void Function(String id) onTap;

  @override
  State<BoxedList> createState() => _BoxedListState();
}

class _BoxedListState extends State<BoxedList> {
  final ScrollController _controller = ScrollController();
  final Map<String, GlobalKey> _keys = {};

  @override
  void didUpdateWidget(BoxedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = widget.focused;
    if (id != null && id != oldWidget.focused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[id]?.currentContext;
        if (ctx != null && mounted) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.3,
            duration: const Duration(milliseconds: 200),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = Theme.of(context).textTheme.bodyLarge
        ?.copyWith(fontWeight: FontWeight.w700, color: p.heading);
    return BorderedPanel(
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: ListView.separated(
          controller: _controller,
          padding: const EdgeInsets.all(8),
          itemCount: widget.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final item = widget.items[i];
            final focused = item.id == widget.focused;
            return Listener(
              key: _keys.putIfAbsent(item.id, GlobalKey.new),
              onPointerDown: (e) =>
                  GestureSurface.claimPointer(context, e.pointer),
              child: Semantics(
                button: true,
                focused: focused,
                label: item.label,
                excludeSemantics: true,
                onTap: () => widget.onTap(item.id),
                child: Material(
                  color: p.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppDimens.panelRadius),
                    ),
                    side: BorderSide(
                      color: focused ? p.focusRing : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => widget.onTap(item.id),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppDimens.minTouchTarget,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Center(
                          child: FitText(item.label, lines: 2, style: style),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
