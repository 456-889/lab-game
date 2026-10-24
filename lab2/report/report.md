# 实验二 实验报告：物理内存管理（Lab2）

## 基本信息

| 项目      | 内容                                                                         |
| ------- | -------------------------------------------------------------------------- |
| 实验名称    | 实验二：物理内存管理（Lab2）                                                           |
| 小组成员    | 【2512336赵翊博、2512337贾宸、2512392宋成坤】                                               |
| 完成日期    | 【2026-10-24】                                                               |
| 代码与报告位置 | `labcodes/lab2`（本工程见文末"附录 A 工程结构"）                                         |
| 实验指导书   | <http://oslab.mobisys.top/lab2026/_book/lab2/lab2_2_1_exercise.html>       |
| 报告要求    | <http://oslab.mobisys.top/lab2026/_book/lab2/lab2_5_labs_requirement.html> |

本报告按照指导书 Lab2「实验报告要求」撰写：整体逻辑理解、核心函数与功能模块理解、每个练习的 spec 与 prompt 写法、AI 生成代码过程中的 bug 及解决、知识点与 OS 原理的对应、OS 原理中本实验未覆盖的内容，并回答练习中提出的全部问题。

---

## 一、实验目的

1. 理解操作系统如何**发现**物理内存：在 RISC-V + OpenSBI 的环境下，通过设备树（DTB）获得物理内存的起始地址与大小。
2. 理解如何**描述与组织**物理内存：用 `struct Page` 描述符数组描述每个物理页，把可用页组织成空闲区并交给物理内存管理器。
3. 理解**页面分配算法**：读懂 First-Fit，实现 Best-Fit，并从零实现 Buddy System，比较按地址顺序链表的连续分配与按 2 的幂分块的伙伴分配。
4. 理解页分配器与**对象分配器**的分层关系：在页级分配之上实现简化版 SLUB，支持任意大小对象、复用与回收。
5. 依据 Lab0.5 的提示词工程方法，用四段式提示词（`[PROMPT] [RELY] [GUARANTEE] [SPECIFICATION]`）与 AI 协作完成设计与实现，并坚持"AI 出假设、实验出结论"。

---

## 二、实验环境

| 项目    | 配置                                                                       |
| ----- | ------------------------------------------------------------------------ |
| 宿主机   | Windows 10/11 + WSL2（Ubuntu）                                             |
| 交叉工具链 | `riscv64-unknown-elf`（SiFive GCC-Metal 10.2.0）                           |
| 模拟器   | QEMU 4.1.1（`qemu-system-riscv64 -machine virt -nographic -bios default`） |
| 固件    | QEMU 自带 OpenSBI v0.4（M 模式，基址 `0x80000000`）                               |
| 目标板   | QEMU virt，128 MiB DRAM（`0x80000000`–`0x87ffffff`），单 CPU                  |
| 构建    | GNU make + 课程 Makefile（`tools/kernel.ld`、`tools/function.mk`）            |
| 关键命令  | `make qemu-best` / `make qemu-buddy` / `make qemu-slub` / `make grade`   |

> 说明：本工程的启动方式沿用实验一的 `-device loader,file=bin/ucore.img,addr=0x80200000`；QEMU 4.1.1 自带的 OpenSBI（`fw_jump`）在编译期固定跳转到 `0x80200000`，与链接脚本 `BASE_ADDRESS` 一致。

---

## 三、本章整体逻辑理解

### 3.1 逻辑主线

本章要解决的问题是：**在 Lab1 已经能启动的内核之上，把物理内存真正管起来**。整章可以概括成一条从"发现"到"组织"再到"分配"的链路：

```
kern_init()
  ├─ memset(edata, 0, end - edata)        清 .bss
  ├─ dtb_init()                          从设备树读出 memory_base / memory_size
  └─ pmm_init()
        ├─ init_pmm_manager()            选择一种物理内存管理器（default / best_fit / buddy）
        ├─ page_init()                   建立 Page 描述符数组，把空闲页交给管理器   ← 任务一
        │     └─ init_memmap(base, n) → pmm_manager->init_memmap(base, n)
        ├─ check_alloc_page()            pmm_manager->check()，跑该管理器的自检
        └─ 打印启动页表 satp 的虚拟/物理地址
  （若启用 SLUB）slub_init() → slub_check()  在页分配之上提供任意大小对象分配
```

### 3.2 功能的逐步实现顺序与理由

1. **先发现内存（`dtb_init`）**。Lab1 的内核只知道自己从 `0x80200000` 开始，并不知道内存有多大。RISC-V 的约定是固件（OpenSBI）把设备树的物理地址放在 `a1` 里传给我们，`entry.S` 保存 `boot_dtb`，`dtb_init()` 解析出 `memory_base`/`memory_size`。没有这一步，后面的页描述符都不知道该覆盖多大范围。
2. **再建立"内存的索引"（任务一 `page_init`）**。物理内存是线性的字节数组，内核需要一个数组来记录每一页的状态（是否保留、是否空闲块头、块长、引用计数）。因此要在内核镜像之后放 `struct Page` 描述符数组，并把 OpenSBI、内核镜像、描述符数组本身排除，只把**完整空闲页**交给分配器。这一步是所有分配算法的前提。
3. **再确定"谁来分配"（`pmm_manager` 抽象）**。框架用函数指针表把 `init / init_memmap / alloc_pages / free_pages / nr_free_pages / check` 抽象出来，`page_init` 只需要调用 `init_memmap`，不用关心底层是 First-Fit 还是 Best-Fit。这使得我们在同一个工程里可以切换四种管理器。
4. **然后理解并实现具体算法**（功能模块二）：
   - 先读懂 First-Fit（`default_pmm.c`）：按地址有序链表 + 头页 `property` 记录块长，分配取第一个够大的块、释放时前后合并；
   - 再实现 Best-Fit：保留同一套链表和元数据约定，只把"选第一个够大的"换成"选最小的够大的"，验证"分配策略"与"数据结构"可以解耦；
   - 再实现 Buddy：换一种数据结构（按 order 的空闲链表），用 2 的幂与异或算伙伴，理解"块大小受限"带来的内部碎片与 O(log n) 级合并；
   - 最后在页分配器之上实现 SLUB：理解"页级分配"与"对象级分配"的分层，以及 slab/partial/full 状态与空页回收。
