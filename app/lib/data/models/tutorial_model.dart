import 'package:equatable/equatable.dart';

class TutorialLesson extends Equatable {
  final String id;
  final String title;
  final String description;
  final String initialFEN;
  final List<TutorialStep> steps;

  const TutorialLesson({
    required this.id,
    required this.title,
    required this.description,
    required this.initialFEN,
    required this.steps,
  });

  @override
  List<Object?> get props => [id, title, description, initialFEN, steps];
}

class TutorialStep extends Equatable {
  final String text;
  final String? expectedMove; // e.g., 'e2e4'
  final String? successMessage;
  final String? errorMessage;
  final bool isCompletion;

  const TutorialStep({
    required this.text,
    this.expectedMove,
    this.successMessage,
    this.errorMessage,
    this.isCompletion = false,
  });

  @override
  List<Object?> get props => [text, expectedMove, successMessage, errorMessage, isCompletion];
}

final List<TutorialLesson> tutorialLessons = [
  TutorialLesson(
    id: 'lesson1',
    title: 'The Pawn Strike',
    description: 'Learn how to move pawns and control the center.',
    initialFEN: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    steps: [
       TutorialStep(
        text: 'Move your king\'s pawn forward two squares to e4.',
        expectedMove: 'e2e4',
        successMessage: 'Great! You\'ve taken control of the center.',
      ),
      TutorialStep(
        text: 'Now move the queen\'s pawn to d4.',
        expectedMove: 'd2d4',
        successMessage: 'Excellent. You have a solid center presence.',
        isCompletion: true,
      ),
    ],
  ),
  TutorialLesson(
    id: 'lesson2',
    title: 'Knight Development',
    description: 'Bring your knights out to active squares.',
    initialFEN: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e3 0 1',
    steps: [
      TutorialStep(
        text: 'Move your kingside knight to f3.',
        expectedMove: 'g1f3',
        successMessage: 'The knight is now attacking e5 and controlling d4.',
        isCompletion: true,
      ),
    ],
  ),
];
