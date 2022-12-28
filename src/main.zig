const std = @import("std");
const panic = std.debug.panic;
const assert = std.debug.assert;
const w32 = std.os.windows;
const impl = @import("implementation");

pub const gl = @import("opengl.zig");

const num_msaa_samples = 8;

pub fn windowFbo() gl.Uint {
    return window_fbo;
}
pub fn frameTime() f32 {
    return @floatCast(f32, frame_time);
}
pub fn frameDeltaTime() f32 {
    return frame_delta_time;
}

pub fn main() !void {
    _ = w32x.user32.SetProcessDPIAware();

    const winclass = w32.user32.WNDCLASSEXA{
        .style = 0,
        .lpfnWndProc = processWindowMessage,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = @ptrCast(w32.HINSTANCE, w32.kernel32.GetModuleHandleW(null)),
        .hIcon = null,
        .hCursor = w32x.user32.LoadCursorA(null, @intToPtr(w32.LPCSTR, 32512)),
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = impl.name,
        .hIconSm = null,
    };
    _ = try w32.user32.registerClassExA(&winclass);

    const style = w32.user32.WS_OVERLAPPED +
        w32.user32.WS_SYSMENU +
        w32.user32.WS_CAPTION +
        w32.user32.WS_MINIMIZEBOX;

    var rect = w32.RECT{ .left = 0, .top = 0, .right = impl.viewport_width, .bottom = impl.viewport_height };
    try w32.user32.adjustWindowRectEx(&rect, style, false, 0);

    const window = try w32.user32.createWindowExA(
        0,
        impl.name,
        impl.name,
        style + w32.user32.WS_VISIBLE,
        w32.user32.CW_USEDEFAULT,
        w32.user32.CW_USEDEFAULT,
        rect.right - rect.left,
        rect.bottom - rect.top,
        null,
        null,
        winclass.hInstance,
        null,
    );
    const hdc = w32.user32.GetDC(window).?;

    const opengl_context = initOpenGl(hdc);
    defer {
        _ = wgl.makeCurrent(null, null);
        _ = wgl.deleteContext(opengl_context);
    }

    gl.matrixLoadIdentityEXT(gl.PROJECTION);
    gl.matrixOrthoEXT(
        gl.PROJECTION,
        -impl.viewport_width * 0.5,
        impl.viewport_width * 0.5,
        -impl.viewport_height * 0.5,
        impl.viewport_height * 0.5,
        -1.0,
        1.0,
    );
    gl.enable(gl.FRAMEBUFFER_SRGB);
    gl.enable(gl.MULTISAMPLE);

    var tex_srgb: gl.Uint = undefined;
    gl.createTextures(gl.TEXTURE_2D_MULTISAMPLE, 1, @ptrCast([*]gl.Uint, &tex_srgb));
    defer gl.deleteTextures(1, @ptrCast([*]const gl.Uint, &tex_srgb));
    gl.textureStorage2DMultisample(
        tex_srgb,
        num_msaa_samples,
        gl.SRGB8_ALPHA8,
        impl.viewport_width,
        impl.viewport_height,
        gl.FALSE,
    );

    gl.createFramebuffers(1, @ptrCast([*]gl.Uint, &window_fbo));
    defer gl.deleteFramebuffers(1, @ptrCast([*]const gl.Uint, &window_fbo));
    gl.namedFramebufferTexture(window_fbo, gl.COLOR_ATTACHMENT0, tex_srgb, 0);
    gl.clearNamedFramebufferfv(window_fbo, gl.COLOR, 0, &[_]f32{ 0.0, 0.0, 0.0, 0.0 });

    gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, window_fbo);

    impl.init();
    defer if (@hasDecl(impl, "deinit")) impl.deinit();

    while (true) {
        var message = std.mem.zeroes(w32.user32.MSG);
        if (try w32.user32.peekMessageA(&message, null, 0, 0, w32.user32.PM_REMOVE)) {
            _ = w32.user32.dispatchMessageA(&message);
            if (message.message == w32.user32.WM_QUIT) break;
        } else {
            const stats = updateFrameStats(window, impl.name);
            frame_time = stats.time;
            frame_delta_time = stats.delta_time;

            impl.draw();

            gl.blitNamedFramebuffer(
                window_fbo,
                0, // default fbo
                0,
                0,
                impl.viewport_width,
                impl.viewport_height,
                0,
                0,
                impl.viewport_width,
                impl.viewport_height,
                gl.COLOR_BUFFER_BIT,
                gl.NEAREST,
            );
            _ = w32.gdi32.SwapBuffers(hdc);

            if (gl.getError() != 0) panic("OpenGL error detected.", .{});
        }
    }

    if (gl.getError() != 0) panic("OpenGL error detected.", .{});
}

