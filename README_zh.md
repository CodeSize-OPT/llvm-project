# LLVM Project Local Build Notes

这个仓库是本地使用的 `llvm-project` 源码树，当前主要关注以下组件的构建：

- `llvm`
- `clang`
- `clang-tools-extra`

仓库内提供了一个统一构建脚本 [build.sh](build.sh)，用于快速完成配置、编译，以及按需安装。

## Build Script Defaults

`build.sh` 当前固定使用以下工具链：

- Build generator: `ninja`
- C compiler: `clang-14`
- C++ compiler: `clang++-14`
- Linker: `ld.lld`

默认路径：

- Source dir: `llvm`
- Build dir: `build`
- Install dir: `../llvm-install`

默认行为：

- 默认只构建，不安装
- 只有显式传入 `-i` 或 `--install` 时才执行安装
- 默认构建类型为 `Release`
- 默认构建：X86、ARM、AArch64、RISCV
- 默认关闭 tests/examples/benchmarks

## Prerequisites

运行脚本前，需要确保以下命令可用：

```bash
ninja
clang-14
clang++-14
ld.lld
cmake
```

如果缺少其中任意一个，脚本会直接报错退出。

## Common Commands
```bash
./build.sh --clean -j "$(nproc)" 
```

## Help

查看脚本帮助：

```bash
./build.sh -h
```