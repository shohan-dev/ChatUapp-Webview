import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'no_internet_screen.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _hasInternet = true;
  StreamSubscription<InternetStatus>? _internetSubscription;

  final String _initialUrl = 'https://chatuapp.ai/';

  @override
  void initState() {
    super.initState();
    _initInternetListener();
    _initWebView();
  }

  @override
  void dispose() {
    _internetSubscription?.cancel();
    super.dispose();
  }

  void _initInternetListener() {
    // Initial check
    InternetConnection().hasInternetAccess.then((hasInternet) {
      if (mounted) {
        setState(() {
          _hasInternet = hasInternet;
        });
      }
    });

    // Listen for changes
    _internetSubscription = InternetConnection().onStatusChange.listen((
      status,
    ) {
      final hasInternet = status == InternetStatus.connected;
      if (mounted && _hasInternet != hasInternet) {
        setState(() {
          _hasInternet = hasInternet;
          if (_hasInternet) {
            _controller.reload();
          }
        });
      }
    });
  }

  void _initWebView() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {});
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {});
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {});
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebResourceError: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            final Uri uri = Uri.parse(request.url);

            // Allow navigation to the main domain
            if (uri.host == 'chatuapp.ai' || uri.host == 'www.chatuapp.ai') {
              return NavigationDecision.navigate;
            }

            // Handle external schemes (tel, mailto, sms, etc.) and other domains
            if (!['http', 'https'].contains(uri.scheme)) {
              _launchExternal(uri);
              return NavigationDecision.prevent;
            }

            // Keep internal links inside the app
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_initialUrl));

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
  }

  Future<void> _launchExternal(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _checkInternetAndReload() async {
    bool hasInternet = await InternetConnection().hasInternetAccess;
    if (mounted) {
      setState(() {
        _hasInternet = hasInternet;
        if (hasInternet) {
          _controller.reload();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // if (!_hasInternet) {
    //   return NoInternetScreen(onRetry: _checkInternetAndReload);
    // }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [Expanded(child: WebViewWidget(controller: _controller))],
          ),
        ),
      ),
    );
  }
}
