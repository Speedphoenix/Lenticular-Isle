import hxd.Key as K;
import h2d.col.Point;
import h2d.col.IPoint;
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
    // spacing={{x: 10, y: 0}}
    // offset-x={50}
    // offset-y={50}
    static var SRC = <board-ui
		content-halign={h2d.Flow.FlowAlign.Middle}
		content-valign={h2d.Flow.FlowAlign.Top}
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

class EntityEnt {
    public var kind(default, set): Data.EntityKind;
    public var inf: Data.Entity;
    public var shape: ShapeEnt;
    public var x(default, set): Int;
    public var y(default, set): Int;

    var hoverGraphic: h2d.Graphics;

    function set_kind(k) {
        inf = Data.entity.get(k);
        return this.kind = k;
    }
    function set_x(v) {
        if (shape != null)
            shape.x = v;
        return this.x = v;
    }
    function set_y(v) {
        if (shape != null)
            shape.y = v;
        return this.y = v;
    }

    public function new(kind: Data.EntityKind, x: Int, y: Int) {
        this.x = x;
        this.y = y;
        this.kind = kind;
        shape = new ShapeEnt(inf.shapes[0].refId, x, y);
        hoverGraphic = new h2d.Graphics(Board.inst.gridCont);
    }

    public function update(dt: Float) {
        var window = hxd.Window.getInstance();
        var mousePos = new Point(window.mouseX, window.mouseY);
        hoverGraphic.clear();
        hoverGraphic.lineStyle(4, 0x1FD346);

        if (shape.contains(mousePos)) {
            shape.draw(hoverGraphic);
            if (K.isPressed(K.MOUSE_LEFT)) {
                Board.inst.onSelect(this);
            }
        }
        hoverGraphic.lineStyle();
    }
}

class ShapeEnt {
    var kind(default, set): Data.ShapeKind;
    var inf: Data.Shape;
    public var x: Int;
    public var y: Int;

    var triangles: Array<{id : Data.Shape_trianglesKind, triIndex: Int, offset: IPoint}> = [];

    var colliders: Array<h2d.col.Polygon> = [];

    function set_kind(k) {
        inf = Data.shape.get(k);
        return this.kind = k;
    }

    public function new(kind: Data.ShapeKind, x: Int, y: Int) {
        this.x = x;
        this.y = y;

        if ((x & 1) != (y & 1))
            throw 'Invalid offset ${x},${y}';
        this.kind = kind;

        var start = inf.triangles[0];
        triangles.push({id: start.id, triIndex: inf.firstTriangle, offset: new IPoint(x, y)});
        colliders.push(Triangle.getCollider(inf.firstTriangle, new IPoint(x, y)));

        for (i in 1...inf.triangles.length) {
            var t = inf.triangles[i];
            var touch = triangles.find(e -> e.id == t.edge1Id || e.id == t.edge2Id || e.id == t.edge3Id);
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
            var touchOffset = touch.offset.clone();
            if (sharedPrev.off != null)
                touchOffset = touchOffset.add(sharedPrev.off);
            if (sharedNew.off != null) {
                touchOffset = touchOffset.sub(sharedNew.off);
            }

            triangles.push({id: t.id, triIndex: newTriangleIdx, offset: touchOffset});
            colliders.push(Triangle.getCollider(newTriangleIdx, touchOffset));
        }
    }

    public function draw(g: h2d.Graphics) {
        for (t in triangles) {
            var inf = inf.triangles.find(e -> e.id == t.id);
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
                        offset = offset.add(tri[i].off);
                    }
                    var edge = Const.BASE_EDGES[tri[i].v];
                    var a = Const.BASE_VERTICES[edge[0].v].clone();
                    a.x += edge[0].off.x + offset.x;
                    a.y += edge[0].off.y + offset.y;
                    var b = Const.BASE_VERTICES[edge[1].v].clone();
                    b.x += edge[1].off.x + offset.x;
                    b.y += edge[1].off.y + offset.y;
                    Board.drawEdgeRaw(a, b, g);
                }
            }
        }
    }
    public function drawColliders(g: h2d.Graphics) {
        for (c in colliders) {
            for (i in 0...c.length) {
                g.moveTo(c[i].x, c[i].y);
                g.lineTo(c[(i+1) % c.length].x, c[(i+1) % c.length].y);
            }
        }
    }

    public function contains(p: Point) {
        return colliders.any(c -> c.contains(p));
    }
}

class Triangle {
    var idx: Int;
    var offset: IPoint;

    public function new(idx, offset: IPoint) {
        this.idx = idx;
        this.offset = offset.clone();
        if ((offset.x & 1) != (offset.y & 1))
            throw 'Invalid offset ${offset.x},${offset.y}';
    }

    public function draw(g: h2d.Graphics) {
        var tri = Const.BASE_TRIANGLES[idx];
        for (i in 0...3) {
            if (Board.inst.currentSelect != null && !Board.inst.currentSelect.inf.selectionEdges.any(e -> e.idx == tri[i].v))
                continue;

            var offset2 = this.offset;
            if (tri[i].off != null) {
                offset2 = offset2.add(tri[i].off);
            }
            var edge = Const.BASE_EDGES[tri[i].v];
            var a = Const.BASE_VERTICES[edge[0].v].clone();
            a.x += edge[0].off.x + offset2.x;
            a.y += edge[0].off.y + offset2.y;
            var b = Const.BASE_VERTICES[edge[1].v].clone();
            b.x += edge[1].off.x + offset2.x;
            b.y += edge[1].off.y + offset2.y;
            Board.drawEdgeRaw(a, b, g);
        }
    }

