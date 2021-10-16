import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

void main() {
  runApp(MaterialApp(home: Board()));
}

class Board extends StatefulWidget {
  const Board({Key? key}) : super(key: key);
  final String title = "Chess";

  @override
  State<StatefulWidget> createState() {
    return _BoardState();
  }
}

class ChessPiece extends StatefulWidget {
  String source;
  int xpos;
  int ypos;
  ChessPiece(this.source, this.xpos, this.ypos);

  @override
  State<StatefulWidget> createState() {
    return _ChessPieceState();
  }
}

class _ChessPieceState extends State<ChessPiece> {
  String source = "";
  int xpos = 0;
  int ypos = 0;
  bool visible = true;

  @override
  initState() {
    super.initState();
    source = widget.source;
    xpos = widget.xpos;
    ypos = widget.ypos;
  }

  Widget getImage() {
    debugPrint("getting image");
    if (visible) {return FractionallySizedBox(
      child: Image.asset("assets/images/$source.png"),
      heightFactor: 1 / 8 * .9,
      widthFactor: 1 / 8 * .9,
    ); }
    else return SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
        alignment: Alignment((xpos - 5 + .5) / 3.6, (ypos - 5 + .5) / 3.6),
        child: Visibility(child: Draggable(
          child: getImage(),
          childWhenDragging: Image.asset("assets/images/$source.png"),//getImage(),
         feedback: SizedBox.shrink(),//getImage(),//Image.asset("assets/images/$source.png"),
          onDraggableCanceled: (velocity, offset) {
            debugPrint("$visible");
            visible = true;
            debugPrint("size" + context.size.toString());
            debugPrint("$xpos ${offset.dx} ${(context.size as Size).width}");
            debugPrint("$ypos ${offset.dy} ${(context.size as Size).height}");
            int nextx = (offset.dx * 8 / (context.size as Size).width + .8).round();
            int nexty = (offset.dy * 8 / (context.size as Size).height + .8).round();
            debugPrint("next: $nextx $nexty");
            if (nextx >= 1 && nextx <= 8 && nexty >= 1 && nexty <= 8) {
              xpos = nextx;
              ypos = nexty;
            }
            debugPrint("drag canceled!");
            debugPrint(offset.toString());
            setState(() {
              debugPrint("setting state");
            });
          },
          onDragEnd: (details) {
            debugPrint("Drag End!");
          },
          onDragStarted: () {
            debugPrint("$visible");
            debugPrint("drag started!");
            visible = false;
            setState(() {
              debugPrint("setting state");
            });
          },
      ),
        visible: visible),
    );
  }
}

class _BoardState extends State<Board> {
  List<ChessPiece> pieces = [];

  _BoardState() {
    List<ChessPiece> pawns =
        List.generate(8, (index) => ChessPiece("pawn", index + 1, 2));
    pieces = [
      ChessPiece("rook", 1, 1),
      ChessPiece("rook", 8, 1),
      ChessPiece("knight", 2, 1),
      ChessPiece("knight", 7, 1),
      ChessPiece("bishop", 3, 1),
      ChessPiece("bishop", 6, 1),
      ChessPiece("queen", 4, 1),
      ChessPiece("king", 5, 1),
    ];
    pieces.addAll(pawns);
  }

  List<Widget> _createChildren() {
    List<Widget> result =
        List.generate(16, (index) => pieces[index]);
    result.insert(
        0,
        Opacity(
        child: Image.asset(
          "assets/images/board.png",
          fit: BoxFit.fill,
        ),
    opacity: .5,
    ));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children:
          _createChildren(),
    );
  }
}
