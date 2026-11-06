# 实验三：中断、异常与 Trap 上下文恢复

| 项目    | 内容                                                                                                                                                       |
| ----- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 实验版本  | 南开大学操作系统实验指导书，2026 版 Lab3                                                                                                                                |
| 姓名与学号 | 赵翊博，2512336,宋成坤，2512392，贾宸，2512337                                                                                                                       |
| 完成日期  | 2026-11-04（北京时间）                                                                                                                                         |
| 实现方式  | 在官方框架中设计规格，通过 AI 辅助补全并实际运行验证                                                                                                                             |
| 提交状态  | 本地完成；按要求暂不推送远程仓库                                                                                                                                         |
| 实验框架  | [课程官方 lab3.zip](http://oslab.mobisys.top/lab2026/lab3.zip)                                                                                               |
| 要求    | [练习](http://oslab.mobisys.top/lab2026/_book/lab3/lab3_2_1_exercise.html)、[报告要求](http://oslab.mobisys.top/lab2026/_book/lab3/lab3_4_lab_requirement.html) |

## 一、实验目标与整体逻辑

Lab2 已经完成物理内存管理和启动页表，Lab3 要让内核在被打断之后仍能继续正确执行。核心不是只打印一条消息，而是建立“保存被打断状态—调用处理程序—恢复状态—返回”的完整链路。

实现顺序如下：

1. 补齐 Lab2 依赖，使内存初始化和页分配自检能够通过。
2. 理解框架已有的 SAVE_ALL 和 trapframe 布局，实现与之对应的 RESTORE_ALL。
3. 补齐汇编入口与 C 函数之间的调用关系，让 trap() 收到当前帧地址。
4. 在 C 层按 cause 区分中断和异常，处理时钟事件、非法指令和断点。
5. 运行官方评分与补充检查，确认多次 Trap 返回仍保持寄存器、栈和控制流正确。

```text
kern_init
  ├─ 清零 BSS、解析 DTB、初始化控制台
  ├─ idt_init：sscratch=0，stvec=__alltraps
  ├─ pmm_init：页描述符初始化、页分配自检
  ├─ clock_init：使能监督态时钟来源，设置第一次事件，ticks=0
  └─ intr_enable：允许监督态中断

中断/异常发生
  → 硬件记录 sepc、scause、stval，更新 sstatus，跳到 stvec
  → __alltraps / SAVE_ALL：把上下文存入当前内核栈
  → a0=sp，调用 trap(tf)
  → trap_dispatch：根据 cause 的最高位分发
  → interrupt_handler 或 exception_handler
  → __trapret / RESTORE_ALL：恢复寄存器与返回状态
  → sret：返回 sepc 指定的位置
```

注意：硬件不会替我们把所有通用寄存器压栈；这一步由 SAVE_ALL 完成。本实验在监督态内核中运行，没有实现完整的用户栈/内核栈切换。

## 二、实际实验环境

| 项目       | 实际验证环境                                          |
| -------- | ----------------------------------------------- |
| 宿主环境     | Windows + WSL2 Ubuntu                           |
| Linux 内核 | 6.18.33.2-microsoft-standard-WSL2               |
| 编译器      | SiFive GCC-Metal 10.2.0，riscv64-unknown-elf-gcc |
| 模拟器      | QEMU 4.1.1，virt 机器                              |
| 固件       | QEMU 自带 OpenSBI v0.4                            |
| 构建工具     | GNU Make 4.4.1                                  |
| 编译要求     | 沿用官方 Makefile，含 -Wall、-Werror、-O2               |
| 启动方式     | 加载 bin/ucore.img 到物理地址 0x80200000               |
| 运行内存     | 默认 128 MiB；由 DTB 探测                             |

可复现命令见 README.md。日志中的版本信息和代码 SHA256 保存在 `logs/verification.json`。

## 三、Lab2 依赖的迁移

官方 Lab3 有两个 lab2 占位：`pmm.c` 中的 page_init，以及 `best_fit_pmm.c` 中的分配器实现。参考用户提供的 `lab2_new333.zip`，只迁移这些部分。

### 3.1 page_init

1. 通过 DTB 得到物理内存起点与大小，检查大小为零和加法溢出。
2. 将内存上界限制在内核直接映射范围内，并向下按页对齐。
3. 检查内存范围覆盖内核镜像。
4. 将 Page 描述符数组放在内核末尾之后的页边界，先验证空间容量，再初始化描述符。
5. 将所有页先设为 reserved，只把描述符数组末尾之后的完整可用页交给 init_memmap。

`npage` 是物理页号的排他上界，描述符数量是 `npage - nbase`，不是简单的 npage。忽略 nbase 会显著高估元数据大小，甚至越界。

Lab2 使用的 PHYSICAL_MEMORY_END、KERNEL_BEGIN_PADDR 在官方 Lab3 的头文件中不存在，因此迁移时分别改为由 `KERNTOP - va_pa_offset` 和 `KERNBASE - va_pa_offset` 推导，避免新增互相矛盾的地址常量。

保留 Lab2 page_init 原注释中的作者 2512337 来源说明；本次集成学号为 2512336。

### 3.2 Best-Fit

空闲块按地址有序排列。分配时选择满足请求的最小块，同大小选择低地址块；块过大则拆分；释放时合并前后相邻块。迁移保留 `free_area/free_list/nr_free` 约定，并补充管理器注册对象。

官方 `basic_check()` 和 `best_fit_check()` 未修改。正式内核仍使用框架原来的 Default/First-Fit 管理器；补充测试仅在临时副本切换为 Best-Fit，运行其原有自检。

没有用 Lab2 的整个 pmm.c 覆盖新框架。Lab3 的 alloc_pages/free_pages/nr_free_pages 已增加 `local_intr_save/restore`，它们保护共享分配器状态，必须保留。

## 四、模块一：Trap 上下文恢复与入口

### 4.1 Trap frame 的布局

RV64 下 REGBYTES=8，SAVE_ALL 分配 36×8=288 字节，仍保持 16 字节栈对齐。

| 槽位   | 字节偏移  | 含义                                    |
| ---- | ----- | ------------------------------------- |
| 0～31 | 0～248 | x0～x31，其中槽 2 是原 sp                    |
| 32   | 256   | sstatus，对应 tf->status                 |
| 33   | 264   | sepc，对应 tf->epc                       |
| 34   | 272   | stval，框架使用旧名 sbadaddr，对应 tf->badvaddr |
| 35   | 280   | scause，对应 tf->cause                   |

实际布局由 SAVE_ALL 的存储偏移和 `struct trapframe` 字段共同确定；恢复过程必须遵守它，不能自行调整顺序。

### 4.2 RESTORE_ALL

先把 status、epc 读入 s1/s2，再写回 sstatus、sepc。此时 s1/s2 只是暂存寄存器，随后仍会从各自的通用寄存器槽恢复原值。

接着恢复 x1、x3～x31，最后从槽 2 恢复 x2，即原 sp。最后恢复 sp 的原因是：此前的 LOAD 都以当前 sp 为 Trap frame 基址，提前恢复会让后续访问落到错误位置。原 sp 是 SAVE_ALL 通过 sscratch 保存的，不能把槽内信息忽略掉。

x0 恒为零，无需恢复。stval 和 scause 记录异常原因和附加信息，用于分发与诊断；返回执行所必需的是 sepc 和 sstatus，并不需要把这两个诊断 CSR 写回。

### 4.3 __alltraps 与 C 调用

SAVE_ALL 执行后，sp 就是完整 Trap frame 的地址。`mv a0, sp` 按 RISC-V ABI 将此地址放入第一个参数寄存器，然后 `call trap` 进入 C 处理函数。

trap() 按约定返回后，sp 仍指向原帧。控制流顺序进入 __trapret，执行 RESTORE_ALL 和 sret。trap() 处理的是帧指针，因此修改 tf->epc 会被 RESTORE_ALL 写回 sepc，真正影响返回位置。

### 4.4 为什么需要保存调用者保存寄存器

中断不是被打断程序主动发起的普通函数调用。它可能发生在任意指令边界，程序不会预先把 t、a 寄存器中的活跃数据保存起来。因此不能只按普通 C 函数的被调用者保存约定处理，必须保护被打断上下文中的通用寄存器。

## 五、模块二：中断与异常处理

### 5.1 分发和中断原因

统一分发器用 tf->cause 最高位区分异步中断与同步异常。interrupt_handler 先清除最高位，再用低位原因号分类；这也兼容官方测试直接调用 handler 并传入原因号的情况。

软件、时钟、外部中断的各个框架已知类型输出对应提示。未知中断先输出原因号，再调用 print_trapframe；不改动传入帧。

### 5.2 时钟中断

监督态时钟处理依次执行：

1. 调用 clock_set_next_event，设置下一次事件。
2. ticks 加一。
3. 当 ticks 是 TICK_NUM=100 的整数倍时，调用原有 print_ticks。
4. 累计输出次数到 SHUTDOWN_AFTER=10 时，调用 sbi_shutdown。

OpenSBI 的定时接口设置的是一次事件。若只增加计数而不重新设置时钟，无法形成持续的周期中断。时钟中断发生在指令边界，返回时继续原执行流，所以不增加 tf->epc。

本次官方压缩包没有定义指导书提到的 SHUTDOWN_AFTER，本实现将其补充为 10，表示“打印次数”，因此正常启动后共处理 1000 次时钟中断、打印 10 行，然后关机。QEMU 中单次运行约 10.14 秒，属于实际环境测量，不是硬实时保证。

### 5.3 非法指令与断点

按官方评分字符串输出 `Illegal instruction at` 或 `Breakpoint at`，并输出异常类型。地址使用 64 位十六进制格式，保留完整内核虚拟地址。

之后读取异常指令的首个 16 位半字。当前 RV64GC 的指令长度判断为：

- 低两位不是 11：16 位压缩编码，epc 增加 2。
- 低两位是 11：本实验使用的 32 位标准编码，epc 增加 4。

不能把所有断点都写成 epc+=4：启用 C 扩展时，断点可能是 16 位 c.ebreak，错误地增加 4 会跳过下一条指令的一部分。只读取半字还避免了把“32 位指令”误等同于“地址一定按 4 字节对齐”。

该实现的范围是本实验中可读、已映射的内核文本及 RV64GC 的 16/32 位指令，不实现 48 位及以上扩展指令解码，也不实现用户地址取指容错。

### 5.4 未处理异常的边界

其他异常只调用 print_trapframe，不擅自调整 epc。这个兜底路径提供诊断，不代表已经具备缺页恢复、用户进程终止等完整机制。如果真实发生一个无法恢复的异常，返回后仍可能再次触发；这是本实验的功能边界。

## 六、Spec、提示词与 AI 协作过程

完整规格保存在 [prompt.md](prompt.md)，采用课程要求的四段式结构：

| 部分            | 本实验中的内容                                    |
| ------------- | ------------------------------------------ |
| PROMPT        | 指明文件、功能模块、只在标记处补全和不得修改的范围                  |
| RELY          | 从真实工程提取结构体布局、宏、已有接口和官方输出约定                 |
| GUARANTEE     | 列出 RESTORE_ALL、__alltraps、两个 handler 等交付接口 |
| SPECIFICATION | 定义前置状态、完成后的状态、不同原因的行为和特殊顺序约束               |

模块一的重点是“恢复结果与保存布局一致”和“sp 最后恢复”。模块二的重点是“下一时钟事件不会遗漏”“同步异常越过正确长度的指令”和“未知类型保持帧内容”。提示词把期望行为与具体指令实现分开，再由实际代码和测试检验。

实现过程中先阅读官方模板与测试，核对接口，然后补全代码，首次正式构建和官方评分均通过。下面记录实际发现和处理的问题，不把预防性检查描述成已经发生过的运行失败。

| 发现的问题                       | 发现方式与处理                                                                                       |
| --------------------------- | --------------------------------------------------------------------------------------------- |
| 2025 仓库与 2026 实验不一致         | 对照网页与官方压缩包，改用 2026 框架，保留旧文件夹作为参考。                                                             |
| Lab2 地址宏与新框架不一致             | 阅读头文件发现旧宏不存在，迁移时改用现有映射常量推导，避免编译失败和地址空间混用。                                                     |
| 整体复制旧 pmm.c 会丢失中断保护         | 比较两个版本的页分配包装函数，只迁移 page_init 和 Best-Fit，保留 local_intr_save/restore。                           |
| 旧代码将断点 epc 固定增加 4           | 阅读旧实现时发现；新代码按首半字判断，补充真实 16 位和 32 位异常测试。                                                       |
| 指导书提到的 SHUTDOWN_AFTER 不在模板中 | 搜索模板确认缺失，新增值为 10 的模块宏；使用真实关机退出和输出行数验证。                                                        |
| 旧版异常提示与官方评分文本不同             | 阅读 grade.sh 的匹配条件，使用今年的 `Breakpoint at`、`Illegal instruction at`。                             |
| 补充测试最初给 C/汇编文件使用相同主文件名      | 运行前审查发现二者可能映射到同一个 .o；将汇编命名为 extra_context.S，避免构建目标冲突。                                         |
| Windows 下审计脚本默认使用 GBK 解码    | 源码完整性审计首次读取含中文注释的 UTF-8 文件时发生 UnicodeDecodeError；显式指定 UTF-8 后重新审计通过。此问题发生在辅助校验脚本，不是内核编译或运行失败。 |

所有官方评分脚本、测试源文件、SAVE_ALL、trapframe 布局及非目标函数均保持原有逻辑，未通过放宽断言获取分数。

## 七、测试结果与证据

### 7.1 官方评分

实际运行官方 `make grade`，结果为：

| 评分项                     | 得分          |
| ----------------------- | ----------- |
| Trap 入口、寄存器恢复、断点 EPC    | 35/35       |
| 非法指令 EPC 与返回、handler 兜底 | 25/25       |
| 时钟重设与重复 Trap 返回         | 40/40       |
| 总分                      | **100/100** |

完整构建及评分输出见 [logs/official-grade.log](logs/official-grade.log)。评分通过不等于覆盖了所有边界，所以另做以下补充检查。

### 7.2 补充的真实 QEMU 测试

`tools/verify_extra.py` 在独立临时副本中构建并运行，每次 QEMU 超时即判为失败。正式源代码的 init.c 和官方测试不会被注入代码。

| 场景         | 检查内容                                                                         | 结果            |
| ---------- | ---------------------------------------------------------------------------- | ------------- |
| normal     | 正常内存自检；恰好 10 行 100 ticks；QEMU 自行退出，退出码 0                                     | PASS，10.135 秒 |
| exceptions | a0/ra/sp/gp/tp 保持；16/32 位断点；16/32 位非法指令；SIE/sscratch；兜底不改 EPC/cause；之后正常时钟关机 | PASS，10.142 秒 |
| best-fit   | 临时启用迁移的 Best-Fit，执行官方原有内存自检，再验证 10 行统计和关机                                    | PASS，10.136 秒 |

补充测试没有在正常程序中预先打印 PASS：每个异常后的标记必须在真实 Trap 返回后才能执行；寄存器与帧字段通过断言检查。三个 QEMU 进程均自行退出，没有把超时终止当作正常关机。

证据文件：

- [logs/normal-qemu.log](logs/normal-qemu.log)
- [logs/exceptions-qemu.log](logs/exceptions-qemu.log)
- [logs/best-fit-qemu.log](logs/best-fit-qemu.log)
- 对应 `*-build.log`：完整编译输出。
- [logs/verification.json](logs/verification.json)：版本、耗时、退出码和四个修改源文件的 SHA256。
- [logs/source-audit.json](logs/source-audit.json)：相对官方框架的改动范围、官方测试完整性与代码标记检查。

## 八、与操作系统原理的联系、差异及未覆盖内容

| 实验知识点                    | OS 原理中的对应概念   | 联系与差异                                     |
| ------------------------ | ------------- | ----------------------------------------- |
| IRQ 与同步 exception 分发     | 异步硬件事件、同步程序异常 | 都经 Trap 入口；中断通常保持返回 PC，而本实验的异常处理主动跳过指令。   |
| SAVE_ALL/RESTORE_ALL     | 上下文保存与恢复      | 保存处理器现场使执行可恢复；这里仍是同一执行流的 Trap，不是调度到另一个进程。 |
| trapframe 与 sepc/sstatus | 现场记录、受控的特权返回  | C 层通过帧改变返回状态；真正返回依赖 sret 和硬件状态语义。         |
| 时钟重设与 ticks              | 周期事件、时间片基础    | 本实验建立周期时钟，但尚未实现时间片分配和抢占调度。                |
| local_intr_save/restore  | 临界区与互斥        | 在当前单核场景防止中断打断共享状态更新；多核仍需锁和内存序机制。          |
| 未知类型输出帧                  | 内核诊断和故障定位     | 能观察故障现场，但不能代替完整异常恢复策略。                    |

本实验没有完整覆盖的重要知识点包括：

1. 进程调度、时间片与进程间上下文切换。
2. 用户态与内核态隔离、系统调用和用户栈/内核栈切换。
3. 缺页处理、按需分页、页面置换和地址空间隔离。
4. 多核并发、自旋锁、内存屏障和跨核中断。
5. 外设驱动、中断控制器、DMA 及延迟处理。
6. 中断嵌套、优先级、低延迟与实时性保证。

## 九、完成情况与文件位置

- [x] 2026 官方 Lab3 框架与来源校验。
- [x] 补齐 Lab2 标记位置，保留中断临界区保护。
- [x] RESTORE_ALL、__alltraps 与两个 handler 实现。
- [x] lab3 标记保留，YOUR CODE 替换为 2512336。
- [x] Markdown 报告、完整 prompt/spec、真实验证日志。
- [x] 官方测试 100/100，额外 QEMU 验证通过。
- [x] Windows/WSL 启动入口与本地压缩包。

- 远程推送：按用户要求暂不执行。

## 参考资料

- [课程练习要求](http://oslab.mobisys.top/lab2026/_book/lab3/lab3_2_1_exercise.html)
- [项目组成与执行流](http://oslab.mobisys.top/lab2026/_book/lab3/lab3_2_2_files.html)
- [中断处理程序](http://oslab.mobisys.top/lab2026/_book/lab3/lab3_3_3_trap.html)
- [时钟中断](http://oslab.mobisys.top/lab2026/_book/lab3/lab3_3_4_clock.html)
- [提示词结构](http://oslab.mobisys.top/lab2026/_book/lab0.5/3_prompt_structure.html)
- [实验报告要求](http://oslab.mobisys.top/lab2026/_book/lab3/lab3_4_lab_requirement.html)
