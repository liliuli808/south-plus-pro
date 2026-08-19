import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectionRegistrar;
import 'package:flutter/services.dart';

import '../../models/forum_models.dart';
import '../../services/external_link_launcher.dart';
import '../../services/image_saver.dart';
import '../../services/perf_trace.dart';
import '../../theme/app_theme.dart';
import '../common/cached_forum_image.dart';
import '../common/forum_emoji_assets.dart';
import 'thread_render_models.dart';
import 'thread_sale_box_view.dart';

class ThreadRichContent extends StatelessWidget {
  ThreadRichContent({
    super.key,
    required List<ThreadContentSegment> segments,
    this.buyingSaleBoxes = const <String>{},
    this.onBuySaleBox,
  }) : renderModel = ThreadPostRenderModel.fromSegments(segments);

  const ThreadRichContent.renderModel({
    super.key,
    required this.renderModel,
    this.buyingSaleBoxes = const <String>{},
    this.onBuySaleBox,
  });

  final ThreadPostRenderModel renderModel;
  final Set<String> buyingSaleBoxes;
  final ValueChanged<ThreadSaleBox>? onBuySaleBox;

  @override
  Widget build(BuildContext context) {
    return PerfTrace.span(
      'ThreadRichContent.build',
      () {
        final baseStyle = Theme.of(context).textTheme.bodyMedium;
        final selectionRegistrar = SelectionContainer.maybeOf(context);
        final selectionColor =
            DefaultSelectionStyle.of(context).selectionColor ??
                DefaultSelectionStyle.defaultColor;
        final children = _buildChildren(
          context,
          renderModel.blocks,
          baseStyle,
          selectionRegistrar,
          selectionColor,
          buyingSaleBoxes,
          onBuySaleBox,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
      arguments: {'blocks': renderModel.blocks.length},
    );
  }
}

List<Widget> _buildChildren(
  BuildContext context,
  List<ThreadRenderBlock> blocks,
  TextStyle? baseStyle,
  SelectionRegistrar? selectionRegistrar,
  Color selectionColor,
  Set<String> buyingSaleBoxes,
  ValueChanged<ThreadSaleBox>? onBuySaleBox,
) {
  final children = <Widget>[];
  final inlineSpans = <InlineSpan>[];

  void flushInline() {
    if (inlineSpans.isEmpty) return;
    children.add(
      RichText(
        selectionRegistrar: selectionRegistrar,
        selectionColor: selectionColor,
        text: TextSpan(
            style: baseStyle, children: List<InlineSpan>.of(inlineSpans)),
      ),
    );
    inlineSpans.clear();
  }

  for (final block in blocks) {
    switch (block.type) {
      case ThreadRenderBlockType.text:
        final textBlock = block as ThreadTextRenderBlock;
        inlineSpans.add(
          TextSpan(
            text: textBlock.text,
            style: _threadTextStyle(baseStyle, textBlock.style),
          ),
        );
      case ThreadRenderBlockType.link:
        final linkBlock = block as ThreadLinkRenderBlock;
        inlineSpans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: SelectionContainer.disabled(
              child: GestureDetector(
                onTap: () => _openInlineLink(context, linkBlock.url),
                onLongPress: () => _copyInlineLink(context, linkBlock.url),
                child: Text(
                  linkBlock.text,
                  style: _threadTextStyle(
                    baseStyle,
                    linkBlock.style,
                    forceLinkColor: true,
                    forceUnderline: true,
                  ),
                ),
              ),
            ),
          ),
        );
      case ThreadRenderBlockType.downloadLink:
        final downloadBlock = block as ThreadDownloadLinkRenderBlock;
        flushInline();
        children.add(
          Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 0 : 10),
            child: _DownloadLinkPanel(
              label: downloadBlock.label,
              url: downloadBlock.url,
            ),
          ),
        );
      case ThreadRenderBlockType.image:
        final imageBlock = block as ThreadImageRenderBlock;
        flushInline();
        children.add(
          Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 0 : 10),
            child: ThreadInlineImage(image: imageBlock.image),
          ),
        );
      case ThreadRenderBlockType.emoji:
        final emojiBlock = block as ThreadEmojiRenderBlock;
        inlineSpans.add(_emojiSpan(context, emojiBlock));
      case ThreadRenderBlockType.quote:
        final quoteBlock = block as ThreadQuoteRenderBlock;
        flushInline();
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _RichQuoteBlock(
              renderModel: quoteBlock.renderModel,
              buyingSaleBoxes: buyingSaleBoxes,
              onBuySaleBox: onBuySaleBox,
            ),
          ),
        );
      case ThreadRenderBlockType.saleBox:
        final saleBlock = block as ThreadSaleBoxRenderBlock;
        flushInline();
        children.add(
          Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 0 : 10),
            child: ThreadSaleBoxView(
              saleBox: saleBlock.saleBox,
              isBuying: buyingSaleBoxes.contains(saleBlock.saleBox.buyPath),
              onBuy: onBuySaleBox == null
                  ? null
                  : () => onBuySaleBox(saleBlock.saleBox),
            ),
          ),
        );
    }
  }

  flushInline();
  return children;
}

