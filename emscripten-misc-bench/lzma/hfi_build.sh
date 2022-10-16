#!/bin/sh
/opt/wasi-sdk/bin/clang --sysroot /opt/wasi-sdk/share/wasi-sysroot -Wl,--export-all *.c -o test_lzma_benchmark.wasm
