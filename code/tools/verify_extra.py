#!/usr/bin/env python3
"""Run QEMU checks in temporary copies without changing official tests.

Usage: python3 tools/verify_extra.py (with the RISC-V toolchain on PATH).
The standard boot, mixed-width exceptions, and migrated Best-Fit are checked.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
LOGS = ROOT / 'logs'

EXTRA_C = r'''
#include <assert.h>
#include <defs.h>
#include <riscv.h>
#include <stdio.h>
#include <string.h>
#include <trap.h>

extern uintptr_t extra_register_context(void);
extern void exception_handler(struct trapframe *tf);
extern void interrupt_handler(struct trapframe *tf);

void extra_checks(void) {
    uintptr_t enabled = read_csr(sstatus) & SSTATUS_SIE;
    assert(extra_register_context() == 0);
    cprintf("[Extra] a0/ra/sp/gp/tp context: PASS\n");

    asm volatile(".option push\n.option norvc\n.word 0x00100073\n.option pop" ::: "memory");
    cprintf("[Extra] 32-bit ebreak return: PASS\n");
    asm volatile(".2byte 0x9002" ::: "memory");
    cprintf("[Extra] 16-bit c.ebreak return: PASS\n");
    asm volatile(".word 0x0000007b" ::: "memory");
    cprintf("[Extra] 32-bit illegal return: PASS\n");
    asm volatile(".2byte 0x0000" ::: "memory");
    cprintf("[Extra] 16-bit illegal return: PASS\n");
    assert((read_csr(sstatus) & SSTATUS_SIE) == enabled);
    assert(read_csr(sscratch) == 0);
    cprintf("[Extra] SIE/sscratch after return: PASS\n");

    struct trapframe tf;
    memset(&tf, 0, sizeof(tf));
    tf.epc = 0x1234;
    tf.cause = 20;
    exception_handler(&tf);
    assert(tf.epc == 0x1234 && tf.cause == 20);
    tf.cause = ((uintptr_t)1 << 63) | 15;
    interrupt_handler(&tf);
    assert(tf.epc == 0x1234 && tf.cause == (((uintptr_t)1 << 63) | 15));
    cprintf("[Extra] fallback preserves EPC/cause: PASS\n");
}
'''

EXTRA_S = r'''
    .text
    .align 2
    .globl extra_register_context
extra_register_context:
    addi sp, sp, -48
    sd ra, 0(sp)
    sd gp, 8(sp)
    sd tp, 16(sp)
    sd sp, 24(sp)
    li ra, 0x101
    li a0, 0x10a
    .option push
    .option norvc
    ebreak
    .option pop
    li t0, 0x101
    bne ra, t0, .Lextra_fail
    li t0, 0x10a
    bne a0, t0, .Lextra_fail
    ld t0, 8(sp)
    bne gp, t0, .Lextra_fail
    ld t0, 16(sp)
    bne tp, t0, .Lextra_fail
    ld t0, 24(sp)
    bne sp, t0, .Lextra_fail
    li a0, 0
    j .Lextra_return
.Lextra_fail:
    li a0, 1
.Lextra_return:
    ld ra, 0(sp)
    ld gp, 8(sp)
    ld tp, 16(sp)
    addi sp, sp, 48
    ret
'''

EXPECTED = [
    'a0/ra/sp/gp/tp context', '32-bit ebreak return',
    '16-bit c.ebreak return', '32-bit illegal return',
    '16-bit illegal return', 'SIE/sscratch after return',
    'fallback preserves EPC/cause',
]


def command(args, cwd, log, timeout):
    start = time.monotonic()
    try:
        run = subprocess.run(args, cwd=cwd, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, timeout=timeout)
        output = run.stdout.decode('utf-8', errors='replace')
        (LOGS / log).write_text(output, encoding='utf-8')
        if run.returncode:
            raise RuntimeError(f'{args[0]} exit={run.returncode}; see logs/{log}')
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or b'').decode('utf-8', errors='replace')
        (LOGS / log).write_text(output, encoding='utf-8')
        raise RuntimeError(f'timeout; see logs/{log}') from error
    return output, round(time.monotonic() - start, 3)


def main():
    LOGS.mkdir(exist_ok=True)
    env = {'platform': os.uname().release}
    for label, args in [
        ('compiler', ['riscv64-unknown-elf-gcc', '--version']),
        ('qemu', ['qemu-system-riscv64', '--version']),
        ('make', ['make', '--version']),
    ]:
        env[label] = subprocess.check_output(args, text=True).splitlines()[0]
    results = {'environment': env, 'cases': []}
    for kind in ('normal', 'exceptions', 'best-fit'):
        print(f'Checking {kind}...', flush=True)
        with tempfile.TemporaryDirectory(prefix='nku-lab3-extra-') as scratch:
            tree = Path(scratch) / 'lab3'
            shutil.copytree(ROOT, tree, ignore=shutil.ignore_patterns(
                'bin', 'obj', '.git', 'logs', '__pycache__', '*.zip'))
            if kind == 'exceptions':
                (tree / 'kern/init/extra.c').write_text(EXTRA_C, encoding='utf-8')
                (tree / 'kern/init/extra_context.S').write_text(EXTRA_S, encoding='utf-8')
                p = tree / 'kern/init/init.c'
                text = p.read_text()
                text = text.replace('int kern_init(void) {',
                    'void extra_checks(void);\nint kern_init(void) {')
                text = text.replace('    clock_init();',
                    '    extra_checks();\n    clock_init();')
                p.write_text(text)
            if kind == 'best-fit':
                p = tree / 'kern/mm/pmm.c'
                p.write_text(p.read_text().replace(
                    'pmm_manager = &default_pmm_manager;',
                    'pmm_manager = &best_fit_pmm_manager;'))
            command(['make', '-j2'], tree, f'{kind}-build.log', 60)
            output, elapsed = command([
                'qemu-system-riscv64', '-machine', 'virt', '-nographic',
                '-bios', 'default', '-device',
                'loader,file=bin/ucore.img,addr=0x80200000',
                '-monitor', 'none', '-no-reboot',
            ], tree, f'{kind}-qemu.log', 25)
            assert 'check_alloc_page() succeeded!' in output, kind
            assert 'panic' not in output.lower(), kind
            count = output.splitlines().count('100 ticks')
            assert count == 10, (kind, count)
            if kind == 'normal':
                assert 'Breakpoint at' not in output and 'Illegal instruction at' not in output
            if kind == 'exceptions':
                for label in EXPECTED:
                    assert f'[Extra] {label}: PASS' in output, label
                assert output.count('Breakpoint at') == 3
                assert output.count('Illegal instruction at') == 2
            if kind == 'best-fit':
                assert 'memory management: best_fit_pmm_manager' in output
            results['cases'].append({'case': kind, 'passed': True,
                'qemu_exit_code': 0, 'tick_lines': count, 'seconds': elapsed})
            print(f'{kind}: PASS; {count} tick lines; QEMU exited itself ({elapsed}s)', flush=True)
    results['source_sha256'] = {
        name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
        for name in ['kern/trap/trap.c', 'kern/trap/trapentry.S',
                     'kern/mm/pmm.c', 'kern/mm/best_fit_pmm.c']
    }
    (LOGS / 'verification.json').write_text(
        json.dumps(results, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print('All additional checks passed.', flush=True)


if __name__ == '__main__':
    main()
