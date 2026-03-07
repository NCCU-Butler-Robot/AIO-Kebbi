import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';

class RecipeWebViewPage extends StatefulWidget {
  final String url;
  const RecipeWebViewPage({super.key, required this.url});

  @override
  State<RecipeWebViewPage> createState() => _RecipeWebViewPageState();
}

class _RecipeWebViewPageState extends State<RecipeWebViewPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: Text(
          'Recipe',
          style: GoogleFonts.itim(fontSize: 22, color: textColor),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
