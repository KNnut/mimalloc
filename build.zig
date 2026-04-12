const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // TODO: add an option to disable override
    if (target.result.os.tag == .windows)
        return error.UnsupportedOperatingSystem;

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .sanitize_c = .off,
    });

    const upstream_dep = b.dependency("mimalloc", .{
        .target = target,
        .optimize = optimize,
    });
    mod.addIncludePath(upstream_dep.path("include"));

    mod.addCMacro("MI_MALLOC_OVERRIDE", "");

    if (optimize != .Debug)
        mod.addCMacro("MI_BUILD_RELEASE", "");

    var cflags: std.ArrayList([]const u8) = .empty;
    try cflags.appendSlice(b.allocator, &.{
        "-Wno-unknown-pragmas",
        "-fvisibility=hidden",
        "-Wstrict-prototypes",
        "-Wno-static-in-inline",
        "-Wno-date-time",
        "-fno-builtin-malloc",
    });

    if (target.result.abi.isMusl()) {
        mod.addCMacro("MI_LIBC_MUSL", "");
        try cflags.append(b.allocator, "-ftls-model=local-dynamic");
    } else {
        try cflags.append(b.allocator, "-ftls-model=initial-exec");
    }

    // https://github.com/microsoft/mimalloc/issues/1134
    if (target.result.os.tag == .wasi)
        mod.addCMacro("mi_align_up_ptr", "_mi_align_up_ptr");

    {
        const secure = b.option(
            SecureLevel,
            "secure",
            "Security mitigations",
        );

        const debug = b.option(
            DebugLevel,
            "debug",
            "Assertion and invariant checking",
        );

        const stat = b.option(
            StatLevel,
            "stat",
            "Statistics",
        );

        const flags = .{ secure, debug, stat };
        const macros = .{ "SECURE", "DEBUG", "STAT" };

        inline for (flags, macros) |flag, macro|
            if (flag) |level|
                mod.addCMacro("MI_" ++ macro, b.fmt("{d}", .{level}));
    }

    {
        const xmalloc = b.option(
            bool,
            "xmalloc",
            "abort() call on memory allocation failure by default",
        ) orelse false;

        const show_errors = b.option(
            bool,
            "show-errors",
            "Printing of error and warning messages by default",
        ) orelse (optimize == .Debug);

        const guarded = b.option(
            bool,
            "guarded",
            "Guard pages behind certain object allocations",
        ) orelse (optimize == .Debug);

        const simd = b.option(
            bool,
            "simd",
            "Use SIMD instructions if available",
        ) orelse false;

        const flags = .{ xmalloc, show_errors, guarded, simd };
        const macros = .{ "XMALLOC", "SHOW_ERRORS", "GUARDED", "OPT_SIMD" };

        inline for (flags, macros) |flag, macro|
            if (flag)
                mod.addCMacro("MI_" ++ macro, "1");
    }

    {
        const padding = b.option(
            bool,
            "padding",
            "Explicit padding of heap blocks",
        );

        if (padding) |f|
            mod.addCMacro("MI_PADDING", if (f) "1" else "0");
    }

    mod.addCSourceFile(.{
        .language = .c,
        .file = upstream_dep.path("src/static.c"),
        .flags = cflags.items,
    });

    const object = b.option(
        bool,
        "object",
        "Single object file",
    ) orelse false;

    if (object) {
        const obj = b.addObject(.{
            .name = "mimalloc",
            .root_module = mod,
        });
        const install_artifact = b.addInstallArtifact(obj, .{
            .dest_dir = .{ .override = .{ .custom = "obj" } },
        });
        b.getInstallStep().dependOn(&install_artifact.step);
    } else {
        const lib = b.addLibrary(.{
            .linkage = .static,
            .name = "mimalloc",
            .root_module = mod,
        });
        inline for (headers) |header|
            lib.installHeader(upstream_dep.path("include/" ++ header), header);
        b.installArtifact(lib);
    }
}

const StatLevel = enum(u8) {
    low = 0,
    medium = 1,
    full = 2,
};

const SecureLevel = enum(u8) {
    off = 0,
    low = 1,
    medium = 2,
    high = 3,
    full = 4,
};

const DebugLevel = enum(u8) {
    off = 0,
    low = 1,
    medium = 2,
    full = 3,
};

const headers = &[_][]const u8{
    "mimalloc.h", "mimalloc-override.h", "mimalloc-new-delete.h", "mimalloc-stats.h",
};