    public inline static function getCollider(idx, offset: IPoint) {
        var tri = Const.BASE_TRIANGLES[idx];
        var ret = [];
        var firstEdge = Const.BASE_EDGES[tri[0].v];

        var a = Const.BASE_VERTICES[firstEdge[0].v].clone();
        a.x += firstEdge[0].off.x + offset.x;
        a.y += firstEdge[0].off.y + offset.y;
        ret.push(a);
        var b = Const.BASE_VERTICES[firstEdge[1].v].clone();
        b.x += firstEdge[1].off.x + offset.x;
        b.y += firstEdge[1].off.y + offset.y;
        ret.push(b);

        var otherEdge = Const.BASE_EDGES[tri[2].v];
        var vert = otherEdge.find(v -> v.v != firstEdge[0].v && v.v != firstEdge[1].v);

        var c = Const.BASE_VERTICES[vert.v].clone();
        c.x += vert.off.x + offset.x;
        c.y += vert.off.y + offset.y;
        ret.push(c);

        for (p in ret) {
            p.x *= Const.HEX_SIDE;
            p.y *= Const.HEX_HEIGHT;
        }

        return ret;
    }
}

class Board {
	public static var inst: Board;

    public var fullUi : BoardUi;

	public var gridCont : SceneObject;
	var gridGraphics : h2d.Graphics;
	var entityGraphics : h2d.Graphics;
    var selectGraphic: h2d.Graphics;
    var boardObj : SceneObject;
    var boardRoot : h2d.Flow;
    var window: hxd.Window;

    // var shapes: Array<ShapeEnt> = [];
    var entities: Array<EntityEnt> = [];

    public var currentSelect: EntityEnt = null;

    var grid = [];

	public function new() {}

    public function init(root: h2d.Object) {
		inst = this;
        window = hxd.Window.getInstance();
        fullUi = new BoardUi(root);

        boardRoot = new h2d.Flow(fullUi.boardCont);
        boardRoot.backgroundTile = h2d.Tile.fromColor(0xFFFFFF);
        boardRoot.fillWidth = true;
        boardRoot.fillHeight = true;
		gridCont = new SceneObject(boardRoot);

		gridGraphics = new h2d.Graphics(gridCont);
        selectGraphic = new h2d.Graphics(gridCont);
        entityGraphics = new h2d.Graphics(gridCont);
        createGrid();
		drawGrid(gridGraphics);

        entities = [
            new EntityEnt(Wrecktangle, 2, 6),
        ];
        entityGraphics.lineStyle(3, 0x00AACC);
        for (e in entities) {
            e.shape.draw(entityGraphics);
        }
        gridGraphics.lineStyle();

		boardObj = new SceneObject(gridCont);
		boardObj.dom.addClass("board");
	}

    function createGrid() {
        for (j in 0...Const.BOARD_HEIGHT) {
            for (i in 0...Const.BOARD_WIDTH + 1) {
                var offset = new IPoint(i * 2 - (j & 1), j);
                for (idx in 0...Const.BASE_TRIANGLES.length) {
                    if (offset.x >= 0 || !Const.UNDERFLOWING_TRIANGLES.has(idx) || Const.OVERFLOWING_TRIANGLES.has(idx))
                        grid.push(new Triangle(idx, offset));
                }
            }
        }
    }

    var prevSelect = null;
    public function update(dt: Float) {
        var mousePos = new Point(window.mouseX, window.mouseY);
        if (K.isPressed(K.MOUSE_LEFT))
            onSelect(null);

        for (e in entities)
            e.update(dt);

        selectGraphic.clear();
        selectGraphic.lineStyle(4, 0x1FD346);

        if (currentSelect != null) {
            currentSelect.shape.draw(selectGraphic);
        }
        selectGraphic.lineStyle();
        if (prevSelect != currentSelect) {
            drawGrid(gridGraphics);
        }
        prevSelect = currentSelect;
    }

    public function onSelect(e: EntityEnt) {
        currentSelect = e;
    }

	function drawGrid(g: h2d.Graphics) {
		g.clear();

		g.lineStyle(2, 0x222222);
		// g.moveTo(0, Const.BOARD_TOP_EXTRA * Const.SIDE);
		g.lineTo(0, Const.BOARD_FULL_HEIGHT);
		g.lineTo(Const.BOARD_FULL_WIDTH, Const.BOARD_FULL_HEIGHT);
		g.lineTo(Const.BOARD_FULL_WIDTH, 0);
		g.lineTo(0, 0);

        if (currentSelect != null)
    		g.lineStyle(2, 0x000000);
        else
            g.lineStyle(1, 0x000000);

        for (t in grid) {
            t.draw(g);
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

    public inline static function drawTriangleRaw(a: Point, b: Point, c: Point, g: h2d.Graphics) {
        drawEdgeRaw(a, b, g);
        drawEdgeRaw(b, c, g);
        drawEdgeRaw(c, a, g);
    }
    public inline static function drawEdgeRaw(a: Point, b: Point, g: h2d.Graphics) {
        g.moveTo(a.x * Const.HEX_SIDE, a.y * Const.HEX_HEIGHT);
        g.lineTo(b.x * Const.HEX_SIDE, b.y * Const.HEX_HEIGHT);
    }

    public inline static function drawLargeTriangleRaw(a: Point, b: Point, c: Point, g: h2d.Graphics) {
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