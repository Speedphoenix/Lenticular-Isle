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
    public var x(default, set): Int;
    public var y(default, set): Int;

    public var shapeIdx: Int;
    public var shape: ShapeEnt;
    public var shapePreview: ShapeEnt = null;

    public var fabLine: Data.Level_entities = null;

    var hoverGraphic: h2d.Graphics;
    var previewGraphic: h2d.Graphics;
    var debGraphic: h2d.Graphics;
    var rangeGraphic: h2d.Graphics;
    var bitmap: h2d.Bitmap;
    var possibleMovements: Array<{pos: IPoint, shapeIdx: Int}> = [];

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

    function setShapeIdx(v: Int) {
        shapeIdx = v;
        if (shape != null)
            shape.kind = inf.shapes[v].refId;
    }

    public function new(kind: Data.EntityKind, shapeIdx: Int, x: Int, y: Int) {
        this.x = x;
        this.y = y;
        this.kind = kind;
        this.shapeIdx = shapeIdx;
        shape = new ShapeEnt(inf.shapes[shapeIdx].refId, x, y);
        hoverGraphic = new h2d.Graphics(Board.inst.gridCont);
        previewGraphic = new h2d.Graphics(Board.inst.gridCont);
        debGraphic = new h2d.Graphics(Board.inst.gridCont);
        rangeGraphic = new h2d.Graphics(Board.inst.gridCont);
        if (inf.gfx != null) {
            // TODO TOMORROW sort them for depth
            bitmap = new h2d.Bitmap(inf.gfx.toTile(), Board.inst.entitiesCont);
            bitmap.scale(0.5);
            updatePos();
        }
    }

    inline function dontinline(a: Dynamic) {}

    public inline function canBeSelected() {
        #if admin
        return true;
        #else
        return !inf.flags.has(NoSelection);
        #end
    }

    public inline function getColor() {
        #if admin
        return inf.color ?? 0x1FD346;
        #else
        return inf.color ?? -1;
        #end
    }

    public function update(dt: Float) {
        var gridMousePos = Board.inst.getGridMousePos();
        if (getColor() >= 0) {
            hoverGraphic.clear();
            hoverGraphic.lineStyle(5, getColor());

            if (canBeSelected() && shape.contains(gridMousePos)) {
                shape.draw(hoverGraphic);
                // shape.drawColliders(hoverGraphic);
                if (K.isPressed(K.MOUSE_LEFT)) {
                    Board.inst.select(this);
                    return;
                }
            }
            hoverGraphic.lineStyle();
        }


        previewGraphic.clear();
        debGraphic.clear();
        if (isSelected) {
            if (shapePreview == null)
                shapePreview = new ShapeEnt(inf.shapes[0].refId, x, y);

            #if admin
            var nearest = getMouseDest(gridMousePos);
            #else
            var nearest = getPossibleDest(gridMousePos);
            #end

            if (nearest != null) {
                shapePreview.kind = inf.shapes[nearest.shape].refId;
                if (nearest.offset.x != x || nearest.offset.y != y || nearest.shape != shapeIdx) {
                    if (K.isPressed(K.MOUSE_LEFT)) {
                        this.x = nearest.offset.x;
                        this.y = nearest.offset.y;
                        setShapeIdx(nearest.shape);
                        Board.inst.select(null);
                        Board.inst.onMove(this);
                    } else if (getColor() >= 0) {
                        shapePreview.x = nearest.offset.x;
                        shapePreview.y = nearest.offset.y;
                        hoverGraphic.lineStyle(2, getColor());
                        shapePreview.draw(hoverGraphic);
                    }
                }
            }
        }
    }

    function getPossibleDest(gridMousePos: Point) {
        var nearest: {shape: Int, offset: IPoint, distSq: Float} = null;

        for (i in 0...possibleMovements.length) {
            var p = possibleMovements[i];
            var o = p.pos;
            #if debug
            switch(p.shapeIdx) {
                case 0: debGraphic.lineStyle(2, 0x9A1FD3);
                case 1: debGraphic.lineStyle(2, 0xD31F1F);
                case 2: debGraphic.lineStyle(2, 0xD39A1F);
                default:
            }
            #end
            var center = Const.getCenter(inf.shapes[p.shapeIdx].ref.firstTriangle, inf.shapes[p.shapeIdx].ref.firstTriangleCenter);
            var c = center.add(o.toPoint());
            if (c.x < 0 || c.y < 0 || c.x > Const.BOARD_WIDTH * 2 + 1 || c.y > Const.BOARD_HEIGHT)
                continue;
            #if debug
            var debCenter = Const.toIso(c);
            debGraphic.drawCircle(debCenter.x, debCenter.y, 5);
            #end
            var d = c.distanceSq(gridMousePos);
            if (nearest == null || nearest.distSq > d) {
                nearest = {
                    shape: p.shapeIdx,
                    offset: o,
                    distSq: d,
                };
            }
        }
        return nearest;
    }


    function getMouseDest(gridMousePos: Point) {
        var center = Const.getCenter(shape.inf.firstTriangle, shape.inf.firstTriangleCenter);

        var offsetToOffset = center.add(gridMousePos);
        var mouseOffset = new IPoint(Math.round(offsetToOffset.x), Math.round(offsetToOffset.y));
        if ((mouseOffset.x & 1) != (mouseOffset.y & 1)) {
            mouseOffset.x--;
        }

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

        for (i in 0...inf.shapes.length) {
            #if debug
            switch(i) {
                case 0: debGraphic.lineStyle(2, 0x9A1FD3);
                case 1: debGraphic.lineStyle(2, 0xD31F1F);
                case 2: debGraphic.lineStyle(2, 0xD39A1F);
                default:
            }
            #end
            var center = Const.getCenter(inf.shapes[i].ref.firstTriangle, inf.shapes[i].ref.firstTriangleCenter);
            for (j in 0...nearOffsets.length) {
                var o = nearOffsets[j];
                var c = center.add(o.toPoint());
                if (c.x < 0 || c.y < 0 || c.x > Const.BOARD_WIDTH * 2 + 1 || c.y > Const.BOARD_HEIGHT)
                    continue;
                #if debug
                var debCenter = Const.toIso(c);
                debGraphic.drawCircle(debCenter.x, debCenter.y, 5);
                #end
                var d = c.distanceSq(gridMousePos);
                if (nearest == null || nearest.distSq > d) {
                    nearest = {
                        shape: i,
                        offset: o,
                        distSq: d,
                    };
                }
            }
        }
        return nearest;
    }

    public function onSelect() {
        var possible = getPossibleMovements(inf.actionPerTurn);
        possibleMovements = possible.positions;

        if (getColor() >= 0) {
            rangeGraphic.lineStyle(5, getColor(), 0.5);
            for (i in 0...possible.hull.length) {
                Board.drawEdgeRaw(possible.hull[i], possible.hull[(i + 1) % possible.hull.length], rangeGraphic);
            }
        }
    }

    public function onDeselect() {
        rangeGraphic.clear();
    }

    public function draw(g: h2d.Graphics) {
        shape.draw(g);
        updatePos();
    }

    function updatePos() {
        if (bitmap != null) {
            var center = Const.getCenter(shape.inf.firstTriangle, shape.inf.firstTriangleCenter);
            var c2 = Const.toIso(center.add(new Point(x, y)));

            bitmap.x = c2.x + (inf.props.gfxOffsetx ?? 0);
            bitmap.y = c2.y + (inf.props.gfxOffsety ?? 0);
        }
    }

    // TODO TOMORROW take the right shape coming back from fromGrid, and specify it to isposvalid
    public /* inline */ function getPossibleMovements(count: Int) {
        var checked = [];
        var ret = [];

        final baseVerts = shape.vertices;
        var verts = baseVerts.toIPolygon(Const.POLY_SCALE);
        for (i in 0...verts.length) {
            verts[i] = verts[i].add(new IPoint(x, y).multiply(Const.POLY_SCALE));
        }

        var start = Const.toGrid(new IPoint(x, y), inf.gridId);
        checked.push(start);

        var nextAdjacents = Const.getGridAdjacent(new IPoint(x, y), inf.gridId);

        for (i in 0...count) {
            if (nextAdjacents.isEmpty())
                break;
            var currAdjacents = nextAdjacents.copy();
            nextAdjacents.clear();
            for (a in currAdjacents) {
                var curr = start.add(a);
                if (checked.any(p -> p.equals(curr)))
                    continue;
                checked.push(curr);
                var currWorld = Const.fromGrid(curr, inf.gridId);

                if (!isPosValid(currWorld))
                    continue;
                ret.push({
                    pos: currWorld,
                    shapeIdx: 0, // TODO, smarter shapes
                });
                for (i in 0...inf.shapes.length) { // TODO, smarter shapes
                    ret.push({
                        pos: currWorld,
                        shapeIdx: i,
                    });
                }
                var currVerts: h2d.col.Polygon = baseVerts.copy();
                for (i in 0...currVerts.length) {
                    currVerts[i] = currVerts[i].add(currWorld.toPoint());
                }
                verts = verts.union(currVerts.toIPolygon(Const.POLY_SCALE), false)[0];

                for (a2 in Const.getGridAdjacent(curr, inf.gridId)) {
                    var next = a.add(a2);
                    if (!checked.any(p -> p.equals(start.add(next))) && !nextAdjacents.any(p -> p.equals(next)))
                        nextAdjacents.push(next);
                }
            }
        }

        var worldVerts = verts.toPolygon(1 / Const.POLY_SCALE);
        return {
            hull: worldVerts,
            positions: ret,
        };
    }

    // TODO TOMORROW for different shapes. They stay on the same grid though, so should check with floating pos?
    inline function isPosValid(p: IPoint) {
        // var center = Const.getCenter(inf.shapes[i].ref.firstTriangle, inf.shapes[i].ref.firstTriangleCenter);
        var center = Const.getCenter(shape.inf.firstTriangle, shape.inf.firstTriangleCenter);

        var c = center.add(p.toPoint());

        if (c.x < 0 || c.y < 0 || c.x > Const.BOARD_WIDTH * 2 + 1 || c.y > Const.BOARD_HEIGHT)
            return false;
        return true;
    }

    public var removed = false;
    public function onRemove() {
        removed = true;
        hoverGraphic.remove();
        previewGraphic.remove();
        debGraphic.remove();
        rangeGraphic.remove();
        bitmap.remove();
    }
    public function saveData() {
        return {
            ref: kind,
            shapeIdx: shapeIdx,
            offsetx: x,
            offsety: y,
        };
    }
}

