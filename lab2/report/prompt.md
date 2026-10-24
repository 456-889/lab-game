任务一
**prompt（`[PROMPT]`+`[RELY]`+`[GUARANTEE]` 摘要）**

> 请根据实验二现有框架，实现 `kern/mm/pmm.c` 中的 `static void page_init(void)`。先阅读 `pmm.c`、`pmm.h`、`memlayout.h`、`defs.h`、`dtb.h`，确认地址转换与页描述符索引约定后再写代码。要求：①用 `get_memory_base()`/`get_memory_size()` 取 DTB 范围，非法则 `panic`；②设置 `va_pa_offset` 并 `cprintf` 输出范围；③上界用 `PHYSICAL_MEMORY_END` 截断后向下按 `PGSIZE` 对齐，不要和虚拟地址 `KERNTOP` 比较；④`npage` 是排他上界，描述符个数为 `npage - nbase`；⑤`pages` 指向 `end` 之后第一个页对齐的虚拟地址，用 `PADDR` 转物理地址做容量检查；⑥所有描述符先 `SetPageReserved`，只把数组末端对齐后到上界之间的完整页交给 `init_memmap(pa2page(...), ...)`；⑦保留页/对齐填充不得进入空闲区，空闲页为零时不调用 `init_memmap`；⑧不改管理器选择。最后给出可直接替换的完整函数。

任务二
**prompt 要点**（全文见工程外模块资料 `AI提示词.md`）：以当前工程为上下文；先读 `default_pmm.c`、`pmm.h`、`memlayout.h`、`list.h` 和给定的两个测试函数；**不得修改测试函数、不得放宽断言**；只提供测试、不提供管理函数和注册结构，需自行设计；保留 `free_area/free_list/nr_free` 命名以兼容测试保存/恢复；明确 Tie-break（同大小取低地址）、精确匹配提前结束、失败不改状态；补充测试需覆盖最小块选择、并列选择、精确匹配、拆分、双向桥接合并、碎片失败，并在结束时恢复空闲状态。

任务三
**提示词一（生成分配模块并接入）**：阅读 `pmm_manager`、`Page`、地址转换宏、`page_init`、`default_pmm.c`、`list.h`；不要复用已有 Buddy 实现，从零写 `buddy_system_pmm.c/.h`；按 order 分类空闲链表（`MAX_ORDER=20`）；`init_memmap` 支持任意起点/页数并分解成对齐的 2 的幂块、不扩范围；`alloc` 向上取整、逐级拆分；`free(base, n)` 传入原申请量，按头页保存的实际页数整块归还；伙伴用 `page2ppn(base) ^ (1<<order)`；实现全部回调并注册 `buddy_pmm_manager`、在 `pmm.c` 选择它；`check` 里做内部不变量校验。

**提示词二（针对生成实现写测试）**：先读实际生成的实现与契约；测试必须在 RISC-V 内核中编译运行，**不得修改算法或删断言来伪造通过**；先从真实分配器申请 128 页对齐场地并保存原状态，测试结束恢复并验证空闲页数完全恢复；至少覆盖：非二次幂/未对齐的 61 页注册、1/2/3/5/8/9/16 页申请与向上取整、0/极大/超容量/碎片失败、61 页耗尽与乱序归还、64 页拆分后先还偶数页再还奇数页、两个 16 页区间中间留空洞、各阶段内部不变量。

challenge slub
**提示词一（生成对象分配层）**：读当前 ucore `pmm.h`、`Page`、地址转换与已实现的 Best-Fit；**在没有 SLUB 框架的情况下从零写** `slub.c/.h`；第一层继续用 `pmm_manager` 页分配（用 Best-Fit 保证"申请 n 页按 n 页归还"）；第二层暴露 `slub_init/kmalloc/kfree/slub_check`；8 个大小类别；每页一个 slab，页首元数据 + 向上 16 字节对齐的对象区；维护 partial 链表与 full/partial 转换；最后一个对象释放归还整页；>2048 字节走连续页并保存请求量与页数；`kmalloc(0)=NULL`、`kfree(NULL)` 无操作；溢出检查；不承诺野指针安全。

**提示词二（生成测试）**：覆盖 0/NULL/极大溢出请求；各大小类别边界（15/16/17、31/32/33、…、2047/2048/2049、4095/4096/4097、8192、17000）；同时申请后检查 16 字节对齐与区间不重叠；对每个对象**写满并逐字节核对**；300 个 16 字节对象跨 slab 扩容；释放偶数对象后重新分配并验证奇数对象未受破坏；partial↔full 转换、空 slab 还页；耗尽页构造 OOM 并恢复；测试前后比对空闲页数。