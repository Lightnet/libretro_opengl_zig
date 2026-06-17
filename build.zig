const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. Set up the dynamic library (DLL) artifact
    const lib = b.addLibrary(.{
        .name = "my_retro_core_libretro",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true, // <-- Correct way to link LibC in the module settings
        }),
    });

    // 2. Translate C headers
    // const c_translation = b.addTranslateC(.{
    //     .root_source_file = b.path("libretro-common/include/libretro.h"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // lib.root_module.addImport("c", c_translation.createModule());

    lib.root_module.addIncludePath(b.path("libretro-common/include"));
    lib.root_module.addIncludePath(b.path("libretro-common")); // ← Important

    // === Add these C files for glsym ===
    // lib.root_module.addCSourceFile(.{ .file = b.path("libretro-common/glsym/rglgen.c") });
    // lib.root_module.addCSourceFile(.{ .file = b.path("libretro-common/glsym/glsym_gl.c") });
    // 3. Define macro flags for compilation
    // Both files require HAVE_OPENGL to load the correct header sections.
    const c_flags = &[_][]const u8{
        "-DHAVE_OPENGL=1",
    };

    // 4. Compile libretro-common dependencies with flags
    lib.root_module.addCSourceFile(.{ .file = b.path("libretro-common/glsym/rglgen.c"), .flags = c_flags });
    lib.root_module.addCSourceFile(.{ .file = b.path("libretro-common/glsym/glsym_gl.c"), .flags = c_flags });

    // 5. Link system graphics libraries based on target
    if (target.result.os.tag == .windows) {
        lib.root_module.linkSystemLibrary("opengl32", .{});
    } else if (target.result.os.tag == .macos) {
        lib.root_module.linkFramework("OpenGL", .{});
    } else {
        // Linux / BSD systems
        lib.root_module.linkSystemLibrary("GL", .{});
    }

    b.installArtifact(lib);
}