5. **每一步都用"自检 + 断言"闭环**：每个管理器都实现 `check`，由 `pmm_init` 在 `check_alloc_page()` 中调用；既验证自己的算法，也验证"空闲页总数在测试结束后完全恢复"这一全局不变量。

---

## 四、核心函数与功能模块理解

### 4.1 物理内存管理框架（`pmm.h` / `pmm.c`）

- `struct Page`：每个物理页一个描述符，含 `ref`（引用计数）、`flags`（`PG_reserved`、`PG_property` 等标志位）、`property`（空闲块页数，仅块头使用）、`page_link`（空闲链表节点）。
- `free_area_t`：`free_list`（空闲块头链表）+ `nr_free`（空闲页总数）。
- `struct pmm_manager`：六项回调。`pmm_init()` 依次做 `init_pmm_manager()`、`page_init()`、`check_alloc_page()`。
- 关键约定：`pages[i]` 对应物理页号 `nbase + i`（`nbase = DRAM_BASE / PGSIZE`），因此 `page2pa(page) = (page - pages + nbase) << PGSHIFT`；`pa2page` 是其反函数。

### 4.2 任务一：`page_init()`（`kern/mm/pmm.c`）

核心是四个地址概念的区分与边界计算：

```c
va_pa_offset = PHYSICAL_MEMORY_OFFSET;           /* 内核虚拟地址 = 物理地址 + 偏移 */

mem_begin = get_memory_base();                   /* 设备树：物理起始，左闭 */
mem_size  = get_memory_size();                   /* 设备树：物理大小 */
mem_end   = mem_begin + mem_size;                /* 物理末端，右开 */

maxpa = min(mem_end, PHYSICAL_MEMORY_END);       /* 用物理地址上界截断 */
maxpa = ROUNDDOWN(maxpa, PGSIZE);                /* 末端向下对齐，丢弃不足一页的尾巴 */

kernel_end_pa = PADDR(end);                      /* end 是虚拟地址，先转物理 */
npage    = maxpa / PGSIZE;                       /* 可管理物理页号的排他上界 */
nr_pages = npage - nbase;                        /* 描述符个数 */
pages    = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);   /* 紧跟内核镜像、页对齐 */

/* 容量检查：描述符数组必须完全落在可管理物理内存内 */
pages_pa  = PADDR(pages);
descs_end = pages_pa + nr_pages * sizeof(struct Page);
free_begin = ROUNDUP(descs_end, PGSIZE);         /* 空闲区物理起点，页对齐 */

/* 先把所有描述符置为保留，防止未完成布局的页被分配 */
for (i = 0; i < nr_pages; i++) { p->flags = 0; p->ref = 0; p->property = 0;
                                 list_init(&p->page_link); SetPageReserved(p); }

/* 只把两端都页对齐、非空的完整区间交给当前管理器 */
if (free_begin < maxpa)
    init_memmap(pa2page(free_begin), (maxpa - free_begin) / PGSIZE);
```

函数理解的要点：

1. **为什么用 `npage` 而不是"描述符总数"**：`npage` 是物理页号上界，描述符数组只需覆盖 `[nbase, npage)`，所以个数是 `npage - nbase`；`pages[0]` 描述的是 `0x80000000` 这一页，不是物理页 0。
2. **为什么上界要用物理常量 `PHYSICAL_MEMORY_END` 截断**：`KERNTOP` 是虚拟地址，直接和物理地址比较没有意义；把两边都化成物理地址比较才是同一维度。
3. **为什么描述符数组也要占用内存、且必须保留**：数组本身在内核镜像之后，也会落在 DRAM 里；如果把这部分页交给分配器，分配出去的页会覆盖描述符，系统立刻崩溃。
4. **为什么先全部 `SetPageReserved`**：`init_memmap` 只处理"空闲区起点之后"的页，之前的页保持保留态；即使中途 `panic`，也不会出现"半初始化"的页被分配。
5. **失败路径**：DTB 无效、范围溢出、内存不覆盖内核、描述符容量不足都 `panic`；没有完整空闲页时跳过 `init_memmap`（不能注册空区间）。

### 4.3 功能模块二 · 任务一：First-Fit（`default_pmm.c`）

- `default_init()`：链表置空、`nr_free = 0`，只建立管理器初始状态。
- `default_init_memmap(base, n)`：校验 `PageReserved`，清 `flags/property/ref`；头页 `property = n`、`SetPageProperty`；按地址有序插入链表；`nr_free += n`。
- `default_alloc_pages(n)`：从头扫描，找到第一个 `property >= n` 的块；整块够则整体摘除，块更大则取前 n 页并把余块（`p + n`，`property = 原值 - n`）插回原位置；`nr_free -= n`，清除返回块头的 `PG_property`。
- `default_free_pages(base, n)`：校验不是保留页/不是空闲块头；清状态、`ref = 0`；按地址插回；先看前驱 `p + p->property == base` 合并，再用合并后的块看后继 `base + base->property == p` 合并；合并只改组织，不再改 `nr_free`。
- 两个标志的区别：`PG_reserved` 表示"保留，不能分配"；`PG_property` 表示"空闲块头"。**空闲块内部页的 `PG_property` 也是 0**，所以"标志为 0"不等于"已分配"——这是理解与查错的关键。

### 4.4 功能模块二 · 任务二：Best-Fit（`best_fit_pmm.c`）

保留 First-Fit 的数据结构约定（`static free_area_t free_area` + `free_list`/`nr_free` 宏、按地址有序、仅头页 `PG_property`），只改变选块策略：

