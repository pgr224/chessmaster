import 'dart:io';

void main() {
  final dir = Directory('lib');
  int totalReplaced = 0;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = entity.readAsStringSync();
      
      // Replace .withValues(alpha: x) with .withOpacity(x)
      // Matches both .withValues(alpha: 0.5) and .withValues(alpha: someVar)
      final newContent = content.replaceAllMapped(
        RegExp(r'\.withValues\(alpha:\s*(.*?)\)'),
        (match) => '.withOpacity(${match.group(1)})',
      );
      
      if (content != newContent) {
        entity.writeAsStringSync(newContent);
        totalReplaced += RegExp(r'\.withValues\(alpha:').allMatches(content).length;
        print('Restored ${entity.path}');
      }
    }
  }
  print('Total .withValues restored to .withOpacity: $totalReplaced');
}
