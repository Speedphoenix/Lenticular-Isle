import hxd.Key as K;
import h2d.col.Point;
using Extensions;
using Const;
using Main;

class SceneObject extends h2d.Object implements h2d.domkit.Object {
	public function new(?parent) {
		super(parent);
		initComponent();
	}
}

@:uiComp("board-ui")
class BoardUi extends h2d.Flow implements h2d.domkit.Object {
    static var SRC = <board-ui
		content-halign={h2d.Flow.FlowAlign.Middle}
		content-valign={h2d.Flow.FlowAlign.Top}
		spacing={{x: 10, y: 0}}
        offset-x={50}
        offset-y={50}
	>
		<flow class="left-cont"
			margin-top={topMargin}
			fill-height={true}
			layout={h2d.Flow.FlowLayout.Vertical}
			valign={h2d.Flow.FlowAlign.Top}
			spacing={{x: 0, y: pad}}
			height={Math.ceil(Const.BOARD_FULL_HEIGHT)}
		>
		</flow>
		<flow class="center-cont" id public
			width={Const.BOARD_FULL_WIDTH}
			height={Math.ceil(Const.BOARD_FULL_HEIGHT)}
		>
			<flow class="board-cont" id public
				position="absolute"
			/>
		</flow>
	</board-ui>
	public static var panelBG = null;

    public function new(?parent) {
		panelBG = {
			tile : hxd.Res.panel_bg.toTile(),
			borderL : 4,
			borderT : 4,
			borderR : 4,
			borderB : 4,
		};
		super(parent);

		var topMargin = 50;
		var pad = 20;

		initComponent();
	}
}

class Board {
	public static var inst: Board;

    public var fullUi : BoardUi;

	public var gridCont : SceneObject;
	var gridGraphics : h2d.Graphics;
    var boardObj : SceneObject;
    var boardRoot : h2d.Flow;

	public function new() {}

    public function init(root: h2d.Object) {
		inst = this;

        fullUi = new BoardUi(root);

        boardRoot = new h2d.Flow(fullUi.boardCont);
        boardRoot.backgroundTile = h2d.Tile.fromColor(0xFFFFFF);
        boardRoot.fillWidth = true;
        boardRoot.fillHeight = true;
		gridCont = new SceneObject(boardRoot);

		gridGraphics = new h2d.Graphics(gridCont);
		drawGrid(gridGraphics);

        drawShape(2, 4, Data.shape.get(Rectangle12), gridGraphics);
        drawShape(4, 4, Data.shape.get(Hexagone12), gridGraphics);
        drawShape(7, 4, Data.shape.get(Star24), gridGraphics);
        drawShape(12, 4, Data.shape.get(Hexagone36), gridGraphics);

		boardObj = new SceneObject(gridCont);
		boardObj.dom.addClass("board");
	}

    inline function addOffsets(a: {x: Int, y: Int}, b: {x: Int, y: Int}) {
        return {x: a.x + b?.x, y: a.y + b?.y};
    }

    function drawShape(x: Int, y: Int, shape: Data.Shape, g: h2d.Graphics) {
        var arr: Array<{id : Data.Shape_trianglesKind, triIndex: Int, offset: {x: Int, y: Int}}> = [];

        var start = shape.triangles[0];
        arr.push({id: start.id, triIndex: shape.firstTriangle, offset: {x: x, y: y}});

        g.lineStyle(3, 0x00AACC);

        for (i in 1...shape.triangles.length) {
            var t = shape.triangles[i];
            var touch = arr.find(e -> e.id == t.edge1Id || e.id == t.edge2Id || e.id == t.edge3Id);
            if (touch == null)
                throw 'Missing previous touching triangle on ${t.id} (wrong triangle order?)';
            var prevTriangle = Const.BASE_TRIANGLES[touch.triIndex];
            var sharedPrev = if (touch.id == t.edge1Id) prevTriangle[0];
                        else if (touch.id == t.edge2Id) prevTriangle[1];
                        else prevTriangle[2];
            var newTriangleIdx = Const.BASE_TRIANGLES.findIndex(e -> e != prevTriangle && e.any(edge -> edge.v == sharedPrev.v));
            var newTriangle = Const.BASE_TRIANGLES[newTriangleIdx];
            var sharedNew = if (touch.id == t.edge1Id) newTriangle[0];
                        else if (touch.id == t.edge2Id) newTriangle[1];
                        else newTriangle[2];
            var touchOffset = addOffsets(touch.offset, sharedPrev.off);
            if (sharedNew.off != null) {
                touchOffset.x -= sharedNew.off.x;
                touchOffset.y -= sharedNew.off.y;
            }

            arr.push({id: t.id, triIndex: newTriangleIdx, offset: touchOffset});
        }

        for (t in arr) {
            var inf = shape.triangles.find(e -> e.id == t.id);
            var tri = Const.BASE_TRIANGLES[t.triIndex];
            for (i in 0...3) {
                var needed = switch (i) {
                    case 0: inf.edge1Id == null;
                    case 1: inf.edge2Id == null;
                    case 2: inf.edge3Id == null;
                    default: true;
                }
                if (needed) {
                    var offset = t.offset;
                    if (tri[i].off != null) {
                        offset = addOffsets(offset, tri[i].off);
                    }
                    var edge = Const.BASE_EDGES[tri[i].v];
                    var a = Const.BASE_VERTICES[edge[0].v].clone();
                    a.x += edge[0].off.x + offset.x;
                    a.y += edge[0].off.y + offset.y;
                    var b = Const.BASE_VERTICES[edge[1].v].clone();
                    b.x += edge[1].off.x + offset.x;
                    b.y += edge[1].off.y + offset.y;
                    drawEdgeRaw(a, b, g);
                }
            }
        }
        g.lineStyle();
    }

