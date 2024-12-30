import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

/// The main entry point of the application, which sets up the MaterialApp.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reversed Minesweeper',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const GameBoard(),
    );
  }
}

/// The main game board widget, responsible for displaying and managing the game.
class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  GameBoardState createState() => GameBoardState();
}

class GameBoardState extends State<GameBoard> with SingleTickerProviderStateMixin{
  static const int boardSize = 10;
  static const int bombCount = 15; // Number of bombs in the game
  static const int initialPieces = 20; // Number of initial movable pieces

  late List<List<BoardSquare>> board;
  late List<Point<int>> bombs;
  late List<GamePiece> pieces;
  late Timer gameTimer;
  int discoveredBombs = 0;
  int explodedBombs = 0;
  bool isGameOver = false;


  // Animation controllers
  late AnimationController _explosionController;
  late AnimationController _gameOverController;
  Point<int>? lastExplodedPosition;


  @override
  void initState() {
    super.initState();

    _explosionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _gameOverController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    initializeGame();
  }


  @override
  void dispose() {
    _explosionController.dispose();
    _gameOverController.dispose();
    gameTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reversed Minesweeper'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              GameStats(
                discoveredBombs: discoveredBombs,
                explodedBombs: explodedBombs,
              ),
              Expanded(
                child: isGameOver
                    ? GameOverAnimation(
                  animation: _gameOverController,
                  discoveredBombs: discoveredBombs,
                )
                    : GameGrid(
                  board: board,
                  pieces: pieces,
                  onPiecePlaced: tryPlacePiece,
                  lastExplodedPosition: lastExplodedPosition,
                  explosionAnimation: _explosionController,
                ),
              ),
            ],
          ),
          if (lastExplodedPosition != null)
            ExplosionEffect(
              position: lastExplodedPosition!,
              animation: _explosionController,
              boardSize: boardSize,
            ),
        ],
      ),
    );
  }

  /// class methods ------------------------------------------------------------
  ///
  void playExplosionAnimation(Point<int> position) {
    setState(() {
      lastExplodedPosition = position;
    });
    _explosionController.forward(from: 0.0).then((_) {
      setState(() {
        lastExplodedPosition = null;
      });
    });
  }
  /// Initializes the game state, including placing bombs and pieces.
  void initializeGame() {
    // Initialize the board with empty squares
    board = List.generate(
      boardSize,
          (i) => List.generate(
        boardSize,
            (j) => BoardSquare(
          position: Point(i, j),
          hasPiece: false,
          hasBomb: false,
        ),
      ),
    );

    // Place bombs randomly on the board
    bombs = [];
    final Random random = Random();
    while (bombs.length < bombCount) {
      final Point<int> position =
      Point(random.nextInt(boardSize), random.nextInt(boardSize));
      if (!bombs.contains(position)) {
        bombs.add(position);
        board[position.x][position.y].hasBomb = true;
      }
    }

    // Place initial movable pieces randomly
    pieces = [];
    while (pieces.length < initialPieces) {
      final Point<int> position =
      Point(random.nextInt(boardSize), random.nextInt(boardSize));
      if (!board[position.x][position.y].hasPiece &&
          !board[position.x][position.y].hasBomb) {
        pieces.add(GamePiece(position: position));
        board[position.x][position.y].hasPiece = true;
      }
    }

    // Start the game timer to randomly explode bombs
    gameTimer = Timer.periodic(
      const Duration(seconds: 10),
          (timer) => explodeRandomBomb(),
    );
  }

  /// Explodes a random bomb from the list of active bombs.
  void explodeRandomBomb() {
    if (bombs.isEmpty) {
      endGame();
      return;
    }

    setState(() {
      final Random random = Random();
      final int bombIndex = random.nextInt(bombs.length);
      bombs.removeAt(bombIndex);
      explodedBombs++;

      if (bombs.isEmpty) {
        endGame();
      }
    });
  }

  /// Ends the game by canceling the timer and setting the game-over state.
  void endGame() {
    gameTimer.cancel();
    setState(() {
      isGameOver = true;
      _gameOverController.forward(from: 0.0);
    });
  }

  /// Attempts to place a piece on the board at a new position.
  bool tryPlacePiece(GamePiece piece, Point<int> newPosition) {
    if (newPosition.x < 0 ||
        newPosition.x >= boardSize ||
        newPosition.y < 0 ||
        newPosition.y >= boardSize) {
      return false;
    }

    final targetSquare = board[newPosition.x][newPosition.y];
    if (targetSquare.hasPiece) {
      return false;
    }

    setState(() {
      board[piece.position.x][piece.position.y].hasPiece = false;
      piece.position = newPosition;
      targetSquare.hasPiece = true;

      if (targetSquare.hasBomb) {
        discoveredBombs++;
        bombs.remove(newPosition);
        targetSquare.hasBomb = false;
        playExplosionAnimation(newPosition);

        if (bombs.isEmpty) {
          endGame();
        }
      }
    });

    return true;
  }

}