| 函数                                                 | 作用                                                                 |
| -------------------------------------------------- | ------------------------------------------------------------------ |
| `best_fit_init()`                                  | 初始化链表与计数                                                           |
| `best_fit_insert_merge(base)`                      | 按地址插入，并与前后相邻空闲块合并                                                  |
| `best_fit_init_memmap(base, n)`                    | 注册空闲区（支持多次注册、可合并）                                                  |
| `best_fit_alloc_pages(n)`                          | 遍历所有可用块，选 **`property` 最小** 者；同大小取先出现的（链表按地址有序 ⇒ 低地址优先）；遇到精确匹配立即结束 |
| `best_fit_free_pages(base, n)`                     | 逐页清理后插入，先并前邻、再并后邻                                                  |
| `best_fit_nr_free_pages()`                         | 返回 `nr_free`                                                       |
| `best_fit_extra_check()` / `best_fit_run_checks()` | 先跑**未修改**的 `basic_check()`/`best_fit_check()`，再跑补充测试               |

选块逻辑的伪代码：

```c
best = NULL;
for (每个空闲块 p) {
    if (p->property >= n) {
        if (best == NULL || p->property < best->property) best = p;
        if (p->property == n) break;          /* 精确匹配，不可能更优 */
    }
}
if (best == NULL) return NULL;                /* 总量够但没有连续块，或总量不够 */
摘除 best；若 property > n 则把余块插回；nr_free -= n；ClearPageProperty(best);
```

Best-Fit 的代价：分配要扫描全部空闲块（最坏 O(F)），换来"本次剩余空间最小"；但它不保证长期碎片最少，可能持续产生很小的余块。

### 4.5 功能模块二 · 任务三：Buddy System（`buddy_system_pmm.c`）

数据结构换成**按 order 分类的空闲链表**：order 为 k 的块含 `2^k` 页，`MAX_ORDER = 20`。

| 函数                                        | 作用                                        |
| ----------------------------------------- | ----------------------------------------- |
| `block_size(order)`                       | `1 << order`                              |
| `buddy_init()`                            | 清空各阶链表与计数                                 |
| `add_block(p, order)` / `remove_block(p)` | 按阶挂入/摘出空闲链表                               |
| `release_block(p, order)`                 | 归还一块并尝试向上递归合并                             |
| `buddy_init_memmap(base, n)`              | 把任意起点、任意页数的区间**按物理页号对齐分解**成若干 2 的幂块，不向外扩张 |
| `buddy_alloc_pages(n)`                    | 请求向上取整到 2 的幂，从对应阶或更高阶找块，逐级二分拆出左半、右半挂回     |
| `mark_allocated(base, actual, requested)` | 头页记录实际页数与原请求页数，内部页打标记                     |
| `buddy_free_pages(base, n)`               | 按原请求 n 找到头页记录的实际页数，归还整块并递归合并              |
| `buddy_nr_free_pages()`                   | 返回空闲页计数                                   |
| `buddy_validate()`                        | 校验块对齐、边界、链表、计数等不变量                        |
| `buddy_check()`                           | 在真实分配器上申请独立测试场地后隔离运行全部用例                  |

伙伴判定的关键是**用绝对物理页号做异或**：

```c
buddy_ppn = page2ppn(base) ^ (1u << order);   /* 不是对虚拟地址、也不是对区间相对下标异或 */
```

只有"同阶、空闲、已注册、在描述符范围内"的伙伴才能合并；跨保留空洞、跨区间边界都不合并。

### 4.6 Challenge：SLUB 对象分配（`slub.c`）

两层架构：**下层继续用 Best-Fit 做页分配，上层用 slab 提供任意大小对象**。

| 函数/结构                             | 作用                                                        |
| --------------------------------- | --------------------------------------------------------- |
| `struct object_cache`             | 8 个大小类别（16/32/64/128/256/512/1024/2048 字节），各自的 partial 链表 |
| `struct slab_header`              | 页首元数据：标识、所属 cache、对象总数、已用数、空闲对象链表、分配位图                    |
| `link_partial` / `unlink_partial` | 维护 partial 链表（有空位 ↔ 已满）                                   |
| `slub_init()`                     | 初始化 8 个类别                                                 |
| `new_slab(index)`                 | 向 PMM 申请一页，切成对象槽，槽内空闲指针串成 freelist                        |
| `kmalloc(size)`                   | 小对象按类别向上取整分配；>2048 字节走连续页路径（页首存请求量与页数）；返回至少 16 字节对齐       |
| `kfree(ptr)`                      | 根据头部判断类别：小对象归还槽位（最后一个对象释放则还页），大对象归还全部连续页                  |
| `slub_check()`                    | 边界、隔离、复用、OOM 等自检                                          |

教学简化点：单 CPU、无锁、无 per-CPU 缓存、无 NUMA；不承诺对野指针/地址重用后的陈旧指针做安全检测。

---

## 五、每个练习的 spec 与 prompt 是怎么写的

我们按 Lab0.5 的四段式框架组织：`[PROMPT]`（做什么/改哪里/怎么改）、`[RELY]`（最小可信上下文：宏、结构、可用函数、工具链）、`[GUARANTEE]`（必须交付的接口或结论清单）、`[SPECIFICATION]`（Pre/Post-Condition + Case + Requirements）。**spec 的作用是把"需求"写成可验证的行为描述，而不是写实现步骤**。

### 5.1 任务一 `page_init()`：spec 与 prompt

**spec（写进 `[SPECIFICATION]` 的核心内容）**

