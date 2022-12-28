const std = @import("std");
const math = std.math;
const app = @import("app");
const gl = app.gl;

pub const name = "0x0001";
pub const viewport_width = 1600;
pub const viewport_height = 1600;

pub fn draw() void {
    gl.clearNamedFramebufferfv(app.windowFbo(), gl.COLOR, 0, &[_]f32{ 0.2, 0.4, 0.8, 1.0 });

    var prng = std.rand.DefaultPrng.init(0);
    const rand = prng.random();

    gl.color4f(0.0, 0.0, 0.0, 0.5);
    gl.pointSize(25.0);
    gl.loadIdentity();
    gl.rotatef(15.0, 0, 0, 1);

    gl.pushMatrix();
    gl.translatef(-500.0, 0, 0);

    var x: f32 = 0.0;
    var i: u32 = 0;
    gl.begin(gl.POINTS);
    while (i < 200) : (i += 1) {
        const frac = @intToFloat(f32, i) / 200.0;
        const y = (-1.0 + 2.0 * rand.float(f32)) * 100 * frac * frac;
        gl.vertex2f(x, y);
        x += 5.0;
    }
    gl.end();
    gl.popMatrix();
}

pub fn init() void {
    _ = app.wgl.swapIntervalEXT(1);
    gl.matrixMode(gl.MODELVIEW);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.blendEquation(gl.FUNC_ADD);
    gl.enable(gl.BLEND);
}
