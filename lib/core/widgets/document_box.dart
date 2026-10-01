import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/theme/app_palette.dart';
import '../../app/theme/app_theme.dart';
import '../../config/constants.dart';
import '../../l10n/app_localizations.dart';
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
  });

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

  ScrollController? _ownController;
  final GlobalKey _textKey = GlobalKey();

  ScrollController get _controller =>
      widget.scrollController ?? (_ownController ??= ScrollController());

  @override
  void didUpdateWidget(DocumentBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight != null && widget.highlight != oldWidget.highlight) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealHighlight());
    }
  }

  /// Scrolls so the highlighted sentence is in view (about a quarter from
  /// the top), if it isn't already.
  void _revealHighlight() {
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
    final top = boxes.first.top + _padTop;
    final bottom = boxes.last.bottom + _padTop;
    final position = _controller.position;
    final viewTop = position.pixels;
    final viewBottom = viewTop + position.viewportDimension;
    if (top >= viewTop && bottom <= viewBottom) return;

    final target = (top - position.viewportDimension * 0.25).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
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
          padding: const EdgeInsets.fromLTRB(14, _padTop, 20, 14),
          child: Text.rich(
            key: _textKey,
            _buildSpans(context, text, widget.highlight),
            textAlign: TextAlign.justify,
            style: AppTheme.documentText(context),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: l10n.readerDocumentLabel,
      child: BorderedPanel(
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
                    : _CaptionStrip(key: ValueKey(caption), message: caption),
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