TextStyle _threadTextStyle(
  TextStyle? baseStyle,
  ThreadTextStyleData style, {
  bool forceLinkColor = false,
  bool forceUnderline = false,
}) {
  final color = style.colorValue == null ? null : Color(style.colorValue!);
  final background = style.backgroundColorValue == null
      ? null
      : Color(style.backgroundColorValue!);
  final decoration = _decoration(
    underline: style.isUnderline || forceUnderline,
    strike: style.isStrike,
  );

  return (baseStyle ?? const TextStyle()).copyWith(
    color: forceLinkColor ? AppColors.link : color,
    backgroundColor: background,
    fontWeight: style.isBold ? FontWeight.w800 : baseStyle?.fontWeight,
    fontStyle: style.isItalic ? FontStyle.italic : baseStyle?.fontStyle,
    decoration: decoration,
    fontSize: (baseStyle?.fontSize ?? 16) * style.fontScale,
  );
}

InlineSpan _emojiSpan(BuildContext context, ThreadEmojiRenderBlock block) {
  const emojiMaxHeight = 70.0;
  const emojiMaxWidth = 191.0;
  final spec = ForumImageDecodeSpec.forDisplay(
    logicalSize: const Size(emojiMaxWidth, emojiMaxHeight),
    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    maxLongEdge: 512,
  );

  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: emojiMaxWidth,
          maxHeight: emojiMaxHeight,
        ),
        child: CachedForumImage(
          url: block.url,
          assetName: forumEmojiAssetNameForUrl(block.url),
          fit: BoxFit.scaleDown,
          memCacheWidth: spec.memCacheWidth,
          memCacheHeight: spec.memCacheHeight,
          maxWidthDiskCache: spec.maxWidthDiskCache,
          maxHeightDiskCache: spec.maxHeightDiskCache,
          bypassLoadPolicy: true,
          errorWidget: (context) => const SizedBox(width: 0, height: 0),
        ),
      ),
    ),
  );
}

TextDecoration _decoration({
  required bool underline,
  required bool strike,
}) {
  final decorations = <TextDecoration>[
    if (underline) TextDecoration.underline,
    if (strike) TextDecoration.lineThrough,
  ];
  if (decorations.isEmpty) return TextDecoration.none;
  if (decorations.length == 1) return decorations.first;
  return TextDecoration.combine(decorations);
}

Future<void> _openInlineLink(BuildContext context, String url) async {
  try {
    await ExternalLinkLauncher.open(url);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$error')),
    );
  }
}

Future<void> _copyInlineLink(BuildContext context, String url) async {
  await _copyDownloadLink(context, url);
}

class _DownloadLinkPanel extends StatelessWidget {
  const _DownloadLinkPanel({
    required this.label,
    required this.url,
  });

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '打开下载链接',
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openDownloadLink(context, url),
          onLongPress: () => _copyDownloadLink(context, url),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: SelectionContainer.disabled(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: AppColors.link,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.link,
                        fontSize: 12,
                        height: 1.35,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openDownloadLink(BuildContext context, String url) async {
  try {
    await ExternalLinkLauncher.open(url);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$error')),
    );
  }
}

Future<void> _copyDownloadLink(BuildContext context, String url) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('链接已复制')),
  );
}

class _RichQuoteBlock extends StatelessWidget {
  const _RichQuoteBlock({
    required this.renderModel,
    required this.buyingSaleBoxes,
    required this.onBuySaleBox,
  });