- *Pre-Condition*：`pmm_init()` 已调用 `init_pmm_manager()`；`dtb_init()` 已保存 `memory_base`/`memory_size`；`va_pa_offset` 尚未设置。
- *Post-Condition*：`va_pa_offset == PHYSICAL_MEMORY_OFFSET`；`npage` 为可管理物理页号排他上界；`pages` 非空且页对齐、位于 `end` 之后；所有描述符初始为 `PG_reserved`；空闲区只包含"描述符数组末端向上对齐"到"可管理物理上界向下对齐"之间的完整页。
- *Case 1（正常）*：打印探测到的物理内存范围，调用一次 `init_memmap`。
- *Case 2（DTB 无效/为 0）*：`panic`，不继续。
- *Case 3（范围溢出或内存不覆盖内核）*：`panic`。
- *Case 4（描述符数组容量不足）*：`panic`。
- *Case 5（末端不对齐）*：丢弃不足一页的尾部；*Case 6（无完整空闲页）*：不调用 `init_memmap`。
- *Requirements*：物理上界必须用物理常量截断；不得把 OpenSBI/内核/描述符数组放进入空闲区；`npage` 与 `pages[0]` 的索引约定不能改。

**prompt（`[PROMPT]`+`[RELY]`+`[GUARANTEE]` 摘要）**

> 请根据实验二现有框架，实现 `kern/mm/pmm.c` 中的 `static void page_init(void)`。先阅读 `pmm.c`、`pmm.h`、`memlayout.h`、`defs.h`、`dtb.h`，确认地址转换与页描述符索引约定后再写代码。要求：①用 `get_memory_base()`/`get_memory_size()` 取 DTB 范围，非法则 `panic`；②设置 `va_pa_offset` 并 `cprintf` 输出范围；③上界用 `PHYSICAL_MEMORY_END` 截断后向下按 `PGSIZE` 对齐，不要和虚拟地址 `KERNTOP` 比较；④`npage` 是排他上界，描述符个数为 `npage - nbase`；⑤`pages` 指向 `end` 之后第一个页对齐的虚拟地址，用 `PADDR` 转物理地址做容量检查；⑥所有描述符先 `SetPageReserved`，只把数组末端对齐后到上界之间的完整页交给 `init_memmap(pa2page(...), ...)`；⑦保留页/对齐填充不得进入空闲区，空闲页为零时不调用 `init_memmap`；⑧不改管理器选择。最后给出可直接替换的完整函数。

### 5.2 任务二 Best-Fit：spec 与 prompt

**spec**

- *Pre*：`init_memmap` 已注册空闲区；`n > 0`；空闲链表按地址有序。
- *Post*：返回块头，实际分配 n 页；余块（若有）仍以头页 `PG_property` 标记；`nr_free = 所有空闲块页数之和`。
- *Case 1*：总空闲量不足 → `NULL`，状态不变。
- *Case 2*：总量够但无连续块满足 → `NULL`。
- *Case 3*：找到 `property == n` 的块 → 整体摘除。
- *Case 4*：找到最小的 `property > n` → 拆分，余块按地址插回。
- *Case 5*：多个同大小候选 → 取地址最低者。
- *Requirements*：`check` 必须先跑**未修改**的原测试再跑补测；不得为测试而改断言；释放要兼容"分段分配、整段回收"。

**prompt 要点**（全文见工程外模块资料 `AI提示词.md`）：以当前工程为上下文；先读 `default_pmm.c`、`pmm.h`、`memlayout.h`、`list.h` 和给定的两个测试函数；**不得修改测试函数、不得放宽断言**；只提供测试、不提供管理函数和注册结构，需自行设计；保留 `free_area/free_list/nr_free` 命名以兼容测试保存/恢复；明确 Tie-break（同大小取低地址）、精确匹配提前结束、失败不改状态；补充测试需覆盖最小块选择、并列选择、精确匹配、拆分、双向桥接合并、碎片失败，并在结束时恢复空闲状态。

### 5.3 任务三 Buddy：两份 prompt

任务三明确要求**两份提示词**，我们按"实现"与"测试"分开：

**提示词一（生成分配模块并接入）**：阅读 `pmm_manager`、`Page`、地址转换宏、`page_init`、`default_pmm.c`、`list.h`；不要复用已有 Buddy 实现，从零写 `buddy_system_pmm.c/.h`；按 order 分类空闲链表（`MAX_ORDER=20`）；`init_memmap` 支持任意起点/页数并分解成对齐的 2 的幂块、不扩范围；`alloc` 向上取整、逐级拆分；`free(base, n)` 传入原申请量，按头页保存的实际页数整块归还；伙伴用 `page2ppn(base) ^ (1<<order)`；实现全部回调并注册 `buddy_pmm_manager`、在 `pmm.c` 选择它；`check` 里做内部不变量校验。

**提示词二（针对生成实现写测试）**：先读实际生成的实现与契约；测试必须在 RISC-V 内核中编译运行，**不得修改算法或删断言来伪造通过**；先从真实分配器申请 128 页对齐场地并保存原状态，测试结束恢复并验证空闲页数完全恢复；至少覆盖：非二次幂/未对齐的 61 页注册、1/2/3/5/8/9/16 页申请与向上取整、0/极大/超容量/碎片失败、61 页耗尽与乱序归还、64 页拆分后先还偶数页再还奇数页、两个 16 页区间中间留空洞、各阶段内部不变量。

**spec 要点**：`Pre` 允许任意起点/长度与多次注册、允许空洞；`Post` 空闲链表的 order 结构、对齐、计数、标志位一致；`Case` 覆盖"取整后超出容量"、"伙伴不在范围/保留/未注册"、"重复释放/内部页释放"的拒绝；`Requirements` 明确单 CPU、无锁、不支持部分释放。

### 5.4 Challenge SLUB：两份 prompt

**提示词一（生成对象分配层）**：读当前 ucore `pmm.h`、`Page`、地址转换与已实现的 Best-Fit；**在没有 SLUB 框架的情况下从零写** `slub.c/.h`；第一层继续用 `pmm_manager` 页分配（用 Best-Fit 保证"申请 n 页按 n 页归还"）；第二层暴露 `slub_init/kmalloc/kfree/slub_check`；8 个大小类别；每页一个 slab，页首元数据 + 向上 16 字节对齐的对象区；维护 partial 链表与 full/partial 转换；最后一个对象释放归还整页；>2048 字节走连续页并保存请求量与页数；`kmalloc(0)=NULL`、`kfree(NULL)` 无操作；溢出检查；不承诺野指针安全。

