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
    public var shapePreview: ShapeEnt = null;
    public var x(default, set): Int;
    public var y(default, set): Int;

    var hoverGraphic: h2d.Graphics;
    var previewGraphic: h2d.Graphics;
    var debGraphic: h2d.Graphics;

    public var isSelected(get, never): Bool;
    function get_isSelected() {
        return Board.inst.currentSelect == this;
    }

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
        previewGraphic = new h2d.Graphics(Board.inst.gridCont);
        debGraphic = new h2d.Graphics(Board.inst.gridCont);
    }

    public function update(dt: Float) {
        var window = hxd.Window.getInstance();
        var mousePos = new Point(window.mouseX, window.mouseY);
        hoverGraphic.clear();
        hoverGraphic.lineStyle(4, 0x1FD346);

        if (shape.contains(mousePos)) {
            shape.draw(hoverGraphic);
            // shape.drawColliders(hoverGraphic);
            if (K.isPressed(K.MOUSE_LEFT)) {
                Board.inst.onSelect(this);
                return;
            }
        }
        hoverGraphic.lineStyle();

        function dontinline(a: Dynamic) {}

        previewGraphic.clear();
        debGraphic.clear();
        if (isSelected) {
            if (shapePreview == null)
                shapePreview = new ShapeEnt(inf.shapes[0].refId, x, y);

            var verts = Const.getVertexOffsets(shape.inf.firstTriangle);
            var center = verts[0].add(verts[1]).add(verts[2]).multiply(1 / 3);
            center.x *= Const.HEX_SIDE;
            center.y *= Const.HEX_HEIGHT;

            var offsetToOffset = center.add(mousePos);
            var mouseOffset = new IPoint(Math.round(offsetToOffset.x / Const.HEX_SIDE), Math.round(offsetToOffset.y / Const.HEX_HEIGHT));
            if ((mouseOffset.x & 1) != (mouseOffset.y & 1)) {
                mouseOffset.x--;
            }
            dontinline(mouseOffset);
            dontinline(center);
            dontinline(offsetToOffset);

            var nearOffsets = [
                new IPoint(mouseOffset.x, mouseOffset.y),
                new IPoint(mouseOffset.x - 2, mouseOffset.y),
                new IPoint(mouseOffset.x + 2, mouseOffset.y),
                new IPoint(mouseOffset.x - 1, mouseOffset.y - 1),
                new IPoint(mouseOffset.x + 1, mouseOffset.y + 1),
                new IPoint(mouseOffset.x + 1, mouseOffset.y - 1),
                new IPoint(mouseOffset.x - 1, mouseOffset.y + 1),

                new IPoint(mouseOffset.x - 4, mouseOffset.y),
                new IPoint(mouseOffset.x - 2, mouseOffset.y - 2),
                new IPoint(mouseOffset.x - 2, mouseOffset.y + 2),
                new IPoint(mouseOffset.x - 4, mouseOffset.y - 2),
                new IPoint(mouseOffset.x - 3, mouseOffset.y - 1),
                new IPoint(mouseOffset.x + 3, mouseOffset.y - 1),
            ];
            var nearest: {shape: Int, offset: IPoint, distSq: Float} = null;
            dontinline(nearest);

            for (i in 0...inf.shapes.length) {
                #if debug
                switch(i) {
                    case 0:
                        debGraphic.lineStyle(2, 0x9A1FD3);
                    case 1:
                        debGraphic.lineStyle(2, 0xD31F1F);
                    case 2:
                        debGraphic.lineStyle(2, 0xD39A1F);
                    default:
                }
                #end
                var verts = Const.getVertexOffsets(inf.shapes[i].ref.firstTriangle);
                var center = verts[0].add(verts[1]).add(verts[2]).multiply(1 / 3);
                for (j in 0...nearOffsets.length) {
                    var o = nearOffsets[j];
                    var c = center.add(o.toPoint());
                    dontinline(c);
                    c.x *= Const.HEX_SIDE;
                    c.y *= Const.HEX_HEIGHT;
                    #if debug
                    debGraphic.drawCircle(c.x, c.y, 5);
                    #end
                    var d = c.distanceSq(mousePos);
                    if (nearest == null || nearest.distSq > d) {
                        nearest = {
                            shape: i,
                            offset: o,
                            distSq: d,
                        };
                    }
                }
            }
            // TODO sometimes the offset picked is wrong (does not take the one that's actually below the mouse)
            // Check with debug, with the small rectangles

            shapePreview.kind = inf.shapes[nearest.shape].refId;
            trace('${shapePreview.kind} (number ${nearest.shape})');
            if (nearest.offset.x != x || nearest.offset.y != y) {
                if (K.isPressed(K.MOUSE_LEFT)) {
                    this.x = nearest.offset.x;
                    this.y = nearest.offset.y;
                    shape.kind = inf.shapes[nearest.shape].refId;
                    Board.inst.onSelect(null);
                } else {
                    shapePreview.x = nearest.offset.x;
                    shapePreview.y = nearest.offset.y;
                    hoverGraphic.lineStyle(2, 0x1FD346);
                    shapePreview.draw(hoverGraphic);
                }
            }
        }
    }
}

class ShapeEnt {
    public var kind(default, set): Data.ShapeKind;
    public var inf: Data.Shape;
    public var x: Int;
    public var y: Int;

    var triangles: Array<{id : Data.Shape_trianglesKind, triIndex: Int, offset: IPoint}> = [];

