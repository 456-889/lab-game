# Lab 4 进程管理｜实验提示词

学号 2512336

这份文件把实验报告中的规格和实现要求整理成可直接复制的提示词。每次复制「通用要求」和对应的一段，按依赖迁移、练习一、练习二、练习三的顺序使用。完成代码后再使用验收和挑战题的提示词。

## 通用要求

你正在协助完成 2026 年 uCore RISC-V Lab 4（进程管理），使用课程随附的 lab4.zip 源码框架。阅读项目中相关声明、调用点、数据结构和课程自检后，直接在现有代码上完成指定练习。以这个框架的 RV64/Sv39 实现为准。

保留 Lab 4 练习标记，将标记中的 YOUR CODE 替换为学号 2512336。保持现有公共接口和调用约定，复用框架的内存、链表、陷入和中断控制接口。保留 tools/test_lab4.c、tools/inject.py 和 tools/grade.sh 的原有内容。工作副本、日志和交付文件统一放在 D 盘。完成后列出实际修改的文件、各项验证结果和仍未验证的情况。

## 前置任务　迁移 Lab 2 和 Lab 3

在 Lab 4 工程中查找标有 lab2 和 lab3 的待补区域，迁移我前两个实验的实现，保留原有来源署名。先对照当前 Lab 4 的头文件和调用点，再适配代码。

1. 在 kern/mm/pmm.c 中迁移 page_init。用 DTB 提供的物理内存范围和本框架的直接映射上限确定可管理内存。将页描述符放在对齐后的内核镜像末尾，保证数组不越界。内核映像、页描述符及其之前的保留区域不进入空闲页链表，只登记余下的完整物理页。
2. 在 kern/mm/default_pmm.c 中接入已有 Best-Fit 分配器，按框架导出 default_pmm_manager。分配时挑选最小的足够空闲块，分裂后维护剩余块；释放时合并相邻空闲块并更新页数。保留已有 basic_check 和 best_fit_check。
3. 在 kern/trap/trapentry.S 中匹配当前 SAVE_ALL、REGBYTES 和 struct trapframe 的布局。把帧指针放进 a0 后调用 trap，返回时恢复 sepc、sstatus 和通用寄存器，最后恢复原 sp，由 sret 继续执行。这条恢复路径也需要支持 Lab 4 的 forkrets。
4. 在 kern/trap/trap.c 中迁移时钟中断和异常分派。时钟中断重设下次事件并累计 tick；移除 Lab 3 专用的计时关机逻辑。继承 Lab 3 对断点和非法指令的处理时，按指令长度推进 epc，并确保异常处理与本项目的 trapframe 布局一致。

验收时检查已有页分配断言、上下文偏移和汇编调用约定。待 Lab 4 练习补齐后，再用课程 Makefile 和 QEMU 验证完整启动过程。

## 练习一　虚拟内存页操作

在 kern/mm/pmm.c 中实现 page_insert 和 page_remove。先读 pmm.h、mmu.h、get_pte、check_pgdir 和 check_boot_pgdir，确认 PTE 标志位、页描述符引用计数、启动大页布局和错误返回约定。

1. page_insert 成功时让 la 映射到给定的物理页。首次映射给目标页增加一次引用；同一物理页重新映射时更新权限，保持引用计数不变；换成不同物理页时增加新页引用，更新 PTE 并使旧翻译失效，再减少旧页引用，归零后释放旧页。框架中 perm = 0 的默认读权限，以及 RISC-V 要求 W 与 R 同时有效的约束，都要纳入设计。
2. 定位 4 KiB 叶项时遍历 Sv39 的两级非叶项。识别已有的大页叶项，避免把它当成下级表。新建的非叶项使用页表指针所需的位。若创建下级表失败，返回 -E_NO_MEM，撤销本次新申请的中间页，保留原来的页表、页引用计数和可用页数。
3. page_remove 只查找现有条目。有效映射先清除 PTE，再失效相应地址的 TLB 翻译，随后扣减并按需释放物理页。目标没有映射或重复删除时，直接返回。
4. 结合 kern/init/entry.S 核对启动页表检查。如果模板中的检查与实际的大页布局不一致，说明差异并核对映射基址和覆盖范围，保留外部评分用例。

验收时覆盖首次映射、同页改权限、不同页替换、重复删除和内存不足回滚。补充检查一种内存不足情形，系统只剩一页而该虚拟地址需要两张新页表，预期失败后仍剩一页且根页表项未变化。对替换后的虚拟地址进行实际读写，确认访问到了新物理页。

## 练习二　进程创建和初始化

