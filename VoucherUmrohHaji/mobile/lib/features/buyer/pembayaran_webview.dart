import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

/// Halaman pembayaran Midtrans Snap di dalam app (WebView).
///
/// - JavaScript & DOM storage aktif (syarat Snap).
/// - Skema app eksternal (gopay://, shopeepay://, dll) diteruskan ke app-nya.
/// - Tombol "Buka di browser" tetap tersedia sebagai cadangan.
class PembayaranWebView extends StatefulWidget {
  const PembayaranWebView({super.key, required this.url});

  final String url;

  @override
  State<PembayaranWebView> createState() => _PembayaranWebViewState();
}

class _PembayaranWebViewState extends State<PembayaranWebView> {
  InAppWebViewController? _controller;
  double _progres = 0;

  Future<NavigationActionPolicy?> _putuskanNavigasi(
      InAppWebViewController c, NavigationAction a) async {
    final uri = a.request.url;
    if (uri == null) return NavigationActionPolicy.ALLOW;
    final skema = uri.scheme.toLowerCase();
    if (skema == 'http' || skema == 'https') return NavigationActionPolicy.ALLOW;
    // Skema app pembayaran (gopay://, shopeepay://, dll) → buka di luar.
    await launchUrl(Uri.parse(uri.toString()), mode: LaunchMode.externalApplication);
    return NavigationActionPolicy.CANCEL;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
        actions: [
          IconButton(
            tooltip: 'Buka di browser',
            icon: const Icon(Icons.open_in_new),
            onPressed: () =>
                launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progres > 0 && _progres < 1)
            LinearProgressIndicator(value: _progres, minHeight: 3),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                supportZoom: false,
              ),
              onWebViewCreated: (c) => _controller = c,
              onProgressChanged: (c, p) => setState(() => _progres = p / 100),
              shouldOverrideUrlLoading: _putuskanNavigasi,
              // 3DS dan beberapa metode pakai window.open/popup.
              onCreateWindow: (c, createWindowRequest) async {
                final uri = createWindowRequest.request.url;
                if (uri != null) {
                  await _controller?.loadUrl(urlRequest: URLRequest(url: uri));
                }
                return true;
              },
            ),
          ),
        ],
      ),
    );
  }
}
