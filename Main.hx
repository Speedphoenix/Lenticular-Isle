import hxd.Key as K;
using Extensions;

class Main extends hxd.App {
	public static var inst: Main;

	var board: Board;

	public static var font: h2d.Font;

	override function init() {
		inst = this;
		var cdbData = hxd.Res.data.entry.getText();
		Data.load(cdbData, false);
		hxd.res.Resource.LIVE_UPDATE = true;
		hxd.Res.data.watch(function() {
			var cdbData = hxd.Res.data.entry.getText();
			Data.load(cdbData, true);
		});
		font = hxd.Res.customFont.toFont();

		board = new Board();
		board.init(s2d);

		onResize();
	}
	static function main() {
		hxd.Res.initEmbed();
		new Main();
	}
	override function update(dt:Float) {
		super.update(dt);
	}
	override function onResize() {
		super.onResize();
	}
}
