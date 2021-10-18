import 'package:flutter/foundation.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame/geometry.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart' hide Image, Draggable;

void main() {
  final myGame = MyGame();
  runApp(
    GameWidget(game: myGame)
  );
}

class Board extends SpriteComponent with HasGameRef<MyGame>{

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
        Rect.fromLTRB(0, 0, gameRef.canvasSize.x, gameRef.canvasSize.y),
        bg);
    paint.color = Colors.black.withOpacity(.5);
    super.render(canvas);
  }
}

class ChessPiece extends SpriteComponent with Draggable, HasGameRef<MyGame> {
  String source;
  Vector2 latestDragLocation = Vector2(0,0);
  Vector2 relativeDragStartPosition = Vector2(0,0);

  ChessPiece(String source) :
    this.source = source,
    super();

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load(source + ".png");
  }

  Vector2 toScreen(Vector2 offscreen) {
    Vector2 transformed = gameRef.canvasSize / 8;
    transformed.multiply(offscreen + Vector2(0.06, .1));
    return transformed;
  }

  Vector2 fromScreen(Vector2 onscreen) {
    onscreen.divide(gameRef.canvasSize / 8);
    return onscreen - Vector2(0.06, .1);
  }

  @override
  void update(double dt) {
    super.update(dt);
    size = gameRef.canvasSize / 8 * .9;
    position = toScreen(gameRef.getPosition(this));
  }

  @override
  bool onDragStart(int id, DragStartInfo info) {
    relativeDragStartPosition = info.eventPosition.game - toScreen(gameRef.getPosition(this));
    return false;
  }

  @override
  bool onDragUpdate(int id, DragUpdateInfo info) {
    latestDragLocation = info.eventPosition.game;
    return false;
  }

  @override
  bool onDragEnd(int id, DragEndInfo info) {
    gameRef.move(
        this,
        fromScreen(latestDragLocation - relativeDragStartPosition));
    return false;
  }
}

class MyGame extends FlameGame with HasDraggableComponents {
  var pieceMap = Map();

  @override
  void update(double dt) {
    super.update(dt);
  }

  addPiece(String src, int x, int y) {
    ChessPiece piece = ChessPiece(src);
    pieceMap[piece] = Vector2(x as double, y as double);
  }

  @override
  Future<void>? onLoad() async {
    super.onLoad();
    var board = Board();
    for(int i = 0; i < 8; i++) {
      addPiece("pawn", i, 1);
    }
    addPiece("rook", 0, 0);
      addPiece("rook", 7, 0);
      addPiece("knight", 1, 0);
      addPiece("knight", 6, 0);
      addPiece("bishop", 2, 0);
      addPiece("bishop", 5, 0);
      addPiece("queen", 3, 0);
      addPiece("king", 4, 0);

      pieceMap.keys.forEach((element) {
        add(element);
        changePriority(element, 1);
      });

      add(board);
      changePriority(board, 0);
  }

  void move(ChessPiece piece, Vector2 updated) {
    updated.round();
    pieceMap[piece] = updated;
  }

  Vector2 getPosition(ChessPiece piece) {
    return pieceMap[piece];
  }
}