	function drawGrid(g: h2d.Graphics) {
		g.clear();

		g.lineStyle(2, 0x222222);
		// g.moveTo(0, Const.BOARD_TOP_EXTRA * Const.SIDE);
		g.lineTo(0, Const.BOARD_FULL_HEIGHT);
		g.lineTo(Const.BOARD_FULL_WIDTH, Const.BOARD_FULL_HEIGHT);
		g.lineTo(Const.BOARD_FULL_WIDTH, 0);
		g.lineTo(0, 0);

		g.lineStyle(1, 0x222222);
        for (j in 0...Const.BOARD_HEIGHT) {
            for (i in 0...Const.BOARD_WIDTH) {
                var num = j * Const.BOARD_WIDTH + i;
                var offset = {x: i * 2 + (j & 1), y: j};
                drawLargeTriangle(offset.x, offset.y, g);
                drawLargeTriangleRev(offset.x, offset.y, g);

            }
        }
        #if debug
        for (j in 0...Const.BOARD_HEIGHT) {
            for (i in 0...Const.BOARD_WIDTH) {
                var num = j * Const.BOARD_WIDTH + i;
                var offset = {x: i * 2 + (j & 1), y: j};
                if (num < Const.BASE_TRIANGLES.length) {
                    var col = num % 2 == 0 ? 0xffff00 : 0xf3b8b8;
                    g.lineStyle(1, col);

                    var tri = Const.BASE_TRIANGLES[num];
                    var text = new h2d.Text(Main.font, gridCont);
                    text.text = "" + num;
                    text.x = offset.x * Const.HEX_SIDE + 15;
                    text.y = offset.y * Const.HEX_HEIGHT;
                    text.textColor = col;
                    for (i in 0...3) {
                        var offset2 = offset;
                        if (tri[i].off != null) {
                            offset2 = addOffsets(offset2, tri[i].off);
                        }
                        var edge = Const.BASE_EDGES[tri[i].v];
                        var a = Const.BASE_VERTICES[edge[0].v].clone();
                        a.x += edge[0].off.x + offset2.x;
                        a.y += edge[0].off.y + offset2.y;
                        var b = Const.BASE_VERTICES[edge[1].v].clone();
                        b.x += edge[1].off.x + offset2.x;
                        b.y += edge[1].off.y + offset2.y;
                        drawEdgeRaw(a, b, g);
                    }
                }
            }
        }
        #end
		g.lineStyle();
	}
    function drawLargeTriangle(i, j, g: h2d.Graphics) {
        var a = new Point(i, j);
        var b = new Point(i + 2, j);
        var c = new Point(i + 1, j + 1);
        drawLargeTriangleRaw(a, b, c, g);
    }
    function drawLargeTriangleRev(i, j, g: h2d.Graphics) {
        var a = new Point(i, j);
        var b = new Point(i + 1, j + 1);
        var c = new Point(i - 1, j + 1);
        drawLargeTriangleRaw(a, b, c, g);
    }

    inline function drawTriangleRaw(a: Point, b: Point, c: Point, g: h2d.Graphics) {
        drawEdgeRaw(a, b, g);
        drawEdgeRaw(b, c, g);
        drawEdgeRaw(c, a, g);
    }
    inline function drawEdgeRaw(a: Point, b: Point, g: h2d.Graphics) {
        g.moveTo(a.x * Const.HEX_SIDE, a.y * Const.HEX_HEIGHT);
        g.lineTo(b.x * Const.HEX_SIDE, b.y * Const.HEX_HEIGHT);
    }

    inline function drawLargeTriangleRaw(a: Point, b: Point, c: Point, g: h2d.Graphics) {
        drawTriangleRaw(a, b, c, g);

        g.lineStyle(1, 0xCC0000);

        var i = a.add(b).multiply(0.5);
        g.moveTo(i.x * Const.HEX_SIDE, i.y * Const.HEX_HEIGHT);
        g.lineTo(c.x * Const.HEX_SIDE, c.y * Const.HEX_HEIGHT);

        i = b.add(c).multiply(0.5);
        g.moveTo(i.x * Const.HEX_SIDE, i.y * Const.HEX_HEIGHT);
        g.lineTo(a.x * Const.HEX_SIDE, a.y * Const.HEX_HEIGHT);

        i = c.add(a).multiply(0.5);
        g.moveTo(i.x * Const.HEX_SIDE, i.y * Const.HEX_HEIGHT);
        g.lineTo(b.x * Const.HEX_SIDE, b.y * Const.HEX_HEIGHT);

        g.lineStyle(1, 0x222222);
    }
}