**提示词二（生成测试）**：覆盖 0/NULL/极大溢出请求；各大小类别边界（15/16/17、31/32/33、…、2047/2048/2049、4095/4096/4097、8192、17000）；同时申请后检查 16 字节对齐与区间不重叠；对每个对象**写满并逐字节核对**；300 个 16 字节对象跨 slab 扩容；释放偶数对象后重新分配并验证奇数对象未受破坏；partial↔full 转换、空 slab 还页；耗尽页构造 OOM 并恢复；测试前后比对空闲页数。

**spec 要点**：`Pre` 单 CPU、`slub_init` 在 `pmm_init` 之后调用一次；`Post` 对象不重叠、对齐、可写满、释放可回收、空 slab 还页；`Case` 覆盖 size=0、>`2048`、溢出、OOM、跨 slab、最后对象释放；`Requirements` 元数据不得与对象区重叠、用位图与边界检查降低误释放风险、明确不保证野指针恢复。

---

## 六、AI 生成代码过程中出现的 bug 及解决方法

| #   | 现象                                                                  | 定位过程                                                                                   | 原因                                                        | 修复                                                                                                                                        |
| --- | ------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | --------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | 任务一实现包在生成环境里"QEMU 启动后看不到内核输出"（资料包自己也标注"不计为通过"）                      | 对比 Makefile 与 OpenSBI 版本：生成环境是 QEMU 8.2/OpenSBI 1.3，课程环境是 QEMU 4.1.1/OpenSBI 0.4       | 启动方式与固件版本不匹配（新版 `fw_dynamic` 需要正确的下一阶段地址）                 | 回到课程环境（QEMU 4.1.1 + `-device loader`），重新跑通 `check_alloc_page()`，并在 `make grade` 中拿到 `[Test 1] Page Init: PASS`                            |
| 2   | 合并后编译报 `implicit declaration of function 'page2kva'`，`-Werror` 直接失败 | 报错指向 `buddy_system_pmm.c:205`；对比实验包与骨架的 `pmm.h`                                        | 骨架 `pmm.h` 里 `KADDR` 被注释掉，也没有 `page2kva` 内联函数；Buddy 实现需要它 | 在 `pmm.h` 中启用 `KADDR`，并补 `static inline void *page2kva(struct Page *p){ return KADDR(page2pa(p)); }`                                      |
| 3   | 三个模块各自带一份 `pmm.c` 和"管理器选择"行，直接互相覆盖会来回打架                             | 对比三份 `pmm.c` 与骨架的差异                                                                    | 三个包是**互相独立的实验版本**，不能简单叠加                                  | 统一到一个工程：`pmm.c` 只保留一份 `page_init`，用 `#if defined(PM_BUDDY)` 选择管理器；Makefile 用 `PM=best/buddy/slub` 传 `-DPM_*`，`qemu-*` 目标先 `make clean` 再编 |
| 4   | Best-Fit 的第一版设计成"只能按分配头精确释放"，与框架原测试"分段分配后整段回收"冲突                    | 原测试 `basic_check()` 里 `free_pages(p0+1,2)`、`free_pages(p0+4,1)` 后还能 `free_pages(p0,5)` | 早期把"分配粒度"和"释放粒度"绑定死了                                      | 保持 First-Fit 的释放约定：释放只要求地址连续、页数合法，允许把多次分配的相邻页一次回收；Best-Fit 本身不新增释放约束                                                                      |
| 5   | Buddy 的伙伴计算用"区间相对下标/虚拟地址"异或，出现"该合并的没合并、不该合并的合并了"                    | 用 64 页拆分的用例：先还偶数页后申请 2 页应失败，再还奇数页后应能申请完整 64 页                                          | 伙伴必须按**绝对物理页号**计算，且只有同阶/在范围/已注册/空闲才可合并                    | 改为 `buddy_ppn = page2ppn(base) ^ (1 << order)`，并在合并前校验四项条件                                                                                |
| 6   | 申请非 2 的幂页数（如 3 页）时，若按"原请求"记账，释放会漏还多给的页                              | 用 3/5/9 页申请 + 写入 + 释放 ± 计数断言                                                           | Buddy 实际分配 4 页，但调用者只知道 3 页                                | 头页保存"实际页数 + 原请求页数"，`free_pages(base, 3)` 时归还实际 4 页；同时明确不支持部分释放                                                                            |
| 7   | SLUB 的页首元数据与对象区重叠，写满对象时踩坏 slab 头                                    | 逐字节写满测试 + 相邻对象内容校验发现首对象数据被改写                                                           | 头部按 `sizeof` 估算，未按 16 字节向上对齐，对象区起点落在头部结束之前                | 头部向上对齐（本实现 96 字节）后再切对象槽；对象区起点再按 16 字节对齐；加位图与边界检查                                                                                          |
| 8   | `make qemu` 跑起来后终端"变哑巴"、`Ctrl+C` 无效                                 | `ps` 看到 `qemu-system-riscv64 -nographic` 仍占着 `pts`；QEMU 的退出键是 `Ctrl+A` 转义              | `-nographic` 把终端变成串口控制台，`Ctrl+C` 被当作串口输入送给 `while(1)` 的内核 | 工程加 `run` 目标用 `timeout 20` 自动退出，并保留 `qemu-*` 一键目标；文档写明 `Ctrl+A` 松开再按 `x`                                                                  |

这些问题有一个共同点：**AI 生成的代码在"正常路径"上通常是对的，出错集中在边界与契约**（对齐、溢出、失败路径、释放语义、跨模块命名）。因此我们的验收方式是"编译 + 断言自检 + 真实 QEMU 运行"，而不是只读代码。

---

## 七、测试与验证

