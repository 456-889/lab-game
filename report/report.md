# 实验四：进程管理——页表操作、内核线程创建与调度切换

| 项目    | 内容                                                                                                                       |
| ----- | ------------------------------------------------------------------------------------------------------------------------ |
| 实验版本  | 南开大学操作系统实验指导书，2026 版 Lab4                                                                                               |
| 姓名与学号 | 赵翊博 2512336、宋成坤 2512392、贾宸 2512337                                                                                    |
| 分工     | 三人共同完成，各承担 1/3：赵翊博 2512336 主责模块一（虚拟内存页操作），宋成坤 2512392 主责模块二（进程创建与初始化），贾宸 2512337 主责模块三（调度与上下文切换）；报告撰写与测试复现全员参与 |
| 完成日期  | 2026-11-20（北京时间）                                                                                                         |
| 实现方式  | 在官方框架中设计规格，通过 AI 辅助补全并实际运行验证                                                                                             |
| 提交状态  | 本地完成；按要求暂不推送远程仓库                                                                                                         |
| 实验框架  | 课程官方 lab4 框架（提交包 `2512336_lab4.zip`，源码目录 `labcodes/lab4`）                                                                                |
| 要求    | [练习](http://oslab.mobisys.top/lab2026/_book/lab4/lab4_2_1_exercises.html)、[报告要求](http://oslab.mobisys.top/lab2026/_book/lab4/lab4_5_labs_requirement.html) |

## 一、实验目标与整体逻辑

Lab3 结束后，内核已经能在陷入后恢复现场，但“进程”还只是框架里的数据结构。Lab4 要把三件事接起来：物理页与虚拟地址之间的映射（能建立、能撤销、能计数）、内核线程的创建（从 PCB 到首次执行）、以及调度切换（选谁运行、怎么保存和恢复寄存器）。

实现顺序如下：

1. 迁移 Lab2/Lab3 的物理内存管理与中断基础，使内存自检、VMA 自检、时钟都能运行。
2. 补全 `get_pte` 的创建路径，实现 `page_insert`、`page_remove`，让页表操作满足引用计数与 TLB 一致性。
3. 按 fork 语义补全 `alloc_proc`、`kernel_thread`、`do_fork`、`copy_thread`、`copy_mm`。
4. 初始化 `idleproc` 与 `initproc`，让 `cpu_idle` 依据 `need_resched` 进入 `schedule`。
5. 实现 `proc_run` 与 RV64 的 `switch_to`，按 `forkret → forkrets → __trapret → kernel_thread_entry` 的链路核对首次执行。
6. 运行官方评测与补充复现，确认 PMM、Process Create、Schedule 三项全部通过。

```text
kern_init
  ├─ pmm_init：Best-Fit 页分配器、boot_pgdir 自检（check_pgdir / check_boot_pgdir）
  ├─ idt_init：stvec = __alltraps，准备中断入口
  ├─ vmm_init：建立 idle 的 mm，检查 VMA 有序插入与查找
  ├─ proc_init
  │    ├─ alloc_proc → idleproc（pid 0，PROC_RUNNABLE，kstack = bootstack）
  │    └─ kernel_thread(init_main) → do_fork → initproc（pid 1）
  ├─ clock_init / intr_enable
  └─ cpu_idle
       └─ schedule：从当前线程之后找下一个 PROC_RUNNABLE
            └─ proc_run：写 satp、刷 TLB、switch_to(&prev->context, &next->context)
                 ├─ 首次运行：ret → forkret → forkrets(tf) → __trapret → sret
                 │            → kernel_thread_entry：a0 = s1，jalr s0（线程函数）
                 └─ 再次运行：ret 回到上次 switch_to 之后继续执行
```

`do_fork` 内部固定顺序是：关中断 → 检查进程数 → `alloc_proc` → `setup_kstack` → `copy_mm` → `copy_thread` → 分配 PID → 挂哈希表与全局链表 → 计数加一 → `wakeup_proc` → 开中断。前三步失败时逆序回收内核栈和 PCB，保证不会把半初始化的线程登记进全局结构。

## 二、实际实验环境

| 项目     | 官方评测与验证环境                                          | 补充复现环境                                              |
| ------ | -------------------------------------------------- | --------------------------------------------------- |
| 宿主环境   | Windows + WSL2 Ubuntu                              | 同左                                                  |
| 编译器    | SiFive GCC-Metal 10.2.0，`riscv64-unknown-elf-gcc`  | 同左                                                  |
| 模拟器    | QEMU 4.1.1，`virt` 机器                               | QEMU 8.2.2，`virt` 机器                                |
| 固件     | QEMU 自带 OpenSBI 0.4                                 | QEMU 自带 OpenSBI 1.3                                  |
| 构建工具   | GNU Make，沿用官方 Makefile（`-Wall`、`-O2`）                | 同左                                                  |
| 启动方式   | `-device loader,file=bin/ucore.img,addr=0x80200000` | `-kernel bin/ucore.img`（临时副本）                       |
| 运行内存   | 默认 128 MiB，由 DTB 探测                                | 同左                                                  |
| 验证结果   | 官方 `make grade` **30/30**                           | 注入测试三项全部 PASS，日志见 `logs/qemu8-grade.log`            |

内核启动后由 DTB 读到 128 MiB 物理内存（`0x80000000`–`0x87ffffff`），管理方式为 `best_fit_pmm_manager`，内核映像占用约 58 KiB。评测脚本 `tools/grade.sh` 用 gdb 在 `readline` 处断开，因此运行到内核调试监视器是预期结束点，而不是崩溃。

## 三、Lab2 与 Lab3 依赖的迁移

Lab4 的框架只提供页表、PCB、链表等骨架，物理页分配器与中断基础来自前两次实验。迁移时只取需要的部分，不整体覆盖新框架。

### 3.1 物理页初始化（page_init）

1. 从 DTB 读取物理内存起点与大小，检查大小为零和加法溢出。
2. 把内存上界限制在内核直接映射范围内，并向下按页对齐。
3. 检查内存范围覆盖内核镜像，确保描述符数组不会落在内核里。
4. 把 `Page` 描述符数组放在内核末尾之后的页边界，先验证容量，再初始化描述符。
5. 先把所有页标记为 reserved，只把描述符数组末尾之后的完整可用页交给 `init_memmap`。

`nbase` 是描述符数组的起始页号，描述符数量是 `npage - nbase`，直接按 `npage` 计算会显著高估元数据大小。初始空闲区间为 `[free_begin, maxpa)`，两端都按页对齐，空区间不登记。

### 3.2 Best-Fit 分配器

复用 Lab2 中由 2512337 完成的 Best-Fit 实现：空闲块按地址有序排列，分配时选满足请求的最小块，同大小取低地址块，块过大则拆分，释放时与前后相邻空闲块合并。保留 `free_area/free_list/nr_free` 约定，并通过 `default_pmm_manager` 导出符号完成注册，启动日志中显示为 `best_fit_pmm_manager`。

新框架的 `alloc_pages/free_pages` 已加 `local_intr_save/restore`，它们保护分配器共享状态，迁移时予以保留。

### 3.3 中断与时钟基础

沿用 Lab3 的 trap 入口、`RESTORE_ALL` 和时钟中断逻辑：`clock_init` 设置第一次时钟事件，每次处理时重设下一次事件并累加 `ticks`。Lab3 中“打印十行后关机”的策略不再介入，Lab4 的结束由 `init_main` 返回后的 `do_exit` 调试入口决定。`idt_init`、`intr_enable` 保持不变。

## 四、模块一：虚拟内存页操作

### 4.1 get_pte：两级遍历与延迟发布

`get_pte(pgdir, la, create)` 逐级取得 4 KiB 叶项的内核虚拟地址：

1. 用 `PDX1(la)` 取根表项。项无效且 `create` 为真时申请一页、清零、`set_page_ref(page, 1)`，用 `ptd_create` 生成非叶项；`create` 为假直接返回 `NULL`。
2. 若根表项有效但 `!PTE_TABLE(...)`，说明它是大页叶项而不是下级页表，直接返回 `NULL`，避免把映射的物理内存当成页表遍历。
3. 用 `KADDR(PDE_ADDR(level1))` 把下级页表的物理地址转成内核可访问地址，再用 `PDX0(la)` 取二级表项；缺失时同样申请一页并清零。
4. 两层都就绪后返回 `&((pte_t *)KADDR(PDE_ADDR(*pdep0)))[PTX(la)]`。

关键点是**上层目录延迟发布**：一级目录先保存在局部变量 `level1` 中，只有二级页表分配成功后才写回 `*pdep1`；二级分配失败时释放一级页，返回 `NULL`。这样不存在“已发布但没有下级表”的中间状态，失败路径不会留下垃圾目录。

### 4.2 page_insert：引用计数、权限归一与 TLB

```text
进入时 local_intr_save
  ptep = get_pte(pgdir, la, 1)；失败则返回 -E_NO_MEM
  old = PTE 有效 ? pte2page(*ptep) : NULL
  若 old != page：page_ref_inc(page)        // 同一页重映射不重复加引用
  权限归一：perm 只有 W，或既无 R 也无 X 时，补上 PTE_R
  *ptep = pte_create(page2ppn(page), perm)
  tlb_invalidate(pgdir, la)                 // sfence.vma la, zero
  若 old 存在且 old != page 且引用减到 0：free_page(old)
  恢复中断
```

几条约定：

- 框架里 `perm == 0` 表示只读，所以“无 R 无 X”时必须补 `PTE_R`；RISC-V 规定 W 必须与 R 或 X 搭配，写权限单独出现也要补 R。
- 替换映射时先加新页引用、再改 PTE、最后减旧页引用；旧页减到零才释放，未减到零说明仍有别的虚拟地址引用它。
- **同一物理页重新映射只更新 PTE 与权限**，不加也不减引用计数，否则自检中的引用计数断言会失败。
- 改完 PTE 必须 `sfence.vma` 使该地址的旧翻译失效，否则 CPU 可能继续用旧 TLB 项访问旧页。

### 4.3 page_remove：幂等删除

`page_remove(pgdir, la)` 用 `get_pte(pgdir, la, 0)` 查找（不创建页表），只有项有效才清 PTE、`sfence.vma`、引用减一，归零则 `free_page`。地址未映射、或已经删过一次时，函数直接返回，因此删除是幂等的。中间页表不随之释放，留给后续映射复用。

### 4.4 与框架自检的对应关系

- `check_pgdir()`：先在 `boot_pgdir_va` 上做“首次映射 → 同页换权限 → 异页替换 → 两次删除”的完整序列，检查每一步的 `page_ref`（1 → 2 → 0 等）；并断言非叶项 `PTE_TABLE(...) && !(PTE_U)`，即中间目录只带 V，不带 U。
- `check_boot_pgdir()`：核对 `entry.S` 安装的 1 GiB 根级叶项的基址、权限与覆盖范围，再在 `0x100` 与 `0x100 + PGSIZE` 两个地址映射同一物理页，通过两条虚拟地址做 `strcpy`/`strcmp` 别名访问，验证映射确实生效，最后清空并检查空闲页恢复原值。

这两段自检直接使用了本次实现的 `page_insert`、`page_remove`、`get_pte`，因此通过它们意味着引用计数与页表维护的基本语义是正确的。

## 五、模块二：进程创建与初始化

### 5.1 alloc_proc

`kmalloc(sizeof(struct proc_struct))` 申请 PCB，随即 `memset` 清零，再显式设置：`state = PROC_UNINIT`、`pid = -1`、`pgdir = boot_pgdir_pa`，并 `list_init` 两个链表节点。清零保证 `mm/tf/parent/kstack/runs/context` 都是确定的初值，`pid = -1` 表示“尚未分配编号”。

### 5.2 kernel_thread 与首个 trapframe

`kernel_thread(fn, arg, clone_flags)` 在栈上构造一个全零 trapframe：

- `gpr.s0 = fn`、`gpr.s1 = arg`，对应 `kernel_thread_entry` 中 `move a0, s1; jalr s0`；
- `epc = kernel_thread_entry`，首次 `sret` 会跳到汇编入口；
- `status = (sstatus | SSTATUS_SPP | SSTATUS_SPIE) & ~SSTATUS_SIE`：`SPP` 保证返回后仍在 S 模式，`SPIE` 保证 `sret` 后开启中断，清 `SIE` 使构造帧期间保持关中断；
- 最后 `do_fork(clone_flags | CLONE_VM, 0, &tf)`。

### 5.3 do_fork 的顺序与失败回退

`do_fork` 全程关中断。`nr_process >= MAX_PROCESS` 时返回 `-E_NO_FREE_PROC`；否则依次 `alloc_proc`、`setup_kstack`（申请 `KSTACKPAGE` 个页）、`copy_mm`、`copy_thread`，这些步骤都成功后才分配 PID、调用 `hash_proc`、`list_add_before(&proc_list, ...)` 插入链表尾部、`nr_process++`，最后 `wakeup_proc` 置为 `PROC_RUNNABLE`。

失败路径分两级：`setup_kstack` 之后失败先 `put_kstack`，`alloc_proc` 之后失败再 `kfree`，从而不遗留内核栈和 PCB。`copy_mm` 在本实验中只会返回 0，但接口保留，便于后续为用户进程复制地址空间。

### 5.4 copy_mm 与 copy_thread

- `copy_mm`：`assert(current->mm == NULL)` 后直接返回 0。Lab4 的内核线程共享启动页表，不拥有独立用户地址空间，因此新线程的 `pgdir` 仍是 `boot_pgdir_pa`。
- `copy_thread`：`kstacktop = proc->kstack + KSTACKSIZE`，`proc->tf = (struct trapframe *)kstacktop - 1`，即把 trapframe 放在内核栈顶下方；整体复制父线程传入的帧，把 `a0` 清零（子线程返回值 0），`sp` 设为调用者给的栈或 `kstacktop`；`context.ra = forkret`、`context.sp = proc->tf`，首次切换时 `ret` 会进入 `forkret`。

### 5.5 proc_init：idle 与 init

```text
初始化 proc_list 与 hash_list
idleproc = alloc_proc()：pid 0，PROC_RUNNABLE，kstack = bootstack
                        need_resched = 1，名字 "idle"，current = idleproc，nr_process++
kernel_thread(init_main, "Hello world!!", 0) → pid 应等于 1
initproc = find_proc(1)，断言存在且 pid == 1，名字设为 "init"
```

`idleproc` 没有独立的 trapframe（`tf == NULL`、`runs == 0`、`context.ra == 0`），它借用启动栈继续执行；`initproc` 才有真正的 trapframe 和首次运行地址。官方评测正是用这些字段来检查两个进程是否被正确创建。

## 六、模块三：进程调度与上下文切换

### 6.1 schedule：轮转起点与 runs

```text
关中断；current->need_resched = 0
next = idleproc
start = (current == idleproc) ? &proc_list : &current->list_link
从 start 的下一个元素开始沿 list_link 循环，遇到第一个 state == PROC_RUNNABLE 即选中
  （循环遇到链表头就跳过，走到 start 为止；没找到就保持 idleproc）
next->runs++
若 next != current：proc_run(next)
开中断
```

从 `current` 之后开始找，使主动让出 CPU 的多个线程能按创建顺序轮流执行；从 idle 出发时从链表头开始找。空队列时回退到 idleproc，保证总有线程可运行。`runs` 记录被选中的次数，测试用它判断各线程是否都得到过执行机会。

### 6.2 proc_run：写 satp 与切换现场

`proc_run(proc)` 在 `proc != current` 时才真正切换：关中断，保存 `prev = current`，`current = proc`，用 `((uintptr_t)SATP_MODE_SV39 << 60) | (proc->pgdir >> RISCV_PGSHIFT)` 写 `satp`（模式字段 8 表示 Sv39，低 44 位放页表物理页号），`flush_tlb()` 后调用 `switch_to(&prev->context, &proc->context)`，返回时恢复中断。

对内核线程而言 `pgdir` 都是 `boot_pgdir_pa`，写 `satp` 实际上不改变地址空间，但这一步把“进程 → 页表”的选择放进了切换路径，是后续支持用户进程所必需的。

### 6.3 switch_to 的寄存器布局

`struct context` 依次是 `ra, sp, s0 … s11`，共 14 个 8 字节槽位。`switch_to(a0 = from, a1 = to)` 按 `REGBYTES` 偏移把 `ra`、`sp`、`s0–s11` 存入 `from`，再从 `to` 取回，最后 `ret`。只保存被调用者保存寄存器（s0–s11）、返回地址和栈指针，是因为切换发生在普通 C 调用点，调用者保存寄存器由编译器按 ABI 负责，不需要内核额外保存。

与 trap 的区别：trap 是异步打断，必须保存全部通用寄存器；调度切换是同步调用，只需维护 ABI 约定的最小现场。

### 6.4 新线程的第一次执行

新线程第一次被 `proc_run` 选中时，`switch_to` 从 `to->context` 恢复出的 `ra` 是 `forkret`、`sp` 是其 trapframe 地址。于是：

```text
ret → forkret()
      forkrets(current->tf)   // 汇编：把 sp 切到 tf，跳 __trapret
      __trapret：按 trapframe 恢复 sstatus、sepc 与通用寄存器，sret
      → 进入 kernel_thread_entry
      move a0, s1；jalr s0    // 调用线程函数 fn(arg)
      函数返回后 jal do_exit
```

之后该线程如果再次被调度，`switch_to` 恢复的 `ra` 是它上次被换出时的返回地址，`sp` 是那时的内核栈位置，因此直接回到 `proc_run` 内部继续执行，不会重复走首次启动链。

### 6.5 cpu_idle 与 need_resched

`cpu_idle` 是死循环：当前线程 `need_resched` 为真就调用 `schedule`。`proc_init` 给 `idleproc` 置 `need_resched = 1`，于是启动后第一次进入 `cpu_idle` 就会切到 `initproc`。`schedule` 进入时先清标志，避免返回后立刻再次调度。

## 七、Spec、提示词与 AI 协作过程

各模块的规格来自指导书接口、框架调用点和随附断言。按报告要求，下面按模块给出编码时使用的任务描述（由负责编码的组员整理），并列出实现过程中实际暴露、随后修正的问题。

### 模块一　虚拟内存页操作

> 根据当前 `kern/mm/pmm.c` 与 `pmm.h` 实现 `page_insert`、`page_remove`，并补全 `get_pte` 的创建路径。逐一处理首次映射、同页权限更新、异页替换、空映射删除和二级分配失败。复用 `get_pte`、`pte_create`、页引用函数和 `tlb_invalidate`。用实际 Sv39 启动映射校验页表遍历；保留随附评分用例和 Lab 4 注释并填入学号。

### 模块二　进程创建和初始化

> 根据 `struct proc_struct` 和实际启动调用补全 `alloc_proc`、`proc_init`、`kernel_thread`、`do_fork`、`copy_thread`、`copy_mm`。按 `forkret → forkrets → __trapret → kernel_thread_entry` 的顺序核对首次运行的 `ra`、`sp`、`epc` 和参数。用空闲线程与第一个内核线程的 PID、父子关系、栈地址和状态作为验收条件，并检查失败分支的资源回收。

### 模块三　进程调度与上下文切换

> 补全 `cpu_idle`、`schedule`、`proc_run` 和 RV64 `switch_to`。根据 `struct context` 的字段次序设置汇编偏移；使用 `SATP_MODE_SV39` 的 64 位模式字段和页表物理页号。检查只有就绪线程被选中、空队列回退 idle、中断状态正确恢复。使用注入测试验证两个子线程反复主动调度后都执行过。

实现中实际处理的问题：

| 发现的问题                        | 发现方式与处理                                                                             |
| ---------------------------- | ----------------------------------------------------------------------------------- |
| 非叶项不应带 `PTE_U`               | `check_pgdir` 断言 `PTE_TABLE(boot_pgdir_va[0]) && !(boot_pgdir_va[0] & PTE_U)`；`ptd_create` 只置 V，用户权限由叶项决定。 |
| 一级目录发布过早会留下空目录               | 读代码发现：先发布再分配下级，失败时根表项指向空表；改为延迟到下级成功后写回 `*pdep1`。                                    |
| `perm == 0` 与 `PTE_W` 单独出现   | `check_pgdir` 用 `perm = 0` 映射并断言 `PTE_U` 被清除；RISC-V 要求 W 与 R/X 搭配，故统一补 `PTE_R`。               |
| 同一页重映射导致引用计数错误               | 注入测试 `test_lab4_pmm_basic` 断言同页重映射引用不变；实现中加 `old != page` 判断。                        |
| 写 satp 后在新版 QEMU 上取指缺页        | 见 8.3 节：QEMU 4.1.1 无此问题，QEMU 8.2 需要补一条恒等映射才能复现，源码不做改动。                               |

所有官方评分脚本、`tools/test_lab4.c`、`tools/inject.py` 保持原样，没有通过放宽断言取分。

## 八、测试结果与证据

### 8.1 官方评分（QEMU 4.1.1）

```text
- check PMM:                                      OK
- check Process Create:                           OK
- check Schedule:                                 OK
Total Score: 30/30
```

| 评分项             | 检查内容                                                                 | 得分    |
| --------------- | -------------------------------------------------------------------- | ----- |
| PMM             | 页表插入/删除、引用计数、同页重映射、权限更新                                               | 10/10 |
| Process Create  | `idleproc` 与 `initproc` 的 PID、状态、栈、父子关系、`mm`、`context` 字段                | 10/10 |
| Schedule        | 两个测试线程反复主动调度后都被执行；`init_main` 打印问候语并进入调试监视器                          | 10/10 |
| 总分              |                                                                      | **30/30** |

原始终端输出截图见 [logs/official-grade.png](logs/official-grade.png)。截图同时保留了随附测试的一个编译警告：`test_lab4_thread` 的返回类型是 `void`，而 `kernel_thread` 原型要求 `int (*)(void *)`。该测试线程始终循环主动调度，不会返回，因此不影响评测。

### 8.2 关键运行输出

下面是注入测试后串口日志的关键片段（完整日志见 [logs/qemu8-grade.log](logs/qemu8-grade.log)）：

```text
(THU.CST) os is loading ...

Special kernel symbols:
  entry  0xc020004a (virtual)
  etext  0xc02044c8 (virtual)
  edata  0xc020a030 (virtual)
  end    0xc020e4ec (virtual)
Kernel executable memory footprint: 58KB
memory management: best_fit_pmm_manager
physical memory map:
  memory: 0x0000000008000000, [0x0000000080000000, 0x0000000087ffffff].
check_alloc_page() succeeded!
check_pgdir() succeeded!
check_boot_pgdir() succeeded!
use SLOB allocator
kmalloc_init() succeeded!
[Test PMM] PASS
check_vma_struct() succeeded!
check_vmm() succeeded.
[Test Process Create] PASS
++ setup timer interrupts
[Test Schedule] PASS
this initproc, pid = 1, name = "init"
To U: "Hello world!!".
To U: "en.., Bye, Bye. :)"
kernel panic at kern/process/proc.c:210:
    process exit!!.

Welcome to the kernel debug monitor!!
Type 'help' for a list of commands.
```

`process exit!!.` 是框架 `do_exit` 的调试入口，`init_main` 返回后线程调用 `do_exit` 触发；随后进入 `readline` 调试监视器，也就是 `grade.sh` 设置断点的位置。这是 Lab4 的正常结束点，不是实现缺陷。

### 8.3 补充复现（QEMU 8.2.2 + OpenSBI 1.3）

在 QEMU 8.2 上直接运行同一镜像会在启用 Sv39 后立即触发 `exec_page_fault`：`entry.S` 打开 `satp` 后仍按物理地址取指，而启动页表只映射了 `0xffffffffc0000000` 起的 1 GiB。旧版 QEMU 会继续执行已翻译的指令块，新版会在写 `satp` 后冲刷，于是下一条取指就缺页。

为了交叉验证实现本身，在**临时验证副本**中给启动页表补了一条恒等映射（`VPN2 = 2`，即 `0x80000000` 起的 1 GiB），源码目录、注入脚本和评分脚本均未改动。补丁后全部自检与三项注入测试通过，输出即 8.2 节所示。构建日志见 [logs/qemu8-build.log](logs/qemu8-build.log)。

### 8.4 测试覆盖与边界

- 注入点：`pmm_init` 末尾调用 `test_lab4_pmm_basic()`，`proc_init` 末尾调用 `test_lab4_process_create()`，`init_main` 开头调用 `test_lab4_schedule()`。
- `test_lab4_pmm_basic` 覆盖：首次映射后引用为 1、同页重映射引用不变、异页替换后旧页释放、删除后引用归零、重复删除幂等。
- `test_lab4_process_create` 覆盖：`idleproc`（pid 0、RUNNABLE、`kstack == bootstack`、`tf == NULL`、`runs == 0`、`context.ra == 0`）与 `initproc`（pid 1、`parent == idleproc`、`mm == NULL`、`context.ra/sp` 非零）。
- `test_lab4_schedule` 覆盖：两个线程各主动调度三次后自旋，主线程调度八次后断言两者都运行过，验证轮转与空转回退。

尚未覆盖：用户进程与独立地址空间、`copy_mm` 的真实页表复制、`do_exit` 的资源回收与父进程等待、时间片抢占、多核并发。这些是后续实验的内容，本次 `do_exit` 仍是 panic 入口。

## 九、挑战题

### 1. `local_intr_save` 和 `local_intr_restore` 如何开关中断

`local_intr_save(flag)` 调用 `__intr_save` 读取当前 hart 的 `sstatus.SIE`。若原来启用中断，就调用 `intr_disable` 清除 SIE 并返回真；原来关闭时返回假。`local_intr_restore(flag)` 只在标志为真时调用 `intr_enable`，把 SIE 重新置位。内外两层嵌套时，内层看到的 SIE 已经清零，退出内层时中断仍关闭，最终由外层恢复。这个机制可以防止本 hart 的 S 模式中断打断本实验的临界区。多核代码若修改共享结构，还需跨 hart 同步。

### 2. `get_pte` 与 Sv32、Sv39、Sv48

| 分页模式 | 页表层数 | 每级 VPN 位数 | PTE 宽度 | 4 KiB 页的地址划分       |
| ---- | ---: | -------: | -----: | ---------------- |
| Sv32 |    2 |       10 |   32 位 | 10 + 10 + 12     |
| Sv39 |    3 |        9 |   64 位 | 9 + 9 + 9 + 12   |
| Sv48 |    4 |        9 |   64 位 | 9 + 9 + 9 + 9 + 12 |

每一级用对应的 VPN 字段索引一张页表。有效非叶项保存下级页表的物理页号；遇到叶项时，物理页号与来自虚拟地址的偏移共同决定物理地址。上层也能保存大页叶项，例如 Sv39 根级可映射 1 GiB。Sv39 查找 4 KiB 叶项时，前两级做的是同一种操作，差别在于分别使用 `PDX1` 和 `PDX0`。所以两段代码都先看项是否有效，必要时准备下级页表，再把下一张表的物理地址转成内核可访问的虚拟地址。Sv32 少重复一级，Sv48 多重复一级。[RISC-V Supervisor ISA](https://docs.riscv.org/reference/isa/v20260120/priv/supervisor.html)

目前把查找与分配放在 `get_pte` 中是合理的。创建与删除可以沿同一条路径，删除传 `create = false` 即可保证不申请页。对于本实验固定的三级页表，保留这个接口便于核对调用者是否会分配内存。如果后续需要多种分页模式、按级拆分大页、并发遍历或复杂错误码，可以在内部抽出统一遍历和创建步骤，再保留两个语义清晰的调用入口。

## 十、与操作系统原理的对应

| 概念        | 在本实验中的实现                                        | 含义和适用范围                                                    |
| --------- | ----------------------------------------------- | ---------------------------------------------------------- |
| 物理页框与引用计数 | `Page`、Best-Fit、`page_insert`、`page_remove`      | 一个页框可以被多个虚拟地址引用，最后一处映射解除后才能回收；分配器负责寻找空闲页框。             |
| 地址空间与地址翻译 | `mm_struct`、`vma_struct`、Sv39、TLB               | VMA 用区间描述逻辑布局，页表说明具体翻译关系，TLB 缓存翻译结果。内核线程共享启动页表并各自持有内核栈。   |
| PCB 与线程生命周期 | `proc_struct`、PID 哈希、`wakeup_proc`              | PCB 保存状态、上下文和关系信息；本实验完整走到可运行阶段。                           |
| 调度与机制分离   | `schedule`、`proc_run`、`switch_to`               | 调度策略选下一线程，上下文切换负责寄存器和栈交接；本实验借助主动调度演示轮转。                   |
| 陷入现场与调用约定 | trapframe、`struct context`                       | 异步陷入需要保存被打断的通用寄存器。同步调用切换点只需要维护 ABI 约定的被调用者保存寄存器、返回地址和栈指针。 |

课程原理中还包括用户态系统调用、独立用户地址空间和写时复制、按需分页与页面置换、进程退出后的资源回收与等待、抢占式时间片调度，以及多核并发和跨核 TLB shootdown。这些机制留待后续实验。

## 十一、完成情况与文件位置

- [x] `get_pte`、`page_insert`、`page_remove`：引用计数、权限归一、TLB 失效、失败回退。
- [x] `alloc_proc`、`copy_mm`、`copy_thread`、`do_fork`、`kernel_thread`、`proc_init`。
- [x] `schedule`、`proc_run`、`cpu_idle`、RV64 `switch_to`。
- [x] Lab4 标记保留为 `//LAB4 functionN 2512336`，无 `YOUR CODE` 残留。
- [x] 官方 `make grade` 30/30，终端截图与串口日志已归档。
- [x] QEMU 8.2 补充复现通过，记录启动页表适配过程。
- [x] Markdown 实验报告与 `logs/` 证据目录。

证据文件：

- [logs/official-grade.png](logs/official-grade.png)：官方 `make grade` 30/30 的终端截图。
- [logs/qemu8-grade.log](logs/qemu8-grade.log)：注入测试后的完整串口输出。
- [logs/qemu8-build.log](logs/qemu8-build.log)：构建日志。
- [logs/verification.md](logs/verification.md)：环境、命令与关键源文件 SHA256。

- 远程推送：按用户要求暂不执行。

## 参考资料

- [Lab 4 指导书](http://oslab.mobisys.top/lab2026/_book/lab4/lab4.html)
- [练习](http://oslab.mobisys.top/lab2026/_book/lab4/lab4_2_1_exercises.html)
- [实验报告要求](http://oslab.mobisys.top/lab2026/_book/lab4/lab4_5_labs_requirement.html)
- [RISC-V Supervisor ISA](https://docs.riscv.org/reference/isa/v20260120/priv/supervisor.html)
