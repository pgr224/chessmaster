import 'package:flutter/material.dart';

/// Loads a route's code only when the player opens it.
class DeferredScreen extends StatefulWidget {
  const DeferredScreen({
    super.key,
    required this.loadLibrary,
    required this.builder,
  });

  final Future<void> Function() loadLibrary;
  final WidgetBuilder builder;

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late Future<void> _loading;

  @override
  void initState() {
    super.initState();
    _loading = widget.loadLibrary();
  }

  @override
  void didUpdateWidget(DeferredScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadLibrary != widget.loadLibrary) {
      _loading = widget.loadLibrary();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('This screen could not load. Try again.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() {
                        _loading = widget.loadLibrary();
                      }),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.done) {
            return widget.builder(context);
          }
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        },
      );
}
