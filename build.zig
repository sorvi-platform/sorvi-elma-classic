const std = @import("std");
const sorvi = @import("sorvi");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sorvi_dep = b.dependency("sorvi", .{
        .target = target,
        .optimize = optimize,
    });
    const frontend = sorvi_dep.artifact("sorvi-frontend");

    const sorvi_api = sorvi.createSorviAPI(b, .{
        .target = target,
        .api = .core,
        .extensions = &.{
            "ext",
            "core_v1",
            "mem_v1",
            "kbm_v1",
            "audio_v1",
            "video_v1",
            "raster_v1",
            "thread_v1",
        },
    });

    const sorvi_target = sorvi.resolveSorviTarget(b, target.query);

    const json_dep = b.dependency("json", .{});
    const elma_dep = b.dependency("elma_classic", .{});
    const elma_lib = b.addLibrary(.{
        .name = "elma-classic",
        .linkage = .static,
        .root_module = D: {
            const mod = b.createModule(.{
                .target = sorvi_target,
                .optimize = optimize,
                .link_libc = true,
                .link_libcpp = true,
                .sanitize_c = .off,
            });
            mod.addCSourceFiles(.{
                .files = &.{"src/platform_sorvi.cpp"},
                .flags = &.{"-std=c++20"},
            });
            mod.addCSourceFiles(.{
                .files = &.{
                    "abc8.cpp",                        "physics_init.cpp",      "anim.cpp",
                    "physics_move.cpp",                "best_times.cpp",        "src/menu/controls.cpp",
                    "editor_dialog.cpp",               "src/menu/dialog.cpp",   "timer.cpp",
                    "editor_canvas.cpp",               "affine_pic_render.cpp", "D_PIC.CPP",
                    "canvas.cpp",                      "editor_help.cpp",       "src/editor/window.cpp",
                    "EDITTOOL.CPP",                    "EDITUJ.CPP",            "editor_topology.cpp",
                    "flagtag.cpp",                     "ball_handler.cpp",      "ball.cpp",
                    "ball_collision.cpp",              "polygon.cpp",           "wav.cpp",
                    "src/menu/player.cpp",             "KIRAJ320.CPP",          "affine_pic.cpp",
                    "grass.cpp",                       "platform_utils.cpp",    "LEJATSZO.CPP",
                    "physics_forces.cpp",              "lgr.cpp",               "level_load.cpp",
                    "main.cpp",                        "src/menu/main.cpp",     "src/menu/external.cpp",
                    "src/menu/pic.cpp",                "src/menu/options.cpp",  "pic8.cpp",
                    "piclist.cpp",                     "src/menu/play.cpp",     "qopen.cpp",
                    "recorder.cpp",                    "src/menu/rec_list.cpp", "src/menu/replay.cpp",
                    "src/menu/replay_cache.cpp",       "skip.cpp",              "src/eol/status_messages.cpp",
                    "state.cpp",                       "segments.cpp",          "src/menu/intro.cpp",
                    "physics_collision.cpp",           "level.cpp",             "src/menu/nav.cpp",
                    "vect2.cpp",                       "eol_settings.cpp",      "sound_engine.cpp",
                    "keys.cpp",                        "fs_utils.cpp",          "object.cpp",
                    "src/renderer/object_overlay.cpp", "sprite.cpp",            "src/debug/profiler.cpp",
                    "src/eol/console.cpp",             "src/eol/eol.cpp",       "src/eol/eol_table.cpp",
                    "src/util/util.cpp",
                },
                .flags = &.{ "-std=c++20", "-DELMA_VERSION=\"1.4\"", "-DELMA_SHAREWARE=1", "-Dmain=elma_main" },
                .root = elma_dep.path(""),
            });
            mod.addIncludePath(elma_dep.path(""));
            mod.addIncludePath(elma_dep.path("include"));
            mod.addIncludePath(json_dep.path("include"));
            break :D mod;
        },
    });

    var assets = b.addWriteFiles();
    _ = assets.addCopyDirectory(b.path("assets"), "", .{});
    _ = assets.addCopyDirectory(elma_dep.path("resources"), "resources", .{});

    const elma = sorvi.addSorviCore(b, .{
        .name = "elma-classic",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/elma-classic.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
            .imports = &.{
                .{ .name = "sorvi", .module = sorvi_api },
            },
        }),
        .assets = assets,
    });
    elma.root_module.linkLibrary(elma_lib);
    elma.fixup(b);

    const step = b.step("run", "Run elma-classic in a reference frontend");
    step.dependOn(&sorvi.addRunSorviCore(b, frontend, elma).step);
}
