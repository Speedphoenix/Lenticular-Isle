import hxd.Key as K;
import h2d.col.Point;
import h2d.col.IPoint;
using Extensions;
using Const;
using Main;

typedef MoveInfo = {
    pos: IPoint,
    shapeIdx: Int,
    ?deb: Array<Point>,
    ?dist: Int,
}

typedef EntityData = {
    ref: Data.EntityKind,
    shapeIdx: Int,
    offsetx: Int,
    offsety: Int,
}

class SceneObject extends h2d.Object implements h2d.domkit.Object {
	public function new(?parent) {
		super(parent);
		initComponent();
	}
}

class SceneEntityObject extends SceneObject {
    static var SRC = <scene-entity-object>
        <bitmap id="bitmap" public/>
    </scene-entity-object>

    public var e: EntityEnt;
    public var inf: Data.Entity;
	public function new(?e: EntityEnt, ?inf: Data.Entity, ?parent) {
        this.e = e;
        if (e != null) {
            inf = e.inf;
        }
        this.inf = inf;
		super(parent);
		initComponent();
        setTile(inf.gfx.toTile());
        dom.addClass(inf.id.toString());
        bitmap.scale(0.5);
        setPos(new Point(), 0);
	}
    public function setTile(t: h2d.Tile) {
        if (t == null)
            bitmap.visible = false;
        else
            bitmap.tile = t;
    }

