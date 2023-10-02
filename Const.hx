import h2d.col.Point;
import h2d.col.IPoint;
using Extensions;

// TODO
// Fix les bords de la grille
// fix le zoffset des bitmaps
// les points d'action/mouvement
// collisions des déplacements

// game title

@:publicFields class Const {

    static final TITLE = "Triangle assault";

    static final SQRT_3 = 1.73205080757;

    static final HEX_SIDE = 50;
    static final HEX_HEIGHT = HEX_SIDE * SQRT_3;
    static final BOARD_WIDTH = 10;
	static final BOARD_HEIGHT = 12;

    static final BOARD_FULL_WIDTH = (BOARD_WIDTH * 2) * HEX_SIDE;
	static final BOARD_FULL_HEIGHT = BOARD_HEIGHT * HEX_HEIGHT;

    static final POLY_SCALE = 6; // multiplying vertex points by this needs to be round

    static var ISO_MATRIX: h2d.col.Matrix = new h2d.col.Matrix();
    static var INV_ISO_MATRIX: h2d.col.Matrix = new h2d.col.Matrix();

    static function initConstants() {
        // ISO_MATRIX.a = HEX_SIDE;    ISO_MATRIX.b = 0;           ISO_MATRIX.x = 0;
        // ISO_MATRIX.c = 0;           ISO_MATRIX.d = HEX_HEIGHT;  ISO_MATRIX.y + 0;

        // ISO_MATRIX.a = 122;  ISO_MATRIX.b = 70; ISO_MATRIX.x = 0;
        // ISO_MATRIX.c = 70;  ISO_MATRIX.d = -42; ISO_MATRIX.y = 450;

        ISO_MATRIX.a = 32.0454545;  ISO_MATRIX.b = 18.18181818; ISO_MATRIX.x = 0;
        ISO_MATRIX.c = 56.25;  ISO_MATRIX.d = -33.33333; ISO_MATRIX.y = 405;

        INV_ISO_MATRIX = ISO_MATRIX.clone();
        INV_ISO_MATRIX.invert();
    }

    static inline function toIso(p) {
        return ISO_MATRIX.transform(p);
    }
    static inline function fromIso(p) {
        return INV_ISO_MATRIX.transform(p);
    }

    static inline function toGrid(p: IPoint, g: Data.GridKind) {
        switch (g) {
            case Base, None:
                return p;
            case TriangleZeroes:
                var ret = new IPoint(Math.round((p.x - (p.y & 1)) / 2), p.y);
                return ret;
            case SmallRectangle:
                return p;
            case SmallTriangle:
                var ret = new IPoint(p.x, Math.round(((3 * p.y) - p.x) / 2));
                trace("togrid ", p, "->", ret);
                return ret;

            case SmallLozange: // TODO
                return p;
        }
    }
    static inline function getGridOffset(p: IPoint, g: Data.GridKind) {
        switch (g) {
            case SmallRectangle:
                if ((p.x & 1) != (p.y & 1))
                    return new IPoint(1, 0);
                return new IPoint(0, 0);
            case SmallTriangle:
                var pointType=(p.x+2*p.y) % 3 ;
                if(pointType==0){
                    return new IPoint(0, 0);
                } else if (pointType==1||pointType==-2){
                    return new IPoint(1, 0);
                } else{
                    return new IPoint(2, 0);
                }
            case None, Base, TriangleZeroes, SmallLozange:
                return new IPoint(0, 0);
        }
    }
    static inline function fromGrid(p: IPoint, g: Data.GridKind) {
        switch (g) {
            case Base, None:
                return p;
            case TriangleZeroes:
                var ret = new IPoint((p.x * 2) + (p.y & 1), p.y);
                return ret;
            case SmallTriangle:
                var off = getGridOffset(p, g);
                var point= p.sub(off);
                var ret = new IPoint(point.x,Math.round((2*point.y+point.x)/3));
                trace("fromGrid ", p, "->", ret);
                return ret;
            case SmallRectangle:
                var off = getGridOffset(p, g);
                return p.sub(off);
            case SmallLozange: // TODO
                return p;
        }
    }
    // can return floating points/different parity
    static inline function fromGridFloat(p: IPoint, g: Data.GridKind) {
        switch (g) {
            case Base, None:
                return p.toPoint();
            case TriangleZeroes:
                var ret = new Point((p.x * 2) + (p.y & 1), p.y);
                return ret;
            case SmallRectangle:
                return p.toPoint();
            case SmallTriangle: // TODO
                return new Point(p.x,(2*p.y+p.x)/3);
            case SmallLozange: // TODO
                return p.toPoint();
        }
    }
    static inline function getGridAdjacent(p: IPoint, g: Data.GridKind) {
        switch (g) {
            case Base, None:
                return [
                    new IPoint(-2, 0),
                    new IPoint(2, 0),
                    new IPoint(-1, -1),
                    new IPoint(1, 1),
                    new IPoint(-1, 1),
                    new IPoint(1, -1),
                ];
            case TriangleZeroes:
                if ((p.y & 1) == 0) {
                    return [
                        new IPoint(-1, 0),
                        new IPoint(1, 0),

                        new IPoint(0, -1),
                        new IPoint(0, 1),

                        new IPoint(-1, 1),
                        new IPoint(-1, -1),
                    ];
                } else {
                    return [
                        new IPoint(-1, 0),
                        new IPoint(1, 0),

                        new IPoint(0, -1),
                        new IPoint(0, 1),

                        new IPoint(1, -1),
                        new IPoint(1, 1),
                    ];
                }
            case SmallRectangle:
                return [
                    new IPoint(-1, 0),
                    new IPoint(1, 0),

                    new IPoint(0, -1),
                    new IPoint(0, 1),
                ];
            case SmallTriangle:
                return [
                    new IPoint(-1, 0),
                    new IPoint(1, 0),

                    new IPoint(-2, 0),
                    new IPoint(2, 0),

                    new IPoint(-3, 0),
                    new IPoint(3, 0),

                    new IPoint(-4, 0),
                    new IPoint(4, 0),

                    new IPoint(-5, 0),
                    new IPoint(5, 0),

                    new IPoint(-1, 1),
                    new IPoint(0, 1),

                    new IPoint(-2, 2),
                    new IPoint(0, 2),

                    new IPoint(-3, 3),
                    new IPoint(0, 3),

                    new IPoint(-4, 4),
                    new IPoint(0, 4),

                    new IPoint(-5, 5),
                    new IPoint(0, 5),

                    new IPoint(0, -1),
                    new IPoint(1, -1),

                    new IPoint(0, -2),
                    new IPoint(2, -2),

                    new IPoint(0, -3),
                    new IPoint(3, -3),

                    new IPoint(0, -4),
                    new IPoint(4, -4),

                    new IPoint(0,-5),
                    new IPoint(5, -5),

                    new IPoint(2, -1),
                    new IPoint(4, -2),
                    new IPoint(6, -3),
                    new IPoint(-2, 1),
                    new IPoint(-4, 2),
                    new IPoint(-6, 3),

                    new IPoint(1, 1),
                    new IPoint(2, 2),
                    new IPoint(3, 3),
                    new IPoint(-1, -1),
                    new IPoint(-2, -2),
                    new IPoint(-3, -3),

                    new IPoint(-1, 2),
                    new IPoint(-2, 4),
                    new IPoint(-3, 6),
                    new IPoint(1, -2),
                    new IPoint(2, -4),
                    new IPoint(3, -6),
                ];
            case SmallLozange: // TODO
                return [
                    new IPoint(-2, 0),
                    new IPoint(2, 0),
                    new IPoint(-1, -1),
                    new IPoint(1, 1),
                    new IPoint(-1, 1),
                    new IPoint(1, -1),
                ];
        }
    }

    static final BASE_VERTICES = [
        new Point(0, 0),        // 0
        new Point(1, 0),        // 1
        new Point(0.5, 0.5),    // 2
        new Point(1.5, 0.5),    // 3
        new Point(1, 1 / 3),    // 4
        new Point(2, 2 / 3),    // 5
    ];

    static final BASE_EDGES = [
        [
            {v: 0, off: new IPoint(0, 0)},
            {v: 1, off: new IPoint(0, 0)},
        ],
        [
            {v: 1, off: new IPoint(0, 0)},
            {v: 0, off: new IPoint(2, 0)},
        ],
        [
            {v: 0, off: new IPoint(0, 0)},
            {v: 2, off: new IPoint(0, 0)},
        ],
        [
            {v: 2, off: new IPoint(0, 0)},
            {v: 0, off: new IPoint(1, 1)},
        ],
        [
            {v: 0, off: new IPoint(1, 1)},
            {v: 3, off: new IPoint(0, 0)},
        ],
        [ // 5
            {v: 3, off: new IPoint(0, 0)},
            {v: 0, off: new IPoint(2, 0)},
        ],
        [
            {v: 0, off: new IPoint(0, 0)},
            {v: 4, off: new IPoint(0, 0)},
        ],
        [
            {v: 1, off: new IPoint(0, 0)},
            {v: 4, off: new IPoint(0, 0)},
        ],
        [
            {v: 0, off: new IPoint(2, 0)},
            {v: 4, off: new IPoint(0, 0)},
        ],
        [
            {v: 3, off: new IPoint(0, 0)},
            {v: 4, off: new IPoint(0, 0)},
        ],
        [ // 10
            {v: 0, off: new IPoint(1, 1)},
            {v: 4, off: new IPoint(0, 0)},
        ],
        [
            {v: 2, off: new IPoint(0, 0)},
            {v: 4, off: new IPoint(0, 0)},
        ],
        [
            {v: 0, off: new IPoint(2, 0)},
            {v: 5, off: new IPoint(0, 0)},
        ],
        [
            {v: 2, off: new IPoint(2, 0)},
            {v: 5, off: new IPoint(0, 0)},
        ],
        [
            {v: 0, off: new IPoint(3, 1)},
            {v: 5, off: new IPoint(0, 0)},
        ],
        [ // 15
            {v: 1, off: new IPoint(1, 1)},
            {v: 5, off: new IPoint(0, 0)},
        ],
        [
            {v: 0, off: new IPoint(1, 1)},
            {v: 5, off: new IPoint(0, 0)},
        ],
        [
            {v: 3, off: new IPoint(0, 0)},
            {v: 5, off: new IPoint(0, 0)},
        ],
    ];

    static final BASE_TRIANGLES: Array<Array<{v: Int, ?off: IPoint}>> = [
        [{v: 6},    {v: 0}, {v: 7}],                        // 0
        [{v: 6},    {v: 2}, {v: 11}],                       // 1
        [{v: 12},   {v: 2, off: new IPoint(2, 0)}, {v: 13}],    // 2
        [{v: 12},   {v: 5}, {v: 17}],                       // 3
        [{v: 8},    {v: 5}, {v: 9}],                        // 4
        [{v: 8},    {v: 1}, {v: 7}],                        // 5
        [{v: 14},   {v: 1, off: new IPoint(1, 1)}, {v: 15}],    // 6
        [{v: 14},   {v: 3, off: new IPoint(2, 0)}, {v: 13}],    // 7
        [{v: 10},   {v: 3}, {v: 11}],                       // 8
        [{v: 10},   {v: 4}, {v: 9}],                        // 9
        [{v: 16},   {v: 4}, {v: 17}],                       // 10
        [{v: 16},   {v: 0, off: new IPoint(1, 1)}, {v: 15}],    // 11
    ];
    static final UNDERFLOWING_TRIANGLES: Array<Int> = [
        0, 1, 8,
    ];
    static final OVERFLOWING_TRIANGLES: Array<Int> = [
        2, 6, 7,
    ];

    static inline function getEdges(triIdx) {
        var ret = [];
        var tri = BASE_TRIANGLES[triIdx];
        for (i in 0...3) {
            var offset2 = new IPoint(0, 0);
            if (tri[i].off != null) {
                offset2 = offset2.add(tri[i].off);
            }
            var edge = BASE_EDGES[tri[i].v];
            var a = BASE_VERTICES[edge[0].v].clone();
            a.x += edge[0].off.x + offset2.x;
            a.y += edge[0].off.y + offset2.y;
            var b = BASE_VERTICES[edge[1].v].clone();
            b.x += edge[1].off.x + offset2.x;
            b.y += edge[1].off.y + offset2.y;
            ret.push({a: a, b: b, idx: tri[i].v});
        }
        return ret;
    }

    static inline function getCenter(triIdx, vertexIdx = -1) {
        var verts = getVertexOffsets(triIdx);
        if (vertexIdx < 0)
            return verts[0].add(verts[1]).add(verts[2]).multiply(1 / 3);

        var tri = BASE_TRIANGLES[triIdx];
        var edges = getEdges(triIdx);
        if (BASE_EDGES[tri[0].v][0].v == vertexIdx)
            return edges[0].a;
        if (BASE_EDGES[tri[0].v][1].v == vertexIdx)
            return edges[0].b;
        if (BASE_EDGES[tri[1].v][0].v == vertexIdx)
            return edges[1].a;
        if (BASE_EDGES[tri[1].v][1].v == vertexIdx)
            return edges[1].b;
        return verts[0].add(verts[1]).add(verts[2]).multiply(1 / 3);
    }
    static inline function getVertexOffsets(triIdx) {
        var edges = getEdges(triIdx);
        var ret = [];
        ret.push(edges[0].a);
        ret.push(edges[0].b);

        var tri = BASE_TRIANGLES[triIdx];
        var firstEdge = BASE_EDGES[tri[0].v];
        var otherEdge = BASE_EDGES[tri[1].v];
        var vert = otherEdge.findIndex(v -> v.v != firstEdge[0].v && v.v != firstEdge[1].v);
        ret.push(vert == 0 ? edges[1].a : edges[1].b);

        return ret;
    }
}