工程提供四个入口（`make qemu-best` 等会先 `make clean` 再按 `PM=` 重编，QEMU 20 秒后自动退出）：

### 7.1 任务一 + 任务二（Best-Fit）

```bash
make qemu-best
```

实际输出（节选）：

```
memory management: best_fit_pmm_manager
physical memory map:
  memory: 0x0000000008000000, [0x0000000080000000, 0x0000000087ffffff].
grading: 1 / 6 points
...
grading: 6 / 6 points
Best-Fit: minimum choice, tie, split, bridge merge, failure PASS
Best-Fit: original and additional checks passed
check_alloc_page() succeeded!
satp virtual address: 0xffffffffc0205000
satp physical address: 0x0000000080205000
```

结论：`page_init` 正确探测并注册了 128 MiB DRAM；原评分测试 6/6 通过；补充测试覆盖最小块、并列、精确匹配、拆分、桥接合并、失败路径；空闲页总数在测试后恢复。

### 7.2 任务三（Buddy System）

```bash
make qemu-buddy
```

```
memory management: buddy_pmm_manager
Buddy: unaligned 61-page range, rounding, exhaustion PASS
Buddy: recursive split, fragmentation, recursive merge PASS
Buddy: disjoint ranges and reserved gap PASS
Buddy: all checks passed; free-page count restored
check_alloc_page() succeeded!
```

### 7.3 Challenge（SLUB）

```bash
make qemu-slub
```

```
memory management: best_fit_pmm_manager
grading: 6 / 6 points
...
SLUB: size boundaries, alignment, full writes, non-overlap PASS
SLUB: multi-slab growth, full/partial transition, reuse/reclaim PASS
SLUB: zero/overflow/OOM, all checks passed; page count restored
check_alloc_page() succeeded!
```

### 7.4 官方评分

```bash
make grade
```

`make grade` 会把工程拷到 `/tmp/lab2_grade`、用 `tools/inject.py` 注入官方 `test_lab2.c`（在 `pmm_init()` 末尾调用 `test_page_init()`、`test_best_fit()`），再运行 `tools/grade.sh` 抓取测试输出。**它不会改动源码**。实际输出：

```
lab2 injection complete
...
  -check page init:                          OK
  -check best fit:                           OK
Total Score: 20/20
```

注入后的内核直接输出：

```
memory management: best_fit_pmm_manager
check_alloc_page() succeeded!
[Test 1] Page Init: PASS
[Test 2] Best-Fit: PASS
```

### 7.5 验证方式说明

- **断言驱动**：每个管理器的 `check` 都用 `assert` 检查不变量（块头标志、`property`、`nr_free` 之和、链表双向链接、对齐等），一旦不满足内核直接 `panic`，比"看起来能跑"可靠。
- **全局不变量**：所有自检在结束时都要求"空闲页总数恢复到测试前"，防止"测试通过但分配器被破坏"。
- **真实环境**：全部在 QEMU + OpenSBI 上运行，不是宿主模拟。
- 说明：资料包附带的 `tools/grade.sh` 里把 `satp` 地址写死为某个具体值，换环境会误判；我们以课程自带的 `make grade`（`[Test 1]/[Test 2]` 检查）为准。

---

## 八、练习问题回答

### 8.1 任务一 Challenge：如果 OS 无法提前知道可用物理内存范围，怎么获取？

思路是把"发现内存"从"依赖固件告诉我们"变成"主动探测/查询"：

1. **固件/引导协议传递**：RISC-V 的 DTB（本实验）、x86 的 E820/UEFI Memory Map、ACPI 的 SRAT/NFIT —— 这是最标准的做法，代价是需要固件配合。
2. **查询固件服务**：通过 SBI/ACPI 等接口向固件询问内存拓扑（Linux 在启动早期就同时使用 E820 与 UEFI memmap）。
3. **主动探测（probing）**：从已知 DRAM 基址开始逐页/逐块读写并捕获异常，探测可用上界；对 MMIO 区域必须跳过（乱写可能触发设备副作用），因此通常先要有一份"哪些地址是 RAM 的"最小信息。
4. **总线枚举/设备树热插拔**：PCIe/内存热插拔控制器会提供可用内存窗口；NUMA 系统通过 SRAT 描述节点与内存范围。
5. **保守回退**：以链接地址和已知 DRAM 基址（QEMU virt 的 `0x80000000`）为起点，用"写入-回读"确定一段安全窗口，先管理这一段，等更完整的信息可用后再扩展。

工程上通常组合使用：**固件描述（首选）→ 固件服务查询 → 探测（兜底）**，并在每步做范围校验（对齐、溢出、与内核/固件保留区不重叠），这与我们 `page_init` 里"用物理上界截断 + 对齐 + 排除保留区"的做法一致。

### 8.2 功能模块二 · 任务一：原有 First-Fit 是否有进一步改进空间？

有，且要区分"搜索效率"与"碎片"两类改进：

1. **搜索效率**：当前每次从头线性扫描，最坏 O(F)（F 为空闲块数）。可以维护按大小分级的链表（segregated free list）、按大小排序的平衡树（子树记录最大块，可跳过不可能满足的区间），或位图/多级索引；代价是拆分与合并时要同步维护两套结构。
2. **扫描策略**：Next-Fit 记录上次位置，减少反复扫描前端小块；但它改变选择策略，不能保证减少碎片。
3. **元数据鲁棒性**：现有 `!PageProperty(p)` 断言不能识别所有非法释放（空闲块内部页也没有 `PG_property`）。可以额外记录分配状态/边界，检测重复释放与越界释放。
4. **对象级需求**：小于一页的对象不应独占一页，应在页分配器之上加 SLUB 一类对象缓存（本实验 Challenge 已实现）。
5. **碎片度量**：First-Fit 不会留下"小于一页"的空闲块，但会有外部碎片（空闲块被已分配页隔开）；合并只能消除相邻空闲块边界，不能跨过正在使用的页。是否换算法要看真实申请分布，不能简单认为 Best-Fit 一定更好。

