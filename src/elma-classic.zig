const std = @import("std");
const sorvi = @import("sorvi");

// TODO: sorvi needs text input extension
// TODO: pass mouse to elma

pub const std_options: std.Options = .{
    .logFn = sorvi.defaultLog,
    .queryPageSize = sorvi.queryPageSize,
    .page_size_max = sorvi.page_size_max,
    .log_level = .debug,
};

pub const os = sorvi.os;
pub const panic = std.debug.FullPanic(sorvi.defaultPanic);

comptime {
    sorvi.init(@This(), .{
        .id = "org.sorvi.elma_classic",
        .name = "elma",
        .version = "0.0.0",
        .core_extensions = &.{ .core_v1, .audio_v1, .video_v1, .kbm_v1 },
        .frontend_extensions = &.{ .core_v1, .mem_v1, .audio_v1, .raster_v1, .thread_v1 },
    });
}

const ELMA_WIDTH = 800;
const ELMA_HEIGHT = 600;

ns_since_last_update: u64 = 0,
elma_time: u64 = 0,

pub fn init(_: *@This()) !void {
    try sorvi.raster_v1.init(.{
        .format = .xbgr8888,
        .scaling = &.{
            .raster_w = ELMA_WIDTH,
            .raster_h = ELMA_HEIGHT,
            .scale = .integer,
            .filter = .nearest,
        },
        .direct = false,
    });

    try sorvi.video_v1.configure(.{
        .w = ELMA_WIDTH * 2,
        .h = ELMA_HEIGHT * 2,
        .flags = .{ .border = true },
        .presentation = .dont_care,
        .mode = .default,
    });

    _ = try sorvi.audio_v1.init(.{
        .format = .s16le,
        .layout = .mono,
        .sample_rate = 11025,
        .buffer_size = 512,
        .direct = false,
    });

    try sorvi.audio_v1.cmd(.@"resume");

    const wrapper = struct {
        extern fn elma_platform_run() void;

        fn fun(_: *sorvi.thread_v1.arg_t) callconv(.c) void {
            elma_platform_run();
        }
    };

    // elma-classic is written using busy loops
    // we need to "asyncify" the execution
    const thread = try sorvi.thread_v1.spawn(.{
        .stack_size = std.Thread.SpawnConfig.default_stack_size,
        .entry = @intFromPtr(&wrapper.fun),
        .arg = @ptrFromInt(0xDEADBEEF),
    });
    sorvi.thread_v1.detach(thread);

    // make sure that the execution is serial
    elma_platform_wait_for_frame();
}

pub fn deinit(_: *@This()) void {}

fn toElmaKey(code: sorvi.kbm_v1.scancode_t) ?u32 {
    return switch (code) {
        .escape => 0x01,
        .enter => 0x1c,
        .space => 0x39,
        .a => 0x1e,
        .b => 0x30,
        .c => 0x2e,
        .d => 0x20,
        .e => 0x12,
        .f => 0x21,
        .g => 0x22,
        .h => 0x23,
        .i => 0x17,
        .j => 0x24,
        .k => 0x25,
        .l => 0x26,
        .m => 0x32,
        .n => 0x31,
        .o => 0x18,
        .p => 0x19,
        .q => 0x10,
        .r => 0x13,
        .s => 0x1f,
        .t => 0x14,
        .u => 0x16,
        .v => 0x2f,
        .w => 0x11,
        .x => 0x2d,
        .y => 0x15,
        .z => 0x2c,
        .@"0" => 0x0b,
        .@"1" => 0x02,
        .@"2" => 0x03,
        .@"3" => 0x04,
        .@"4" => 0x05,
        .@"5" => 0x06,
        .@"6" => 0x07,
        .@"7" => 0x08,
        .@"8" => 0x09,
        .@"9" => 0x0a,
        .f1 => 0x3b,
        .f2 => 0x3c,
        .f3 => 0x3d,
        .f4 => 0x3e,
        .f5 => 0x3f,
        .f6 => 0x40,
        .f7 => 0x41,
        .f8 => 0x42,
        .f9 => 0x43,
        .f10 => 0x44,
        .f11 => 0x57,
        .f12 => 0x58,
        .left_shift => 0x2a,
        .right_shift => 0x36,
        .left_control => 0x1d,
        .right_control => 0x9d,
        .left_arrow => 0xcb,
        .right_arrow => 0xcd,
        .up_arrow => 0xc8,
        .down_arrow => 0xd0,
        else => null,
    };
}

