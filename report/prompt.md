# Lab3 规格与 AI 提示词

日期：2026-11-04。


## 0. Lab2 依赖迁移

### [PROMPT]

任务：补齐 `kern/mm/pmm.c` 和 `kern/mm/best_fit_pmm.c` 中的 lab2 标记，参考用户提供的 `lab2_new333.zip` 及其此前的 Lab2 提示词。只迁移 Lab3 框架缺少的物理内存初始化和 Best-Fit 实现，不替换整个 pmm.c。

操作要求：修改实际文件，保留本年度框架的中断临界区保护、默认管理器选择、原有自检和其他函数。保留 lab2 注释及来源说明，不照搬新框架不存在的宏。不得修改官方测试以通过测试。

### [RELY]

- `get_memory_base()`、`get_memory_size()`：DTB 内存区间。
- `KERNBASE`、`KERNTOP`、`PHYSICAL_MEMORY_OFFSET`、`PGSIZE`。
- `Page`、`pages`、`npage`、`nbase`、`PADDR`、`pa2page`、`init_memmap`。
- `pmm_manager` 接口，`free_area_t`，原有链表函数与 Page 标志位。
- Lab2 的 page_init 注释记录原作者 2512337；Best-Fit 记录 2512336。迁移保留来源。

### [GUARANTEE]

实现 `static void page_init(void)`，Best-Fit 的 init/init_memmap/alloc_pages/free_pages/nr_free_pages 回调，以及 `best_fit_pmm_manager` 注册对象。保留官方 `basic_check()`、`best_fit_check()`。

### [SPECIFICATION]

**page_init Pre-Condition**：DTB 已初始化，内核固定映射已建立，物理页管理器已初始化。

**Post-Condition**：有效内存上界受直接映射范围限制；页描述符数组放在内核之后并对齐；OpenSBI、内核、描述符、对齐空隙不会被分配；只有剩余完整物理页进入空闲链表。

**Case**：内存范围溢出、无法覆盖内核或无法容纳描述符时停止并报告错误；剩余空闲区为空时不得注册零页块。

**Best-Fit Pre-Condition**：空闲链表按地址有序，只有空闲块头拥有 property 标记。

**Post-Condition**：从足够大的块中选择最小块，同大小选择较低地址；分裂保留剩余空闲块，归还时合并左右相邻块；空闲页数准确；失败不改变状态。

## 1. 练习1完整提示词：Trap 上下文恢复与入口

````text
[PROMPT]

请先读取实际工程中的 `kern/trap/trapentry.S`、`kern/trap/trap.h`、`libs/riscv.h` 和 `kern/trap/trap.c`。核对 SAVE_ALL 的栈布局、REGBYTES 与 LOAD/STORE 宏、trapframe 字段和 trap() 的调用关系，再补全代码。

任务：在 `kern/trap/trapentry.S` 的两个 lab3 function1 标记处实现 `RESTORE_ALL` 和 `__alltraps` 缺失部分，使 Trap 经 C 处理后能够正确返回。

操作要求：直接修改实际文件。只补全标记区域，不改 SAVE_ALL、不改 trapframe 布局、不改 trap() 签名。把 YOUR CODE 替换为 2512336。不得照搬与实际布局不一致的汇编模板。

输出要求：完成实际文件修改后，列出修改位置，解释 a0 传参、CSR 恢复顺序以及最后恢复 sp 的原因。给出实际执行过的编译或测试命令与结果。若模块二或 Lab2 依赖尚未补齐，应说明完整测试还依赖哪些实现，记录实际验证范围。

[RELY]

- `REGBYTES=8`（当前 RV64）；SAVE_ALL 分配 36 个寄存器宽度的栈帧，共 288 字节。
- 槽 0～31 对应 x0～x31；槽 2 保存的是通过 sscratch 取回的被打断时的 sp。
- 槽 32、33、34、35 对应 sstatus、sepc、stval（旧名 sbadaddr）、scause。
- `void trap(struct trapframe *tf)`；RISC-V ABI 第一个参数通过 a0 传递。
- `__trapret` 已提供 RESTORE_ALL 调用和 sret。

[GUARANTEE]

- `RESTORE_ALL` 恢复返回所需状态和通用寄存器。
- `__alltraps` 正确传递当前 Trap frame 并调用 trap。

[SPECIFICATION]

**RESTORE_ALL Pre-Condition**：sp 指向 SAVE_ALL 布局的完整帧；C 处理函数已经返回，可能更新了 tf->epc。

**Post-Condition**：恢复后的 sepc 使用帧中的最新 epc；sstatus 恢复帧中的状态；x1、x3～x31 恢复原值；最后恢复原 sp；x0 不需要写回。stval/scause 用于诊断，无需在返回时写回。

**Requirements**：利用临时寄存器写回 CSR 后再恢复这些临时寄存器自身；在所有基于 sp 的访问完成前不得恢复 sp；保持栈对齐与调用约定。

