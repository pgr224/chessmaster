import 'dart:io';

void main() {
  final dir = Directory('lib');
  int totalReplaced = 0;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = entity.readAsStringSync();
      final newContent = content.replaceAllMapped(
        RegExp(r'\.withOpacity\(([^()]+)\)'),
        (match) => '.withValues(alpha: ${match.group(1)})',
      );
      if (content != newContent) {
        entity.writeAsStringSync(newContent);
        totalReplaced += RegExp(r'\.withOpacity\(').allMatches(content).length;
        print('Updated ${entity.path}');
      }
    }
  }
  print('Total .withOpacity replaced: $totalReplaced');
}
