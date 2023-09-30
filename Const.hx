import h2d.col.Point;
import h2d.col.IPoint;
using Extensions;

@:publicFields class Const {

    static final TITLE = "Triangle assault";

    static final SQRT_3 = 1.73205080757;

    static final HEX_SIDE = 50;
    static final HEX_HEIGHT = HEX_SIDE * SQRT_3;
    static final BOARD_WIDTH = 10;
	static final BOARD_HEIGHT = 12;

    static final BOARD_FULL_WIDTH = (BOARD_WIDTH * 2) * HEX_SIDE;
	static final BOARD_FULL_HEIGHT = BOARD_HEIGHT * HEX_HEIGHT;

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

    static inline function getEdges(idx) {
        var ret = [];
        var tri = BASE_TRIANGLES[idx];
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

    static inline function getVertexOffsets(idx) {
        var edges = getEdges(idx);
        var ret = [];
        ret.push(edges[0].a);
        ret.push(edges[0].b);

        var tri = BASE_TRIANGLES[idx];
        var firstEdge = BASE_EDGES[tri[0].v];
        var otherEdge = BASE_EDGES[tri[1].v];
        var vert = otherEdge.findIndex(v -> v.v != firstEdge[0].v && v.v != firstEdge[1].v);
        ret.push(vert == 0 ? edges[1].a : edges[1].b);

        return ret;
    }
}