### 8.3 功能模块二 · 任务二：你的 Best-Fit 是否有进一步改进空间？

有：

1. **查找加速**：当前 O(F) 线性扫描。可以按块大小建平衡树（`lower_bound` 找最小可用块）或分级大小桶，同时保留按地址的索引用于合并，两个索引在拆分/合并时同步更新。最坏从 O(F) 降到 O(log F)。
2. **碎片策略**：Best-Fit 让本次剩余最小，但可能持续制造很小的余块。可以对真实申请分布做实验，比较 First-Fit / Best-Fit / Next-Fit 的搜索长度、最大空闲块、失败次数；也可以设"余块小于阈值时整块给出"的策略，但**必须同时修改接口或记录实际分配页数**，否则调用者按原 n 页释放会泄漏多给的页——本实现保持"精确分配 n 页"的契约，没有采用。
3. **分级配合**：把页分配器的压力转移到对象缓存（SLUB），让页级请求更接近 2 的幂，从而减少余块。
4. **并发**：单 CPU 无锁；多核需要加锁或 per-CPU 缓存。

### 8.4 任务三：测试覆盖了哪些核心行为与边界，为什么能有效检验？

| 测试                           | 关键断言                  | 能发现的问题              |
| ---------------------------- | --------------------- | ------------------- |
| 偏移 1 页、长度 61 页的初始化           | 总量为 61，返回页都在区间内       | 向上扩展初始范围、尾页遗漏、错误对齐  |
| 1/2/3/5/8/9/16 页申请           | 实际扣减为 2 的幂、物理页号按块长对齐  | 取整错误、按虚拟地址算伙伴、计数错误  |
| 写满申请范围                       | 首尾字节正确、页都在申请范围内       | 分配范围不可用或不足          |
| 61 页逐页耗尽 + 固定乱序归还            | 地址互不重复、计数恢复           | 重复分配、节点丢失、释放计数错误    |
| 64 页拆分，先还偶数页                 | 32 页空闲但申请 2 页失败       | 把非连续单页拼成连续块         |
| 再还奇数页并申请 64 页                | 成功返回整块                | 只合并一层、伙伴计算错误、链表删除错误 |
| 两个 16 页区间中间留空洞               | 总量 32 但申请 32 失败，空洞仍保留 | 跨空洞合并、管理了保留内存       |
| 0/极大/超容量/碎片失败                | 返回 NULL，空闲状态不变        | 溢出、无限移位、失败路径破坏状态    |
| `buddy_validate()` 与测试前后计数恢复 | 对齐、边界、链表、标志、总量一致      | 表面分配成功但元数据/真实管理器已损坏 |

有效性来自三点：①**能区分"正确实现"与"看似正确"**（如"先还偶数页后申请 2 页应失败"能抓住把非连续单页拼块的错误）；②**用固定地址断言**而非只判非空；③**测试隔离**——在真实分配器上申请独立场地，跑完恢复原状态并核对空闲页数，因此既精确又不污染内核。

### 8.5 Challenge SLUB：测试覆盖与有效性

| 测试                     | 检查内容                | 为什么有效                           |
| ---------------------- | ------------------- | ------------------------------- |
| 30 种大小（含类别/页边界）        | 类别选择、页数取整           | 发现 off-by-one                   |
| 同时持有不同大小对象             | 区间不重叠、16 字节对齐       | 发现返回重复对象、头部重叠、对齐错误              |
| 每个对象写满并逐字节核对           | 请求范围内容保持            | 发现对象之间、对象与元数据之间的交叉破坏            |
| 300 个 16 字节对象          | 至少用两页               | 真正走到 slab 变满与扩容                 |
| 释放偶数对象后重新分配            | 旧对象数据保持、新对象可写       | 检查 freelist 复用与 full/partial 转换 |
| 逆序释放并全部释放              | 空闲页数恢复基线            | 空 slab 回收、大对象页数归还、泄漏            |
| 0 / NULL / 最大 `size_t` | 无操作或失败、页数不变         | 边界语义与整数溢出                       |
| 耗尽底层页后申请               | 小/大对象都返回 NULL，归还后恢复 | `new_slab` 与连续大对象分配的失败处理        |

与完整 Linux SLUB 的差距：没有 per-CPU 缓存、并发同步、NUMA、安全加固与调试选项；对象大小向上归类与页首元数据仍带来内部碎片。

### 8.6 补充问答：为什么 `page_init` 不能用虚拟地址上界直接比较？

`KERNTOP`、`pages` 都是虚拟地址，而 DTB 给出的内存范围是物理地址；在 `va_pa_offset` 建立之前/之后混用会导致上界算错（内核虚拟地址远高于物理地址，比较结果永远"内存足够"）。正确做法是把链接符号 `end` 用 `PADDR` 转成物理地址，和 DTB 的物理末端、`PHYSICAL_MEMORY_END` 在同一维度比较。

---

## 九、本实验知识点与 OS 原理知识点的对应

