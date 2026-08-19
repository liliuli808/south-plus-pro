import 'package:flutter_test/flutter_test.dart';
import 'package:south_plus_rewrite/features/thread/thread_render_models.dart';
import 'package:south_plus_rewrite/models/forum_models.dart';

void main() {
  test('precompiles segments into stable render blocks', () {
    const magnetUrl =
        'magnet:?xt=urn:btih:abcdef1234567890abcdef1234567890abcdef12';
    final renderModel = ThreadPostRenderModel.fromSegments(const [
      ThreadContentSegment.text('第一段'),
      ThreadContentSegment.text('正文'),
      ThreadContentSegment.text(
        '示例链接',
        href: 'https://example.com/thread',
      ),
      ThreadContentSegment.text(magnetUrl),
      ThreadContentSegment.quote([
        ThreadContentSegment.text('引用内容'),
      ]),
      ThreadContentSegment.image(url: 'https://example.com/image.jpg'),
      ThreadContentSegment.image(
        url: 'https://example.com/emoji.png',
        isEmoji: true,
      ),
    ]);

    expect(renderModel.hasImages, isTrue);
    expect(renderModel.hasEmoji, isTrue);
    expect(renderModel.hasDownloadLinks, isTrue);
    expect(renderModel.hasQuotes, isTrue);
    expect(renderModel.hasSaleBoxes, isFalse);
    expect(renderModel.blocks, hasLength(6));

    expect(renderModel.blocks[0], isA<ThreadTextRenderBlock>());
    expect(
      (renderModel.blocks[0] as ThreadTextRenderBlock).text,
      '第一段正文',
    );

    expect(renderModel.blocks[1], isA<ThreadLinkRenderBlock>());
    expect(
      (renderModel.blocks[1] as ThreadLinkRenderBlock).url,
      'https://example.com/thread',
    );

    expect(renderModel.blocks[2], isA<ThreadDownloadLinkRenderBlock>());
    expect(
      (renderModel.blocks[2] as ThreadDownloadLinkRenderBlock).url,
      magnetUrl,
    );

    final quoteBlock = renderModel.blocks[3] as ThreadQuoteRenderBlock;
    expect(quoteBlock.renderModel.blocks, hasLength(1));
    expect(
      (quoteBlock.renderModel.blocks.single as ThreadTextRenderBlock).text,
      '引用内容',
    );

    expect(renderModel.blocks[4], isA<ThreadImageRenderBlock>());
    expect(renderModel.blocks[5], isA<ThreadEmojiRenderBlock>());
  });

  test('auto-linkifies bare URLs in plain text', () {
    final renderModel = ThreadPostRenderModel.fromSegments(const [
      ThreadContentSegment.text('看这里 https://example.com/foo 后面文字'),
      ThreadContentSegment.text('纯文本'),
    ]);

    expect(renderModel.blocks, hasLength(3));
    expect(renderModel.blocks[0], isA<ThreadTextRenderBlock>());
    expect(
      (renderModel.blocks[0] as ThreadTextRenderBlock).text,
      '看这里 ',
    );

    expect(renderModel.blocks[1], isA<ThreadLinkRenderBlock>());
    expect(
      (renderModel.blocks[1] as ThreadLinkRenderBlock).url,
      'https://example.com/foo',
    );

    expect(renderModel.blocks[2], isA<ThreadTextRenderBlock>());
    expect(
      (renderModel.blocks[2] as ThreadTextRenderBlock).text,
      ' 后面文字纯文本',
    );
  });

  test('bare URL keeps trailing punctuation out of the link', () {
    final renderModel = ThreadPostRenderModel.fromSegments(const [
      ThreadContentSegment.text('见 https://example.com/foo。下一个'),
    ]);

    expect(renderModel.blocks[1], isA<ThreadLinkRenderBlock>());
    expect(
      (renderModel.blocks[1] as ThreadLinkRenderBlock).url,
      'https://example.com/foo',
    );
    expect(renderModel.blocks[2], isA<ThreadTextRenderBlock>());
    expect(
      (renderModel.blocks[2] as ThreadTextRenderBlock).text,
      '。下一个',
    );
  });

  test('bare magnet URL still becomes a download link block', () {
    const magnetUrl =
        'magnet:?xt=urn:btih:abcdef1234567890abcdef1234567890abcdef12';
    final renderModel = ThreadPostRenderModel.fromSegments(const [
      ThreadContentSegment.text('下载：$magnetUrl 结束'),
    ]);

    expect(renderModel.hasDownloadLinks, isTrue);
    expect(renderModel.blocks[1], isA<ThreadDownloadLinkRenderBlock>());
    expect(
      (renderModel.blocks[1] as ThreadDownloadLinkRenderBlock).url,
      magnetUrl,
    );
  });

  test('bare URL is not swallowed when Chinese text follows', () {
    final renderModel = ThreadPostRenderModel.fromSegments(const [
      ThreadContentSegment.text('https://example.com/foo中文'),
    ]);

    expect(renderModel.blocks[1], isA<ThreadLinkRenderBlock>());
    expect(
      (renderModel.blocks[1] as ThreadLinkRenderBlock).url,
      'https://example.com/foo',
    );
    expect(renderModel.blocks[2], isA<ThreadTextRenderBlock>());
    expect(
      (renderModel.blocks[2] as ThreadTextRenderBlock).text,
      '中文',
    );
  });

  test('precompiles sale box blocks in content order', () {
    final renderModel = ThreadPostRenderModel.fromSegments(const [
      ThreadContentSegment.text('前文'),
      ThreadContentSegment.saleBox(
        ThreadSaleBox(
          summary: '此帖售价 5 SP币,已有 8 人购买',
          buyPath: 'job.php?action=buytopic&tid=1&pid=1',
          warning: '购买风险提示',
          price: 5,
          buyers: 8,
        ),
      ),
      ThreadContentSegment.image(url: 'https://example.com/image.jpg'),
    ]);

    expect(renderModel.hasSaleBoxes, isTrue);
    expect(renderModel.blocks, hasLength(3));
    expect(renderModel.blocks[0], isA<ThreadTextRenderBlock>());
    expect(renderModel.blocks[1], isA<ThreadSaleBoxRenderBlock>());
    expect(
      (renderModel.blocks[1] as ThreadSaleBoxRenderBlock).saleBox.buyPath,
      'job.php?action=buytopic&tid=1&pid=1',
    );
    expect(renderModel.blocks[2], isA<ThreadImageRenderBlock>());
  });
}
