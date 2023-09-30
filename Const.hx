import h2d.col.Point;

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
            {v: 0, off: {x: 0, y: 0}},
            {v: 1, off: {x: 0, y: 0}},
        ],
        [
            {v: 1, off: {x: 0, y: 0}},
            {v: 0, off: {x: 2, y: 0}},
        ],
        [
            {v: 0, off: {x: 0, y: 0}},
            {v: 2, off: {x: 0, y: 0}},
        ],
        [
            {v: 2, off: {x: 0, y: 0}},
            {v: 0, off: {x: 1, y: 1}},
        ],
        [
            {v: 0, off: {x: 1, y: 1}},
            {v: 3, off: {x: 0, y: 0}},
        ],
        [ // 5
            {v: 3, off: {x: 0, y: 0}},
            {v: 0, off: {x: 2, y: 0}},
        ],
        [
            {v: 0, off: {x: 0, y: 0}},
            {v: 4, off: {x: 0, y: 0}},
        ],
        [
            {v: 1, off: {x: 0, y: 0}},
            {v: 4, off: {x: 0, y: 0}},
        ],
        [
            {v: 0, off: {x: 2, y: 0}},
            {v: 4, off: {x: 0, y: 0}},
        ],
        [
            {v: 3, off: {x: 0, y: 0}},
            {v: 4, off: {x: 0, y: 0}},
        ],
        [ // 10
            {v: 0, off: {x: 1, y: 1}},
            {v: 4, off: {x: 0, y: 0}},
        ],
        [
            {v: 2, off: {x: 0, y: 0}},
            {v: 4, off: {x: 0, y: 0}},
        ],
        [
            {v: 0, off: {x: 2, y: 0}},
            {v: 5, off: {x: 0, y: 0}},
        ],
        [
            {v: 2, off: {x: 2, y: 0}},
            {v: 5, off: {x: 0, y: 0}},
        ],
        [
            {v: 0, off: {x: 3, y: 1}},
            {v: 5, off: {x: 0, y: 0}},
        ],
        [ // 15
            {v: 1, off: {x: 1, y: 1}},
            {v: 5, off: {x: 0, y: 0}},
        ],
        [
            {v: 0, off: {x: 1, y: 1}},
            {v: 5, off: {x: 0, y: 0}},
        ],
        [
            {v: 3, off: {x: 0, y: 0}},
            {v: 5, off: {x: 0, y: 0}},
        ],
    ];

    static final BASE_TRIANGLES: Array<Array<{v: Int, ?off: {x: Int, y: Int}}>> = [
        [{v: 6},    {v: 0}, {v: 7}],                        // 0
        [{v: 6},    {v: 2}, {v: 11}],                       // 1
        [{v: 12},   {v: 2, off: {x: 2, y: 0}}, {v: 13}],    // 2
        [{v: 12},   {v: 5}, {v: 17}],                       // 3
        [{v: 8},    {v: 5}, {v: 9}],                        // 4
        [{v: 8},    {v: 1}, {v: 7}],                        // 5
        [{v: 14},   {v: 1, off: {x: 1, y: 1}}, {v: 15}],    // 6
        [{v: 14},   {v: 3, off: {x: 2, y: 0}}, {v: 13}],    // 7
        [{v: 10},   {v: 3}, {v: 11}],                       // 8
        [{v: 10},   {v: 4}, {v: 9}],                        // 9
        [{v: 16},   {v: 4}, {v: 17}],                       // 10
        [{v: 16},   {v: 0, off: {x: 1, y: 1}}, {v: 15}],    // 11
    ];
}