  final ThreadPostRenderModel renderModel;
  final Set<String> buyingSaleBoxes;
  final ValueChanged<ThreadSaleBox>? onBuySaleBox;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        border: Border(
          left: BorderSide(color: AppColors.brand, width: 4),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              height: 1.55,
            ),
        child: ThreadRichContent.renderModel(
          renderModel: renderModel,
          buyingSaleBoxes: buyingSaleBoxes,
          onBuySaleBox: onBuySaleBox,
        ),
      ),
    );
  }
}

class ThreadInlineImage extends StatefulWidget {
  const ThreadInlineImage({super.key, required this.image});

  final ThreadImage image;

  @override
  State<ThreadInlineImage> createState() => _ThreadInlineImageState();
}

class _ThreadInlineImageState extends State<ThreadInlineImage> {
  bool _saving = false;

  Future<void> _saveImage() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final file = await ForumImageCache.manager.getSingleFile(
        widget.image.url,
      );
      final bytes = await file.readAsBytes();
      await ImageSaver.saveImage(bytes, sourceUrl: widget.image.url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片已保存到相册')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存图片失败：$error')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
    }
  }

  void _openImageViewer() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        final spec = ForumImageDecodeSpec.forDisplay(
          logicalSize: Size(size.width * 0.92, size.height * 0.82),
          devicePixelRatio: MediaQuery.devicePixelRatioOf(dialogContext),
          memoryScale: 1.2,
          diskScale: 1.2,
          maxLongEdge: 2600,
        );
        return Dialog(
          child: SizedBox(
            width: size.width * 0.92,
            height: size.height * 0.82,
            child: Column(
              children: [
                Expanded(
                  child: InteractiveViewer(
                    child: CachedForumImage(
                      url: widget.image.url,
                      fit: BoxFit.contain,
                      memCacheWidth: spec.memCacheWidth,
                      memCacheHeight: spec.memCacheHeight,
                      maxWidthDiskCache: spec.maxWidthDiskCache,
                      maxHeightDiskCache: spec.maxHeightDiskCache,
                      bypassLoadPolicy: true,
                      errorWidget: (context) => ThreadImageFailurePlaceholder(
                        url: widget.image.url,
                        onOpen: () =>
                            _openDownloadLink(context, widget.image.url),
                        onCopy: () =>
                            _copyDownloadLink(context, widget.image.url),
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white70,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                    child: TextButton.icon(
                      onPressed: _saveImage,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('保存图片'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PerfTrace.span(
      'ThreadInlineImage.build',
      () {
        return SelectionContainer.disabled(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _openImageViewer,
            onLongPress: _saveImage,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                key: const ValueKey('thread-inline-image-container'),
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 360),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final logicalWidth = constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : MediaQuery.sizeOf(context).width;
                    final spec = ForumImageDecodeSpec.forDisplay(
                      logicalSize: Size(logicalWidth, 360),
                      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                      includeMemHeight: false,
                      maxLongEdge: 1600,
                    );

                    return CachedForumImage(
                      url: widget.image.url,
                      fit: BoxFit.contain,
                      memCacheWidth: spec.memCacheWidth,
                      memCacheHeight: spec.memCacheHeight,
                      maxWidthDiskCache: spec.maxWidthDiskCache,
                      maxHeightDiskCache: spec.maxHeightDiskCache,
                      placeholder: (context) {
                        return const SizedBox(
                          height: 160,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorWidget: (context) => ThreadImageFailurePlaceholder(
                        url: widget.image.url,
                        onOpen: () =>
                            _openDownloadLink(context, widget.image.url),
                        onCopy: () =>
                            _copyDownloadLink(context, widget.image.url),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
      arguments: {'url': widget.image.url},
    );
  }
}

class ThreadImageFailurePlaceholder extends StatelessWidget {
  const ThreadImageFailurePlaceholder({
    super.key,
    required this.url,
    required this.onOpen,
    required this.onCopy,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String url;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = foregroundColor ?? AppColors.textMuted;
    final bgColor = backgroundColor ?? AppColors.surfaceTint;

    return Semantics(
      button: true,
      label: '图片加载失败',
      hint: '点按浏览器打开，长按复制链接',
      child: Material(
        color: bgColor,
        child: InkWell(
          onTap: onOpen,
          onLongPress: onCopy,
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image_outlined, color: textColor),
                    const SizedBox(height: 8),
                    Text(
                      '图片加载失败',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '点按浏览器打开\n长按复制链接',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColor.withValues(alpha: 0.88),
                        height: 1.3,
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
