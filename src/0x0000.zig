const std = @import("std");
const math = std.math;
const app = @import("app");
const gl = app.gl;
const zm = @import("zmath");

pub const name = "0x0000";
pub const viewport_width = 1600;
pub const viewport_height = 1600;

const main_color = [_]f32{ 0.025, 0.025, 0.025, 1.0 };

fn compileList() gl.Uint {
    const list: gl.Uint = 1;
    gl.newList(list, gl.COMPILE);
    gl.color4fv(&main_color);
    {
        var j: u32 = 0;
        while (j < 1) : (j += 1) {
            var i: u32 = 0;
            gl.pushMatrix();
            while (i < 5) : (i += 1) {
                gl.begin(gl.POINTS);
                gl.vertex2f(0, 0);
                gl.end();
                if (i == 4 and j == 0) {
                    gl.begin(gl.POINTS);
                    gl.color3f(0.2, 0.0, 0.0);
                    gl.vertex2f(0, 0);
                    gl.color4fv(&main_color);
                    gl.end();
                }
                gl.translatef(67.0, 0.0, 0.0);
            }
            gl.popMatrix();
            gl.translatef(0.0, -67.0, 0.0);
        }
    }
    {
        var j: u32 = 0;
        while (j < 1) : (j += 1) {
            var i: u32 = 0;
            gl.pushMatrix();
            while (i < 7) : (i += 1) {
                gl.begin(gl.POINTS);
                gl.vertex2f(0, 0);
                gl.end();
                if (i == 6 and j == 0) {
                    gl.begin(gl.POINTS);
                    gl.color3f(0.0, 0.0, 0.5);
                    gl.vertex2f(0, 0);
                    gl.color4fv(&main_color);
                    gl.end();
                }
                gl.translatef(67.0, 0.0, 0.0);
            }
            gl.popMatrix();
            gl.translatef(0.0, -67.0, 0.0);
        }
    }
    {
        var j: u32 = 0;
        while (j < 5) : (j += 1) {
            var i: u32 = 0;
            gl.pushMatrix();
            while (i < 2) : (i += 1) {
                gl.begin(gl.POINTS);
                gl.vertex2f(0, 0);
                gl.end();
                if (i == 1 and j == 4) {
                    gl.begin(gl.POINTS);
                    gl.color3f(0.2, 0.0, 0.0);
                    gl.vertex2f(0, 0);
                    gl.color4fv(&main_color);
                    gl.end();
                }
                gl.translatef(67.0, 0.0, 0.0);
            }
            gl.popMatrix();
            gl.translatef(0.0, -67.0, 0.0);
        }
    }
    {
        var j: u32 = 0;
        while (j < 2) : (j += 1) {
            var i: u32 = 0;
            gl.pushMatrix();
            while (i < 1) : (i += 1) {
                gl.begin(gl.POINTS);
                gl.vertex2f(0, 0);
                gl.end();
                if (i == 0 and j == 1) {
                    gl.begin(gl.POINTS);
                    gl.color3f(0.0, 0.15, 0.0);
                    gl.vertex2f(0, 0);
                    gl.color4fv(&main_color);
                    gl.end();
                }
                gl.translatef(67.0, 0.0, 0.0);
            }

            gl.popMatrix();
            gl.translatef(0.0, -67.0, 0.0);
        }
    }
    gl.endList();
    return list;
}

pub fn draw() void {
    gl.clearNamedFramebufferfv(app.windowFbo(), gl.COLOR, 0, &[_]f32{ 1.0, 1.0, 1.0, 1.0 });

    gl.pointSize(64.0);
    gl.loadIdentity();
    gl.rotatef(15.0, 0, 0, 1);

    const list = compileList();

    gl.pushMatrix();
    gl.translatef(-600.0, 600.0, 0.0);
    gl.callList(list);
    gl.popMatrix();

    gl.pushMatrix();
    gl.translatef(600.0, -600.0, 0.0);
    gl.scalef(-1.0, -1.0, 1.0);
    gl.callList(list);
    gl.popMatrix();

    gl.pushMatrix();
    gl.translatef(0.0, -100.0, 0.0);
    gl.scalef(-1.0, -1.0, 1.0);
    gl.callList(list);
    gl.popMatrix();

    gl.pushMatrix();
    gl.translatef(0.0, 100.0, 0.0);
    gl.callList(list);
    gl.popMatrix();

    gl.pointSize(65.0);
    gl.pushMatrix();
    gl.translatef(0.0, 33.5, 0.0);
    gl.begin(gl.POINTS);
    gl.color3f(1.0, 1.0, 1.0);
    gl.vertex2f(0, 0);
    gl.end();
    gl.popMatrix();
}

pub fn init() void {
    _ = app.wgl.swapIntervalEXT(1);
    //gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    //gl.blendEquation(gl.FUNC_ADD);
    //gl.enable(gl.BLEND);
    //gl.enable(gl.POINT_SMOOTH);
    //gl.enable(gl.POINT_SPRITE);
    gl.matrixMode(gl.MODELVIEW);
}