class ShapeEnt {
    public var kind(default, set): Data.ShapeKind;
    public var inf: Data.Shape;
    public var x: Int;
    public var y: Int;

    var triangles: Array<{id : Data.Shape_trianglesKind, triIndex: Int, offset: IPoint}> = [];

    var colliders: Array<h2d.col.Polygon> = [];
    public var vertices: h2d.col.Polygon = [];

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
        // colliders.push(Triangle.getCollider(inf.firstTriangle, new IPoint(0, 0)));

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
            // colliders.push(Triangle.getCollider(newTriangleIdx, touchOffset));
        }
        vertices = getVertices();
        colliders.push(vertices);
    }

    public function getVertices() {
        var allEdges: Array<{a: Point, b: Point}> = [];
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
                    var offset = new Point(t.offset.x, t.offset.y);
                    allEdges.push({
                        a: edges[i].a.add(offset),
                        b: edges[i].b.add(offset),
                    });
                }
            }
        }
        var ret = [];
        var e = allEdges.pop();
        ret.push(e.a);
        ret.push(e.b);
        while (!allEdges.isEmpty()) {
            var top = ret.last();
            var e = allEdges.find(e2 -> e2.a.equals(top) || e2.b.equals(top));
            if (e == null) {
                throw "Unclosed shape " + kind.toString();
            }
            if (e.a.equals(top))
                ret.push(e.b);
            else if (e.b.equals(top))
                ret.push(e.a);
            allEdges.remove(e);
        }
        return ret;
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
                Board.drawEdgeRaw(c[i], c[(i + 1) % c.length], g);
            }
        }
    }

    public function contains(p: Point) {
        var actual = p.clone();
        actual.x -= x;
        actual.y -= y;
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
            if (Board.inst.forceSelectionEdges != null) {
                if (!Board.inst.forceSelectionEdges.selectionEdges.any(e2 -> e2.idx == e.idx))
                    continue;
            } else {
                var s = Board.inst.currentSelect;
                if (s != null) {
                    if (s.inf.grid != null && !s.inf.grid.selectionEdges.any(e2 -> e2.idx == e.idx))
                        continue;
                    if (s.inf.flags.has(NoSelection))
                        continue;
                }
            }

            Board.drawEdgeRaw(e.a.add(offset.toPoint()), e.b.add(offset.toPoint()), g);
        }
    }

    public inline static function getCollider(idx, offset: IPoint) {
        var verts = Const.getVertexOffsets(idx);

        for (v in verts) {
            v.x += offset.x;
            v.y += offset.y;
        }
        return verts;
    }
}