在 kern/process/proc.c 中完成 alloc_proc、proc_init、kernel_thread、do_fork、copy_thread 和 copy_mm。查看 proc.h、trap.h、kern/process/entry.S 及 kern/trap/trapentry.S，核对 C 与汇编对 PCB、trapframe 和入口参数的约定。

1. alloc_proc 用 kmalloc 申请并初始化 PCB，默认状态为 PROC_UNINIT，PID 为 -1，使用 boot_pgdir_pa，初始化链表和哈希节点。proc_init 初始化进程链表和 PID 哈希表，将启动执行现场登记为 PID 0 的 idleproc，复用 bootstack 并置重调度标记。将 current 设为 idleproc，再通过 kernel_thread 创建 PID 1 的 initproc。
2. kernel_thread 构造临时 trapframe，把线程函数和参数分别写入 s0、s1，将 epc 指向 kernel_thread_entry。设置 SPP 和 SPIE 并清除 SIE，让首次 sret 进入 S 态后开启中断。通过 do_fork 将组织好的执行现场交给新线程。
3. do_fork 先检查进程数限制，再准备 PCB、父子关系和内核栈。调用 copy_mm 与 copy_thread 完成地址空间接口和执行现场初始化。本实验线程共享内核页表，用户 mm 为空。资源准备完毕后，在临界区分配唯一 PID、登记哈希和进程链表、更新计数并唤醒线程。成功返回 PID，失败返回相应负错误码并回收已取得的资源。
4. copy_thread 把 trapframe 拷入新线程内核栈，令子线程 a0 为 0，线程栈指针使用传入栈地址或默认内核栈顶。设置 context.ra 为 forkret，context.sp 指向保存好的 trapframe。逐步检查 forkret、forkrets、__trapret 和 kernel_thread_entry 之间 sp、ra、epc、s0、s1 的传递。

验收时检查 idleproc 与 initproc 的 PID、父子关系、栈地址、状态和入口地址。确认 initproc 能运行到 init_main，并能从入口读到正确参数。

## 练习三　进程调度和上下文切换

实现 kern/schedule/sched.c 的 schedule，kern/process/proc.c 的 cpu_idle、proc_run，以及 kern/process/switch.S 的 switch_to。根据 proc.h 中 struct context 的真实字段顺序确定汇编偏移。

1. cpu_idle 在 need_resched 置位时调用 schedule。schedule 关本地中断，清除当前线程的重调度标记。当前为普通线程时从它的下一项开始环形查找，当前为 idle 时从队首开始。只选 PROC_RUNNABLE，跳过链表哨兵，无就绪线程就选 idleproc。更新选中线程的 runs，目标与当前线程不同时才执行切换。
2. proc_run 在同一临界区内更新 current，根据目标页表物理基址构造 64 位 Sv39 satp，使用 SATP_MODE_SV39 和物理页号。写入 satp 后刷新 TLB，再调用 switch_to。线程将来恢复运行时应恢复自己进入临界区前的中断状态。
3. switch_to 使用 a0 和 a1 指向旧、新上下文，保存与恢复 ra、sp、s0 至 s11，最后 ret。核对新线程会进入 forkret，已运行线程会回到先前的切换调用点。保持课程模板的线程退出入口，先验收创建、切换及执行路径。

验收时用课程注入用例创建两个子线程并主动反复调度，确认两个线程都真正运行过。检查从 idle、普通线程和无就绪项三种起点执行的选择逻辑。

## 综合验收　构建、运行和评分

在 D 盘项目目录中，用课程指定的 RISC-V 工具链和 QEMU 依次运行 make、make qemu、make grade。评测临时目录也设在 D 盘。核对普通启动经过物理内存、页表、VMA 自检，以及 initproc 的 PID 1 和问候语输出。模板中 init_main 返回后会进入调试监视器。评分应实际检查 PMM、Process Create、Schedule 三项。记录真实输出和分数，发现失败时定位并修复后重新验证。

## 挑战题　中断开关与多级页表

根据当前实现写出两道挑战题的解释，使用中文并引用具体函数和寄存器。

1. 从 kern/sync/sync.h 和 kern/driver/intr.c 追踪 local_intr_save 与 local_intr_restore，解释如何读写 sstatus.SIE。分别推演原本开中断、原本关中断和两层嵌套临界区三种情形，说明标志保存了什么，以及只影响当前 hart 的限制。
2. 从 get_pte 的 PDX1、PDX0 和 PTX 解释两段页表遍历代码为何相似。用一张表对比 Sv32、Sv39、Sv48 的页表层数、每级索引位数、PTE 宽度、页内偏移。说明上层遇到大页叶项应怎样处理，并结合只查找与按需创建的调用，分析当前 create 参数的优点、缺点和将来拆分的条件。
