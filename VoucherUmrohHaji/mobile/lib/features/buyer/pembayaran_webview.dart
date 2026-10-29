import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Halaman pembayaran Midtrans Snap di dalam app (WebView).
///
/// - JavaScript aktif (syarat Snap).
/// - Skema app eksternal (gopay://, shopeepay://, dll) diteruskan ke app-nya.
/// - Tombol "Buka di browser" tetap tersedia sebagai cadangan.
class PembayaranWebView extends StatefulWidget {
  const PembayaranWebView({super.key, required this.url});

  final String url;

  @override
  State<PembayaranWebView> createState() => _PembayaranWebViewState();
}

class _PembayaranWebViewState extends State<PembayaranWebView> {
  double _progres = 0;

  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(
        onProgress: (p) => setState(() => _progres = p / 100),
        onNavigationRequest: (req) {
          final uri = Uri.tryParse(req.url);
          final skema = uri?.scheme.toLowerCase();
          if (uri == null || skema == 'http' || skema == 'https') {
            return NavigationDecision.navigate;
          }
          // Skema app pembayaran (gopay://, shopeepay://, dll) → buka di luar.
          launchUrl(uri, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
      ),
    )
    ..loadRequest(Uri.parse(widget.url));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
        actions: [
          IconButton(
            tooltip: 'Buka di browser',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => launchUrl(Uri.parse(widget.url),
                mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progres > 0 && _progres < 1)
            LinearProgressIndicator(value: _progres, minHeight: 3),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