**__alltraps Pre-Condition**：已执行框架 SAVE_ALL，sp 指向当前帧。

**Post-Condition**：trap() 收到真实帧地址；调用返回后 sp 仍指向同一帧；控制流进入 __trapret，最终 sret 返回。

验收要求：
1. 源码布局与 SAVE_ALL、struct trapframe 一致，学号标记完整。
2. 补齐全部实验依赖后运行官方 make grade，确认 Trap 入口、通用寄存器恢复和断点返回测试通过。
3. 对照返回路径检查：trap() 返回后经过 __trapret、RESTORE_ALL、sret；处理函数对 tf->epc 的更新应反映到实际返回位置。
````

## 2. 练习2完整提示词：中断与异常处理

````text
[PROMPT]

请先读取实际工程中的 `kern/trap/trap.c`、`kern/trap/trap.h`、`kern/driver/clock.c`、`kern/driver/clock.h`、`libs/riscv.h`、`libs/sbi.h`、`libs/sbi.c`，以及 `tools/grade.sh`、`tools/test_lab3.c`。核对原因码、时钟接口、关机接口、输出格式与测试条件，再补全代码。实验要求与真实接口共同作为实现依据。

任务：在 `kern/trap/trap.c` 的 lab3 function2 标记处实现 interrupt_handler() 和 exception_handler()，按官方测试格式输出，完成时钟事件重设、计数、异常恢复与定时关机。

操作要求：只补全此模块，允许添加必要的 include、模块内宏、静态计数与静态辅助函数；不改 trap()、trap_dispatch()、print_ticks()、print_trapframe() 等已有函数；不改官方测试。标记保留并使用学号 2512336。

输出要求：完成实际文件修改后，说明时钟事件如何持续触发、ticks 与打印次数如何分别计数、16/32 位异常指令如何推进返回地址，以及未知类型如何输出诊断。列出实际执行过的编译、官方评分与补充测试结果，测试结果必须来自真实运行记录。

[RELY]

- `tf->cause` 最高位表示中断，低位表示原因；tf->epc 保存异常 PC。
- `clock_set_next_event()`、全局 volatile ticks、TICK_NUM=100、print_ticks()。
- 关机接口为 libs/sbi.h 中的 `sbi_shutdown()`。
- 官网讲义提到 SHUTDOWN_AFTER，但下载的框架没有定义；本模块补充为 10，表示输出次数。
- IRQ_*、CAUSE_ILLEGAL_INSTRUCTION、CAUSE_BREAKPOINT、print_trapframe(tf)。
- 官方 grade.sh 检查 `Breakpoint at`、`Illegal instruction at`、`Supervisor software interrupt`、`Unknown interrupt: cause 15`。
- 当前实验运行 RV64GC，实际测试覆盖 16 位压缩和 32 位标准指令，异常指令位于可读的内核映射中。

[GUARANTEE]

```c
void interrupt_handler(struct trapframe *tf);
void exception_handler(struct trapframe *tf);
```

可以添加静态指令长度辅助函数，不改变公开接口。

[SPECIFICATION]

**interrupt_handler Pre-Condition**：tf 是有效帧，统一分发器已判定为中断；直接单元调用时也允许传入无最高位的原因码。

**Post-Condition / Case 1**：监督态时钟中断重新安排下一事件；ticks 恰增加一次；每达到 100 的倍数输出一次；第 10 次输出后调用关机接口。处理中断不调整 epc。

**Case 2**：其他框架已知中断输出相应类型。

**Case 3**：未知中断输出清除最高位后的原因号及完整帧，不改变输入帧。

**exception_handler Pre-Condition**：tf 有效；非法指令和断点异常的 epc 指向可读取的内核指令。

**Post-Condition / Case 1**：非法指令异常输出类型与原地址，然后越过触发异常的指令。

**Case 2**：断点异常输出类型与原地址，然后越过对应断点；压缩断点前进 2 字节，标准断点前进 4 字节。

**Case 3**：其余异常仅调用 print_trapframe，不擅自修改 epc 或伪装恢复。

**Requirements**：读取 16 位指令首半字，通过低两位区分当前 RV64GC 的 16/32 位编码；避免用 32 位读取隐含 4 字节对齐假设；本实验不承诺支持可变长扩展指令、用户空间取指失败或页错误恢复。

验收要求：
1. 完整工程编译通过，官方 make grade 检查中断与异常路径。
2. 在 QEMU 中确认时钟中断连续发生，每 100 次打印一行，正常运行恰好输出 10 行后由 sbi_shutdown() 触发退出。
3. 在独立测试副本中分别触发 16 位 c.ebreak、32 位 ebreak、16 位和 32 位非法指令，验证异常处理后能够执行后续指令。
4. 验证其他已知中断的提示输出，以及未知中断、未处理异常的 Trap frame 输出与返回地址保持情况。
````


