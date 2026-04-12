# mimalloc

[mimalloc](https://github.com/microsoft/mimalloc) on the [Zig Build System](https://ziglang.org/learn/build-system/).

## Usage

Add this package to `build.zig.zon`:

```sh
zig fetch --save git+https://github.com/KNnut/mimalloc
```

### Static library

Import `mimalloc` in `build.zig` with:

```zig
const mimalloc_dep = b.dependency("mimalloc", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.linkLibrary(mimalloc_dep.artifact("mimalloc"));
```

### Object file

Link with the `mimalloc` single object file in `build.zig` with:

```zig
const mimalloc_dep = b.dependency("mimalloc", .{
    .target = target,
    .optimize = optimize,
    .object = true,
});
exe.root_module.addObject(mimalloc_dep.artifact("mimalloc"));
```