var opengl32_dll: std.DynLib = undefined;

var window_fbo: gl.Uint = 0;
var frame_time: f64 = 0.0;
var frame_delta_time: f32 = 0.0;

pub const wgl = struct {
    var createContext: *const fn (?w32.HDC) callconv(w32.WINAPI) ?w32.HGLRC = undefined;
    var deleteContext: *const fn (?w32.HGLRC) callconv(w32.WINAPI) w32.BOOL = undefined;
    var makeCurrent: *const fn (?w32.HDC, ?w32.HGLRC) callconv(w32.WINAPI) w32.BOOL = undefined;
    var getProcAddress: *const fn (w32.LPCSTR) callconv(w32.WINAPI) ?w32.FARPROC = undefined;
    pub var swapIntervalEXT: *const fn (i32) callconv(w32.WINAPI) w32.BOOL = undefined;
};

fn initOpenGl(hdc: w32.HDC) w32.HGLRC {
    var pfd = std.mem.zeroes(w32.gdi32.PIXELFORMATDESCRIPTOR);
    pfd.nSize = @sizeOf(w32.gdi32.PIXELFORMATDESCRIPTOR);
    pfd.nVersion = 1;
    pfd.dwFlags = w32x.gdi32.PFD_SUPPORT_OPENGL +
        w32x.gdi32.PFD_DOUBLEBUFFER +
        w32x.gdi32.PFD_DRAW_TO_WINDOW;
    pfd.iPixelType = w32x.gdi32.PFD_TYPE_RGBA;
    pfd.cColorBits = 32;
    pfd.cDepthBits = 24;
    pfd.cStencilBits = 8;
    const pixel_format = w32.gdi32.ChoosePixelFormat(hdc, &pfd);
    if (!w32.gdi32.SetPixelFormat(hdc, pixel_format, &pfd)) {
        panic("SetPixelFormat failed.", .{});
    }

    opengl32_dll = std.DynLib.open("/windows/system32/opengl32.dll") catch unreachable;
    wgl.createContext = opengl32_dll.lookup(@TypeOf(wgl.createContext), "wglCreateContext").?;
    wgl.deleteContext = opengl32_dll.lookup(@TypeOf(wgl.deleteContext), "wglDeleteContext").?;
    wgl.makeCurrent = opengl32_dll.lookup(@TypeOf(wgl.makeCurrent), "wglMakeCurrent").?;
    wgl.getProcAddress = opengl32_dll.lookup(@TypeOf(wgl.getProcAddress), "wglGetProcAddress").?;

    const opengl_context = wgl.createContext(hdc);
    if (wgl.makeCurrent(hdc, opengl_context) == w32.FALSE) {
        panic("Failed to create OpenGL context.", .{});
    }

    wgl.swapIntervalEXT = getProcAddress(@TypeOf(wgl.swapIntervalEXT), "wglSwapIntervalEXT").?;
    _ = wgl.swapIntervalEXT(1);

    gl.newList = getProcAddress(@TypeOf(gl.newList), "glNewList").?;
    gl.callList = getProcAddress(@TypeOf(gl.callList), "glCallList").?;
    gl.endList = getProcAddress(@TypeOf(gl.endList), "glEndList").?;
    gl.loadIdentity = getProcAddress(@TypeOf(gl.loadIdentity), "glLoadIdentity").?;
    gl.vertex2fv = getProcAddress(@TypeOf(gl.vertex2fv), "glVertex2fv").?;
    gl.vertex2fv = getProcAddress(@TypeOf(gl.vertex2fv), "glVertex2fv").?;
    gl.vertex3fv = getProcAddress(@TypeOf(gl.vertex3fv), "glVertex3fv").?;
    gl.vertex4fv = getProcAddress(@TypeOf(gl.vertex4fv), "glVertex4fv").?;
    gl.color3fv = getProcAddress(@TypeOf(gl.color3fv), "glColor3fv").?;
    gl.color4fv = getProcAddress(@TypeOf(gl.color4fv), "glColor4fv").?;
    gl.rectf = getProcAddress(@TypeOf(gl.rectf), "glRectf").?;
    gl.matrixMode = getProcAddress(@TypeOf(gl.matrixMode), "glMatrixMode").?;
    gl.hint = getProcAddress(@TypeOf(gl.hint), "glHint").?;
    gl.clearNamedFramebufferfv = getProcAddress(@TypeOf(gl.clearNamedFramebufferfv), "glClearNamedFramebufferfv").?;
    gl.matrixLoadIdentityEXT = getProcAddress(@TypeOf(gl.matrixLoadIdentityEXT), "glMatrixLoadIdentityEXT").?;
    gl.matrixOrthoEXT = getProcAddress(@TypeOf(gl.matrixOrthoEXT), "glMatrixOrthoEXT").?;
    gl.enable = getProcAddress(@TypeOf(gl.enable), "glEnable").?;
    gl.disable = getProcAddress(@TypeOf(gl.disable), "glDisable").?;
    gl.textureStorage2DMultisample = getProcAddress(@TypeOf(gl.textureStorage2DMultisample), "glTextureStorage2DMultisample").?;
    gl.textureStorage2D = getProcAddress(@TypeOf(gl.textureStorage2D), "glTextureStorage2D").?;
    gl.createTextures = getProcAddress(@TypeOf(gl.createTextures), "glCreateTextures").?;
    gl.deleteTextures = getProcAddress(@TypeOf(gl.deleteTextures), "glDeleteTextures").?;
    gl.createFramebuffers = getProcAddress(@TypeOf(gl.createFramebuffers), "glCreateFramebuffers").?;
    gl.deleteFramebuffers = getProcAddress(@TypeOf(gl.deleteFramebuffers), "glDeleteFramebuffers").?;
    gl.namedFramebufferTexture = getProcAddress(@TypeOf(gl.namedFramebufferTexture), "glNamedFramebufferTexture").?;
    gl.blitNamedFramebuffer = getProcAddress(@TypeOf(gl.blitNamedFramebuffer), "glBlitNamedFramebuffer").?;
    gl.bindFramebuffer = getProcAddress(@TypeOf(gl.bindFramebuffer), "glBindFramebuffer").?;
    gl.begin = getProcAddress(@TypeOf(gl.begin), "glBegin").?;
    gl.end = getProcAddress(@TypeOf(gl.end), "glEnd").?;
    gl.getError = getProcAddress(@TypeOf(gl.getError), "glGetError").?;
    gl.pointSize = getProcAddress(@TypeOf(gl.pointSize), "glPointSize").?;
    gl.lineWidth = getProcAddress(@TypeOf(gl.lineWidth), "glLineWidth").?;
    gl.blendFunc = getProcAddress(@TypeOf(gl.blendFunc), "glBlendFunc").?;
    gl.blendEquation = getProcAddress(@TypeOf(gl.blendEquation), "glBlendEquation").?;
    gl.vertex2f = getProcAddress(@TypeOf(gl.vertex2f), "glVertex2f").?;
    gl.vertex2d = getProcAddress(@TypeOf(gl.vertex2d), "glVertex2d").?;
    gl.vertex2i = getProcAddress(@TypeOf(gl.vertex2i), "glVertex2i").?;
    gl.color3f = getProcAddress(@TypeOf(gl.color3f), "glColor3f").?;
    gl.color4f = getProcAddress(@TypeOf(gl.color4f), "glColor4f").?;
    gl.color4ub = getProcAddress(@TypeOf(gl.color4ub), "glColor4ub").?;
    gl.pushMatrix = getProcAddress(@TypeOf(gl.pushMatrix), "glPushMatrix").?;
    gl.popMatrix = getProcAddress(@TypeOf(gl.popMatrix), "glPopMatrix").?;
    gl.rotatef = getProcAddress(@TypeOf(gl.rotatef), "glRotatef").?;
    gl.scalef = getProcAddress(@TypeOf(gl.scalef), "glScalef").?;
    gl.translatef = getProcAddress(@TypeOf(gl.translatef), "glTranslatef").?;
    gl.createShaderProgramv = getProcAddress(@TypeOf(gl.createShaderProgramv), "glCreateShaderProgramv").?;
    gl.useProgram = getProcAddress(@TypeOf(gl.useProgram), "glUseProgram").?;
    gl.bindBuffer = getProcAddress(@TypeOf(gl.bindBuffer), "glBindBuffer").?;
    gl.bindBufferRange = getProcAddress(@TypeOf(gl.bindBufferRange), "glBindBufferRange").?;
    gl.bindBufferBase = getProcAddress(@TypeOf(gl.bindBufferBase), "glBindBufferBase").?;
    gl.createBuffers = getProcAddress(@TypeOf(gl.createBuffers), "glCreateBuffers").?;
    gl.deleteBuffers = getProcAddress(@TypeOf(gl.deleteBuffers), "glDeleteBuffers").?;
    gl.namedBufferStorage = getProcAddress(@TypeOf(gl.namedBufferStorage), "glNamedBufferStorage").?;
    gl.clearTexImage = getProcAddress(@TypeOf(gl.clearTexImage), "glClearTexImage").?;
    gl.bindImageTexture = getProcAddress(@TypeOf(gl.bindImageTexture), "glBindImageTexture").?;
    gl.deleteProgram = getProcAddress(@TypeOf(gl.deleteProgram), "glDeleteProgram").?;
    gl.memoryBarrier = getProcAddress(@TypeOf(gl.memoryBarrier), "glMemoryBarrier").?;
    gl.colorMask = getProcAddress(@TypeOf(gl.colorMask), "glColorMask").?;
    gl.getIntegerv = getProcAddress(@TypeOf(gl.getIntegerv), "glGetIntegerv").?;
    gl.bindTextureUnit = getProcAddress(@TypeOf(gl.bindTextureUnit), "glBindTextureUnit").?;

    return opengl_context.?;
}

