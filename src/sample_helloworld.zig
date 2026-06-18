const std = @import("std");

const retro = @cImport({
    @cInclude("libretro.h");
});

const gl = @cImport({
    @cInclude("glsym/glsym.h");
});

// Globals
var environ_cb: retro.retro_environment_t = null;
var video_cb: retro.retro_video_refresh_t = null;
var input_poll_cb: retro.retro_input_poll_t = null;
var hw_render: retro.retro_hw_render_callback = undefined;

// ============================================================================
// NEW: 8x8 Retro Font Binary Bitmap Atlas
// ============================================================================
// Each line of 8 pixels is represented by 1 byte (where a 1 bit is a filled pixel).
const font_8x8 = struct {
    const H = [_]u8{ 0x66, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00 };
    const e = [_]u8{ 0x00, 0x00, 0x3C, 0x66, 0x7E, 0x60, 0x3C, 0x00 };
    const l = [_]u8{ 0x1C, 0x08, 0x08, 0x08, 0x08, 0x08, 0x1C, 0x00 };
    const o = [_]u8{ 0x00, 0x00, 0x3C, 0x66, 0x66, 0x66, 0x3C, 0x00 };
    const W = [_]u8{ 0x66, 0x66, 0x66, 0x66, 0x6E, 0x7F, 0x31, 0x00 };
    const r = [_]u8{ 0x00, 0x00, 0x2E, 0x30, 0x20, 0x20, 0x20, 0x00 };
    const d = [_]u8{ 0x02, 0x02, 0x3E, 0x66, 0x66, 0x66, 0x3E, 0x00 };
    const comma = [_]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x08 };
    const excl = [_]u8{ 0x18, 0x18, 0x18, 0x18, 0x00, 0x00, 0x18, 0x00 };
    const space = [_]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
};

// Maps an ASCII character byte to its corresponding 8x8 bitmap array data matrix
fn getGlyph(char: u8) [8]u8 {
    return switch (char) {
        'H' => font_8x8.H,
        'e' => font_8x8.e,
        'l' => font_8x8.l,
        'o' => font_8x8.o,
        'W' => font_8x8.W,
        'r' => font_8x8.r,
        'd' => font_8x8.d,
        ',' => font_8x8.comma,
        '!' => font_8x8.excl,
        else => font_8x8.space,
    };
}

// Draws a single character using pixel manipulation scaled via standard OpenGL primitives
fn drawChar(char: u8, start_x: f32, start_y: f32, size: f32) void {
    const glyph = getGlyph(char);
    const pixel_size = size / 8.0;

    // Outer loops process the bitmap row by row, column by column
    var row: usize = 0;
    while (row < 8) : (row += 1) {
        const byte = glyph[row];
        var col: usize = 0;
        while (col < 8) : (col += 1) {
            // Check if the bit index is active (reading from Left to Right bits)
            if (((byte >> @intCast(7 - col)) & 1) == 1) {
                // Compute standard screen space constraints for rendering this pixel quad
                const px = start_x + (@as(f32, @floatFromInt(col)) * pixel_size);
                const py = start_y - (@as(f32, @floatFromInt(row)) * pixel_size);

                gl.glBegin(gl.GL_QUADS);
                gl.glVertex2f(px, py);
                gl.glVertex2f(px + pixel_size, py);
                gl.glVertex2f(px + pixel_size, py - pixel_size);
                gl.glVertex2f(px, py - pixel_size);
                gl.glEnd();
            }
        }
    }
}

// Iterates across a string array layout to draw text on screen
fn drawString(str: []const u8, x: f32, y: f32, char_size: f32, tracking: f32) void {
    for (str, 0..) |char, i| {
        const offset_x = x + (@as(f32, @floatFromInt(i)) * (char_size + tracking));
        drawChar(char, offset_x, y, char_size);
    }
}

// ============================================================================
// Libretro Lifecycle API Hooks
// ============================================================================

export fn retro_api_version() callconv(.c) c_uint {
    return retro.RETRO_API_VERSION;
}

export fn retro_get_system_info(info: *retro.retro_system_info) callconv(.c) void {
    info.* = .{
        .library_name = "Zig Hello World Text Test",
        .library_version = "0.2",
        .valid_extensions = null,
        .need_fullpath = false,
        .block_extract = false,
    };
}

export fn retro_get_system_av_info(info: *retro.retro_system_av_info) callconv(.c) void {
    info.* = .{
        .geometry = .{
            .base_width = 640,
            .base_height = 480,
            .max_width = 640,
            .max_height = 480,
            .aspect_ratio = 4.0 / 3.0,
        },
        .timing = .{ .fps = 60.0, .sample_rate = 0.0 },
    };
}