    public function setPos(p: Point, shapeIdx: Int) {
        var s = inf.shapes[shapeIdx].ref;
        var center = Const.getCenter(s.firstTriangle, s.firstTriangleCenter);
        var c2 = Const.toIso(center.add(new Point(p.x, p.y)));

        x = c2.x + (inf.props.gfxOffsetx ?? 0) + (inf.shapes[shapeIdx].props.gfxOffsetx ?? 0);
        y = c2.y + (inf.props.gfxOffsety ?? 0) + (inf.shapes[shapeIdx].props.gfxOffsety ?? 0);
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
            layout={h2d.Flow.FlowLayout.Stack}
		>
			<flow class="board-cont" id public/>
			<flow id="hud" public>
                <button("Next turn [ENTER]") id="nextTurnBtn" public/>
                <flow class="turn-count-cont">
                    <text id="turnCount" public
                        font={Main.font}
                    />
                </flow>
                <button("Attack [A]") id="attackBtn" public/>
                <button("Restart level [R]") id="restartBtn" public/>
                <button("Previous turn [P]") id="revertBtn" public/>
            </flow>
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
    static var nextId = 0;

    public var id = 0;

    public var kind(default, set): Data.EntityKind;
    public var inf: Data.Entity;
    public var x(default, set): Int;
    public var y(default, set): Int;

    public var shapeIdx: Int;
    public var shape(get, never): ShapeEnt;
    function get_shape() {
        return shapes[shapeIdx];
    }
    public var shapes: Array<ShapeEnt> = [];
    public var shapePreview: ShapeEnt = null;

    public var fabLine: Data.Level_entities = null;

    var hoverGraphic: h2d.Graphics;
    var previewGraphic: h2d.Graphics;
    var previewObj: SceneEntityObject;

    var debGraphic: h2d.Graphics;
    var rangeGraphic: h2d.Graphics;
    var rangeGraphic2: h2d.Graphics;
    public var obj: SceneEntityObject;
    var possibleMovements: Array<MoveInfo> = [];

    var turnMovements = 0;
    var turnAttacks = 0;

    var isAttacking(get, never): Bool;

    function get_isAttacking() {
        return isSelected && Board.inst.isAttacking;
    }

    public var isSelected(get, never): Bool;
    function get_isSelected() {
        return Board.inst.currentSelect == this;
    }

    function set_kind(k) {
        inf = Data.entity.get(k);
        return this.kind = k;
    }
    function set_x(v) {
        for (s in shapes)
            s.x = v;
        return this.x = v;
    }
    function set_y(v) {
        for (s in shapes)
            s.y = v;
        return this.y = v;
    }

    function setShapeIdx(v: Int) {
        shapeIdx = v;
    }

    public function new(kind: Data.EntityKind, shapeIdx: Int, x: Int, y: Int) {
        this.id = nextId;
        nextId++;

        this.x = x;
        this.y = y;
        this.kind = kind;
        this.shapeIdx = shapeIdx;
        for (i in 0...inf.shapes.length) {
            shapes.push(new ShapeEnt(inf.shapes[i].refId, x, y));
        }
        hoverGraphic = new h2d.Graphics(Board.inst.gridCont);
        previewGraphic = new h2d.Graphics(Board.inst.gridCont);
        debGraphic = new h2d.Graphics(Board.inst.gridCont);
        rangeGraphic = new h2d.Graphics(Board.inst.gridCont);
        rangeGraphic2 = new h2d.Graphics(Board.inst.gridCont);
        if (getColor() > 0)
            rangeGraphic2.tile = h2d.Tile.fromColor(getColor());
        if (inf.gfx != null) {
            obj = new SceneEntityObject(this, Board.inst.entitiesCont);
            updatePos();
        }
    }

    inline function dontinline(a: Dynamic) {}

    public inline function canAttack() {
        return inf.attackGrid != null;
    }
    public inline function canBeSelected() {
        if (Board.inst.currentSelect != null)
            return false;
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
            if (previewObj == null) {
                previewObj = new SceneEntityObject(this, Board.inst.entitiesCont);
                previewObj.bitmap.alpha = 0.5;
            }


            #if admin
            var nearest = getMouseDest(gridMousePos);
            #else
            var nearest = getPossibleDest(gridMousePos);
            #end

            if (nearest != null && nearest.distMouseSq <= 4) {
                if (isAttacking) {
                    switch (this.kind) {
                        case Hexachad:
                            previewObj.inf = Data.entity.get(Obstacle_Hexa_Hammer);
                            previewObj.setPos(nearest.info.pos.toPoint(), nearest.info.shapeIdx);
                            previewObj.visible = true;
                            previewObj.setTile(previewObj.inf.gfx.toTile());
                        default:
                            previewObj.visible = false;
                    }
                } else {
                    previewObj.inf = inf;
                    previewObj.setPos(nearest.info.pos.toPoint(), nearest.info.shapeIdx);
                    previewObj.visible = true;
                    previewObj.setTile(inf.gfx.toTile());
                }
                shapePreview.kind = inf.shapes[nearest.info.shapeIdx].refId;

                if (nearest.info.pos.x != x || nearest.info.pos.y != y || nearest.info.shapeIdx != shapeIdx) {
                    if (K.isPressed(K.MOUSE_LEFT)) {
                        if (isAttacking) {
                            attackTo(nearest.info);
                        } else {
                            moveTo(nearest.info);
                        }
                        Board.inst.select(null);
                    } else if (getColor() >= 0) {
                        shapePreview.x = nearest.info.pos.x;
                        shapePreview.y = nearest.info.pos.y;
                        hoverGraphic.lineStyle(2, getColor());
                        shapePreview.draw(hoverGraphic);
                    }
                }
            }
        }
    }

    public function moveTo(info: MoveInfo) {
        this.x = info.pos.x;
        this.y = info.pos.y;
        setShapeIdx(info.shapeIdx);
        if (info.dist != null) {
            turnMovements += info.dist;
        }
        Board.inst.onMove(this);
    }
    // TODO fxs
    public function attackTo(info: MoveInfo) {
        switch (kind) {
            case Wrecktangle:
                var toKill = getAttackColliding(info);
                for (e in toKill) {
                    trace('entity $kind ($id) kills ${e.kind} (${e.id})');
                    Board.inst.deleteEntity(e);
                }
                Board.inst.onMove();
            case Hexachad:

                var spawned = new EntityEnt(Obstacle_Hexa_Hammer, info.shapeIdx, info.pos.x, info.pos.y);
                Board.inst.entities.push(spawned);
                var toKill = getAttackColliding(info);
                for (e in toKill) {
                    trace('entity $kind ($id) kills ${e.kind} (${e.id})');
                    Board.inst.deleteEntity(e);
                }
                Board.inst.onMove();
            case Lozecannon: // TODO
            case Slime, Slime2, Slime3:
                var toKill = getAttackColliding(info);
                for (e in toKill) {
                    trace('entity $kind ($id) kills ${e.kind} (${e.id})');
                    Board.inst.deleteEntity(e);
                }
                moveTo(info);
            case Cyclope: // TODO
            default:
        }
    }

