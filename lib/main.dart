import 'package:flutter/foundation.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  StreamSubscription<DocumentSnapshot>? query;
  ChessPiece? moving;
  Vector2? movingFrom;
  Vector2? movingTo;
  Vector2? movingLatest;
  double elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (movingTo == null) {
      return;
    }
    elapsed += dt;
    if (elapsed > .5) {
      elapsed = 0;
      double dist = movingTo!.distanceTo(movingLatest!);
      Vector2 newPos;
      if(dist <= .1) {
        newPos = movingTo!;
        movingFrom = null;
        movingTo = null;
        pieceMap[moving!] = newPos;
        moving = null;
        Map<String, dynamic> data = Map();
        data["latest"] = null;
        data["from"] = null;
        data["moving"] = false;
        FirebaseFirestore.instance.collection("data").doc("game").set(data, SetOptions(merge:true));
      } else {
        Vector2 diff = movingTo! - movingLatest!;
        Vector2 change = diff / (dist * 10);
        newPos = movingLatest! + change;
        Map<String, dynamic> data = Map();
        data["latest"] = [newPos.x, newPos.y];
        FirebaseFirestore.instance.collection("data").doc("game").set(data, SetOptions(merge:true));
      }
    }
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
      await Firebase.initializeApp();
      query = FirebaseFirestore.instance
            .collection('data')
            .doc("game")
            .snapshots()
            .listen((snapshot) {
          Map<String, dynamic> data = snapshot.data()!;
          if(data["moving"] == null || data["moving"] == false) {
            return;
          }
          List? receivedLatest = data["latest"];
          if(receivedLatest == null) return;
          movingLatest = Vector2(receivedLatest[0], receivedLatest[1]);
          List receivedFrom = data["from"];
          movingFrom = Vector2(receivedFrom[0], receivedFrom[1]);
        });
  }

  void move(ChessPiece piece, Vector2 updated) {
    updated.round();
    moving = piece;
    movingFrom = pieceMap[piece]; // Operated on when retrieved
    movingTo = updated; // registers intent, not sent to firebase
    movingLatest = movingFrom; // initialized here for state, then updated as read
    elapsed = 0;
    Map<String, dynamic> data = Map();
    data["from"] = [movingFrom!.x, movingFrom!.y];
    data["latest"] = [movingLatest!.x, movingLatest!.y];
    data["moving"] = true;
    FirebaseFirestore.instance.collection("data").doc("game").set(data, SetOptions(merge:true));
  }

  Vector2 getPosition(ChessPiece piece) {
    if (movingFrom != null && movingFrom!.distanceTo(pieceMap[piece]) == 0) {
      return movingLatest!;
    }
    return pieceMap[piece];
  }
}
