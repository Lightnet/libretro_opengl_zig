# libretro_opengl_zig

# License: MIT

# Information:
  Sample test to run on zig 0.16.0.

  Base on the some understand it almost the same format for c but using the namespace to handle c files.

  Using some reference and A.I model to help create sample test. It will run without rom. Render opengl 2D square by using the libretro common files.

# Project Dir:
- libretro-common d4a67f542e87ef7dbc94c08b875d22806453c351 ( folder download from github repo)
- src
- build.zig
- build.zig.zon

# build.zig:
  There are change in the config build for Zig 0.16.0

  It need to use opengl library for windows. It will error on missing function call example.

```
lld-link: undefined symbol: glViewport
```
  It need opengl dll to load those functions.

# main.zig:
  The file is library build for libretro core. Note the name functions must have match api call to be there else it will error.

```zig
// Import the Libretro core header definitions.
const retro = @cImport({
    @cInclude("libretro.h");
});
```


# opengl:
  Libretro common has built in opengl.
```zig
const gl = @cImport({
    @cInclude("glsym/glsym.h");
});
```

# Libretro Config:
  Note it need to setup in order to run core stand alone application to start core.
```zig
// Populates core metadata including name, version, and supported file extensions.
export fn retro_get_system_info(info: *retro.retro_system_info) callconv(.c) void {
    info.* = .{
        .library_name = "Zig Square Test",
        .library_version = "0.1",
        .valid_extensions = null, // null indicates no ROM files are needed.
        .need_fullpath = false,
        .block_extract = false,
    };
}
```

```
// Defines video constraints (dimensions, aspect ratio) and targeted frame rates.
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
```

```zig
// Frontend invokes this to provide the core with its primary environmental callback.
export fn retro_set_environment(cb: retro.retro_environment_t) callconv(.c) void {
    environ_cb = cb;
    if (cb) |c| {
        var no_rom = true;
        _ = c(retro.RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME, &no_rom);
    }
}
```

```zig
// Invoked when game loop initialization occurs. Here we request Hardware Acceleration.
export fn retro_load_game(game: ?*const retro.retro_game_info) callconv(.c) bool {
    _ = game;

    // Define OpenGL parameters requested by the core.
    hw_render = .{
        .context_type = retro.RETRO_HW_CONTEXT_OPENGL,
        .context_reset = context_reset,
        .context_destroy = context_destroy,
        .get_current_framebuffer = null, // RetroArch will supply this wrapper function pointer
        .get_proc_address = null,
        .depth = true,
        .stencil = false,
        .bottom_left_origin = true,
        .version_major = 2, // Request legacy OpenGL 2.1 environment.
        .version_minor = 1,
        .cache_context = false,
        .debug_context = false,
    };

    // Negotiate hardware context settings handshake with the frontend.
    if (environ_cb) |cb| {
        if (!cb(retro.RETRO_ENVIRONMENT_SET_HW_RENDER, &hw_render)) {
            std.log.err("Frontend failed to accept hardware rendering settings.", .{});
            return false;
        }
    }
    return true;
}
```

## render:
```zig
// Standard main frame loop executed roughly 60 times per second.
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

    // Render a deep blue background layout.
    gl.glClearColor(0.1, 0.1, 0.2, 1.0);
    gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);

    // Draw an orange quad centered in the middle of clip space.
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
```

# PATH:

```
RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY (system folder) (for BIOS/system files)
RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY (downloads folder)  (for custom text/font assets) ()
GET_FILE_BROWSER_START_DIRECTORY ( empty )
GET_LIBRETRO_PATH (cores folder libraries)
RETRO_ENVIRONMENT_GET_FILE_BROWSER_START_DIRECTORY
RETRO_ENVIRONMENT_GET_CONTENT_DIRECTORY (Deprecated legacy)
RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY ( /saves/<name library> folder) 

```


# Credits:
- Grok A.I
- Google A.I
  - More update Libretro common reasons.