class Board {
	public static var inst: Board;

    public var fullUi : BoardUi;

	public var gridCont : SceneObject;
	public var entitiesCont : SceneObject;
	var gridGraphics : h2d.Graphics;
	var entityGraphics : h2d.Graphics;
    var selectGraphic: h2d.Graphics;
    var debugGraphic: h2d.Graphics;
    var boardObj : SceneObject;
    var boardRoot : h2d.Flow;
    var window: hxd.Window;

    var entities: Array<EntityEnt> = [];
    var sideEntities: Array<EntityEnt> = [];

    var level: Data.LevelKind;

    public var currentSelect: EntityEnt = null;

    public var forceSelectionEdges: Data.Grid = null;

    var grid = [];
    var worldGrid: Array<Array<Array<EntityEnt>>> = [];

	public function new() {}

    public function init(root: h2d.Object) {
		inst = this;
        window = hxd.Window.getInstance();
        fullUi = new BoardUi(root);

        boardRoot = new h2d.Flow(fullUi.boardCont);
        boardRoot.backgroundTile = h2d.Tile.fromColor(0xFFFFFF);
        boardRoot.fillWidth = true;
        boardRoot.fillHeight = true;
        boardRoot.layout = Stack;

        var gridPlatform = new h2d.Bitmap(hxd.Res.platform_A.toTile(), boardRoot);
        gridPlatform.setScale(0.5);
        // boardRoot.getProperties(gridPlatform).paddingLeft = -5;
        // boardRoot.getProperties(gridPlatform).paddingTop = 40;

		gridCont = new SceneObject(boardRoot);
        boardRoot.getProperties(gridCont).paddingLeft = 10;
        // boardRoot.getProperties(gridPlatform).paddingTop = 30;

        entitiesCont = new SceneObject(gridCont);

		gridGraphics = new h2d.Graphics(gridCont);
        selectGraphic = new h2d.Graphics(gridCont);
        entityGraphics = new h2d.Graphics(gridCont);
        debugGraphic = new h2d.Graphics(gridCont);
        startLevel(Data.level.all[0].id);

		boardObj = new SceneObject(gridCont);
		boardObj.dom.addClass("board");
	}

