import 'dart:math';
import 'dart:ui';

import 'package:flame/palette.dart';
import 'package:flutter/foundation.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_animation_progress_bar/flutter_animation_progress_bar.dart';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame/geometry.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart' hide Image, Draggable;
import 'package:provider/provider.dart';

class BoardState extends ChangeNotifier {
  int? score = 50;
  bool puzzle = false;
  String fen = "";
  bool reset = false;
  int turn = 0;
  Vector2? movingFrom;
  Vector2? movingTo;
  Vector2? movingLatest;
  StreamSubscription<DocumentSnapshot>? query;
  var boardMap = Map();

  onLoad() async {
    query = FirebaseFirestore.instance
        .collection('data')
        .doc("game")
        .snapshots()
        .listen((snapshot) {
      debugPrint("snapshot");
      Map<String, dynamic> data = snapshot.data()!;
      debugPrint(data.toString());
      score = data["score"];
      turn = data["turn"] ?? 0;
      puzzle = data["puzzle"] ?? false;
      String newFen = data["fen"]!;
      if (fen != newFen) {
        fen = newFen;
        reset = true;
      }
      List? receivedLatest = data["latest"];
      if (receivedLatest != null && receivedLatest.isNotEmpty) {
        movingLatest = Vector2(receivedLatest[0], receivedLatest[1]);
      } else {
        movingLatest = null;
      }
      List receivedTo = data["to"];
      if (receivedTo != null && receivedTo.isNotEmpty) {
        movingTo = Vector2(receivedTo[0], receivedTo[1]);
      } else {
        movingTo = null;
      }
      List receivedFrom = data["from"];
      if (receivedFrom != null && receivedFrom.isNotEmpty) {
        movingFrom = Vector2(receivedFrom[0], receivedFrom[1]);
        if (boardMap[movingFrom] != null) {
          ChessPiece moved = boardMap[movingFrom];
          moved.location = movingTo!;
          boardMap[movingTo] = moved;
        }
      } else {
        movingFrom = null;
      }
    });
  }

  notify() {
    notifyListeners();
  }

  int getScore() {
    return puzzle
        ? 50
        : (100 / (1 + exp(score! * (turn == 0 ? 1 : -1)))).round();
  }
}

void main() async {
  await Firebase.initializeApp();
  BoardState state = BoardState();
  final myGame = MyGame(state);
  runApp(
    MaterialApp(
      title: "chess",
      home: ChangeNotifierProvider<BoardState>(
        create: (context) => state,
        child: Column(
          children: [
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  child: const Text("New Game"),
                  onPressed: () {
                    HttpsCallable callable =
                        FirebaseFunctions.instance.httpsCallable("newGame");
                    callable();
                  },
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  child: const Text("Get Puzzle"),
                  onPressed: () {
                    HttpsCallable callable =
                        FirebaseFunctions.instance.httpsCallable("newPuzzle");
                    callable();
                  },
                ),
              ),
            ]),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: GameWidget(game: myGame)),
                  Consumer<BoardState>(
                    builder: (context, state, child) {
                      return FAProgressBar(
                        direction: Axis.vertical,
                        verticalDirection: VerticalDirection.up,
                        currentValue: state.getScore(),
                      );
                    },
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    ),
  );
}

class Board extends SpriteComponent with HasGameRef<MyGame> {
  Future<void> onLoad() async {
    sprite = await Sprite.load("board.png");
  }

  @override
  void onGameResize(Vector2 gameSize) {
    size = gameSize;
  }

  @override
  update(double t) {
    size = gameRef.canvasSize;
  }

  @override
  void render(Canvas canvas) {
    Paint bg = Paint();
    bg.color = Colors.white;
    canvas.drawRect(
        Rect.fromLTRB(0, 0, gameRef.canvasSize.x, gameRef.canvasSize.y), bg);
    paint.color = Colors.black.withOpacity(.5);
    super.render(canvas);
  }
}

class ChessPiece extends SpriteComponent with Draggable, HasGameRef<MyGame> {
  String source;
  bool black;
  Vector2 location;
  Vector2? latestDragLocation = null;
  Vector2? relativeDragStartPosition = null;