extern fn elma_platform_key(u32, bool) void;

pub fn kbmKeyPress(_: *@This(), _: u64, _: sorvi.kbm_v1.absolute_t, _: sorvi.kbm_v1.modifiers_t, code: sorvi.kbm_v1.scancode_t) !void {
    if (toElmaKey(code)) |key| {
        elma_platform_key(key, true);
    }
}

pub fn kbmKeyRelease(_: *@This(), _: u64, _: sorvi.kbm_v1.absolute_t, _: sorvi.kbm_v1.modifiers_t, code: sorvi.kbm_v1.scancode_t) !void {
    if (toElmaKey(code)) |key| {
        elma_platform_key(key, false);
    }
}

extern fn elma_platform_button(u32, bool) void;

pub fn kbmButtonPress(_: *@This(), _: u64, _: sorvi.kbm_v1.absolute_t, _: sorvi.kbm_v1.modifiers_t, button: sorvi.kbm_v1.button_t) !void {
    switch (button) {
        .left => elma_platform_button(0, true),
        .right => elma_platform_button(1, true),
        else => {},
    }
}

pub fn kbmButtonRelease(_: *@This(), _: u64, _: sorvi.kbm_v1.absolute_t, _: sorvi.kbm_v1.modifiers_t, button: sorvi.kbm_v1.button_t) !void {
    switch (button) {
        .left => elma_platform_button(0, false),
        .right => elma_platform_button(1, false),
        else => {},
    }
}

pub fn kbmMouseMotion(_: *@This(), _: u64, _: sorvi.kbm_v1.absolute_t, _: sorvi.kbm_v1.modifiers_t, _: sorvi.kbm_v1.relative_t) !void {}

pub fn kbmMouseScroll(_: *@This(), _: u64, _: sorvi.kbm_v1.absolute_t, _: sorvi.kbm_v1.modifiers_t, _: sorvi.kbm_v1.relative_t) !void {}

extern fn elma_platform_mix_sound([*]align(1) i16, usize) void;

pub fn audioTick(_: *@This(), u8_buffer: []u8) !void {
    const s16_buffer = std.mem.bytesAsSlice(i16, u8_buffer);
    elma_platform_mix_sound(s16_buffer.ptr, s16_buffer.len);
}

var frame_mutex: sorvi.Mutex = .init;
var frame_cond: sorvi.Condition = .init;

extern fn elma_platform_frame_data(u16, u16, [*]u8, u64) void;

pub fn videoTick(self: *@This(), frame: sorvi.video_v1.frame_t) !u64 {
    std.debug.assert(frame.w == ELMA_WIDTH and frame.h == ELMA_HEIGHT);
    const target_rate = std.time.ns_per_s / 60;
    self.elma_time += frame.time_ns;
    self.ns_since_last_update += frame.time_ns;
    if (target_rate > self.ns_since_last_update) return target_rate - self.ns_since_last_update;
    const buffer = try sorvi.raster_v1.acquire_buffer();
    while (self.ns_since_last_update >= target_rate) {
        self.ns_since_last_update -= target_rate;
        elma_platform_frame_data(frame.w, frame.h, buffer.ptr, self.elma_time / std.time.ns_per_ms);
        elma_platform_wait_for_frame();
    }
    sorvi.raster_v1.damage(&.{.{ .x = 0, .y = 0, .w = frame.w, .h = frame.h }});
    return target_rate - self.ns_since_last_update;
}

export fn elma_platform_wait_for_frame() void {
    frame_mutex.lock();
    defer frame_mutex.unlock();
    frame_cond.signal();
    frame_cond.wait(&frame_mutex);
}