    function getPossibleDest(gridMousePos: Point) {
        var nearest: {info: MoveInfo, distMouseSq: Float} = null;

        for (i in 0...possibleMovements.length) {
            var p = possibleMovements[i];
            #if debug
            switch(p.shapeIdx) {
                case 0: debGraphic.lineStyle(2, 0x9A1FD3);
                case 1: debGraphic.lineStyle(2, 0xD31F1F);
                case 2: debGraphic.lineStyle(2, 0xD39A1F);
                default:
            }
            #end
            var center = Const.getCenter(inf.shapes[p.shapeIdx].ref.firstTriangle, inf.shapes[p.shapeIdx].ref.firstTriangleCenter);
            var c = center.add(p.pos.toPoint());
            if (c.x < 0 || c.y < 0 || c.x > Const.BOARD_WIDTH * 2 + 1 || c.y > Const.BOARD_HEIGHT)
                continue;
            #if debug
            var debCenter = Const.toIso(c);
            debGraphic.drawCircle(debCenter.x, debCenter.y, 5);
            #end
            var d = c.distanceSq(gridMousePos);
            if (nearest == null || nearest.distMouseSq > d) {
                nearest = {
                    info: p,
                    distMouseSq: d,
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
        var nearest: {info: MoveInfo, distMouseSq: Float} = null;

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
                if (nearest == null || nearest.distMouseSq > d) {
                    nearest = {
                        info: {
                            pos: o,
                            shapeIdx: i,
                            dist: 0,
                        },
                        distMouseSq: d,
                    };
                }
            }
        }
        return nearest;
    }

    public function onSelect() {
        var possible = getPossibleMovements(isAttacking ? getRemainingAttacks() : getRemainingMove(), isAttacking);
        possibleMovements = possible.positions;

        if (getColor() >= 0) {
            rangeGraphic.clear();
            rangeGraphic.lineStyle(5, getColor(), 0.5);
            for (i in 0...possible.hull.length) {
                Board.drawEdgeRaw(possible.hull[i], possible.hull[(i + 1) % possible.hull.length], rangeGraphic);
            }

            // TODO TOREMOVE
            // This is meant as debug info, but possible.hull is a bit broken
            rangeGraphic.lineStyle(1, 0xff0000);
            for (i in possible.positions) {
                for (j in 0...i.deb.length) {
                    Board.drawEdgeRaw(i.deb[j], i.deb[(j + 1) % i.deb.length], rangeGraphic);
                }
            }

            rangeGraphic2.clear();
            rangeGraphic2.beginFill(getColor(), 0.2);
            for (i in 0...possible.hull.length) {
                var p = Const.toIso(possible.hull[i]);
                rangeGraphic2.addVertex(p.x, p.y, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5);
            }
            var p = Const.toIso(possible.hull[0]);
            rangeGraphic2.addVertex(p.x, p.y, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5);
        }
    }

    public function onDeselect() {
        rangeGraphic.clear();
        rangeGraphic2.clear();
        if (previewObj != null)
            previewObj.visible = false;
    }

    public function draw(g: h2d.Graphics) {
        #if debug
        shape.draw(g);
        #else
        if (obj == null)
            shape.draw(g);
        #end
        updatePos();
    }

    function updatePos() {
        if (obj != null) {
            obj.setPos(new Point(x, y), shapeIdx);
        }
    }

    public function getRemainingAttacks() {
        return inf.attackPerTurn - turnAttacks;
    }
    public function getRemainingMove() {
        return inf.movePerTurn - turnMovements;
    }

    public function nextTurn() {
        if (inf.flags.has(AutoAction)) {
            if (getRemainingMove() > 0 && inf.grid != null) {
                var possible = getPossibleMovements(getRemainingMove());
                possibleMovements = possible.positions;
                var choice = possibleMovements.pickRandom();
                moveTo(choice);
            } else if (getRemainingAttacks() > 0 && inf.attackGrid != null) {
                var possible = getPossibleMovements(getRemainingAttacks(), true);
                var possibleAttacks = possible.positions;
                var choice = possibleAttacks.pickRandom();
                if (choice != null)
                    attackTo(choice);
            }
        }
        turnMovements = 0;
        turnAttacks = 0;
    }

    public inline function getGridPos() {
        var p = Const.toGrid(new IPoint(x, y), inf.grid);
        p.x += inf.shapes[shapeIdx].gridx;
        p.y += inf.shapes[shapeIdx].gridy;
        return p;
    }
    public inline function fromGridPos(p: IPoint): MoveInfo {
        var gridOff = Const.getGridOffset(p, inf.grid);
        var newP = Const.fromGrid(p, inf.grid);
        var s = inf.shapes.findIndex(s -> s.gridx == gridOff.x && s.gridy == gridOff.y);
        if (s < 0)
            throw 'Missing shape with grid offset ${gridOff} on entity $kind';
        return {
            pos: newP,
            shapeIdx: s,
        };
    }

    public /* inline */ function getPossibleMovements(count: Int, isAttack = false) {
        var checked = [];
        var ret: Array<MoveInfo> = [];

        var grid = isAttack ? inf.attackGrid : inf.grid;

        var start = getGridPos();
        checked.push(start);

        var worldFloatStart = Const.fromGridFloat(start, grid);

        final baseVerts = shape.vertices;
        var verts = baseVerts.toIPolygon(Const.POLY_SCALE);
        for (i in 0...verts.length) {
            // verts[i] = verts[i].add(worldFloatStart.toIPoint(Const.POLY_SCALE));
            verts[i] = verts[i].add(new IPoint(x, y).multiply(Const.POLY_SCALE));
        }

        var nextAdjacents = Const.getGridAdjacent(new IPoint(x, y), grid);

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
                var currWorld = fromGridPos(curr);

                if (!isPosValid(currWorld.pos, currWorld.shapeIdx, isAttack))
                    continue;
                var currVerts: h2d.col.Polygon = baseVerts.copy();
                currWorld.deb = currVerts;
                currWorld.dist = i + 1;
                ret.push(currWorld);
                var currWorldFloat = Const.fromGridFloat(curr, grid);
                for (j in 0...currVerts.length) {
                    // currVerts[j] = currVerts[j].add(currWorldFloat);
                    currVerts[j] = currVerts[j].add(currWorld.pos.toPoint());
                }
                var unionRet = verts.union(currVerts.toIPolygon(Const.POLY_SCALE), false);
                if (unionRet.isEmpty()) {
                    trace("null verts", shape.vertices.length, baseVerts.length, verts.length, currVerts.length);
                } else
                    verts = unionRet[0];
                // verts = verts.union(currVerts.toIPolygon(Const.POLY_SCALE), false)[0];

                for (a2 in Const.getGridAdjacent(curr, grid)) {
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

    // TODO TOMORROW grid border and chasm for different shapes.
    // They stay on the same grid though, so should check with floating pos?
    function isPosValid(p: IPoint, sidx: Int, isAttack: Bool) {
        var shape = shapes[sidx];
        var center = Const.getCenter(inf.shapes[sidx].ref.firstTriangle, inf.shapes[sidx].ref.firstTriangleCenter);
        var c = center.add(p.toPoint());

        if (c.x < 0 || c.y < 0 || c.x > Const.BOARD_WIDTH * 2 + 1 || c.y > Const.BOARD_HEIGHT)
            return false;

        if (isAttack) {
            switch (kind) {
                case Wrecktangle:
                    return true;
                default:
            }
        }

        var checkOffsets = [];
        for (t in shape.triangles) {
            if (!checkOffsets.any(o -> o.x == t.offset.x && o.y == t.offset.y))
                checkOffsets.push(t.offset);
        }
        for (o in checkOffsets) {
            var ents = Board.inst.getEntitiesAt(o.x + p.x, o.y + p.y);
            if (ents == null)
                continue;
            for (e in ents) {
                if (e != this && !e.inf.flags.has(HasEffect) && shape.collides(e.shape, p.x, p.y)) {
                    if (!isAttack)
                        return false;
                    if (inf.flags.has(IsEnemy) && e.inf.flags.has(IsEnemy))
                        return false;
                    switch (kind) {
                        case Hexachad, Slime, Slime2, Slime3:
                            if (!e.inf.flags.has(Killable))
                                return false;
                        case Wrecktangle:
                            if (!e.inf.flags.has(Killable) && !e.inf.flags.has(Breakable))
                                return false;
                        default:
                            return false;
                    }
                }
            }
        }
        return true;
    }

    public function getAttackColliding(info: MoveInfo) {
        var shape = shapes[info.shapeIdx];

        var ret = [];
        var checked = [];

        var checkOffsets = [];
        for (t in shape.triangles) {
            if (!checkOffsets.any(o -> o.x == t.offset.x && o.y == t.offset.y))
                checkOffsets.push(t.offset);
        }
        for (o in checkOffsets) {
            var ents = Board.inst.getEntitiesAt(o.x + info.pos.x, o.y + info.pos.y);
            if (ents == null)
                continue;
            for (e in ents) {
                if (e != this && !e.inf.flags.has(HasEffect) && !checked.has(e) && shape.collides(e.shape, info.pos.x, info.pos.y)) {
                    checked.push(e);
                    switch (kind) {
                        case Wrecktangle:
                            if (e.inf.flags.has(Killable) || e.inf.flags.has(Breakable))
                                ret.pushUnique(e);
                        default:
                            if (e.inf.flags.has(Killable))
                                ret.pushUnique(e);
                    }
                }
            }
        }
        return ret;
    }

    public var removed = false;
    public function onRemove() {
        removed = true;
        hoverGraphic.remove();
        if (previewGraphic != null)
            previewGraphic.remove();
        debGraphic.remove();
        rangeGraphic.remove();
        obj.remove();
        if (previewObj != null)
            previewObj.remove();
    }
    public function saveData(): EntityData {
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

    public var triangles: Array<{id : Data.Shape_trianglesKind, triIndex: Int, offset: IPoint}> = [];

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

    public function collides(other: ShapeEnt, ?x: Int, ?y: Int) {
        if (x == null)
            x = this.x;
        if (y == null)
            y = this.y;
        for (t in triangles) {
            var tx = x + t.offset.x;
            var ty = y + t.offset.y;
            for (t2 in other.triangles) {
                var t2x = other.x + t2.offset.x;
                var t2y = other.y + t2.offset.y;
                if (tx == t2x && ty == t2y && t.triIndex == t2.triIndex) {
                    return true;
                }
            }
        }
        return false;
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
        var first = ret[0];
        while (!allEdges.isEmpty()) {
            var top = ret.last();
            var e = allEdges.find(e2 -> e2.a.equals(top) || e2.b.equals(top));
            if (e == null) {
                throw "Unclosed shape " + kind.toString();
            }
            if (e.a.equals(first) || e.b.equals(first))
                break;
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
    public var offset: IPoint;

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

    public var entities: Array<EntityEnt> = [];
    var entityHistory: Array<Array<EntityData>> = [];
    var sideEntities: Array<EntityEnt> = [];

    public var level: Data.LevelKind;
    public var currTurn = 0;

    public var currentSelect: EntityEnt = null;
    public var isAttacking = false;

    public var forceSelectionEdges: Data.Grid = null;

    var grid = [];
    public var worldFirstGrid: Array<Array<Array<EntityEnt>>> = [];
    public var worldGrid: Array<Array<Array<EntityEnt>>> = [];

	public function new() {}

    public function init(root: h2d.Object) {
		inst = this;
        window = hxd.Window.getInstance();
        fullUi = new BoardUi(root);

        fullUi.boardCont.padding = 50;
        boardRoot = new h2d.Flow(fullUi.boardCont);
        fullUi.boardCont.backgroundTile = hxd.Res.vistaBackground.toTile();
        fullUi.nextTurnBtn.onClick = function() {
            nextTurn();
        }
        fullUi.attackBtn.onClick = function() {
            toggleAttack();
        }
        fullUi.restartBtn.onClick = function() {
            startLevel(level);
        }
        fullUi.revertBtn.onClick = function() {
            startLevel(level, entityHistory.pop());
        }
        boardRoot.fillWidth = true;
        boardRoot.fillHeight = true;
        boardRoot.layout = Stack;

        var gridPlatform = new h2d.Bitmap(hxd.Res.platform_A.toTile(), boardRoot);
        boardRoot.getProperties(gridPlatform).paddingBottom = - 161;

        gridPlatform.setScale(0.5);
        // boardRoot.getProperties(gridPlatform).paddingLeft = -5;
        // boardRoot.getProperties(gridPlatform).paddingTop = 40;

		gridCont = new SceneObject(boardRoot);
        gridCont.dom.addClass("gridCont");
        boardRoot.getProperties(gridCont).paddingLeft = 10;
        // boardRoot.getProperties(gridPlatform).paddingTop = 30;

        entitiesCont = new SceneObject(gridCont);
        entitiesCont.dom.addClass("entitiesCont");

		gridGraphics = new h2d.Graphics(gridCont);
        selectGraphic = new h2d.Graphics(gridCont);
        entityGraphics = new h2d.Graphics(gridCont);
        debugGraphic = new h2d.Graphics(gridCont);
        startLevel(Data.level.all[0].id);

		boardObj = new SceneObject(gridCont);
		boardObj.dom.addClass("boardObj");
	}

    function startLevel(lv: Data.LevelKind, ?data: Array<EntityData>) {
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
        if (data != null) {
            for (e in data) {
                var ent = new EntityEnt(e.ref, e.shapeIdx, e.offsetx, e.offsety);
                entities.push(ent);
            }
        } else {
            for (e in inf.entities) {
                var ent = new EntityEnt(e.refId, e.shapeIdx, e.offsetx, e.offsety);
                ent.fabLine = e;
                entities.push(ent);
            }
            entityHistory.clear();
            entityHistory.push(entities.map(e -> e.saveData()));
            currTurn = 0;
        }

        nextTurn(true);

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

    function nextTurn(isFirst = false) {
        select(null);

        if (!isFirst) {
            currTurn++;
            for (e in entities) {
                e.nextTurn();
            }
            entityHistory.push(entities.map(e -> e.saveData()));
        }
        fullUi.turnCount.text = "Turns: " + currTurn;
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
        var mousePos = boardRoot.globalToLocal(mousePos);
        return Const.fromIso(mousePos);
    }

    public function refreshWorldGrid() {
        function clear(arr: Array<Array<Array<EntityEnt>>>) {
            for (l in arr) {
                if (l != null) {
                    for (c in l) {
                        if (c != null)
                            c.clear();
                    }
                }
            }
        }
        clear(worldFirstGrid);
        clear(worldGrid);

        function addTo(arr: Array<Array<Array<EntityEnt>>>, x, y, e) {
            x += Const.BOARD_HEIGHT;
            y += Const.BOARD_HEIGHT;
            if (arr[x] == null)
                arr[x] = [];
            if (arr[x][y] == null)
                arr[x][y] = [];
            arr[x][y].pushUnique(e);
        }

        for (e in entities) {
            addTo(worldFirstGrid, e.x, e.y, e);
            for (t in e.shape.triangles) {
                addTo(worldGrid, t.offset.x + e.x, t.offset.y + e.y, e);
            }
        }
    }
    public function getEntitiesAt(x: Int, y: Int) {
        x += Const.BOARD_HEIGHT;
        y += Const.BOARD_HEIGHT;
        if (worldGrid[x] == null)
            return null;
        if (worldGrid[x][y] == null)
            return null;
        return worldGrid[x][y];
    }

    public function deleteEntity(e: EntityEnt) {
        e.onRemove();
        entities.remove(e);
        if (currentSelect == e) {
            currentSelect = null;
            select(null);
        }
    }

    var prevSelect = null;
    public function update(dt: Float) {
        debugGraphic.clear();
        debugGraphic.lineStyle(1, 0xFF0000);

        refreshWorldGrid();

        entityGraphics.clear();
        for (e in entities) {
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
        if (K.isPressed(K.ENTER) || K.isPressed(K.NUMPAD_ENTER))
            nextTurn();
        if (K.isPressed(K.A))
            toggleAttack();
        if (K.isPressed(K.R))
            startLevel(level);
        if (K.isPressed(K.P))
            startLevel(level, entityHistory.pop());
        #if !release
        if (K.isPressed(K.DELETE)) {
            if (currentSelect != null && entities.has(currentSelect)) {
                deleteEntity(currentSelect);
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
        for (l in worldFirstGrid) {
            if (l != null) {
                for (c in l) {
                    if (c != null) {
                        for (e in c) {
                            if (e.inf.flags.has(HasEffect)) {
                                if (c.any(e2 -> e2 != e && e2.shape.kind == e.shape.kind)) {
                                    activeEffects++;
                                    if (e.inf.props.onStompLevelId != null) {
                                        startLevel(e.inf.props.onStompLevelId);
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
        isAttacking = false;
    }

    public function toggleAttack() {
        if (isAttacking) {
            isAttacking = false;
            if (currentSelect != null) {
                currentSelect.onSelect();
            }
        } else {
            if (currentSelect != null && currentSelect.canAttack()) {
                isAttacking = true;
                currentSelect.onSelect();
            }
        }
    }

    public function onMove(?e: EntityEnt) {
        if (e != null) {
            var i = sideEntities.indexOf(e);
            if (i >= 0) {
                sideEntities[i] = makeSide(e.kind, i);
                entities.push(e);
            }
        }

        refreshWorldGrid();
        reorderBitmap();
    }

    public function compareObj(a: h2d.Object, b: h2d.Object) {
        var oa = Std.downcast(a, SceneEntityObject);
        var ob = Std.downcast(b, SceneEntityObject);
        // TODO the preview (e is null)
        if (oa != null && ob != null && oa.e != null && ob.e != null) {
            var enta = oa.e;
            var entb = ob.e;
            if (enta.inf.flags.has(AlwaysBehind) && !entb.inf.flags.has(AlwaysBehind)) return -1;
            else if (entb.inf.flags.has(AlwaysBehind) && !enta.inf.flags.has(AlwaysBehind)) return 1;
            else {
                var centerA = Const.getCenter(enta.shape.inf.firstTriangle,enta.shape.inf.firstTriangleCenter);
                var centerB = Const.getCenter(entb.shape.inf.firstTriangle,entb.shape.inf.firstTriangleCenter);
                var isoCenterA = Const.toIso(centerA.add(new Point(enta.x,enta.y)));
                var isoCenterB = Const.toIso(centerB.add(new Point(entb.x,entb.y)));
                var res = isoCenterB.y - isoCenterA.y;
                if (res > 0) return -1;
                else if (res < 0) return 1;
                else return 0;
            }
        }
        return 0;
    }

    public function reorderBitmap(){
         @:privateAccess entitiesCont.children.sort(compareObj);
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
            #if debug
            if (t.offset.x == 0 && t.offset.y == 0) {
                g.lineStyle(1, 0xD8980F);
            } else {
                if (forceSelectionEdges != null)
                    g.lineStyle(1, 0x000000);
                else if (currentSelect != null)
                    g.lineStyle(2, 0xA5A5A5);
                else
                    g.lineStyle(0, 0x000000);
            }
            #end
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