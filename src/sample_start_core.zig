const std = @import("std");

// Libretro Constants
const RETRO_API_VERSION = 1;
const RETRO_REGION_NTSC = 0;

// Libretro Environment Commands
const RETRO_ENVIRONMENT_SET_PIXEL_FORMAT = 10;
const RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME = 18;
const RETRO_ENVIRONMENT_SET_HW_RENDER = 14;

// Libretro HW Context Types
const RETRO_HW_CONTEXT_OPENGL = 1;

// Libretro Pixel Formats
const RETRO_PIXEL_FORMAT_XRGB8888 = 1;

// Special Frame Buffer Pointer
const RETRO_HW_FRAME_BUFFER_VALID = @as(?*const anyopaque, @ptrFromInt(1));

// Function Pointer Signatures
const retro_environment_t = *const fn (cmd: c_uint, data: ?*anyopaque) callconv(.c) bool;
const retro_video_refresh_t = *const fn (data: ?*const anyopaque, width: c_uint, height: c_uint, pitch: usize) callconv(.c) void;
const retro_audio_sample_t = *const fn (left: i16, right: i16) callconv(.c) void;
const retro_audio_sample_batch_t = *const fn (data: ?*const i16, frames: usize) callconv(.c) usize;
const retro_input_poll_t = *const fn () callconv(.c) void;
const retro_input_state_t = *const fn (port: c_uint, device: c_uint, index: c_uint, id: c_uint) callconv(.c) i16;

const retro_hw_get_proc_address_t = *const fn (sym: [*:0]const u8) callconv(.c) ?*const anyopaque;
const retro_hw_get_current_framebuffer_t = *const fn () callconv(.c) usize;

// C-Equivalent Struct Types
pub const retro_hw_render_callback = extern struct {
    context_type: c_uint,
    context_reset: ?*const fn () callconv(.c) void,
    // Add '?' to make these nullable function pointers
    get_current_framebuffer: ?*const fn () callconv(.c) usize,
    get_proc_address: ?*const fn (sym: [*:0]const u8) callconv(.c) ?*const anyopaque,
    depth: u8,
    stencil: u8,
    bottom_left_origin: u8,
    version_major: c_uint,
    version_minor: c_uint,
    cache_context: u8,
    context_destroy: ?*const fn () callconv(.c) void,
    debug_context: u8,
};

pub const retro_game_geometry = extern struct {
    base_width: c_uint,
    base_height: c_uint,
    max_width: c_uint,
    max_height: c_uint,
    aspect_ratio: f32,
};

pub const retro_system_timing = extern struct {
    fps: f64,
    sample_rate: f64,
};

pub const retro_system_av_info = extern struct {
    geometry: retro_game_geometry,
    timing: retro_system_timing,
};

pub const struct_retro_system_info = extern struct {
    library_name: [*:0]const u8,
    library_version: [*:0]const u8,
    valid_extensions: ?[*:0]const u8,
    need_fullpath: bool,
    block_extract: bool,
};

// Global host callbacks state
var environ_cb: retro_environment_t = undefined;
var video_cb: retro_video_refresh_t = undefined;
var input_poll_cb: retro_input_poll_t = undefined;
var input_state_cb: retro_input_state_t = undefined;

// Current frame metrics
var screen_width: c_uint = 320;
var screen_height: c_uint = 240;
var frame_count: u32 = 0;

// Host hardware render context tracking
var hw_render: retro_hw_render_callback = undefined;

// Target System Info Definition
export fn retro_api_version() callconv(.c) c_uint {
    return RETRO_API_VERSION;
}

export fn retro_get_system_info(info: *struct_retro_system_info) callconv(.c) void {
    info.library_name = "Zig OpenGL Core";
    info.library_version = "v1";
    info.valid_extensions = null;
    info.need_fullpath = false;
    info.block_extract = false;
}

