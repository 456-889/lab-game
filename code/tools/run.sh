#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v riscv64-unknown-elf-gcc >/dev/null 2>&1; then
    toolchain_bin="${RISCV_TOOLCHAIN_BIN:-/mnt/d/操作系统/riscv64-unknown-elf-toolchain-10.2.0-2020.12.8-x86_64-linux-ubuntu14/bin}"
    if [[ ! -x "$toolchain_bin/riscv64-unknown-elf-gcc" ]]; then
        echo "RISC-V compiler missing. Set RISCV_TOOLCHAIN_BIN to its bin directory." >&2
        exit 1
    fi
    export PATH="$toolchain_bin:$PATH"
fi

case "${1:-run}" in
    build) make -j2 ;;
    run) make qemu ;;
    grade)
        mkdir -p logs
        scratch=$(mktemp -d -t nku-lab3-grade-XXXXXXXX)
        trap 'rmdir "$scratch" 2>/dev/null || true' EXIT
        make grade GRADE_TMP="$scratch/tree" 2>&1 | tee logs/official-grade.log
        ;;
    verify) python3 tools/verify_extra.py ;;
    *) echo "Usage: bash tools/run.sh {build|run|grade|verify}" >&2; exit 2 ;;
esac
