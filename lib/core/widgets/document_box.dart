import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/theme/app_palette.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_settings.dart';
import '../../config/constants.dart';
import '../../l10n/app_localizations.dart';
import '../gestures/gesture_surface.dart';
import 'bordered_panel.dart';

/// The Document Box on the Reader screen: shows extracted text (bold,
/// justified) with an always-visible scrollbar, a loading state while
/// scanning, the sentence being read highlighted, and a transient caption
/// strip for short system messages ("Bilis: 1.2x", "Na-save").
///
/// Only normal scrolling happens here — no navigation gestures.
class DocumentBox extends StatefulWidget {
  /// Creates a Document Box.
  const DocumentBox({
    super.key,
    required this.text,
    this.isLoading = false,
    this.loadingMessage,
    this.highlight,
    this.caption,
    this.scrollController,
    this.emptyMessage,
    this.onTextSize,
    this.onFavorite,
    this.favoriteLabel,
    this.header,
  });

  /// Saves the current spot as a favorite. Non-null shows a "Paborito" button
  /// between A− and A+.
  final VoidCallback? onFavorite;

  /// Spoken and visible label of the favorite button.
  final String? favoriteLabel;

  /// Asks for a bigger (1) or smaller (−1) text size. Non-null shows the
  /// A−/A+ buttons above the text and turns on pinch-to-zoom.
  final void Function(int direction)? onTextSize;

  /// Shown above the text, inside the scrolling area (the picture on the
  /// Description screen).
  final Widget? header;

  /// Document text, or null/empty when there is nothing to show.
  final String? text;

  /// Show the scanning/extraction state instead of [text].
  final bool isLoading;

  /// Progress message while loading; defaults to "Binabasa ang dokumento…".
  final String? loadingMessage;

  /// Character range of [text] currently being spoken.
  final TextRange? highlight;

  /// Short system message pinned at the top, or null to hide it. The caller
  /// clears it after [AppDurations.captionVisible].
  final String? caption;

  /// Optional external controller (the reader uses it to auto-scroll).
  final ScrollController? scrollController;

  /// Shown instead of "Walang tekstong mababasa." when there is no text
  /// (e.g. why the file couldn't be read).
  final String? emptyMessage;

  @override
  State<DocumentBox> createState() => _DocumentBoxState();
}

class _DocumentBoxState extends State<DocumentBox> {
  static const double _padTop = 14;

  /// Spread change (pinch out / in) that counts as one text-size step.
  static const double _pinchStep = 1.18;

  ScrollController? _ownController;
  final GlobalKey _textKey = GlobalKey();
  final GlobalKey _headerKey = GlobalKey();
  final Map<int, Offset> _pointers = {};
  double? _pinchBase;
  double? _lastSize;