export fn retro_set_environment(cb: retro.retro_environment_t) callconv(.c) void {
    environ_cb = cb;
    if (cb) |c| {
        var no_rom = true;
        _ = c(retro.RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME, &no_rom);
    }
}

export fn retro_set_video_refresh(cb: retro.retro_video_refresh_t) callconv(.c) void {
    video_cb = cb;
}
export fn retro_set_input_poll(cb: retro.retro_input_poll_t) callconv(.c) void {
    input_poll_cb = cb;
}
export fn retro_set_audio_sample(cb: retro.retro_audio_sample_t) callconv(.c) void {
    _ = cb;
}
export fn retro_set_audio_sample_batch(cb: retro.retro_audio_sample_batch_t) callconv(.c) void {
    _ = cb;
}
export fn retro_set_input_state(cb: retro.retro_input_state_t) callconv(.c) void {
    _ = cb;
}

fn context_reset() callconv(.c) void {
    if (hw_render.get_proc_address) |get_proc| {
        gl.rglgen_resolve_symbols(get_proc);
    }
}

fn context_destroy() callconv(.c) void {
    std.log.info("Context Destroyed", .{});
}

export fn retro_load_game(game: ?*const retro.retro_game_info) callconv(.c) bool {
    _ = game;
    hw_render = .{
        .context_type = retro.RETRO_HW_CONTEXT_OPENGL,
        .context_reset = context_reset,
        .context_destroy = context_destroy,
        .get_current_framebuffer = null,
        .get_proc_address = null,
        .depth = true,
        .stencil = false,
        .bottom_left_origin = true,
        .version_major = 2,
        .version_minor = 1,
        .cache_context = false,
        .debug_context = false,
    };

    if (environ_cb) |cb| {
        if (!cb(retro.RETRO_ENVIRONMENT_SET_HW_RENDER, &hw_render)) return false;
    }
    return true;
}

export fn retro_run() callconv(.c) void {
    if (input_poll_cb) |poll| poll();

    if (hw_render.get_current_framebuffer) |get_fbo| {
        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, @intCast(get_fbo()));
    }

    gl.glViewport(0, 0, 640, 480);
    gl.glClearColor(0.1, 0.1, 0.2, 1.0);
    gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);

    // 1. Draw the baseline background orange quad
    gl.glBegin(gl.GL_QUADS);
    gl.glColor3f(1.0, 0.5, 0.0);
    gl.glVertex2f(-0.6, -0.6);
    gl.glVertex2f(0.6, -0.6);
    gl.glVertex2f(0.6, 0.6);
    gl.glVertex2f(-0.6, 0.6);
    gl.glEnd();

    // 2. Draw the text layers directly on top using bright white coloring
    gl.glColor3f(1.0, 1.0, 1.0);

    // Arguments: (String, Start X, Start Y, Character Size, Kerning Spacing)
    drawString("Hello, World!", -0.5, 0.1, 0.08, 0.01);

    if (video_cb) |vcb| {
        vcb(retro.RETRO_HW_FRAME_BUFFER_VALID, 640, 480, 0);
    }
}

// Boilerplate Unused Implementation
export fn retro_init() callconv(.c) void {}
export fn retro_deinit() callconv(.c) void {}
export fn retro_reset() callconv(.c) void {}
export fn retro_unload_game() callconv(.c) void {}
export fn retro_set_controller_port_device(port: c_uint, device: c_uint) callconv(.c) void {
    _ = port;
    _ = device;
}
export fn retro_serialize(data: ?*anyopaque, size: usize) callconv(.c) bool {
    _ = data;
    _ = size;
    return false;
}
export fn retro_unserialize(data: ?*const anyopaque, size: usize) callconv(.c) bool {
    _ = data;
    _ = size;
    return false;
}
export fn retro_serialize_size() callconv(.c) usize {
    return 0;
}
export fn retro_cheat_reset() callconv(.c) void {}
export fn retro_cheat_set(index: c_uint, is_code: bool, code: [*:0]const u8) callconv(.c) void {
    _ = index;
    _ = is_code;
    _ = code;
}
export fn retro_load_game_special(game_type: c_uint, info: ?*const retro.retro_game_info, num_info: usize) callconv(.c) bool {
    _ = game_type;
    _ = info;
    _ = num_info;
    return false;
}
export fn retro_get_region() callconv(.c) c_uint {
    return retro.RETRO_REGION_NTSC;
}
export fn retro_get_memory_data(id: c_uint) callconv(.c) ?*anyopaque {
    _ = id;
    return null;
}
export fn retro_get_memory_size(id: c_uint) callconv(.c) usize {
    _ = id;
    return 0;
}