    var colliders: Array<h2d.col.Polygon> = [];

    function set_kind(k) {
        if (k != kind) {
            inf = Data.shape.get(k);
            initTriangles();
        }
        return this.kind = k;
    }

    public function new(kind: Data.ShapeKind, x: Int, y: Int) {
        this.x = x;
        this.y = y;

        if ((x & 1) != (y & 1))
            throw 'Invalid offset ${x},${y}';
        this.kind = kind;
    }

    public function initTriangles() {
        triangles.clear();
        colliders.clear();
        var start = inf.triangles[0];
        triangles.push({id: start.id, triIndex: inf.firstTriangle, offset: new IPoint(0, 0)});
        colliders.push(Triangle.getCollider(inf.firstTriangle, new IPoint(0, 0)));

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
            var edges = Const.getEdges(t.triIndex);
            for (i in 0...3) {
                var needed = switch (i) {
                    case 0: inf.edge1Id == null;
                    case 1: inf.edge2Id == null;
                    case 2: inf.edge3Id == null;
                    default: true;
                }
                if (needed) {
                    var offset = new Point(this.x + t.offset.x, this.y + t.offset.y);
                    Board.drawEdgeRaw(edges[i].a.add(offset), edges[i].b.add(offset), g);
                }
            }
        }
    }
    public function drawDebug(g: h2d.Graphics) {
        var t = triangles[0];
        var edges = Const.getEdges(t.triIndex);
        for (i in 0...3) {
            var offset = new Point(this.x + t.offset.x, this.y + t.offset.y);
            Board.drawEdgeRaw(edges[i].a.add(offset), edges[i].b.add(offset), g);
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
        var actual = p.clone();
        actual.x -= x * Const.HEX_SIDE;
        actual.y -= y * Const.HEX_HEIGHT;
        return colliders.any(c -> c.contains(actual));
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
        var edges = Const.getEdges(idx);

        for (e in edges) {
            if (Board.inst.currentSelect != null && !Board.inst.currentSelect.inf.selectionEdges.any(e2 -> e2.idx == e.idx))
                continue;

            Board.drawEdgeRaw(e.a.add(offset.toPoint()), e.b.add(offset.toPoint()), g);
        }
    }

    public inline static function getCollider(idx, offset: IPoint) {
        var verts = Const.getVertexOffsets(idx);

        for (v in verts) {
            v.x += offset.x;
            v.y += offset.y;

            v.x *= Const.HEX_SIDE;
            v.y *= Const.HEX_HEIGHT;
        }
        return verts;
    }
}

class Board {
	public static var inst: Board;

    public var fullUi : BoardUi;

	public var gridCont : SceneObject;
	var gridGraphics : h2d.Graphics;
	var entityGraphics : h2d.Graphics;
    var selectGraphic: h2d.Graphics;
    var debugGraphic: h2d.Graphics;
    var boardObj : SceneObject;
    var boardRoot : h2d.Flow;
    var window: hxd.Window;

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
        debugGraphic = new h2d.Graphics(gridCont);
        createGrid();
		drawGrid(gridGraphics);

        entities = [
            new EntityEnt(Wrecktangle, 2, 6),
            new EntityEnt(Hexachad, 9, 3),
            new EntityEnt(Lozecannon, 15, 5),
            new EntityEnt(Slime, 12, 6),
            new EntityEnt(Obstacle_Rectangle6, 0, 2),
            new EntityEnt(Obstacle_Rectangle6, 0, 4),
            new EntityEnt(Obstacle_Rectangle6, 0, 6),
        ];

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
        debugGraphic.clear();
        debugGraphic.lineStyle(1, 0xFF0000);

        entityGraphics.clear();
        entityGraphics.lineStyle(3, 0x00AACC);
        for (e in entities) {
            e.shape.draw(entityGraphics);
            #if debug
            e.shape.drawDebug(debugGraphic);
            #end
        }
        gridGraphics.lineStyle();


        if (K.isPressed(K.ESCAPE) || K.isPressed(K.MOUSE_RIGHT))
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
        drawEdgeRaw(new Point(0, 0), new Point(0, Const.BOARD_HEIGHT), g);
        drawEdgeRaw(new Point(0, Const.BOARD_HEIGHT), new Point(Const.BOARD_WIDTH * 2, Const.BOARD_HEIGHT), g);
        drawEdgeRaw(new Point(Const.BOARD_WIDTH * 2, Const.BOARD_HEIGHT), new Point(Const.BOARD_WIDTH * 2, 0), g);
        drawEdgeRaw(new Point(Const.BOARD_WIDTH * 2, 0), new Point(0, 0), g);

        if (currentSelect != null)
    		g.lineStyle(2, 0x000000);
        else
            g.lineStyle(#if debug 1 #else 0 #end, 0x000000);

        for (t in grid) {
            t.draw(g);
        }
		g.lineStyle();
	}

    public static inline function drawTriangleRaw(a: Point, b: Point, c: Point, g: h2d.Graphics) {
        drawEdgeRaw(a, b, g);
        drawEdgeRaw(b, c, g);
        drawEdgeRaw(c, a, g);
    }
    public static inline function drawEdgeRaw(a: Point, b: Point, g: h2d.Graphics) {
        var a2 = Const.ISO_MATRIX.transform(a);
        var b2 = Const.ISO_MATRIX.transform(b);
        g.moveTo(a2.x, a2.y);
        g.lineTo(b2.x, b2.y);
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