    function startLevel(lv: Data.LevelKind) {
        level = lv;
        var inf = Data.level.get(level);

        gridGraphics.clear();
        selectGraphic.clear();
        entityGraphics.clear();
        debugGraphic.clear();

        grid.clear();
        createGrid();
		drawGrid(gridGraphics);

        for (e in entities)
            e.onRemove();
        entities.clear();
        for (e in inf.entities) {
            var ent = new EntityEnt(e.refId, e.shapeIdx, e.offsetx, e.offsety);
            ent.fabLine = e;
            entities.push(ent);
        }

        #if admin
        for (e in sideEntities)
            e.onRemove();
        sideEntities.clear();

        var i = 0;
        for (e in Data.entity.all) {
            sideEntities.push(makeSide(e.id, i));
            i++;
        }
        #end
    }

    function makeSide(k: Data.EntityKind, i) {
        var x = Const.BOARD_WIDTH * 2 + 4;
        var y = i * 2;
        if (i >= 9) {
            x = (i - 9) * 3;
            y = Const.BOARD_HEIGHT + (x & 1);
        }
        return new EntityEnt(k, 0, x, y);
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

    public inline function getGridMousePos() {
        var mousePos = new Point(window.mouseX, window.mouseY);
        return Const.fromIso(mousePos);
    }

    var prevSelect = null;
    public function update(dt: Float) {
        debugGraphic.clear();
        debugGraphic.lineStyle(1, 0xFF0000);

        for (l in worldGrid) {
            if (l != null) {
                for (c in l) {
                    if (c != null)
                        c.clear();
                }
            }
        }

        entityGraphics.clear();
        for (e in entities) {
            if (e.x >= 0 && e.y >= 0) {
                if (worldGrid[e.x] == null)
                    worldGrid[e.x] = [];
                if (worldGrid[e.x][e.y] == null)
                    worldGrid[e.x][e.y] = [];
                worldGrid[e.x][e.y].push(e);
            }
            if (e.getColor() >= 0) {
                entityGraphics.lineStyle(3, e.getColor());
                e.draw(entityGraphics);
            }
            #if debug
            e.shape.drawDebug(debugGraphic);
            #end
        }
        for (e in sideEntities) {
            entityGraphics.lineStyle(3, e.getColor());
            e.draw(entityGraphics);
            #if debug
            e.shape.drawDebug(debugGraphic);
            #end
        }
        gridGraphics.lineStyle();

        var gridChanged = false;
        if (K.isPressed(K.ESCAPE) || K.isPressed(K.MOUSE_RIGHT))
            select(null);
        #if !release
        if (K.isPressed(K.DELETE)) {
            if (currentSelect != null && entities.has(currentSelect)) {
                currentSelect.onRemove();
                entities.remove(currentSelect);
                currentSelect = null;
            }
        }
        if (K.isPressed(K.F6)) {
            if (forceSelectionEdges == null) {
                forceSelectionEdges = Data.grid.all[0];
            } else {
                var i = Data.grid.all.indexOf(forceSelectionEdges);
                if (i == Data.grid.all.length - 1)
                    forceSelectionEdges = null;
                else
                    forceSelectionEdges = Data.grid.all[i + 1];
            }
            gridChanged = true;
        }
        if (K.isPressed(K.F5)) {
            var data = [];
            for (e in entities) {
                data.push(e.saveData()); // TODO DELETE
            }
            trace("--- BEGIN LEVEL ---");
            trace(haxe.Json.stringify(data));
            trace("--- END LEVEL ---");
        }
        #end

        for (e in entities)
            e.update(dt);
        for (e in sideEntities)
            e.update(dt);

        selectGraphic.clear();
        selectGraphic.lineStyle(4, 0x1FD346);

        if (currentSelect != null) {
            currentSelect.shape.draw(selectGraphic);
        }
        selectGraphic.lineStyle();
        if (gridChanged || prevSelect != currentSelect) {
            drawGrid(gridGraphics);
        }
        prevSelect = currentSelect;

        var missingEffects = 0;
        var activeEffects = 0;
        for (l in worldGrid) {
            if (l != null) {
                for (c in l) {
                    if (c != null) {
                        for (e in c) {
                            if (e.inf.flags.has(HasEffect)) {
                                if (c.any(e2 -> e2 != e && e2.shape.kind == e.shape.kind)) {
                                    activeEffects++;
                                    if (e.fabLine != null && e.fabLine.stompGoToId != null) {
                                        startLevel(e.fabLine.stompGoToId);
                                        return;
                                    }
                                } else {
                                    missingEffects++;
                                }
                            }
                        }
                    }
                }
            }
        }
        if (missingEffects == 0 && activeEffects > 0 && level != null) {
            var inf = Data.level.get(level);
            if (inf.allEffectsStompedId != null)
                startLevel(inf.allEffectsStompedId);
        }
    }

    public function select(e: EntityEnt) {
        if (currentSelect != null && !currentSelect.removed)
            currentSelect.onDeselect();
        currentSelect = e;
        if (currentSelect != null)
            currentSelect.onSelect();
    }

    public function onMove(e: EntityEnt) {
        var i = sideEntities.indexOf(e);
        if (i >= 0) {
            sideEntities[i] = makeSide(e.kind, i);
            entities.push(e);
        }
    }

	function drawGrid(g: h2d.Graphics) {
		g.clear();

		g.lineStyle(2, 0x222222);
        drawEdgeRaw(new Point(0, 0), new Point(0, Const.BOARD_HEIGHT), g);
        drawEdgeRaw(new Point(0, Const.BOARD_HEIGHT), new Point(Const.BOARD_WIDTH * 2 + 2, Const.BOARD_HEIGHT), g);
        drawEdgeRaw(new Point(Const.BOARD_WIDTH * 2 + 2, Const.BOARD_HEIGHT), new Point(Const.BOARD_WIDTH * 2 + 2, 0), g);
        drawEdgeRaw(new Point(Const.BOARD_WIDTH * 2 + 2, 0), new Point(0, 0), g);

        if (forceSelectionEdges != null)
    		g.lineStyle(1, 0x000000);
        else if (currentSelect != null)
    		g.lineStyle(2, 0xA5A5A5);
        else
            g.lineStyle(0, 0x000000);

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
        var a2 = Const.toIso(a);
        var b2 = Const.toIso(b);
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