  ChessPiece(String source, bool black, Vector2 location)
      : this.source = source,
        this.black = black,
        this.location = location,
        super() {
    if (!black) {
      paint.colorFilter = ColorFilter.mode(Colors.amberAccent, BlendMode.srcIn);
    }
  }

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load(source + ".png");
  }

  Vector2 toScreen(Vector2 offscreen) {
    offscreen = Vector2(offscreen.x, 9 - offscreen.y);
    Vector2 transformed = gameRef.canvasSize / 8;
    transformed.multiply(offscreen - Vector2(1, 1) + Vector2(0.06, .1));
    return transformed;
  }

  Vector2 fromScreen(Vector2 onscreen) {
    onscreen.divide(gameRef.canvasSize / 8);
    onscreen = onscreen - Vector2(0.06, .1) + Vector2(1, 1);
    onscreen = Vector2(onscreen.x, 9 - onscreen.y);
    return onscreen;
  }

  @override
  void update(double dt) {
    super.update(dt);
    size = gameRef.canvasSize / 8 * .9;
    Vector2? position = gameRef.getPosition(this);
    if (position == null) {
      if (latestDragLocation != null) {
        position = fromScreen(latestDragLocation! - relativeDragStartPosition!);
      } else {
        position = location;
      }
    }
    this.position = toScreen(position);
  }

  @override
  bool onDragStart(int id, DragStartInfo info) {
    if (gameRef.moving != null) {
      return false;
    }
    relativeDragStartPosition =
        info.eventPosition.game - toScreen(location);
    return false;
  }

  @override
  bool onDragUpdate(int id, DragUpdateInfo info) {
    if (relativeDragStartPosition == null) {
      return false;
    }
    latestDragLocation = info.eventPosition.game;
    return false;
  }

  @override
  bool onDragEnd(int id, DragEndInfo info) {
    if (relativeDragStartPosition == null) {
      return false;
    }
    gameRef.move(
        this, fromScreen(latestDragLocation! - relativeDragStartPosition!));
    return false;
  }
}

class MyGame extends FlameGame with HasDraggableComponents {
  Vector2? moving;
  double elapsed = 0;
  BoardState state;

  MyGame(BoardState state)
      : this.state = state,
        super();

  @override
  void update(double dt) {
    super.update(dt);
    if (state.reset) {
      reset();
    }
    if (moving == null || state.movingFrom == null) {
      return;
    }
    elapsed += dt;
    if (elapsed > .5) {
      elapsed = 0;
      double dist = state.movingTo!.distanceTo(state.movingLatest!);
      if (dist <= .1) {
        state.movingFrom = null;
        state.movingTo = null;
        state.movingLatest = null;
        moving = null;
        Map<String, dynamic> data = Map();
        data["latest"] = null;
        data["from"] = null;
        data["to"] = null;
        FirebaseFirestore.instance
            .collection("data")
            .doc("game")
            .set(data, SetOptions(merge: true));
      } else {
        Vector2 diff = state.movingTo! - state.movingLatest!;
        Vector2 change = diff / (dist * 10);
        Vector2 newPos = state.movingLatest! + change;
        Map<String, dynamic> data = Map();
        data["latest"] = [newPos.x, newPos.y];
        FirebaseFirestore.instance
            .collection("data")
            .doc("game")
            .set(data, SetOptions(merge: true));
      }
    }
  }

  addPiece(String src, bool black, int x, int y) {
    Vector2 location = Vector2(x as double, y as double);
    ChessPiece piece = ChessPiece(src, black, location);
    state.boardMap[location] = piece;
    add(piece);
    changePriority(piece, 1);
  }

  reset() {
    state.boardMap.forEach((key, value) {
      remove(value);
    });
    state.boardMap = Map();
    int index = 0;
    for (int row = 8; row > 0; row--) {
      for (int col = 1; col <= 8;) {
        String next = state.fen[index++];
        if (next == "/") {
          continue;
        }
        int skip = int.tryParse(next) ?? 0;
        if (skip > 0) {
          col += skip;
          continue;
        }
        String nextUpper = next.toUpperCase();
        bool black = false;
        if (next != nextUpper) {
          black = true;
        }
        switch (nextUpper) {
          case "R":
            {
              addPiece("rook", black, col, row);
            }
            break;
          case "N":
            {
              addPiece("knight", black, col, row);
            }
            break;
          case "B":
            {
              addPiece("bishop", black, col, row);
            }
            break;
          case "Q":
            {
              addPiece("queen", black, col, row);
            }
            break;
          case "K":
            {
              addPiece("king", black, col, row);
            }
            break;
          case "P":
            {
              addPiece("pawn", black, col, row);
            }
            break;
        }
        col++;
      }
    }
    state.reset = false;
  }

  @override
  Future<void>? onLoad() async {
    super.onLoad();
    var board = Board();
    add(board);
    changePriority(board, 0);
    state.onLoad();
  }

  void move(ChessPiece piece, Vector2 updated) {
    updated.round();
    moving = updated;
    Vector2 movingFrom = piece.location;
    Vector2 movingTo = updated;
    Vector2 movingLatest = movingFrom;
    elapsed = 0;
    Map<String, dynamic> data = Map();
    data["latest"] = [movingLatest.x, movingLatest.y];
    FirebaseFirestore.instance
        .collection("data")
        .doc("game")
        .set(data, SetOptions(merge: true));
    String alphabet = "xabcdefgh";
    String from = "${alphabet[movingFrom.x.toInt()]}${movingFrom.y}";
    String to = "${alphabet[movingTo.x.toInt()]}${movingTo.y}";
    HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable("makeMove");
    debugPrint("makeMove " + from + to);
    callable.call(<String, dynamic>{
      "move": from + to,
    }).catchError((error) {
      debugPrint("move failed");
      moving = null;
    });
  }

  Vector2? getPosition(ChessPiece piece) {
    if (state.movingTo != null && state.movingLatest != null ) {
      if (state.movingTo!.distanceTo(piece.location) == 0) {
        return state.movingLatest!;
      }
    }
    return null;
  }
}
