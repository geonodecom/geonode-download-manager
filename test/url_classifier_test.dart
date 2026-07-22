import 'package:flutter_test/flutter_test.dart';
import 'package:geonode_download_manager/src/services/url_classifier.dart';

void main() {
  group('UrlClassifier', () {
    test('detects youtube watch URLs', () {
      expect(
        UrlClassifier.classify(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        DownloadUrlKind.youtube,
      );
    });

    test('watch with list is single video not playlist', () {
      expect(
        UrlClassifier.classify(
          'https://www.youtube.com/watch?v=UdsO4SM4wKI&list=RDUdsO4SM4wKI&start_radio=1',
        ),
        DownloadUrlKind.youtube,
      );
    });

    test('detects youtu.be URLs', () {
      expect(
        UrlClassifier.classify('https://youtu.be/dQw4w9WgXcQ'),
        DownloadUrlKind.youtube,
      );
    });

    test('detects youtube shorts', () {
      expect(
        UrlClassifier.classify('https://www.youtube.com/shorts/abc123xyz01'),
        DownloadUrlKind.youtube,
      );
    });

    test('detects live embed clip and v paths', () {
      expect(
        UrlClassifier.classify('https://www.youtube.com/live/dQw4w9WgXcQ'),
        DownloadUrlKind.youtube,
      );
      expect(
        UrlClassifier.classify('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        DownloadUrlKind.youtube,
      );
      expect(
        UrlClassifier.classify('https://www.youtube.com/clip/UgkxABCDEFGHI'),
        DownloadUrlKind.youtube,
      );
      expect(
        UrlClassifier.classify('https://www.youtube.com/v/dQw4w9WgXcQ'),
        DownloadUrlKind.youtube,
      );
    });

    test('detects music and nocookie hosts', () {
      expect(
        UrlClassifier.classify(
          'https://music.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        DownloadUrlKind.youtube,
      );
      expect(
        UrlClassifier.classify(
          'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ',
        ),
        DownloadUrlKind.youtube,
      );
    });

    test('normalizes bare youtube hosts', () {
      expect(
        UrlClassifier.normalizeInputUrl(
          'youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        'https://youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(
        UrlClassifier.classify('youtube.com/watch?v=dQw4w9WgXcQ'),
        DownloadUrlKind.youtube,
      );
    });

    test('detects playlist-only URLs', () {
      expect(
        UrlClassifier.classify(
          'https://www.youtube.com/playlist?list=PL123',
        ),
        DownloadUrlKind.youtubePlaylist,
      );
    });

    test('watch with list but no video id is not a playlist', () {
      expect(
        UrlClassifier.classify(
          'https://www.youtube.com/watch?list=RDUdsO4SM4wKI&index=9',
        ),
        DownloadUrlKind.direct,
      );
    });

    test('normalizeYoutubeUrl strips list params to canonical watch url', () {
      expect(
        UrlClassifier.normalizeYoutubeUrl(
          'https://www.youtube.com/watch?v=YyepU5ztLf4&list=RDUdsO4SM4wKI&index=9',
        ),
        'https://www.youtube.com/watch?v=YyepU5ztLf4',
      );
    });

    test('normalizeInputUrl strips zero-width characters', () {
      expect(
        UrlClassifier.normalizeInputUrl(
          '\uFEFFhttps://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
    });

    test('normalizeYoutubeUrl returns canonical watch url', () {
      expect(
        UrlClassifier.normalizeYoutubeUrl(
          'https://youtu.be/dQw4w9WgXcQ?si=abc',
        ),
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
    });

    test('leaves direct URLs unchanged', () {
      expect(
        UrlClassifier.classify('https://example.com/file.bin'),
        DownloadUrlKind.direct,
      );
    });
  });
}
