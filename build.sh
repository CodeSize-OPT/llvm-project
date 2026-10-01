#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/llvm"
DEFAULT_BUILD_DIR="${SCRIPT_DIR}/build"
DEFAULT_INSTALL_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)/llvm-install"

BUILD_DIR="${DEFAULT_BUILD_DIR}"
INSTALL_DIR="${DEFAULT_INSTALL_DIR}"
BUILD_TYPE="Release"
JOBS="${JOBS:-$(nproc)}"
INSTALL_AFTER_BUILD=0
CLEAN_BUILD=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [-- extra-cmake-options...]

Options:
  -B, --build-dir <dir>     Build directory (default: ${DEFAULT_BUILD_DIR})
  -I, --install-dir <dir>   Install directory (default: ${DEFAULT_INSTALL_DIR})
  -t, --build-type <type>   CMake build type (default: Release)
  -j, --jobs <n>            Parallel build jobs (default: nproc)
  -i, --install             Run 'cmake --install' after build
      --clean               Remove build directory before configuring
  -h, --help                Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --clean -j "$(nproc)"
  $(basename "$0") -i -I /opt/llvm
  $(basename "$0") -- -DLLVM_ENABLE_ASSERTIONS=ON
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  local cmd="$1"
  have_cmd "${cmd}" || die "required command not found: ${cmd}"
}

EXTRA_CMAKE_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -B|--build-dir)
      [[ $# -ge 2 ]] || die "missing value for $1"
      BUILD_DIR="$2"
      shift 2
      ;;
    -I|--install-dir)
      [[ $# -ge 2 ]] || die "missing value for $1"
      INSTALL_DIR="$2"
      shift 2
      ;;
    -t|--build-type)
      [[ $# -ge 2 ]] || die "missing value for $1"
      BUILD_TYPE="$2"
      shift 2
      ;;
    -j|--jobs)
      [[ $# -ge 2 ]] || die "missing value for $1"
      JOBS="$2"
      shift 2
      ;;
    -i|--install)
      INSTALL_AFTER_BUILD=1
      shift
      ;;
    --clean)
      CLEAN_BUILD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      EXTRA_CMAKE_ARGS+=("$@")
      break
      ;;
    *)
      EXTRA_CMAKE_ARGS+=("$1")
      shift
      ;;
  esac
done

[[ -f "${SOURCE_DIR}/CMakeLists.txt" ]] || die "LLVM source directory not found: ${SOURCE_DIR}"
[[ "${JOBS}" =~ ^[0-9]+$ ]] || die "jobs must be a positive integer"
(( JOBS > 0 )) || die "jobs must be greater than 0"

require_cmd ninja
require_cmd clang-14
require_cmd clang++-14
require_cmd ld.lld

CMAKE_GENERATOR="Ninja"
CC="$(command -v clang-14)"
CXX="$(command -v clang++-14)"
LINKER_TYPE="lld"

if [[ "${CLEAN_BUILD}" -eq 1 && -d "${BUILD_DIR}" ]]; then
  rm -rf "${BUILD_DIR}"
fi

mkdir -p "${BUILD_DIR}" "${INSTALL_DIR}"

CMAKE_ARGS=(
  -G "${CMAKE_GENERATOR}"
  -S "${SOURCE_DIR}"
  -B "${BUILD_DIR}"
  -DCMAKE_BUILD_TYPE="${BUILD_TYPE}"
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"
  -DCMAKE_C_COMPILER="${CC}"
  -DCMAKE_CXX_COMPILER="${CXX}"
  -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra"
  -DLLVM_TARGETS_TO_BUILD="X86;ARM;RISCV;AArch64"
  -DLLVM_INCLUDE_BENCHMARKS=OFF
  -DLLVM_INCLUDE_EXAMPLES=OFF
  -DLLVM_INCLUDE_TESTS=OFF
  -DLLVM_BUILD_TESTS=OFF
  -DLLVM_BUILD_BENCHMARKS=OFF
  -DLLVM_BUILD_EXAMPLES=OFF
  -DLLVM_ENABLE_TERMINFO=OFF
)

if [[ -n "${LINKER_TYPE}" ]]; then
  CMAKE_ARGS+=("-DLLVM_USE_LINKER=${LINKER_TYPE}")
fi

if [[ ${#EXTRA_CMAKE_ARGS[@]} -gt 0 ]]; then
  CMAKE_ARGS+=("${EXTRA_CMAKE_ARGS[@]}")
fi

echo "==> Source dir   : ${SOURCE_DIR}"
echo "==> Build dir    : ${BUILD_DIR}"
echo "==> Install dir  : ${INSTALL_DIR}"
echo "==> Build type   : ${BUILD_TYPE}"
echo "==> Jobs         : ${JOBS}"
echo "==> C compiler   : ${CC}"
echo "==> CXX compiler : ${CXX}"
echo "==> Linker       : ${LINKER_TYPE} ($(command -v ld.lld))"
echo "==> Generator    : ${CMAKE_GENERATOR}"

cmake "${CMAKE_ARGS[@]}"
cmake --build "${BUILD_DIR}" --parallel "${JOBS}"

if [[ "${INSTALL_AFTER_BUILD}" -eq 1 ]]; then
  cmake --install "${BUILD_DIR}"
fi