| 本实验知识点                                     | 对应 OS 原理知识点                   | 含义、关系与差异                                                                                     |
| ------------------------------------------ | ----------------------------- | -------------------------------------------------------------------------------------------- |
| DTB（设备树）描述物理内存范围                           | 硬件发现与固件接口（BIOS/UEFI、设备树、ACPI） | 原理讲"OS 如何知道硬件配置"；实验用 OpenSBI 通过 `a1` 传 DTB，`dtb_init` 解析出 Base/Size。差异：真实机器信息源更多、更复杂，且要处理热插拔 |
| `struct Page` 描述符数组                        | 物理页框管理（页帧数据库）                 | 原理中"每页一个描述符"是抽象；实验把它具体化为"紧跟内核镜像的连续数组 + 索引约定 `pages[0] ↔ nbase`"                              |
| `pmm_manager` 函数指针表                        | 内核抽象与策略/机制分离                  | 原理强调"机制与策略分离"；实验用同一套 `page_init` 驱动四种分配器，正是把"策略"外置                                           |
| First-Fit / Best-Fit                       | 动态分区分配算法（首次适配/最佳适配）           | 原理给出算法定义与外部碎片分析；实验在页级、按地址有序链表上实现，并用断言验证"合并"与"失败不改状态"                                         |
| Buddy System                               | 伙伴分配、内部碎片与合并                  | 原理讲 2 的幂分块与伙伴异或；实验用 `page2ppn ^ (1<<order)` 并验证"跨空洞不合并""取整带来内部碎片"                            |
| SLUB                                       | slab 分配器、对象缓存、slab 生命周期       | 原理讲"页分配之上按对象大小缓存"；实验实现 8 个类别、partial/full、空页回收，并明确与 Linux 的差距                                |
| `PG_reserved` / `PG_property` / `property` | 资源状态元数据与不变量                   | 原理很少展开"元数据怎么编码"；实验用位标志 + 头页块长，并用自检校验"只有头页置位、`nr_free` 等于各块之和"                                |
| `PADDR/KADDR`、`va_pa_offset`               | 内核地址空间与直接映射                   | 原理讲虚拟地址到物理地址的转换；实验的内核是"高虚拟地址 + 固定偏移"的直接映射，`PADDR/KADDR` 就是这一映射的薄封装                           |
| `ref` 引用计数                                 | 资源生命周期与引用计数                   | 原理中引用计数用于对象/页的共享与释放；实验用它区分"已分配页"与空闲页，并在 `free` 时清零                                           |
| 页对齐、向上/向下取整                                | 内存对齐与边界处理                     | 原理强调对齐的硬件原因；实验中所有边界（描述符起点、空闲区起点、内存末端）都必须按 `PGSIZE` 处理，错一处就 panic 或泄漏                         |

---

## 十、OS 原理中很重要、但本实验没有对应上的知识点

1. **虚拟内存与页表映射**：本实验重点在物理内存；`entry.S` 只是建立了启动用的 Sv39 页表并开启分页，没有实现页表建立/修改、缺页处理、地址空间隔离（属于后续实验）。
2. **进程与线程管理**：没有 PCB、没有进程创建/切换/调度，内核初始化完就 `while(1)`。
3. **中断与异常处理**：没有实现 trap 入口、时钟中断、中断嵌套；本实验的 `ecall` 只用于调用固件服务。
4. **并发与同步**：单 CPU、无锁，分配器没有考虑多核竞争、死锁、RCU 等。
5. **文件系统与持久化存储**：没有块设备驱动、inode、目录、文件读写。
6. **页面回收与换页**：没有 LRU、工作集、swap、页回收线程；SLUB 只回收空 slab。
7. **内存分配的安全与隔离**：没有 SMAP/SMEP、用户指针校验、越界检测；SLUB 明确不保证野指针安全。
8. **NUMA、内存热插拔、per-CPU 缓存**：SLUB 与页分配器都是单 CPU 简化版。
9. **内存压缩/碎片整理、大页**：未涉及。

---

## 十一、总结与 AI 协作经验

1. **spec 写得越像"契约"，AI 产出越稳**。例如页分配器只要把"失败不改变状态""同大小取低地址""只有块头置 `PG_property`""释放兼容分段回收"这几条写进 `[SPECIFICATION]`，生成的代码就基本可测；反过来，只写"实现 Best-Fit"，AI 很容易在 tie-break、余块、失败路径上给出似是而非的版本。
2. **实现与测试必须分两份提示词**。任务三与 SLUB 都要求两份 prompt，这不仅是格式要求，更是防止"实现者给自己出题"的有效手段：测试提示词的约束是"不得改算法、不得删断言、必须先申请独立场地再隔离、结束后恢复并核对空闲页数"。
3. **AI 的错误集中在边界与契约**，而不是正常路径：对齐、溢出、向上取整的记账、释放语义、跨模块命名（`page2kva`）是本次踩坑最多的四类。解决办法是"编译 + 断言自检 + 真实 QEMU 运行"三层闭环，并用 `assert` 把不变量写死在 `check` 里。
4. **全局不变量最有价值**：所有自检结束时都要求"空闲页数恢复到测试前"。这条断言抓出了多次"表面通过但状态被破坏"的问题（如合并只改计数、释放漏还整块）。
5. **工程化同样重要**：三个实验包各带一份 `pmm.c`，直接叠加会互相覆盖。我们最终用"一个工程 + 编译期 `PM=best/buddy/slub` 切换 + `make qemu-*` 一键目标 + QEMU 超时自动退出"把这些版本统一起来，避免了"换一个算法就把另一个版本改坏"的问题。

---

## 附录 A 工程结构与改动

```
lab2_submit/                    （即提交目录 labcodes/lab2）
├── Makefile                    新增 PM=best|buddy|slub 变体选择；新增 run/qemu-best/qemu-buddy/qemu-slub 目标
├── README_如何运行.md
├── .vscode/tasks.json          一键任务（Ctrl+Shift+B）
├── kern/
│   ├── init/init.c             新增 #ifdef PM_SLUB 的 slub_init()/slub_check() 调用
│   └── mm/
│       ├── pmm.c               ★ 任务一：page_init()；管理器选择改为编译期分支
│       ├── pmm.h               ★ 启用 KADDR、补充 page2kva()
│       ├── default_pmm.c       课程 First-Fit（未改动，用于对照/思考题）
│       ├── best_fit_pmm.c/.h   ★ 任务二：Best-Fit 实现
│       ├── buddy_system_pmm.c/.h  ★ 任务三：Buddy System
│       ├── slub.c/.h           ★ Challenge：SLUB 对象分配
│       └── memlayout.h / mmu.h
├── libs/                       字符串、printf、SBI 封装等
└── tools/                      kernel.ld、function.mk、grade.sh、inject.py、test_lab2.c 等
```