  ScrollController get _controller =>
      widget.scrollController ?? (_ownController ??= ScrollController());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = Theme.of(context).extension<AppTextMetrics>()?.textSize;
    if (_lastSize != null && size != _lastSize) {
      // The text reflowed: keep the sentence being read where the user can
      // see it.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _revealHighlight(force: true),
      );
    }
    _lastSize = size;
  }

  double _spread() {
    final p = _pointers.values.take(2).toList();
    return (p[0] - p[1]).distance;
  }

  void _pointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 2 && widget.onTextSize != null) {
      setState(() => _pinchBase = _spread());
    }
  }

  void _pointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    final base = _pinchBase;
    final onSize = widget.onTextSize;
    if (base == null || base < 1 || _pointers.length < 2 || onSize == null) {
      return;
    }
    final ratio = _spread() / base;
    if (ratio >= _pinchStep) {
      _pinchBase = _spread();
      onSize(1);
    } else if (ratio <= 1 / _pinchStep) {
      _pinchBase = _spread();
      onSize(-1);
    }
  }

  void _pointerEnd(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2 && _pinchBase != null) {
      setState(() => _pinchBase = null);
    }
  }

  @override
  void didUpdateWidget(DocumentBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight != null && widget.highlight != oldWidget.highlight) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealHighlight());
    }
  }

  /// Scrolls so the highlighted sentence is in view (about a quarter from
  /// the top), if it isn't already — or always, with [force] (after a text
  /// size change, jumping at once).
  void _revealHighlight({bool force = false}) {
    final range = widget.highlight;
    final paragraph = _textKey.currentContext?.findRenderObject();
    if (!mounted ||
        range == null ||
        paragraph is! RenderParagraph ||
        !_controller.hasClients) {
      return;
    }
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: range.start, extentOffset: range.end),
    );
    if (boxes.isEmpty) return;
    final headerHeight = (_headerKey.currentContext?.size?.height ?? 0);
    final top = boxes.first.top + _padTop + headerHeight;
    final bottom = boxes.last.bottom + _padTop + headerHeight;
    final position = _controller.position;
    final viewTop = position.pixels;
    final viewBottom = viewTop + position.viewportDimension;
    if (!force && top >= viewTop && bottom <= viewBottom) return;

    final target = (top - position.viewportDimension * 0.25).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (force || MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(target);
    } else {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = widget.text;
    final caption = widget.caption;

    final Widget body;
    if (widget.isLoading) {
      body = _LoadingState(
        message: widget.loadingMessage ?? l10n.readerLoading,
      );
    } else if (text == null || text.trim().isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            widget.emptyMessage ?? l10n.readerEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    } else {
      body = Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _controller,
          // Two fingers pinch; they don't also scroll.
          physics: _pinchBase == null
              ? null
              : const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, _padTop, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.header != null)
                KeyedSubtree(
                  key: _headerKey,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: widget.header,
                  ),
                ),
              Text.rich(
                key: _textKey,
                _buildSpans(context, text, widget.highlight),
                textAlign: TextAlign.justify,
                style: AppTheme.documentText(context),
                textScaler: AppTheme.documentTextScaler,
              ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: l10n.readerDocumentLabel,
      child: BorderedPanel(
        child: Column(
          children: [
            if (widget.onTextSize != null)
              _SizeBar(
                size: _lastSize ?? TextSize.standard,
                onTextSize: widget.onTextSize!,
                onFavorite: widget.onFavorite,
                favoriteLabel: widget.favoriteLabel,
              ),
            Expanded(
              child: Listener(
                onPointerDown: _pointerDown,
                onPointerMove: _pointerMove,
                onPointerUp: _pointerEnd,
                onPointerCancel: _pointerEnd,
                child: Stack(
                  children: [
                    Positioned.fill(child: body),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: AnimatedSwitcher(
                        duration: AppDurations.fade,
                        child: caption == null
                            ? const SizedBox.shrink()
                            : _CaptionStrip(
                                key: ValueKey(caption),
                                message: caption,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static TextSpan _buildSpans(
    BuildContext context,
    String text,
    TextRange? range,
  ) {
    if (range == null ||
        !range.isValid ||
        range.isCollapsed ||
        range.end > text.length) {
      return TextSpan(text: text);
    }
    final p = context.palette;
    return TextSpan(
      children: [
        TextSpan(text: range.textBefore(text)),
        TextSpan(
          text: range.textInside(text),
          // Underline as well as background, so the highlight is not
          // conveyed by color alone.
          style: TextStyle(
            backgroundColor: p.highlight,
            color: p.onHighlight,
            decoration: TextDecoration.underline,
            decorationColor: p.onHighlight,
            decorationThickness: 2,
          ),
        ),
        TextSpan(text: range.textAfter(text)),
      ],
    );
  }
}

/// "A−  18  A+" above the text: big, always visible, spoken by label.
class _SizeBar extends StatelessWidget {
  const _SizeBar({
    required this.size,
    required this.onTextSize,
    this.onFavorite,
    this.favoriteLabel,
  });

  final double size;
  final void Function(int direction) onTextSize;
  final VoidCallback? onFavorite;
  final String? favoriteLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(
        children: [
          _SizeButton(
            glyph: 'A−',
            label: l10n.readerTextSmaller,
            onTap: () => onTextSize(-1),
          ),
          Expanded(
            child: onFavorite == null
                ? ExcludeSemantics(
                    child: Text(
                      '${size.round()}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: p.body),
                    ),
                  )
                : Center(
                    child: _SizeButton(
                      glyph: '★ ${favoriteLabel ?? ''}',
                      label: favoriteLabel ?? '',
                      onTap: onFavorite!,
                    ),
                  ),
          ),
          _SizeButton(
            glyph: 'A+',
            label: l10n.readerTextBigger,
            onTap: () => onTextSize(1),
          ),
        ],
      ),
    );
  }
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  final String glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Listener(
      onPointerDown: (e) => GestureSurface.claimPointer(context, e.pointer),
      child: Semantics(
        button: true,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: p.secondary,
          shape: StadiumBorder(
            side: BorderSide(color: p.secondaryOutline, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: AppDimens.minTouchTarget + 8,
                minHeight: AppDimens.minTouchTarget - 8,
              ),
              child: Center(
                child: Text(
                  glyph,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: p.onSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptionStrip extends StatelessWidget {
  const _CaptionStrip({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: p.primary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: p.onPrimary, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
