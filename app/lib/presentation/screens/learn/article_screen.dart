import 'package:flutter/material.dart';

class ArticleScreen extends StatelessWidget {
  final String articleId;
  const ArticleScreen({super.key, required this.articleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Article')),
      body: Center(
        child: Text('Article Content ($articleId) - Coming Soon'),
      ),
    );
  }
}
