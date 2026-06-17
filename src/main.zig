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

// =============================================

export fn retro_api_version() callconv(.c) c_uint {
    return retro.RETRO_API_VERSION;
}

export fn retro_get_system_info(info: *retro.retro_system_info) callconv(.c) void {
    info.* = .{
        .library_name = "Zig Square Test",
        .library_version = "0.1",
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
    std.log.info("Context Reset - Initializing glsym", .{});

    if (hw_render.get_proc_address) |get_proc| {
        gl.rglgen_resolve_symbols(get_proc);
    } else {
        std.log.err("glsym critical error: get_proc_address is null!", .{});
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
        .get_current_framebuffer = null, // RetroArch will supply this wrapper function pointer
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
        if (!cb(retro.RETRO_ENVIRONMENT_SET_HW_RENDER, &hw_render)) {
            std.log.err("Frontend failed to accept hardware rendering settings.", .{});
            return false;
        }
    }
    return true;
}

export fn retro_run() callconv(.c) void {
    if (input_poll_cb) |poll| poll();

    // CHANGE 1: Bind RetroArch's internal Framebuffer target before drawing
    if (hw_render.get_current_framebuffer) |get_fbo| {
        const fbo_id = get_fbo();
        // Since glsym redefines standard GL bindings, call through gl prefix
        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, @intCast(fbo_id));
    }

    // Set view scale viewport explicitly matching geometry resolution
    gl.glViewport(0, 0, 640, 480);

    gl.glClearColor(0.1, 0.1, 0.2, 1.0);
    gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);

    gl.glBegin(gl.GL_QUADS);
    gl.glColor3f(1.0, 0.5, 0.0);

    gl.glVertex2f(-0.5, -0.5);
    gl.glVertex2f(0.5, -0.5);
    gl.glVertex2f(0.5, 0.5);
    gl.glVertex2f(-0.5, 0.5);

    gl.glEnd();

    // CHANGE 2: Inform RetroArch that the hardware framebuffer is fully drawn.
    // Pass RETRO_HW_FRAME_BUFFER_VALID as the primary data pointer address.
    if (video_cb) |vcb| {
        vcb(retro.RETRO_HW_FRAME_BUFFER_VALID, 640, 480, 0);
    }
}

// Boilerplate
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