fn getProcAddress(comptime T: type, name: [:0]const u8) ?T {
    if (wgl.getProcAddress(name.ptr)) |addr| {
        return @ptrCast(T, addr);
    } else if (opengl32_dll.lookup(T, name)) |addr| {
        return addr;
    } else {
        panic("{s} not found", .{name});
    }
}

fn updateFrameStats(window: w32.HWND, name: [:0]const u8) struct { time: f64, delta_time: f32 } {
    const state = struct {
        var timer: std.time.Timer = undefined;
        var previous_time_ns: u64 = 0;
        var header_refresh_time_ns: u64 = 0;
        var frame_count: u64 = ~@as(u64, 0);
    };

    if (state.frame_count == ~@as(u64, 0)) {
        state.timer = std.time.Timer.start() catch unreachable;
        state.previous_time_ns = 0;
        state.header_refresh_time_ns = 0;
        state.frame_count = 0;
    }

    const now_ns = state.timer.read();
    const time = @intToFloat(f64, now_ns) / std.time.ns_per_s;
    const delta_time = @intToFloat(f32, now_ns - state.previous_time_ns) / std.time.ns_per_s;
    state.previous_time_ns = now_ns;

    if ((now_ns - state.header_refresh_time_ns) >= std.time.ns_per_s) {
        const t = @intToFloat(f64, now_ns - state.header_refresh_time_ns) / std.time.ns_per_s;
        const fps = @intToFloat(f64, state.frame_count) / t;
        const ms = (1.0 / fps) * 1000.0;

        var buffer = [_]u8{0} ** 128;
        const buffer_slice = buffer[0 .. buffer.len - 1];
        const header = std.fmt.bufPrint(
            buffer_slice,
            "[{d:.1} fps  {d:.3} ms] {s}",
            .{ fps, ms, name.ptr },
        ) catch buffer_slice;

        _ = w32x.user32.SetWindowTextA(window, @ptrCast(w32.LPCSTR, header.ptr));

        state.header_refresh_time_ns = now_ns;
        state.frame_count = 0;
    }
    state.frame_count += 1;

    return .{ .time = time, .delta_time = delta_time };
}