export fn retro_get_system_av_info(info: *retro_system_av_info) callconv(.c) void {
    info.timing = .{
        .fps = 60.0,
        .sample_rate = 0.0,
    };
    info.geometry = .{
        .base_width = 320,
        .base_height = 240,
        .max_width = 2048,
        .max_height = 2048,
        .aspect_ratio = 4.0 / 3.0,
    };
}

// Environment Registration Hooks
export fn retro_set_environment(cb: retro_environment_t) callconv(.c) void {
    environ_cb = cb;

    var no_rom: bool = true;
    _ = cb(RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME, &no_rom);
}

export fn retro_set_video_refresh(cb: retro_video_refresh_t) callconv(.c) void {
    video_cb = cb;
}
export fn retro_set_audio_sample(cb: retro_audio_sample_t) callconv(.c) void {
    _ = cb;
}
export fn retro_set_audio_sample_batch(cb: retro_audio_sample_batch_t) callconv(.c) void {
    _ = cb;
}
export fn retro_set_input_poll(cb: retro_input_poll_t) callconv(.c) void {
    input_poll_cb = cb;
}
export fn retro_set_input_state(cb: retro_input_state_t) callconv(.c) void {
    input_state_cb = cb;
}

// Hardware OpenGL Callbacks
fn context_reset() callconv(.c) void {
    std.log.info("OpenGL Context Created/Reset by Frontend!", .{});
    // This is where you call your Zig OpenGL symbol resolver!
    // Example: gl.loadUserProcAddress(hw_render.get_proc_address);
}

fn context_destroy() callconv(.c) void {
    std.log.info("OpenGL Context Destroyed!", .{});
}

// Core Execution Lifecycle Hooks
export fn retro_init() callconv(.c) void {}
export fn retro_deinit() callconv(.c) void {}
export fn retro_reset() callconv(.c) void {}

export fn retro_run() callconv(.c) void {
    input_poll_cb();
    frame_count += 1;

    // Safely unwrap and call if RetroArch has populated the function pointer
    if (hw_render.get_current_framebuffer) |get_fbo| {
        const current_fbo = get_fbo();
        _ = current_fbo;
    }

    // Report hardware frame completion to the engine
    video_cb(RETRO_HW_FRAME_BUFFER_VALID, screen_width, screen_height, 0);
}

export fn retro_load_game(game: ?*const anyopaque) callconv(.c) bool {
    _ = game;

    // 1. Establish the color architecture rules
    var fmt: c_uint = RETRO_PIXEL_FORMAT_XRGB8888;
    if (!environ_cb(RETRO_ENVIRONMENT_SET_PIXEL_FORMAT, &fmt)) {
        return false;
    }

    // 2. Build out clean, matching structure fields
    hw_render = .{
        .context_type = RETRO_HW_CONTEXT_OPENGL,
        .context_reset = context_reset,
        .context_destroy = context_destroy,
        .get_current_framebuffer = hw_render.get_current_framebuffer, // will be filled by frontend
        .get_proc_address = hw_render.get_proc_address, // will be filled by frontend
        .depth = 24, // better defaults
        .stencil = 8,
        .bottom_left_origin = 1,
        .version_major = 3, // request at least 3.2/3.3 core if you want modern GL
        .version_minor = 3,
        .cache_context = 0,
        .debug_context = 0,
    };

    // 3. Request the hardware rendering context assignment
    if (!environ_cb(RETRO_ENVIRONMENT_SET_HW_RENDER, &hw_render)) {
        return false;
    }

    return true;
}

export fn retro_unload_game() callconv(.c) void {}

// Remaining Libretro Core Stubs
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
export fn retro_load_game_special(game_type: c_uint, info: ?*anyopaque, num_info: usize) callconv(.c) bool {
    _ = game_type;
    _ = info;
    _ = num_info;
    return false;
}
export fn retro_get_region() callconv(.c) c_uint {
    return RETRO_REGION_NTSC;
}
export fn retro_get_memory_data(id: c_uint) callconv(.c) ?*anyopaque {
    _ = id;
    return null;
}
export fn retro_get_memory_size(id: c_uint) callconv(.c) usize {
    _ = id;
    return 0;
}
