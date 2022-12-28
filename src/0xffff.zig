const std = @import("std");
const math = std.math;
const app = @import("app");
const gl = app.gl;

pub const name = "0xffff";
pub const viewport_width = 1600;
pub const viewport_height = 1600;

pub fn draw() void {
    gl.clearNamedFramebufferfv(app.windowFbo(), gl.COLOR, 0, &[_]f32{ 1.0, 1.0, 1.0, 1.0 });
}

pub fn init() void {
    _ = app.wgl.swapIntervalEXT(1);
    gl.matrixMode(gl.MODELVIEW);
}