const w32x = struct {
    const user32 = struct {
        const VK_ESCAPE = 0x001B;

        extern "user32" fn SetProcessDPIAware() callconv(w32.WINAPI) bool;
        extern "user32" fn SetWindowTextA(hWnd: w32.HWND, lpString: w32.LPCSTR) callconv(w32.WINAPI) bool;
        extern "user32" fn LoadCursorA(
            hInstance: ?w32.HINSTANCE,
            lpCursorName: w32.LPCSTR,
        ) callconv(w32.WINAPI) w32.HCURSOR;
    };

    const gdi32 = struct {
        const PFD_DOUBLEBUFFER = 0x00000001;
        const PFD_SUPPORT_OPENGL = 0x00000020;
        const PFD_DRAW_TO_WINDOW = 0x00000004;
        const PFD_TYPE_RGBA = 0;
    };
};

fn processWindowMessage(
    window: w32.HWND,
    message: w32.UINT,
    wparam: w32.WPARAM,
    lparam: w32.LPARAM,
) callconv(.C) w32.LRESULT {
    const processed = switch (message) {
        w32.user32.WM_DESTROY => blk: {
            w32.user32.PostQuitMessage(0);
            break :blk true;
        },
        w32.user32.WM_KEYDOWN => blk: {
            if (wparam == w32x.user32.VK_ESCAPE) {
                w32.user32.PostQuitMessage(0);
                break :blk true;
            }
            break :blk false;
        },
        else => false,
    };
    return if (processed) 0 else w32.user32.DefWindowProcA(window, message, wparam, lparam);
}