/// A widget to display the game statistics such as discovered and exploded bombs.
class GameStats extends StatelessWidget {
  final int discoveredBombs;
  final int explodedBombs;

  const GameStats({
    super.key,
    required this.discoveredBombs,
    required this.explodedBombs,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text('Discovered Bombs: $discoveredBombs'),
          Text('Exploded Bombs: $explodedBombs'),
        ],
      ),
    );
  }
}

/// A widget representing the game grid with draggable and droppable pieces.
class GameGrid extends StatelessWidget {
  final List<List<BoardSquare>> board;
  final List<GamePiece> pieces;
  final bool Function(GamePiece piece, Point<int> newPosition) onPiecePlaced;
  final Point<int>? lastExplodedPosition;
  final Animation<double> explosionAnimation;

  const GameGrid({
    super.key,
    required this.board,
    required this.pieces,
    required this.onPiecePlaced,
    required this.lastExplodedPosition,
    required this.explosionAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 10,
        childAspectRatio: 1.0,
        crossAxisSpacing: 2.0,
        mainAxisSpacing: 2.0,
      ),
      itemCount: 100,
      itemBuilder: (context, index) {
        final x = index ~/ 10;
        final y = index % 10;

        return DragTarget<GamePiece>(
          builder: (context, candidates, rejects) {
            return Container(
              decoration: BoxDecoration(
                border: Border.all(),
                color: candidates.isNotEmpty ? Colors.grey[300] : Colors.white,
              ),
              child: board[x][y].hasPiece
                  ? Draggable<GamePiece>(
                data: pieces.firstWhere(
                      (p) => p.position.x == x && p.position.y == y,
                ),
                feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                childWhenDragging: Container(),
                child: const GamePieceWidget(),
              )
                  : null,
            );
          },
          onWillAcceptWithDetails: (_) => !board[x][y].hasPiece,
          onAcceptWithDetails: (piece) {
            onPiecePlaced(piece.data, Point(x, y));
          },
        );
      },
    );
  }
}


/// A widget to display a "Game Over" message and the total discovered bombs.
class GameOverWidget extends StatelessWidget {
  final int discoveredBombs;

  const GameOverWidget({
    super.key,
    required this.discoveredBombs,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Game Over!',
            style: TextStyle(fontSize: 24),
          ),
          Text(
            'Total Discovered Bombs: $discoveredBombs',
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

/// A data class representing a square on the board.
class BoardSquare {
  Point<int> position;
  bool hasPiece;
  bool hasBomb;

  BoardSquare({
    required this.position,
    required this.hasPiece,
    required this.hasBomb,
  });
}

/// A data class representing a movable game piece.
class GamePiece {
  Point<int> position;

  GamePiece({required this.position});
}

/// A widget to represent a game piece visually.
class GamePieceWidget extends StatelessWidget {
  const GamePieceWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
    );
  }
}


class ExplosionEffect extends StatelessWidget {
  final Point<int> position;
  final Animation<double> animation;
  final int boardSize;

  const ExplosionEffect({
    super.key,
    required this.position,
    required this.animation,
    required this.boardSize,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final size = MediaQuery.of(context).size;
        final cellSize = (size.width - 32) / boardSize;
        final x = position.x * cellSize + 16;
        final y = position.y * cellSize + 80; // Adjusted for AppBar and stats

        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: 1.0 - animation.value,
            child: Transform.scale(
              scale: 1.0 + animation.value * 2,
              child: Container(
                width: cellSize,
                height: cellSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.yellow.withOpacity(0.8),
                      Colors.orange.withOpacity(0.6),
                      Colors.red.withOpacity(0.4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


class GameOverAnimation extends StatelessWidget {
  final Animation<double> animation;
  final int discoveredBombs;

  const GameOverAnimation({
    super.key,
    required this.animation,
    required this.discoveredBombs,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.5 + animation.value * 0.5,
          child: Opacity(
            opacity: animation.value,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Game Over!',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TweenAnimationBuilder<int>(
                    duration: const Duration(seconds: 2),
                    tween: IntTween(begin: 0, end: discoveredBombs),
                    builder: (context, value, child) {
                      return Text(
                        'Discovered Bombs: $value',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}