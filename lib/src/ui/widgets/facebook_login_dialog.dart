import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../facebook/facebook_cookies.dart';
import '../../facebook/facebook_session.dart';

/// Whether in-app WebView cookie capture is supported on this platform.
bool facebookWebViewLoginSupported() =>
    Platform.isAndroid || Platform.isIOS;

Future<bool?> showFacebookLoginDialog(
  BuildContext context, {
  FacebookSession? session,
}) {
  if (!facebookWebViewLoginSupported()) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Facebook login'),
        content: const Text(
          'In-app Facebook login is available on Android. '
          'On Windows/Linux, use a cookies.txt file or '
          '"Import from browser" in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => FacebookLoginDialog(
      session: session ?? FacebookSession(),
    ),
  );
}

class FacebookLoginDialog extends StatefulWidget {
  const FacebookLoginDialog({required this.session, super.key});

  final FacebookSession session;

  @override
  State<FacebookLoginDialog> createState() => _FacebookLoginDialogState();
}

class _FacebookLoginDialogState extends State<FacebookLoginDialog> {
  late final WebViewController _controller;
  var _loading = true;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() => _error = error.description);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://m.facebook.com/login'));
  }

  Future<void> _saveSession() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final cookies = await _readFacebookCookies();
      if (!facebookSessionLooksLoggedIn(cookies)) {
        setState(() {
          _saving = false;
          _error =
              'No Facebook session found yet. Log in in the page above, '
              'then tap Save session.';
        });
        return;
      }
      await widget.session.saveCookies(cookies);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<List<FacebookCookie>> _readFacebookCookies() async {
    final manager = WebViewCookieManager();
    final urls = [
      Uri.parse('https://www.facebook.com'),
      Uri.parse('https://m.facebook.com'),
      Uri.parse('https://facebook.com'),
    ];
    final byName = <String, FacebookCookie>{};

    if (manager.platform is AndroidWebViewCookieManager) {
      final android = manager.platform as AndroidWebViewCookieManager;
      for (final url in urls) {
        final list = await android.getCookies(url);
        for (final item in list) {
          if (item.name.isEmpty) continue;
          byName[item.name] = FacebookCookie(
            name: item.name,
            value: item.value,
            domain: _normalizeDomain(item.domain),
            path: item.path.isEmpty ? '/' : item.path,
            isSecure: true,
          );
        }
      }
    }

    return byName.values.toList();
  }

  static String _normalizeDomain(String domain) {
    final host = Uri.tryParse(domain)?.host;
    final value = (host != null && host.isNotEmpty) ? host : domain;
    if (value.startsWith('.')) return value;
    if (value.contains('facebook.com') || value.contains('fb.com')) {
      return '.$value';
    }
    return value.isEmpty ? '.facebook.com' : value;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: const Text('Log in to Facebook'),
      content: SizedBox(
        width: size.width < 600 ? size.width * 0.95 : 520,
        height: size.height * 0.65,
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sign in below, then tap Save session. '
                'Your session cookies stay on this device.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _saveSession,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save session'),
        ),
      ],
    );
  }
}
