
bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

ffffffffc0200000 <kern_entry>:
    .globl kern_entry
kern_entry:
    # a0: hartid
    # a1: dtb physical address
    # save hartid and dtb address
    la t0, boot_hartid
ffffffffc0200000:	00007297          	auipc	t0,0x7
ffffffffc0200004:	00028293          	mv	t0,t0
    sd a0, 0(t0)
ffffffffc0200008:	00a2b023          	sd	a0,0(t0) # ffffffffc0207000 <boot_hartid>
    la t0, boot_dtb
ffffffffc020000c:	00007297          	auipc	t0,0x7
ffffffffc0200010:	ffc28293          	addi	t0,t0,-4 # ffffffffc0207008 <boot_dtb>
    sd a1, 0(t0)
ffffffffc0200014:	00b2b023          	sd	a1,0(t0)

    # t0 := 三级页表的虚拟地址
    lui     t0, %hi(boot_page_table_sv39)
ffffffffc0200018:	c02062b7          	lui	t0,0xc0206
    # t1 := 0xffffffff40000000 即虚实映射偏移量
    li      t1, 0xffffffffc0000000 - 0x80000000
ffffffffc020001c:	ffd0031b          	addiw	t1,zero,-3
ffffffffc0200020:	037a                	slli	t1,t1,0x1e
    # t0 减去虚实映射偏移量 0xffffffff40000000，变为三级页表的物理地址
    sub     t0, t0, t1
ffffffffc0200022:	406282b3          	sub	t0,t0,t1
    # t0 >>= 12，变为三级页表的物理页号
    srli    t0, t0, 12
ffffffffc0200026:	00c2d293          	srli	t0,t0,0xc

    # t1 := 8 << 60，设置 satp 的 MODE 字段为 Sv39
    li      t1, 8 << 60
ffffffffc020002a:	fff0031b          	addiw	t1,zero,-1
ffffffffc020002e:	137e                	slli	t1,t1,0x3f
    # 将刚才计算出的预设三级页表物理页号附加到 satp 中
    or      t0, t0, t1
ffffffffc0200030:	0062e2b3          	or	t0,t0,t1
    # 将算出的 t0(即新的MODE|页表基址物理页号) 覆盖到 satp 中
    csrw    satp, t0
ffffffffc0200034:	18029073          	csrw	satp,t0
    # 使用 sfence.vma 指令刷新 TLB
    sfence.vma
ffffffffc0200038:	12000073          	sfence.vma
    # 从此，我们给内核搭建出了一个完美的虚拟内存空间！
    #nop # 可能映射的位置有些bug。。插入一个nop
    
    # 我们在虚拟内存空间中：随意将 sp 设置为虚拟地址！
    lui sp, %hi(bootstacktop)
ffffffffc020003c:	c0206137          	lui	sp,0xc0206

    # 我们在虚拟内存空间中：随意跳转到虚拟地址！
    # 跳转到 kern_init
    lui t0, %hi(kern_init)
ffffffffc0200040:	c02002b7          	lui	t0,0xc0200
    addi t0, t0, %lo(kern_init)
ffffffffc0200044:	0d828293          	addi	t0,t0,216 # ffffffffc02000d8 <kern_init>
    jr t0
ffffffffc0200048:	8282                	jr	t0

ffffffffc020004a <print_kerninfo>:
/* *
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void print_kerninfo(void) {
ffffffffc020004a:	1141                	addi	sp,sp,-16
    extern char etext[], edata[], end[];
    cprintf("Special kernel symbols:\n");
ffffffffc020004c:	00002517          	auipc	a0,0x2
ffffffffc0200050:	6fc50513          	addi	a0,a0,1788 # ffffffffc0202748 <etext>
void print_kerninfo(void) {
ffffffffc0200054:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc0200056:	0fe000ef          	jal	ra,ffffffffc0200154 <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", (uintptr_t)kern_init);
ffffffffc020005a:	00000597          	auipc	a1,0x0
ffffffffc020005e:	07e58593          	addi	a1,a1,126 # ffffffffc02000d8 <kern_init>
ffffffffc0200062:	00002517          	auipc	a0,0x2
ffffffffc0200066:	70650513          	addi	a0,a0,1798 # ffffffffc0202768 <etext+0x20>
ffffffffc020006a:	0ea000ef          	jal	ra,ffffffffc0200154 <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc020006e:	00002597          	auipc	a1,0x2
ffffffffc0200072:	6da58593          	addi	a1,a1,1754 # ffffffffc0202748 <etext>
ffffffffc0200076:	00002517          	auipc	a0,0x2
ffffffffc020007a:	71250513          	addi	a0,a0,1810 # ffffffffc0202788 <etext+0x40>
ffffffffc020007e:	0d6000ef          	jal	ra,ffffffffc0200154 <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200082:	00007597          	auipc	a1,0x7
ffffffffc0200086:	f9658593          	addi	a1,a1,-106 # ffffffffc0207018 <free_area>
ffffffffc020008a:	00002517          	auipc	a0,0x2
ffffffffc020008e:	71e50513          	addi	a0,a0,1822 # ffffffffc02027a8 <etext+0x60>
ffffffffc0200092:	0c2000ef          	jal	ra,ffffffffc0200154 <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc0200096:	00008597          	auipc	a1,0x8
ffffffffc020009a:	9c258593          	addi	a1,a1,-1598 # ffffffffc0207a58 <end>
ffffffffc020009e:	00002517          	auipc	a0,0x2
ffffffffc02000a2:	72a50513          	addi	a0,a0,1834 # ffffffffc02027c8 <etext+0x80>
ffffffffc02000a6:	0ae000ef          	jal	ra,ffffffffc0200154 <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - (char*)kern_init + 1023) / 1024);
ffffffffc02000aa:	00008597          	auipc	a1,0x8
ffffffffc02000ae:	dad58593          	addi	a1,a1,-595 # ffffffffc0207e57 <end+0x3ff>
ffffffffc02000b2:	00000797          	auipc	a5,0x0
ffffffffc02000b6:	02678793          	addi	a5,a5,38 # ffffffffc02000d8 <kern_init>
ffffffffc02000ba:	40f587b3          	sub	a5,a1,a5
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000be:	43f7d593          	srai	a1,a5,0x3f
}
ffffffffc02000c2:	60a2                	ld	ra,8(sp)
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000c4:	3ff5f593          	andi	a1,a1,1023
ffffffffc02000c8:	95be                	add	a1,a1,a5
ffffffffc02000ca:	85a9                	srai	a1,a1,0xa
ffffffffc02000cc:	00002517          	auipc	a0,0x2
ffffffffc02000d0:	71c50513          	addi	a0,a0,1820 # ffffffffc02027e8 <etext+0xa0>
}
ffffffffc02000d4:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000d6:	a8bd                	j	ffffffffc0200154 <cprintf>

ffffffffc02000d8 <kern_init>:

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
ffffffffc02000d8:	00007517          	auipc	a0,0x7
ffffffffc02000dc:	f4050513          	addi	a0,a0,-192 # ffffffffc0207018 <free_area>
ffffffffc02000e0:	00008617          	auipc	a2,0x8
ffffffffc02000e4:	97860613          	addi	a2,a2,-1672 # ffffffffc0207a58 <end>
int kern_init(void) {
ffffffffc02000e8:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
ffffffffc02000ea:	8e09                	sub	a2,a2,a0
ffffffffc02000ec:	4581                	li	a1,0
int kern_init(void) {
ffffffffc02000ee:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
ffffffffc02000f0:	646020ef          	jal	ra,ffffffffc0202736 <memset>
    dtb_init();
ffffffffc02000f4:	134000ef          	jal	ra,ffffffffc0200228 <dtb_init>
    cons_init();  // init the console
ffffffffc02000f8:	126000ef          	jal	ra,ffffffffc020021e <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc02000fc:	00002517          	auipc	a0,0x2
ffffffffc0200100:	71c50513          	addi	a0,a0,1820 # ffffffffc0202818 <etext+0xd0>
ffffffffc0200104:	086000ef          	jal	ra,ffffffffc020018a <cputs>

    print_kerninfo();
ffffffffc0200108:	f43ff0ef          	jal	ra,ffffffffc020004a <print_kerninfo>

    // grade_backtrace();
    pmm_init();  // init physical memory management
ffffffffc020010c:	4ca010ef          	jal	ra,ffffffffc02015d6 <pmm_init>
    slub_init();
ffffffffc0200110:	1bd010ef          	jal	ra,ffffffffc0201acc <slub_init>
    slub_check();
ffffffffc0200114:	4c7010ef          	jal	ra,ffffffffc0201dda <slub_check>
    /* do nothing */
    while (1)
ffffffffc0200118:	a001                	j	ffffffffc0200118 <kern_init+0x40>

ffffffffc020011a <cputch>:
/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void
cputch(int c, int *cnt) {
ffffffffc020011a:	1141                	addi	sp,sp,-16
ffffffffc020011c:	e022                	sd	s0,0(sp)
ffffffffc020011e:	e406                	sd	ra,8(sp)
ffffffffc0200120:	842e                	mv	s0,a1
    cons_putc(c);
ffffffffc0200122:	0fe000ef          	jal	ra,ffffffffc0200220 <cons_putc>
    (*cnt) ++;
ffffffffc0200126:	401c                	lw	a5,0(s0)
}
ffffffffc0200128:	60a2                	ld	ra,8(sp)
    (*cnt) ++;
ffffffffc020012a:	2785                	addiw	a5,a5,1
ffffffffc020012c:	c01c                	sw	a5,0(s0)
}
ffffffffc020012e:	6402                	ld	s0,0(sp)
ffffffffc0200130:	0141                	addi	sp,sp,16
ffffffffc0200132:	8082                	ret

ffffffffc0200134 <vcprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want cprintf() instead.
 * */
int
vcprintf(const char *fmt, va_list ap) {
ffffffffc0200134:	1101                	addi	sp,sp,-32
ffffffffc0200136:	862a                	mv	a2,a0
ffffffffc0200138:	86ae                	mv	a3,a1
    int cnt = 0;
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc020013a:	00000517          	auipc	a0,0x0
ffffffffc020013e:	fe050513          	addi	a0,a0,-32 # ffffffffc020011a <cputch>
ffffffffc0200142:	006c                	addi	a1,sp,12
vcprintf(const char *fmt, va_list ap) {
ffffffffc0200144:	ec06                	sd	ra,24(sp)
    int cnt = 0;
ffffffffc0200146:	c602                	sw	zero,12(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200148:	1d8020ef          	jal	ra,ffffffffc0202320 <vprintfmt>
    return cnt;
}
ffffffffc020014c:	60e2                	ld	ra,24(sp)
ffffffffc020014e:	4532                	lw	a0,12(sp)
ffffffffc0200150:	6105                	addi	sp,sp,32
ffffffffc0200152:	8082                	ret

ffffffffc0200154 <cprintf>:
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int
cprintf(const char *fmt, ...) {
ffffffffc0200154:	711d                	addi	sp,sp,-96
    va_list ap;
    int cnt;
    va_start(ap, fmt);
ffffffffc0200156:	02810313          	addi	t1,sp,40 # ffffffffc0206028 <boot_page_table_sv39+0x28>
cprintf(const char *fmt, ...) {
ffffffffc020015a:	8e2a                	mv	t3,a0
ffffffffc020015c:	f42e                	sd	a1,40(sp)
ffffffffc020015e:	f832                	sd	a2,48(sp)
ffffffffc0200160:	fc36                	sd	a3,56(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200162:	00000517          	auipc	a0,0x0
ffffffffc0200166:	fb850513          	addi	a0,a0,-72 # ffffffffc020011a <cputch>
ffffffffc020016a:	004c                	addi	a1,sp,4
ffffffffc020016c:	869a                	mv	a3,t1
ffffffffc020016e:	8672                	mv	a2,t3
cprintf(const char *fmt, ...) {
ffffffffc0200170:	ec06                	sd	ra,24(sp)
ffffffffc0200172:	e0ba                	sd	a4,64(sp)
ffffffffc0200174:	e4be                	sd	a5,72(sp)
ffffffffc0200176:	e8c2                	sd	a6,80(sp)
ffffffffc0200178:	ecc6                	sd	a7,88(sp)
    va_start(ap, fmt);
ffffffffc020017a:	e41a                	sd	t1,8(sp)
    int cnt = 0;
ffffffffc020017c:	c202                	sw	zero,4(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc020017e:	1a2020ef          	jal	ra,ffffffffc0202320 <vprintfmt>
    cnt = vcprintf(fmt, ap);
    va_end(ap);
    return cnt;
}
ffffffffc0200182:	60e2                	ld	ra,24(sp)
ffffffffc0200184:	4512                	lw	a0,4(sp)
ffffffffc0200186:	6125                	addi	sp,sp,96
ffffffffc0200188:	8082                	ret

ffffffffc020018a <cputs>:
/* *
 * cputs- writes the string pointed by @str to stdout and
 * appends a newline character.
 * */
int
cputs(const char *str) {
ffffffffc020018a:	1101                	addi	sp,sp,-32
ffffffffc020018c:	e822                	sd	s0,16(sp)
ffffffffc020018e:	ec06                	sd	ra,24(sp)
ffffffffc0200190:	e426                	sd	s1,8(sp)
ffffffffc0200192:	842a                	mv	s0,a0
    int cnt = 0;
    char c;
    while ((c = *str ++) != '\0') {
ffffffffc0200194:	00054503          	lbu	a0,0(a0)
ffffffffc0200198:	c51d                	beqz	a0,ffffffffc02001c6 <cputs+0x3c>
ffffffffc020019a:	0405                	addi	s0,s0,1
ffffffffc020019c:	4485                	li	s1,1
ffffffffc020019e:	9c81                	subw	s1,s1,s0
    cons_putc(c);
ffffffffc02001a0:	080000ef          	jal	ra,ffffffffc0200220 <cons_putc>
    while ((c = *str ++) != '\0') {
ffffffffc02001a4:	00044503          	lbu	a0,0(s0)
ffffffffc02001a8:	008487bb          	addw	a5,s1,s0
ffffffffc02001ac:	0405                	addi	s0,s0,1
ffffffffc02001ae:	f96d                	bnez	a0,ffffffffc02001a0 <cputs+0x16>
    (*cnt) ++;
ffffffffc02001b0:	0017841b          	addiw	s0,a5,1
    cons_putc(c);
ffffffffc02001b4:	4529                	li	a0,10
ffffffffc02001b6:	06a000ef          	jal	ra,ffffffffc0200220 <cons_putc>
        cputch(c, &cnt);
    }
    cputch('\n', &cnt);
    return cnt;
}
ffffffffc02001ba:	60e2                	ld	ra,24(sp)
ffffffffc02001bc:	8522                	mv	a0,s0
ffffffffc02001be:	6442                	ld	s0,16(sp)
ffffffffc02001c0:	64a2                	ld	s1,8(sp)
ffffffffc02001c2:	6105                	addi	sp,sp,32
ffffffffc02001c4:	8082                	ret
    while ((c = *str ++) != '\0') {
ffffffffc02001c6:	4405                	li	s0,1
ffffffffc02001c8:	b7f5                	j	ffffffffc02001b4 <cputs+0x2a>

ffffffffc02001ca <__panic>:
 * __panic - __panic is called on unresolvable fatal errors. it prints
 * "panic: 'message'", and then enters the kernel monitor.
 * */
void
__panic(const char *file, int line, const char *fmt, ...) {
    if (is_panic) {
ffffffffc02001ca:	00008317          	auipc	t1,0x8
ffffffffc02001ce:	84630313          	addi	t1,t1,-1978 # ffffffffc0207a10 <is_panic>
ffffffffc02001d2:	00032e03          	lw	t3,0(t1)
__panic(const char *file, int line, const char *fmt, ...) {
ffffffffc02001d6:	715d                	addi	sp,sp,-80
ffffffffc02001d8:	ec06                	sd	ra,24(sp)
ffffffffc02001da:	e822                	sd	s0,16(sp)
ffffffffc02001dc:	f436                	sd	a3,40(sp)
ffffffffc02001de:	f83a                	sd	a4,48(sp)
ffffffffc02001e0:	fc3e                	sd	a5,56(sp)
ffffffffc02001e2:	e0c2                	sd	a6,64(sp)
ffffffffc02001e4:	e4c6                	sd	a7,72(sp)
    if (is_panic) {
ffffffffc02001e6:	000e0363          	beqz	t3,ffffffffc02001ec <__panic+0x22>
    vcprintf(fmt, ap);
    cprintf("\n");
    va_end(ap);

panic_dead:
    while (1) {
ffffffffc02001ea:	a001                	j	ffffffffc02001ea <__panic+0x20>
    is_panic = 1;
ffffffffc02001ec:	4785                	li	a5,1
ffffffffc02001ee:	00f32023          	sw	a5,0(t1)
    va_start(ap, fmt);
ffffffffc02001f2:	8432                	mv	s0,a2
ffffffffc02001f4:	103c                	addi	a5,sp,40
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02001f6:	862e                	mv	a2,a1
ffffffffc02001f8:	85aa                	mv	a1,a0
ffffffffc02001fa:	00002517          	auipc	a0,0x2
ffffffffc02001fe:	63e50513          	addi	a0,a0,1598 # ffffffffc0202838 <etext+0xf0>
    va_start(ap, fmt);
ffffffffc0200202:	e43e                	sd	a5,8(sp)
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc0200204:	f51ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
    vcprintf(fmt, ap);
ffffffffc0200208:	65a2                	ld	a1,8(sp)
ffffffffc020020a:	8522                	mv	a0,s0
ffffffffc020020c:	f29ff0ef          	jal	ra,ffffffffc0200134 <vcprintf>
    cprintf("\n");
ffffffffc0200210:	00002517          	auipc	a0,0x2
ffffffffc0200214:	60050513          	addi	a0,a0,1536 # ffffffffc0202810 <etext+0xc8>
ffffffffc0200218:	f3dff0ef          	jal	ra,ffffffffc0200154 <cprintf>
ffffffffc020021c:	b7f9                	j	ffffffffc02001ea <__panic+0x20>

ffffffffc020021e <cons_init>:

/* serial_intr - try to feed input characters from serial port */
void serial_intr(void) {}

/* cons_init - initializes the console devices */
void cons_init(void) {}
ffffffffc020021e:	8082                	ret

ffffffffc0200220 <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void cons_putc(int c) { sbi_console_putchar((unsigned char)c); }
ffffffffc0200220:	0ff57513          	zext.b	a0,a0
ffffffffc0200224:	47e0206f          	j	ffffffffc02026a2 <sbi_console_putchar>

ffffffffc0200228 <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc0200228:	7119                	addi	sp,sp,-128
    cprintf("DTB Init\n");
ffffffffc020022a:	00002517          	auipc	a0,0x2
ffffffffc020022e:	62e50513          	addi	a0,a0,1582 # ffffffffc0202858 <etext+0x110>
void dtb_init(void) {
ffffffffc0200232:	fc86                	sd	ra,120(sp)
ffffffffc0200234:	f8a2                	sd	s0,112(sp)
ffffffffc0200236:	e8d2                	sd	s4,80(sp)
ffffffffc0200238:	f4a6                	sd	s1,104(sp)
ffffffffc020023a:	f0ca                	sd	s2,96(sp)
ffffffffc020023c:	ecce                	sd	s3,88(sp)
ffffffffc020023e:	e4d6                	sd	s5,72(sp)
ffffffffc0200240:	e0da                	sd	s6,64(sp)
ffffffffc0200242:	fc5e                	sd	s7,56(sp)
ffffffffc0200244:	f862                	sd	s8,48(sp)
ffffffffc0200246:	f466                	sd	s9,40(sp)
ffffffffc0200248:	f06a                	sd	s10,32(sp)
ffffffffc020024a:	ec6e                	sd	s11,24(sp)
    cprintf("DTB Init\n");
ffffffffc020024c:	f09ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
    cprintf("HartID: %ld\n", boot_hartid);
ffffffffc0200250:	00007597          	auipc	a1,0x7
ffffffffc0200254:	db05b583          	ld	a1,-592(a1) # ffffffffc0207000 <boot_hartid>
ffffffffc0200258:	00002517          	auipc	a0,0x2
ffffffffc020025c:	61050513          	addi	a0,a0,1552 # ffffffffc0202868 <etext+0x120>
ffffffffc0200260:	ef5ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc0200264:	00007417          	auipc	s0,0x7
ffffffffc0200268:	da440413          	addi	s0,s0,-604 # ffffffffc0207008 <boot_dtb>
ffffffffc020026c:	600c                	ld	a1,0(s0)
ffffffffc020026e:	00002517          	auipc	a0,0x2
ffffffffc0200272:	60a50513          	addi	a0,a0,1546 # ffffffffc0202878 <etext+0x130>
ffffffffc0200276:	edfff0ef          	jal	ra,ffffffffc0200154 <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc020027a:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc020027e:	00002517          	auipc	a0,0x2
ffffffffc0200282:	61250513          	addi	a0,a0,1554 # ffffffffc0202890 <etext+0x148>
    if (boot_dtb == 0) {
ffffffffc0200286:	120a0463          	beqz	s4,ffffffffc02003ae <dtb_init+0x186>
        return;
    }
    
    // 转换为虚拟地址
    uintptr_t dtb_vaddr = boot_dtb + PHYSICAL_MEMORY_OFFSET;
ffffffffc020028a:	57f5                	li	a5,-3
ffffffffc020028c:	07fa                	slli	a5,a5,0x1e
ffffffffc020028e:	00fa0733          	add	a4,s4,a5
    const struct fdt_header *header = (const struct fdt_header *)dtb_vaddr;
    
    // 验证DTB
    uint32_t magic = fdt32_to_cpu(header->magic);
ffffffffc0200292:	431c                	lw	a5,0(a4)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200294:	00ff0637          	lui	a2,0xff0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200298:	6b41                	lui	s6,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020029a:	0087d59b          	srliw	a1,a5,0x8
ffffffffc020029e:	0187969b          	slliw	a3,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002a2:	0187d51b          	srliw	a0,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002a6:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002aa:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002ae:	8df1                	and	a1,a1,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002b0:	8ec9                	or	a3,a3,a0
ffffffffc02002b2:	0087979b          	slliw	a5,a5,0x8
ffffffffc02002b6:	1b7d                	addi	s6,s6,-1
ffffffffc02002b8:	0167f7b3          	and	a5,a5,s6
ffffffffc02002bc:	8dd5                	or	a1,a1,a3
ffffffffc02002be:	8ddd                	or	a1,a1,a5
    if (magic != 0xd00dfeed) {
ffffffffc02002c0:	d00e07b7          	lui	a5,0xd00e0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002c4:	2581                	sext.w	a1,a1
    if (magic != 0xd00dfeed) {
ffffffffc02002c6:	eed78793          	addi	a5,a5,-275 # ffffffffd00dfeed <end+0xfed8495>
ffffffffc02002ca:	10f59163          	bne	a1,a5,ffffffffc02003cc <dtb_init+0x1a4>
        return;
    }
    
    // 提取内存信息
    uint64_t mem_base, mem_size;
    if (extract_memory_info(dtb_vaddr, header, &mem_base, &mem_size) == 0) {
ffffffffc02002ce:	471c                	lw	a5,8(a4)
ffffffffc02002d0:	4754                	lw	a3,12(a4)
    int in_memory_node = 0;
ffffffffc02002d2:	4c81                	li	s9,0
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002d4:	0087d59b          	srliw	a1,a5,0x8
ffffffffc02002d8:	0086d51b          	srliw	a0,a3,0x8
ffffffffc02002dc:	0186941b          	slliw	s0,a3,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e0:	0186d89b          	srliw	a7,a3,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002e4:	01879a1b          	slliw	s4,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e8:	0187d81b          	srliw	a6,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002ec:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f0:	0106d69b          	srliw	a3,a3,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002f4:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f8:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002fc:	8d71                	and	a0,a0,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002fe:	01146433          	or	s0,s0,a7
ffffffffc0200302:	0086969b          	slliw	a3,a3,0x8
ffffffffc0200306:	010a6a33          	or	s4,s4,a6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020030a:	8e6d                	and	a2,a2,a1
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020030c:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200310:	8c49                	or	s0,s0,a0
ffffffffc0200312:	0166f6b3          	and	a3,a3,s6
ffffffffc0200316:	00ca6a33          	or	s4,s4,a2
ffffffffc020031a:	0167f7b3          	and	a5,a5,s6
ffffffffc020031e:	8c55                	or	s0,s0,a3
ffffffffc0200320:	00fa6a33          	or	s4,s4,a5
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200324:	1402                	slli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200326:	1a02                	slli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200328:	9001                	srli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc020032a:	020a5a13          	srli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc020032e:	943a                	add	s0,s0,a4
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200330:	9a3a                	add	s4,s4,a4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200332:	00ff0c37          	lui	s8,0xff0
        switch (token) {
ffffffffc0200336:	4b8d                	li	s7,3
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200338:	00002917          	auipc	s2,0x2
ffffffffc020033c:	5a890913          	addi	s2,s2,1448 # ffffffffc02028e0 <etext+0x198>
ffffffffc0200340:	49bd                	li	s3,15
        switch (token) {
ffffffffc0200342:	4d91                	li	s11,4
ffffffffc0200344:	4d05                	li	s10,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc0200346:	00002497          	auipc	s1,0x2
ffffffffc020034a:	59248493          	addi	s1,s1,1426 # ffffffffc02028d8 <etext+0x190>
        uint32_t token = fdt32_to_cpu(*struct_ptr++);
ffffffffc020034e:	000a2703          	lw	a4,0(s4)
ffffffffc0200352:	004a0a93          	addi	s5,s4,4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200356:	0087569b          	srliw	a3,a4,0x8
ffffffffc020035a:	0187179b          	slliw	a5,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020035e:	0187561b          	srliw	a2,a4,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200362:	0106969b          	slliw	a3,a3,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200366:	0107571b          	srliw	a4,a4,0x10
ffffffffc020036a:	8fd1                	or	a5,a5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020036c:	0186f6b3          	and	a3,a3,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200370:	0087171b          	slliw	a4,a4,0x8
ffffffffc0200374:	8fd5                	or	a5,a5,a3
ffffffffc0200376:	00eb7733          	and	a4,s6,a4
ffffffffc020037a:	8fd9                	or	a5,a5,a4
ffffffffc020037c:	2781                	sext.w	a5,a5
        switch (token) {
ffffffffc020037e:	09778c63          	beq	a5,s7,ffffffffc0200416 <dtb_init+0x1ee>
ffffffffc0200382:	00fbea63          	bltu	s7,a5,ffffffffc0200396 <dtb_init+0x16e>
ffffffffc0200386:	07a78663          	beq	a5,s10,ffffffffc02003f2 <dtb_init+0x1ca>
ffffffffc020038a:	4709                	li	a4,2
ffffffffc020038c:	00e79763          	bne	a5,a4,ffffffffc020039a <dtb_init+0x172>
ffffffffc0200390:	4c81                	li	s9,0
ffffffffc0200392:	8a56                	mv	s4,s5
ffffffffc0200394:	bf6d                	j	ffffffffc020034e <dtb_init+0x126>
ffffffffc0200396:	ffb78ee3          	beq	a5,s11,ffffffffc0200392 <dtb_init+0x16a>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
        // 保存到全局变量，供 PMM 查询
        memory_base = mem_base;
        memory_size = mem_size;
    } else {
        cprintf("Warning: Could not extract memory info from DTB\n");
ffffffffc020039a:	00002517          	auipc	a0,0x2
ffffffffc020039e:	5be50513          	addi	a0,a0,1470 # ffffffffc0202958 <etext+0x210>
ffffffffc02003a2:	db3ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc02003a6:	00002517          	auipc	a0,0x2
ffffffffc02003aa:	5ea50513          	addi	a0,a0,1514 # ffffffffc0202990 <etext+0x248>
}
ffffffffc02003ae:	7446                	ld	s0,112(sp)
ffffffffc02003b0:	70e6                	ld	ra,120(sp)
ffffffffc02003b2:	74a6                	ld	s1,104(sp)
ffffffffc02003b4:	7906                	ld	s2,96(sp)
ffffffffc02003b6:	69e6                	ld	s3,88(sp)
ffffffffc02003b8:	6a46                	ld	s4,80(sp)
ffffffffc02003ba:	6aa6                	ld	s5,72(sp)
ffffffffc02003bc:	6b06                	ld	s6,64(sp)
ffffffffc02003be:	7be2                	ld	s7,56(sp)
ffffffffc02003c0:	7c42                	ld	s8,48(sp)
ffffffffc02003c2:	7ca2                	ld	s9,40(sp)
ffffffffc02003c4:	7d02                	ld	s10,32(sp)
ffffffffc02003c6:	6de2                	ld	s11,24(sp)
ffffffffc02003c8:	6109                	addi	sp,sp,128
    cprintf("DTB init completed\n");
ffffffffc02003ca:	b369                	j	ffffffffc0200154 <cprintf>
}
ffffffffc02003cc:	7446                	ld	s0,112(sp)
ffffffffc02003ce:	70e6                	ld	ra,120(sp)
ffffffffc02003d0:	74a6                	ld	s1,104(sp)
ffffffffc02003d2:	7906                	ld	s2,96(sp)
ffffffffc02003d4:	69e6                	ld	s3,88(sp)
ffffffffc02003d6:	6a46                	ld	s4,80(sp)
ffffffffc02003d8:	6aa6                	ld	s5,72(sp)
ffffffffc02003da:	6b06                	ld	s6,64(sp)
ffffffffc02003dc:	7be2                	ld	s7,56(sp)
ffffffffc02003de:	7c42                	ld	s8,48(sp)
ffffffffc02003e0:	7ca2                	ld	s9,40(sp)
ffffffffc02003e2:	7d02                	ld	s10,32(sp)
ffffffffc02003e4:	6de2                	ld	s11,24(sp)
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003e6:	00002517          	auipc	a0,0x2
ffffffffc02003ea:	4ca50513          	addi	a0,a0,1226 # ffffffffc02028b0 <etext+0x168>
}
ffffffffc02003ee:	6109                	addi	sp,sp,128
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003f0:	b395                	j	ffffffffc0200154 <cprintf>
                int name_len = strlen(name);
ffffffffc02003f2:	8556                	mv	a0,s5
ffffffffc02003f4:	2c8020ef          	jal	ra,ffffffffc02026bc <strlen>
ffffffffc02003f8:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003fa:	4619                	li	a2,6
ffffffffc02003fc:	85a6                	mv	a1,s1
ffffffffc02003fe:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc0200400:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc0200402:	30e020ef          	jal	ra,ffffffffc0202710 <strncmp>
ffffffffc0200406:	e111                	bnez	a0,ffffffffc020040a <dtb_init+0x1e2>
                    in_memory_node = 1;
ffffffffc0200408:	4c85                	li	s9,1
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc020040a:	0a91                	addi	s5,s5,4
ffffffffc020040c:	9ad2                	add	s5,s5,s4
ffffffffc020040e:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc0200412:	8a56                	mv	s4,s5
ffffffffc0200414:	bf2d                	j	ffffffffc020034e <dtb_init+0x126>
                uint32_t prop_len = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200416:	004a2783          	lw	a5,4(s4)
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc020041a:	00ca0693          	addi	a3,s4,12
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020041e:	0087d71b          	srliw	a4,a5,0x8
ffffffffc0200422:	01879a9b          	slliw	s5,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200426:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020042a:	0107171b          	slliw	a4,a4,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020042e:	0107d79b          	srliw	a5,a5,0x10
ffffffffc0200432:	00caeab3          	or	s5,s5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200436:	01877733          	and	a4,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020043a:	0087979b          	slliw	a5,a5,0x8
ffffffffc020043e:	00eaeab3          	or	s5,s5,a4
ffffffffc0200442:	00fb77b3          	and	a5,s6,a5
ffffffffc0200446:	00faeab3          	or	s5,s5,a5
ffffffffc020044a:	2a81                	sext.w	s5,s5
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc020044c:	000c9c63          	bnez	s9,ffffffffc0200464 <dtb_init+0x23c>
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + prop_len + 3) & ~3);
ffffffffc0200450:	1a82                	slli	s5,s5,0x20
ffffffffc0200452:	00368793          	addi	a5,a3,3
ffffffffc0200456:	020ada93          	srli	s5,s5,0x20
ffffffffc020045a:	9abe                	add	s5,s5,a5
ffffffffc020045c:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc0200460:	8a56                	mv	s4,s5
ffffffffc0200462:	b5f5                	j	ffffffffc020034e <dtb_init+0x126>
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200464:	008a2783          	lw	a5,8(s4)
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200468:	85ca                	mv	a1,s2
ffffffffc020046a:	e436                	sd	a3,8(sp)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020046c:	0087d51b          	srliw	a0,a5,0x8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200470:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200474:	0187971b          	slliw	a4,a5,0x18
ffffffffc0200478:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020047c:	0107d79b          	srliw	a5,a5,0x10
ffffffffc0200480:	8f51                	or	a4,a4,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200482:	01857533          	and	a0,a0,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200486:	0087979b          	slliw	a5,a5,0x8
ffffffffc020048a:	8d59                	or	a0,a0,a4
ffffffffc020048c:	00fb77b3          	and	a5,s6,a5
ffffffffc0200490:	8d5d                	or	a0,a0,a5
                const char *prop_name = strings_base + prop_nameoff;
ffffffffc0200492:	1502                	slli	a0,a0,0x20
ffffffffc0200494:	9101                	srli	a0,a0,0x20
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200496:	9522                	add	a0,a0,s0
ffffffffc0200498:	25a020ef          	jal	ra,ffffffffc02026f2 <strcmp>
ffffffffc020049c:	66a2                	ld	a3,8(sp)
ffffffffc020049e:	f94d                	bnez	a0,ffffffffc0200450 <dtb_init+0x228>
ffffffffc02004a0:	fb59f8e3          	bgeu	s3,s5,ffffffffc0200450 <dtb_init+0x228>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc02004a4:	00ca3783          	ld	a5,12(s4)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc02004a8:	014a3703          	ld	a4,20(s4)
        cprintf("Physical Memory from DTB:\n");
ffffffffc02004ac:	00002517          	auipc	a0,0x2
ffffffffc02004b0:	43c50513          	addi	a0,a0,1084 # ffffffffc02028e8 <etext+0x1a0>
           fdt32_to_cpu(x >> 32);
ffffffffc02004b4:	4207d613          	srai	a2,a5,0x20
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004b8:	0087d31b          	srliw	t1,a5,0x8
           fdt32_to_cpu(x >> 32);
ffffffffc02004bc:	42075593          	srai	a1,a4,0x20
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004c0:	0187de1b          	srliw	t3,a5,0x18
ffffffffc02004c4:	0186581b          	srliw	a6,a2,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c8:	0187941b          	slliw	s0,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004cc:	0107d89b          	srliw	a7,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004d0:	0187d693          	srli	a3,a5,0x18
ffffffffc02004d4:	01861f1b          	slliw	t5,a2,0x18
ffffffffc02004d8:	0087579b          	srliw	a5,a4,0x8
ffffffffc02004dc:	0103131b          	slliw	t1,t1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004e0:	0106561b          	srliw	a2,a2,0x10
ffffffffc02004e4:	010f6f33          	or	t5,t5,a6
ffffffffc02004e8:	0187529b          	srliw	t0,a4,0x18
ffffffffc02004ec:	0185df9b          	srliw	t6,a1,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004f0:	01837333          	and	t1,t1,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004f4:	01c46433          	or	s0,s0,t3
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004f8:	0186f6b3          	and	a3,a3,s8
ffffffffc02004fc:	01859e1b          	slliw	t3,a1,0x18
ffffffffc0200500:	01871e9b          	slliw	t4,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200504:	0107581b          	srliw	a6,a4,0x10
ffffffffc0200508:	0086161b          	slliw	a2,a2,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020050c:	8361                	srli	a4,a4,0x18
ffffffffc020050e:	0107979b          	slliw	a5,a5,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200512:	0105d59b          	srliw	a1,a1,0x10
ffffffffc0200516:	01e6e6b3          	or	a3,a3,t5
ffffffffc020051a:	00cb7633          	and	a2,s6,a2
ffffffffc020051e:	0088181b          	slliw	a6,a6,0x8
ffffffffc0200522:	0085959b          	slliw	a1,a1,0x8
ffffffffc0200526:	00646433          	or	s0,s0,t1
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020052a:	0187f7b3          	and	a5,a5,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020052e:	01fe6333          	or	t1,t3,t6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200532:	01877c33          	and	s8,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200536:	0088989b          	slliw	a7,a7,0x8
ffffffffc020053a:	011b78b3          	and	a7,s6,a7
ffffffffc020053e:	005eeeb3          	or	t4,t4,t0
ffffffffc0200542:	00c6e733          	or	a4,a3,a2
ffffffffc0200546:	006c6c33          	or	s8,s8,t1
ffffffffc020054a:	010b76b3          	and	a3,s6,a6
ffffffffc020054e:	00bb7b33          	and	s6,s6,a1
ffffffffc0200552:	01d7e7b3          	or	a5,a5,t4
ffffffffc0200556:	016c6b33          	or	s6,s8,s6
ffffffffc020055a:	01146433          	or	s0,s0,a7
ffffffffc020055e:	8fd5                	or	a5,a5,a3
           fdt32_to_cpu(x >> 32);
ffffffffc0200560:	1702                	slli	a4,a4,0x20
ffffffffc0200562:	1b02                	slli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200564:	1782                	slli	a5,a5,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc0200566:	9301                	srli	a4,a4,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200568:	1402                	slli	s0,s0,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc020056a:	020b5b13          	srli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc020056e:	0167eb33          	or	s6,a5,s6
ffffffffc0200572:	8c59                	or	s0,s0,a4
        cprintf("Physical Memory from DTB:\n");
ffffffffc0200574:	be1ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
        cprintf("  Base: 0x%016lx\n", mem_base);
ffffffffc0200578:	85a2                	mv	a1,s0
ffffffffc020057a:	00002517          	auipc	a0,0x2
ffffffffc020057e:	38e50513          	addi	a0,a0,910 # ffffffffc0202908 <etext+0x1c0>
ffffffffc0200582:	bd3ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc0200586:	014b5613          	srli	a2,s6,0x14
ffffffffc020058a:	85da                	mv	a1,s6
ffffffffc020058c:	00002517          	auipc	a0,0x2
ffffffffc0200590:	39450513          	addi	a0,a0,916 # ffffffffc0202920 <etext+0x1d8>
ffffffffc0200594:	bc1ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc0200598:	008b05b3          	add	a1,s6,s0
ffffffffc020059c:	15fd                	addi	a1,a1,-1
ffffffffc020059e:	00002517          	auipc	a0,0x2
ffffffffc02005a2:	3a250513          	addi	a0,a0,930 # ffffffffc0202940 <etext+0x1f8>
ffffffffc02005a6:	bafff0ef          	jal	ra,ffffffffc0200154 <cprintf>
    cprintf("DTB init completed\n");
ffffffffc02005aa:	00002517          	auipc	a0,0x2
ffffffffc02005ae:	3e650513          	addi	a0,a0,998 # ffffffffc0202990 <etext+0x248>
        memory_base = mem_base;
ffffffffc02005b2:	00007797          	auipc	a5,0x7
ffffffffc02005b6:	4687b323          	sd	s0,1126(a5) # ffffffffc0207a18 <memory_base>
        memory_size = mem_size;
ffffffffc02005ba:	00007797          	auipc	a5,0x7
ffffffffc02005be:	4767b323          	sd	s6,1126(a5) # ffffffffc0207a20 <memory_size>
    cprintf("DTB init completed\n");
ffffffffc02005c2:	b3f5                	j	ffffffffc02003ae <dtb_init+0x186>

ffffffffc02005c4 <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc02005c4:	00007517          	auipc	a0,0x7
ffffffffc02005c8:	45453503          	ld	a0,1108(a0) # ffffffffc0207a18 <memory_base>
ffffffffc02005cc:	8082                	ret

ffffffffc02005ce <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
ffffffffc02005ce:	00007517          	auipc	a0,0x7
ffffffffc02005d2:	45253503          	ld	a0,1106(a0) # ffffffffc0207a20 <memory_size>
ffffffffc02005d6:	8082                	ret

ffffffffc02005d8 <best_fit_init>:
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
ffffffffc02005d8:	00007797          	auipc	a5,0x7
ffffffffc02005dc:	a4078793          	addi	a5,a5,-1472 # ffffffffc0207018 <free_area>
ffffffffc02005e0:	e79c                	sd	a5,8(a5)
ffffffffc02005e2:	e39c                	sd	a5,0(a5)
#define free_list (free_area.free_list)
#define nr_free (free_area.nr_free)

static void best_fit_init(void) {
    list_init(&free_list);
    nr_free = 0;
ffffffffc02005e4:	0007a823          	sw	zero,16(a5)
}
ffffffffc02005e8:	8082                	ret

ffffffffc02005ea <best_fit_nr_free_pages>:
    SetPageProperty(base);
    nr_free += n;
    best_fit_insert_merge(base);
}

static size_t best_fit_nr_free_pages(void) { return nr_free; }
ffffffffc02005ea:	00007517          	auipc	a0,0x7
ffffffffc02005ee:	a3e56503          	lwu	a0,-1474(a0) # ffffffffc0207028 <free_area+0x10>
ffffffffc02005f2:	8082                	ret

ffffffffc02005f4 <best_fit_insert_merge>:
 * list_next - get the next entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_next(list_entry_t *listelm) {
    return listelm->next;
ffffffffc02005f4:	00007697          	auipc	a3,0x7
ffffffffc02005f8:	a2468693          	addi	a3,a3,-1500 # ffffffffc0207018 <free_area>
ffffffffc02005fc:	669c                	ld	a5,8(a3)
static void best_fit_insert_merge(struct Page *base) {
ffffffffc02005fe:	1141                	addi	sp,sp,-16
ffffffffc0200600:	e406                	sd	ra,8(sp)
    while (at != &free_list && le2page(at, page_link) < base) {
ffffffffc0200602:	00d79663          	bne	a5,a3,ffffffffc020060e <best_fit_insert_merge+0x1a>
ffffffffc0200606:	a801                	j	ffffffffc0200616 <best_fit_insert_merge+0x22>
ffffffffc0200608:	679c                	ld	a5,8(a5)
ffffffffc020060a:	00d78663          	beq	a5,a3,ffffffffc0200616 <best_fit_insert_merge+0x22>
ffffffffc020060e:	fe878713          	addi	a4,a5,-24
ffffffffc0200612:	fea76be3          	bltu	a4,a0,ffffffffc0200608 <best_fit_insert_merge+0x14>
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200616:	6390                	ld	a2,0(a5)
    list_add_before(at, &base->page_link);
ffffffffc0200618:	01850593          	addi	a1,a0,24
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_add(list_entry_t *elm, list_entry_t *prev, list_entry_t *next) {
    prev->next = next->prev = elm;
ffffffffc020061c:	e38c                	sd	a1,0(a5)
ffffffffc020061e:	e60c                	sd	a1,8(a2)
    elm->next = next;
ffffffffc0200620:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200622:	ed10                	sd	a2,24(a0)
    if (prev != &free_list) {
ffffffffc0200624:	02d60363          	beq	a2,a3,ffffffffc020064a <best_fit_insert_merge+0x56>
        assert(p + p->property <= base);
ffffffffc0200628:	ff862303          	lw	t1,-8(a2) # fefff8 <kern_entry-0xffffffffbf210008>
        struct Page *p = le2page(prev, page_link);
ffffffffc020062c:	fe860893          	addi	a7,a2,-24
        assert(p + p->property <= base);
ffffffffc0200630:	02031813          	slli	a6,t1,0x20
ffffffffc0200634:	02085813          	srli	a6,a6,0x20
ffffffffc0200638:	00281713          	slli	a4,a6,0x2
ffffffffc020063c:	9742                	add	a4,a4,a6
ffffffffc020063e:	070e                	slli	a4,a4,0x3
ffffffffc0200640:	9746                	add	a4,a4,a7
ffffffffc0200642:	08e56163          	bltu	a0,a4,ffffffffc02006c4 <best_fit_insert_merge+0xd0>
        if (p + p->property == base) {
ffffffffc0200646:	02a70663          	beq	a4,a0,ffffffffc0200672 <best_fit_insert_merge+0x7e>
    if (next != &free_list) {
ffffffffc020064a:	02d78163          	beq	a5,a3,ffffffffc020066c <best_fit_insert_merge+0x78>
        assert(base + base->property <= p);
ffffffffc020064e:	490c                	lw	a1,16(a0)
        struct Page *p = le2page(next, page_link);
ffffffffc0200650:	fe878693          	addi	a3,a5,-24
        assert(base + base->property <= p);
ffffffffc0200654:	02059613          	slli	a2,a1,0x20
ffffffffc0200658:	9201                	srli	a2,a2,0x20
ffffffffc020065a:	00261713          	slli	a4,a2,0x2
ffffffffc020065e:	9732                	add	a4,a4,a2
ffffffffc0200660:	070e                	slli	a4,a4,0x3
ffffffffc0200662:	972a                	add	a4,a4,a0
ffffffffc0200664:	06e6ef63          	bltu	a3,a4,ffffffffc02006e2 <best_fit_insert_merge+0xee>
        if (base + base->property == p) {
ffffffffc0200668:	02d70763          	beq	a4,a3,ffffffffc0200696 <best_fit_insert_merge+0xa2>
}
ffffffffc020066c:	60a2                	ld	ra,8(sp)
ffffffffc020066e:	0141                	addi	sp,sp,16
ffffffffc0200670:	8082                	ret
            p->property += base->property;
ffffffffc0200672:	01052803          	lw	a6,16(a0)
            ClearPageProperty(base);
ffffffffc0200676:	6518                	ld	a4,8(a0)
            p->property += base->property;
ffffffffc0200678:	0068033b          	addw	t1,a6,t1
ffffffffc020067c:	fe662c23          	sw	t1,-8(a2)
            ClearPageProperty(base);
ffffffffc0200680:	9b75                	andi	a4,a4,-3
ffffffffc0200682:	e518                	sd	a4,8(a0)
            base->property = 0;
ffffffffc0200684:	00052823          	sw	zero,16(a0)
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc0200688:	e61c                	sd	a5,8(a2)
    next->prev = prev;
ffffffffc020068a:	e390                	sd	a2,0(a5)
    elm->prev = elm->next = elm;
ffffffffc020068c:	f10c                	sd	a1,32(a0)
    return listelm->next;
ffffffffc020068e:	661c                	ld	a5,8(a2)
    elm->prev = elm->next = elm;
ffffffffc0200690:	ed0c                	sd	a1,24(a0)
            base = p;
ffffffffc0200692:	8546                	mv	a0,a7
ffffffffc0200694:	bf5d                	j	ffffffffc020064a <best_fit_insert_merge+0x56>
            base->property += p->property;
ffffffffc0200696:	ff87a683          	lw	a3,-8(a5)
            ClearPageProperty(p);
ffffffffc020069a:	ff07b703          	ld	a4,-16(a5)
    __list_del(listelm->prev, listelm->next);
ffffffffc020069e:	0007b803          	ld	a6,0(a5)
ffffffffc02006a2:	6790                	ld	a2,8(a5)
            base->property += p->property;
ffffffffc02006a4:	9db5                	addw	a1,a1,a3
ffffffffc02006a6:	c90c                	sw	a1,16(a0)
            ClearPageProperty(p);
ffffffffc02006a8:	9b75                	andi	a4,a4,-3
ffffffffc02006aa:	fee7b823          	sd	a4,-16(a5)
            p->property = 0;
ffffffffc02006ae:	fe07ac23          	sw	zero,-8(a5)
    prev->next = next;
ffffffffc02006b2:	00c83423          	sd	a2,8(a6)
}
ffffffffc02006b6:	60a2                	ld	ra,8(sp)
    next->prev = prev;
ffffffffc02006b8:	01063023          	sd	a6,0(a2)
    elm->prev = elm->next = elm;
ffffffffc02006bc:	e79c                	sd	a5,8(a5)
ffffffffc02006be:	e39c                	sd	a5,0(a5)
ffffffffc02006c0:	0141                	addi	sp,sp,16
ffffffffc02006c2:	8082                	ret
        assert(p + p->property <= base);
ffffffffc02006c4:	00002697          	auipc	a3,0x2
ffffffffc02006c8:	2e468693          	addi	a3,a3,740 # ffffffffc02029a8 <etext+0x260>
ffffffffc02006cc:	00002617          	auipc	a2,0x2
ffffffffc02006d0:	2f460613          	addi	a2,a2,756 # ffffffffc02029c0 <etext+0x278>
ffffffffc02006d4:	45e9                	li	a1,26
ffffffffc02006d6:	00002517          	auipc	a0,0x2
ffffffffc02006da:	30250513          	addi	a0,a0,770 # ffffffffc02029d8 <etext+0x290>
ffffffffc02006de:	aedff0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert(base + base->property <= p);
ffffffffc02006e2:	00002697          	auipc	a3,0x2
ffffffffc02006e6:	30e68693          	addi	a3,a3,782 # ffffffffc02029f0 <etext+0x2a8>
ffffffffc02006ea:	00002617          	auipc	a2,0x2
ffffffffc02006ee:	2d660613          	addi	a2,a2,726 # ffffffffc02029c0 <etext+0x278>
ffffffffc02006f2:	02600593          	li	a1,38
ffffffffc02006f6:	00002517          	auipc	a0,0x2
ffffffffc02006fa:	2e250513          	addi	a0,a0,738 # ffffffffc02029d8 <etext+0x290>
ffffffffc02006fe:	acdff0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc0200702 <best_fit_alloc_pages>:
    assert(n > 0);
ffffffffc0200702:	cd4d                	beqz	a0,ffffffffc02007bc <best_fit_alloc_pages+0xba>
    if (n > nr_free) return NULL;
ffffffffc0200704:	00007597          	auipc	a1,0x7
ffffffffc0200708:	91458593          	addi	a1,a1,-1772 # ffffffffc0207018 <free_area>
ffffffffc020070c:	0105a883          	lw	a7,16(a1)
ffffffffc0200710:	862a                	mv	a2,a0
ffffffffc0200712:	02089793          	slli	a5,a7,0x20
ffffffffc0200716:	9381                	srli	a5,a5,0x20
ffffffffc0200718:	0aa7e063          	bltu	a5,a0,ffffffffc02007b8 <best_fit_alloc_pages+0xb6>
    return listelm->next;
ffffffffc020071c:	659c                	ld	a5,8(a1)
    struct Page *best = NULL;
ffffffffc020071e:	4501                	li	a0,0
    for (list_entry_t *le = list_next(&free_list); le != &free_list;
ffffffffc0200720:	08b78b63          	beq	a5,a1,ffffffffc02007b6 <best_fit_alloc_pages+0xb4>
        if (p->property >= n && (!best || p->property < best->property)) {
ffffffffc0200724:	ff87a703          	lw	a4,-8(a5)
ffffffffc0200728:	02071693          	slli	a3,a4,0x20
ffffffffc020072c:	9281                	srli	a3,a3,0x20
ffffffffc020072e:	00c6eb63          	bltu	a3,a2,ffffffffc0200744 <best_fit_alloc_pages+0x42>
ffffffffc0200732:	c509                	beqz	a0,ffffffffc020073c <best_fit_alloc_pages+0x3a>
ffffffffc0200734:	01052803          	lw	a6,16(a0)
ffffffffc0200738:	01077663          	bgeu	a4,a6,ffffffffc0200744 <best_fit_alloc_pages+0x42>
        struct Page *p = le2page(le, page_link);
ffffffffc020073c:	fe878513          	addi	a0,a5,-24
            if (p->property == n) break;
ffffffffc0200740:	00c68663          	beq	a3,a2,ffffffffc020074c <best_fit_alloc_pages+0x4a>
ffffffffc0200744:	679c                	ld	a5,8(a5)
    for (list_entry_t *le = list_next(&free_list); le != &free_list;
ffffffffc0200746:	fcb79fe3          	bne	a5,a1,ffffffffc0200724 <best_fit_alloc_pages+0x22>
    if (!best) return NULL;
ffffffffc020074a:	c535                	beqz	a0,ffffffffc02007b6 <best_fit_alloc_pages+0xb4>
    __list_del(listelm->prev, listelm->next);
ffffffffc020074c:	02053803          	ld	a6,32(a0)
    return listelm->prev;
ffffffffc0200750:	6d18                	ld	a4,24(a0)
    ClearPageProperty(best);
ffffffffc0200752:	651c                	ld	a5,8(a0)
    size_t old_size = best->property;
ffffffffc0200754:	4914                	lw	a3,16(a0)
    prev->next = next;
ffffffffc0200756:	01073423          	sd	a6,8(a4)
    next->prev = prev;
ffffffffc020075a:	00e83023          	sd	a4,0(a6)
    ClearPageProperty(best);
ffffffffc020075e:	9bf5                	andi	a5,a5,-3
    list_del_init(&best->page_link);
ffffffffc0200760:	01850813          	addi	a6,a0,24
    ClearPageProperty(best);
ffffffffc0200764:	e51c                	sd	a5,8(a0)
    size_t old_size = best->property;
ffffffffc0200766:	02069793          	slli	a5,a3,0x20
    elm->prev = elm->next = elm;
ffffffffc020076a:	03053023          	sd	a6,32(a0)
ffffffffc020076e:	01053c23          	sd	a6,24(a0)
    best->property = 0;
ffffffffc0200772:	00052823          	sw	zero,16(a0)
    size_t old_size = best->property;
ffffffffc0200776:	9381                	srli	a5,a5,0x20
        rest->property = old_size - n;
ffffffffc0200778:	0006081b          	sext.w	a6,a2
    if (old_size > n) {
ffffffffc020077c:	02f67863          	bgeu	a2,a5,ffffffffc02007ac <best_fit_alloc_pages+0xaa>
        struct Page *rest = best + n;
ffffffffc0200780:	00261793          	slli	a5,a2,0x2
ffffffffc0200784:	97b2                	add	a5,a5,a2
ffffffffc0200786:	078e                	slli	a5,a5,0x3
ffffffffc0200788:	97aa                	add	a5,a5,a0
        SetPageProperty(rest);
ffffffffc020078a:	6790                	ld	a2,8(a5)
    __list_add(elm, listelm, listelm->next);
ffffffffc020078c:	00873303          	ld	t1,8(a4)
        rest->property = old_size - n;
ffffffffc0200790:	410686bb          	subw	a3,a3,a6
        SetPageProperty(rest);
ffffffffc0200794:	00266613          	ori	a2,a2,2
        rest->property = old_size - n;
ffffffffc0200798:	cb94                	sw	a3,16(a5)
        SetPageProperty(rest);
ffffffffc020079a:	e790                	sd	a2,8(a5)
        list_add_after(prev, &rest->page_link);
ffffffffc020079c:	01878693          	addi	a3,a5,24
    prev->next = next->prev = elm;
ffffffffc02007a0:	00d33023          	sd	a3,0(t1)
ffffffffc02007a4:	e714                	sd	a3,8(a4)
    elm->next = next;
ffffffffc02007a6:	0267b023          	sd	t1,32(a5)
    elm->prev = prev;
ffffffffc02007aa:	ef98                	sd	a4,24(a5)
    nr_free -= n;
ffffffffc02007ac:	410888bb          	subw	a7,a7,a6
ffffffffc02007b0:	0115a823          	sw	a7,16(a1)
    return best;
ffffffffc02007b4:	8082                	ret
}
ffffffffc02007b6:	8082                	ret
    if (n > nr_free) return NULL;
ffffffffc02007b8:	4501                	li	a0,0
ffffffffc02007ba:	8082                	ret
static struct Page *best_fit_alloc_pages(size_t n) {
ffffffffc02007bc:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc02007be:	00002697          	auipc	a3,0x2
ffffffffc02007c2:	25268693          	addi	a3,a3,594 # ffffffffc0202a10 <etext+0x2c8>
ffffffffc02007c6:	00002617          	auipc	a2,0x2
ffffffffc02007ca:	1fa60613          	addi	a2,a2,506 # ffffffffc02029c0 <etext+0x278>
ffffffffc02007ce:	04000593          	li	a1,64
ffffffffc02007d2:	00002517          	auipc	a0,0x2
ffffffffc02007d6:	20650513          	addi	a0,a0,518 # ffffffffc02029d8 <etext+0x290>
static struct Page *best_fit_alloc_pages(size_t n) {
ffffffffc02007da:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc02007dc:	9efff0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc02007e0 <best_fit_free_pages>:
static void best_fit_free_pages(struct Page *base, size_t n) {
ffffffffc02007e0:	1141                	addi	sp,sp,-16
ffffffffc02007e2:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc02007e4:	c9b5                	beqz	a1,ffffffffc0200858 <best_fit_free_pages+0x78>
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc02007e6:	00259693          	slli	a3,a1,0x2
ffffffffc02007ea:	96ae                	add	a3,a3,a1
ffffffffc02007ec:	068e                	slli	a3,a3,0x3
ffffffffc02007ee:	96aa                	add	a3,a3,a0
ffffffffc02007f0:	87aa                	mv	a5,a0
ffffffffc02007f2:	02d57363          	bgeu	a0,a3,ffffffffc0200818 <best_fit_free_pages+0x38>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc02007f6:	6798                	ld	a4,8(a5)
ffffffffc02007f8:	8b0d                	andi	a4,a4,3
ffffffffc02007fa:	ef1d                	bnez	a4,ffffffffc0200838 <best_fit_free_pages+0x58>
        p->flags = 0;
ffffffffc02007fc:	01878713          	addi	a4,a5,24
ffffffffc0200800:	0007b423          	sd	zero,8(a5)
        p->property = 0;
ffffffffc0200804:	0007a823          	sw	zero,16(a5)
    return (void *)(page2pa(page) + va_pa_offset);
}

static inline int page_ref(struct Page *page) { return page->ref; }

static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0200808:	0007a023          	sw	zero,0(a5)
    elm->prev = elm->next = elm;
ffffffffc020080c:	f398                	sd	a4,32(a5)
ffffffffc020080e:	ef98                	sd	a4,24(a5)
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200810:	02878793          	addi	a5,a5,40
ffffffffc0200814:	fed7e1e3          	bltu	a5,a3,ffffffffc02007f6 <best_fit_free_pages+0x16>
    SetPageProperty(base);
ffffffffc0200818:	6518                	ld	a4,8(a0)
    nr_free += n;
ffffffffc020081a:	00006697          	auipc	a3,0x6
ffffffffc020081e:	7fe68693          	addi	a3,a3,2046 # ffffffffc0207018 <free_area>
ffffffffc0200822:	4a9c                	lw	a5,16(a3)
    base->property = n;
ffffffffc0200824:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc0200826:	00276713          	ori	a4,a4,2
    base->property = n;
ffffffffc020082a:	c90c                	sw	a1,16(a0)
}
ffffffffc020082c:	60a2                	ld	ra,8(sp)
    SetPageProperty(base);
ffffffffc020082e:	e518                	sd	a4,8(a0)
    nr_free += n;
ffffffffc0200830:	9dbd                	addw	a1,a1,a5
ffffffffc0200832:	ca8c                	sw	a1,16(a3)
}
ffffffffc0200834:	0141                	addi	sp,sp,16
    best_fit_insert_merge(base);
ffffffffc0200836:	bb7d                	j	ffffffffc02005f4 <best_fit_insert_merge>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200838:	00002697          	auipc	a3,0x2
ffffffffc020083c:	1e068693          	addi	a3,a3,480 # ffffffffc0202a18 <etext+0x2d0>
ffffffffc0200840:	00002617          	auipc	a2,0x2
ffffffffc0200844:	18060613          	addi	a2,a2,384 # ffffffffc02029c0 <etext+0x278>
ffffffffc0200848:	05e00593          	li	a1,94
ffffffffc020084c:	00002517          	auipc	a0,0x2
ffffffffc0200850:	18c50513          	addi	a0,a0,396 # ffffffffc02029d8 <etext+0x290>
ffffffffc0200854:	977ff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(n > 0);
ffffffffc0200858:	00002697          	auipc	a3,0x2
ffffffffc020085c:	1b868693          	addi	a3,a3,440 # ffffffffc0202a10 <etext+0x2c8>
ffffffffc0200860:	00002617          	auipc	a2,0x2
ffffffffc0200864:	16060613          	addi	a2,a2,352 # ffffffffc02029c0 <etext+0x278>
ffffffffc0200868:	05c00593          	li	a1,92
ffffffffc020086c:	00002517          	auipc	a0,0x2
ffffffffc0200870:	16c50513          	addi	a0,a0,364 # ffffffffc02029d8 <etext+0x290>
ffffffffc0200874:	957ff0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc0200878 <best_fit_init_memmap>:
static void best_fit_init_memmap(struct Page *base, size_t n) {
ffffffffc0200878:	1141                	addi	sp,sp,-16
ffffffffc020087a:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc020087c:	c9b5                	beqz	a1,ffffffffc02008f0 <best_fit_init_memmap+0x78>
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc020087e:	00259693          	slli	a3,a1,0x2
ffffffffc0200882:	96ae                	add	a3,a3,a1
ffffffffc0200884:	068e                	slli	a3,a3,0x3
ffffffffc0200886:	96aa                	add	a3,a3,a0
ffffffffc0200888:	87aa                	mv	a5,a0
ffffffffc020088a:	02d57363          	bgeu	a0,a3,ffffffffc02008b0 <best_fit_init_memmap+0x38>
        assert(PageReserved(p));
ffffffffc020088e:	6798                	ld	a4,8(a5)
ffffffffc0200890:	8b05                	andi	a4,a4,1
ffffffffc0200892:	cf1d                	beqz	a4,ffffffffc02008d0 <best_fit_init_memmap+0x58>
        p->flags = 0;
ffffffffc0200894:	01878713          	addi	a4,a5,24
ffffffffc0200898:	0007b423          	sd	zero,8(a5)
        p->property = 0;
ffffffffc020089c:	0007a823          	sw	zero,16(a5)
ffffffffc02008a0:	0007a023          	sw	zero,0(a5)
ffffffffc02008a4:	f398                	sd	a4,32(a5)
ffffffffc02008a6:	ef98                	sd	a4,24(a5)
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc02008a8:	02878793          	addi	a5,a5,40
ffffffffc02008ac:	fed7e1e3          	bltu	a5,a3,ffffffffc020088e <best_fit_init_memmap+0x16>
    SetPageProperty(base);
ffffffffc02008b0:	6518                	ld	a4,8(a0)
    nr_free += n;
ffffffffc02008b2:	00006697          	auipc	a3,0x6
ffffffffc02008b6:	76668693          	addi	a3,a3,1894 # ffffffffc0207018 <free_area>
ffffffffc02008ba:	4a9c                	lw	a5,16(a3)
    base->property = n;
ffffffffc02008bc:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc02008be:	00276713          	ori	a4,a4,2
    base->property = n;
ffffffffc02008c2:	c90c                	sw	a1,16(a0)
}
ffffffffc02008c4:	60a2                	ld	ra,8(sp)
    SetPageProperty(base);
ffffffffc02008c6:	e518                	sd	a4,8(a0)
    nr_free += n;
ffffffffc02008c8:	9dbd                	addw	a1,a1,a5
ffffffffc02008ca:	ca8c                	sw	a1,16(a3)
}
ffffffffc02008cc:	0141                	addi	sp,sp,16
    best_fit_insert_merge(base);
ffffffffc02008ce:	b31d                	j	ffffffffc02005f4 <best_fit_insert_merge>
        assert(PageReserved(p));
ffffffffc02008d0:	00002697          	auipc	a3,0x2
ffffffffc02008d4:	17068693          	addi	a3,a3,368 # ffffffffc0202a40 <etext+0x2f8>
ffffffffc02008d8:	00002617          	auipc	a2,0x2
ffffffffc02008dc:	0e860613          	addi	a2,a2,232 # ffffffffc02029c0 <etext+0x278>
ffffffffc02008e0:	03300593          	li	a1,51
ffffffffc02008e4:	00002517          	auipc	a0,0x2
ffffffffc02008e8:	0f450513          	addi	a0,a0,244 # ffffffffc02029d8 <etext+0x290>
ffffffffc02008ec:	8dfff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(n > 0);
ffffffffc02008f0:	00002697          	auipc	a3,0x2
ffffffffc02008f4:	12068693          	addi	a3,a3,288 # ffffffffc0202a10 <etext+0x2c8>
ffffffffc02008f8:	00002617          	auipc	a2,0x2
ffffffffc02008fc:	0c860613          	addi	a2,a2,200 # ffffffffc02029c0 <etext+0x278>
ffffffffc0200900:	03100593          	li	a1,49
ffffffffc0200904:	00002517          	auipc	a0,0x2
ffffffffc0200908:	0d450513          	addi	a0,a0,212 # ffffffffc02029d8 <etext+0x290>
ffffffffc020090c:	8bfff0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc0200910 <best_fit_run_checks>:
    best_fit_free_pages(arena, 64);
    assert(nr_free == original);
    cprintf("Best-Fit: minimum choice, tie, split, bridge merge, failure PASS\n");
}

static void best_fit_run_checks(void) {
ffffffffc0200910:	7135                	addi	sp,sp,-160
ffffffffc0200912:	f0da                	sd	s6,96(sp)
    return listelm->next;
ffffffffc0200914:	00006b17          	auipc	s6,0x6
ffffffffc0200918:	704b0b13          	addi	s6,s6,1796 # ffffffffc0207018 <free_area>
ffffffffc020091c:	008b3783          	ld	a5,8(s6)
ffffffffc0200920:	ed06                	sd	ra,152(sp)
ffffffffc0200922:	e922                	sd	s0,144(sp)
ffffffffc0200924:	e526                	sd	s1,136(sp)
ffffffffc0200926:	e14a                	sd	s2,128(sp)
ffffffffc0200928:	fcce                	sd	s3,120(sp)
ffffffffc020092a:	f8d2                	sd	s4,112(sp)
ffffffffc020092c:	f4d6                	sd	s5,104(sp)
ffffffffc020092e:	ecde                	sd	s7,88(sp)
ffffffffc0200930:	e8e2                	sd	s8,80(sp)
ffffffffc0200932:	e4e6                	sd	s9,72(sp)
ffffffffc0200934:	e0ea                	sd	s10,64(sp)
ffffffffc0200936:	fc6e                	sd	s11,56(sp)
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200938:	69678963          	beq	a5,s6,ffffffffc0200fca <best_fit_run_checks+0x6ba>
    int count = 0, total = 0;
ffffffffc020093c:	4401                	li	s0,0
ffffffffc020093e:	4481                	li	s1,0
        assert(PageProperty(p));
ffffffffc0200940:	ff07b703          	ld	a4,-16(a5)
ffffffffc0200944:	8b09                	andi	a4,a4,2
ffffffffc0200946:	6a070663          	beqz	a4,ffffffffc0200ff2 <best_fit_run_checks+0x6e2>
        count ++, total += p->property;
ffffffffc020094a:	ff87a703          	lw	a4,-8(a5)
ffffffffc020094e:	679c                	ld	a5,8(a5)
ffffffffc0200950:	2485                	addiw	s1,s1,1
ffffffffc0200952:	9c39                	addw	s0,s0,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200954:	ff6796e3          	bne	a5,s6,ffffffffc0200940 <best_fit_run_checks+0x30>
    assert(total == nr_free_pages());
ffffffffc0200958:	8922                	mv	s2,s0
ffffffffc020095a:	471000ef          	jal	ra,ffffffffc02015ca <nr_free_pages>
ffffffffc020095e:	23251ae3          	bne	a0,s2,ffffffffc0201392 <best_fit_run_checks+0xa82>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200962:	4505                	li	a0,1
ffffffffc0200964:	44f000ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0200968:	892a                	mv	s2,a0
ffffffffc020096a:	6e050463          	beqz	a0,ffffffffc0201052 <best_fit_run_checks+0x742>
    assert((p1 = alloc_page()) != NULL);
ffffffffc020096e:	4505                	li	a0,1
ffffffffc0200970:	443000ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0200974:	8a2a                	mv	s4,a0
ffffffffc0200976:	6a050e63          	beqz	a0,ffffffffc0201032 <best_fit_run_checks+0x722>
    assert((p2 = alloc_page()) != NULL);
ffffffffc020097a:	4505                	li	a0,1
ffffffffc020097c:	437000ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0200980:	89aa                	mv	s3,a0
ffffffffc0200982:	74050863          	beqz	a0,ffffffffc02010d2 <best_fit_run_checks+0x7c2>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200986:	73490663          	beq	s2,s4,ffffffffc02010b2 <best_fit_run_checks+0x7a2>
ffffffffc020098a:	72a90463          	beq	s2,a0,ffffffffc02010b2 <best_fit_run_checks+0x7a2>
ffffffffc020098e:	72aa0263          	beq	s4,a0,ffffffffc02010b2 <best_fit_run_checks+0x7a2>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200992:	00092783          	lw	a5,0(s2)
ffffffffc0200996:	6e079e63          	bnez	a5,ffffffffc0201092 <best_fit_run_checks+0x782>
ffffffffc020099a:	000a2783          	lw	a5,0(s4)
ffffffffc020099e:	6e079a63          	bnez	a5,ffffffffc0201092 <best_fit_run_checks+0x782>
ffffffffc02009a2:	411c                	lw	a5,0(a0)
ffffffffc02009a4:	6e079763          	bnez	a5,ffffffffc0201092 <best_fit_run_checks+0x782>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc02009a8:	00007797          	auipc	a5,0x7
ffffffffc02009ac:	0887b783          	ld	a5,136(a5) # ffffffffc0207a30 <pages>
ffffffffc02009b0:	40f90733          	sub	a4,s2,a5
ffffffffc02009b4:	870d                	srai	a4,a4,0x3
ffffffffc02009b6:	00003597          	auipc	a1,0x3
ffffffffc02009ba:	e9a5b583          	ld	a1,-358(a1) # ffffffffc0203850 <error_string+0x38>
ffffffffc02009be:	02b70733          	mul	a4,a4,a1
ffffffffc02009c2:	00003617          	auipc	a2,0x3
ffffffffc02009c6:	ea663603          	ld	a2,-346(a2) # ffffffffc0203868 <nbase>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc02009ca:	00007697          	auipc	a3,0x7
ffffffffc02009ce:	05e6b683          	ld	a3,94(a3) # ffffffffc0207a28 <npage>
ffffffffc02009d2:	06b2                	slli	a3,a3,0xc
ffffffffc02009d4:	9732                	add	a4,a4,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc02009d6:	0732                	slli	a4,a4,0xc
ffffffffc02009d8:	68d77d63          	bgeu	a4,a3,ffffffffc0201072 <best_fit_run_checks+0x762>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc02009dc:	40fa0733          	sub	a4,s4,a5
ffffffffc02009e0:	870d                	srai	a4,a4,0x3
ffffffffc02009e2:	02b70733          	mul	a4,a4,a1
ffffffffc02009e6:	9732                	add	a4,a4,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc02009e8:	0732                	slli	a4,a4,0xc
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc02009ea:	7ed77463          	bgeu	a4,a3,ffffffffc02011d2 <best_fit_run_checks+0x8c2>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc02009ee:	40f507b3          	sub	a5,a0,a5
ffffffffc02009f2:	878d                	srai	a5,a5,0x3
ffffffffc02009f4:	02b787b3          	mul	a5,a5,a1
ffffffffc02009f8:	97b2                	add	a5,a5,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc02009fa:	07b2                	slli	a5,a5,0xc
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc02009fc:	7ad7fb63          	bgeu	a5,a3,ffffffffc02011b2 <best_fit_run_checks+0x8a2>
    assert(alloc_page() == NULL);
ffffffffc0200a00:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc0200a02:	000b3c03          	ld	s8,0(s6)
ffffffffc0200a06:	008b3b83          	ld	s7,8(s6)
    unsigned int nr_free_store = nr_free;
ffffffffc0200a0a:	010b2a83          	lw	s5,16(s6)
    elm->prev = elm->next = elm;
ffffffffc0200a0e:	016b3423          	sd	s6,8(s6)
ffffffffc0200a12:	016b3023          	sd	s6,0(s6)
    nr_free = 0;
ffffffffc0200a16:	00006797          	auipc	a5,0x6
ffffffffc0200a1a:	6007a923          	sw	zero,1554(a5) # ffffffffc0207028 <free_area+0x10>
    assert(alloc_page() == NULL);
ffffffffc0200a1e:	395000ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0200a22:	76051863          	bnez	a0,ffffffffc0201192 <best_fit_run_checks+0x882>
    free_page(p0);
ffffffffc0200a26:	4585                	li	a1,1
ffffffffc0200a28:	854a                	mv	a0,s2
ffffffffc0200a2a:	395000ef          	jal	ra,ffffffffc02015be <free_pages>
    free_page(p1);
ffffffffc0200a2e:	4585                	li	a1,1
ffffffffc0200a30:	8552                	mv	a0,s4
ffffffffc0200a32:	38d000ef          	jal	ra,ffffffffc02015be <free_pages>
    free_page(p2);
ffffffffc0200a36:	4585                	li	a1,1
ffffffffc0200a38:	854e                	mv	a0,s3
ffffffffc0200a3a:	385000ef          	jal	ra,ffffffffc02015be <free_pages>
    assert(nr_free == 3);
ffffffffc0200a3e:	010b2703          	lw	a4,16(s6)
ffffffffc0200a42:	478d                	li	a5,3
ffffffffc0200a44:	72f71763          	bne	a4,a5,ffffffffc0201172 <best_fit_run_checks+0x862>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200a48:	4505                	li	a0,1
ffffffffc0200a4a:	369000ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0200a4e:	892a                	mv	s2,a0
ffffffffc0200a50:	70050163          	beqz	a0,ffffffffc0201152 <best_fit_run_checks+0x842>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200a54:	4505                	li	a0,1
ffffffffc0200a56:	35d000ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0200a5a:	8a2a                	mv	s4,a0
ffffffffc0200a5c:	6c050b63          	beqz	a0,ffffffffc0201132 <best_fit_run_checks+0x822>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200a60:	4505                	li	a0,1
ffffffffc0200a62:	351000ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0200a66:	89aa                	mv	s3,a0
ffffffffc0200a68:	6a050563          	beqz	a0,ffffffffc0201112 <best_fit_run_checks+0x802>
    assert(alloc_page() == NULL);
ffffffffc0200a6c:	4505                	li	a0,1
ffffffffc0200a6e:	345000ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0200a72:	68051063          	bnez	a0,ffffffffc02010f2 <best_fit_run_checks+0x7e2>
    free_page(p0);
ffffffffc0200a76:	4585                	li	a1,1
ffffffffc0200a78:	854a                	mv	a0,s2
ffffffffc0200a7a:	345000ef          	jal	ra,ffffffffc02015be <free_pages>
    assert(!list_empty(&free_list));
ffffffffc0200a7e:	008b3783          	ld	a5,8(s6)
ffffffffc0200a82:	316788e3          	beq	a5,s6,ffffffffc0201592 <best_fit_run_checks+0xc82>
    assert((p = alloc_page()) == p0);
ffffffffc0200a86:	4505                	li	a0,1
ffffffffc0200a88:	32b000ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0200a8c:	16a913e3          	bne	s2,a0,ffffffffc02013f2 <best_fit_run_checks+0xae2>
    assert(alloc_page() == NULL);
ffffffffc0200a90:	4505                	li	a0,1
ffffffffc0200a92:	321000ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0200a96:	12051ee3          	bnez	a0,ffffffffc02013d2 <best_fit_run_checks+0xac2>
    assert(nr_free == 0);
ffffffffc0200a9a:	010b2783          	lw	a5,16(s6)
ffffffffc0200a9e:	2c079ae3          	bnez	a5,ffffffffc0201572 <best_fit_run_checks+0xc62>
    free_page(p);
ffffffffc0200aa2:	854a                	mv	a0,s2
ffffffffc0200aa4:	4585                	li	a1,1
    free_list = free_list_store;
ffffffffc0200aa6:	018b3023          	sd	s8,0(s6)
ffffffffc0200aaa:	017b3423          	sd	s7,8(s6)
    nr_free = nr_free_store;
ffffffffc0200aae:	015b2823          	sw	s5,16(s6)
    free_page(p);
ffffffffc0200ab2:	30d000ef          	jal	ra,ffffffffc02015be <free_pages>
    free_page(p1);
ffffffffc0200ab6:	4585                	li	a1,1
ffffffffc0200ab8:	8552                	mv	a0,s4
ffffffffc0200aba:	305000ef          	jal	ra,ffffffffc02015be <free_pages>
    free_page(p2);
ffffffffc0200abe:	4585                	li	a1,1
ffffffffc0200ac0:	854e                	mv	a0,s3
ffffffffc0200ac2:	2fd000ef          	jal	ra,ffffffffc02015be <free_pages>
    struct Page *p0 = alloc_pages(5), *p1, *p2;
ffffffffc0200ac6:	4515                	li	a0,5
ffffffffc0200ac8:	2eb000ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0200acc:	892a                	mv	s2,a0
    assert(p0 != NULL);
ffffffffc0200ace:	280502e3          	beqz	a0,ffffffffc0201552 <best_fit_run_checks+0xc42>
    assert(!PageProperty(p0));
ffffffffc0200ad2:	651c                	ld	a5,8(a0)
ffffffffc0200ad4:	8b89                	andi	a5,a5,2
ffffffffc0200ad6:	24079ee3          	bnez	a5,ffffffffc0201532 <best_fit_run_checks+0xc22>
    assert(alloc_page() == NULL);
ffffffffc0200ada:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc0200adc:	000b3a83          	ld	s5,0(s6)
ffffffffc0200ae0:	008b3a03          	ld	s4,8(s6)
ffffffffc0200ae4:	016b3023          	sd	s6,0(s6)
ffffffffc0200ae8:	016b3423          	sd	s6,8(s6)
    assert(alloc_page() == NULL);
ffffffffc0200aec:	2c7000ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0200af0:	220511e3          	bnez	a0,ffffffffc0201512 <best_fit_run_checks+0xc02>
    free_pages(p0 + 1, 2);
ffffffffc0200af4:	4589                	li	a1,2
ffffffffc0200af6:	02890513          	addi	a0,s2,40
    unsigned int nr_free_store = nr_free;
ffffffffc0200afa:	010b2b83          	lw	s7,16(s6)
    free_pages(p0 + 4, 1);
ffffffffc0200afe:	0a090c13          	addi	s8,s2,160
    nr_free = 0;
ffffffffc0200b02:	00006797          	auipc	a5,0x6
ffffffffc0200b06:	5207a323          	sw	zero,1318(a5) # ffffffffc0207028 <free_area+0x10>
    free_pages(p0 + 1, 2);
ffffffffc0200b0a:	2b5000ef          	jal	ra,ffffffffc02015be <free_pages>
    free_pages(p0 + 4, 1);
ffffffffc0200b0e:	8562                	mv	a0,s8
ffffffffc0200b10:	4585                	li	a1,1
ffffffffc0200b12:	2ad000ef          	jal	ra,ffffffffc02015be <free_pages>
    assert(alloc_pages(4) == NULL);
ffffffffc0200b16:	4511                	li	a0,4
ffffffffc0200b18:	29b000ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0200b1c:	1c051be3          	bnez	a0,ffffffffc02014f2 <best_fit_run_checks+0xbe2>
    assert(PageProperty(p0 + 1) && p0[1].property == 2);
ffffffffc0200b20:	03093783          	ld	a5,48(s2)
ffffffffc0200b24:	8b89                	andi	a5,a5,2
ffffffffc0200b26:	1a0786e3          	beqz	a5,ffffffffc02014d2 <best_fit_run_checks+0xbc2>
ffffffffc0200b2a:	03892703          	lw	a4,56(s2)
ffffffffc0200b2e:	4789                	li	a5,2
ffffffffc0200b30:	1af711e3          	bne	a4,a5,ffffffffc02014d2 <best_fit_run_checks+0xbc2>
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc0200b34:	4505                	li	a0,1
ffffffffc0200b36:	27d000ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0200b3a:	89aa                	mv	s3,a0
ffffffffc0200b3c:	16050be3          	beqz	a0,ffffffffc02014b2 <best_fit_run_checks+0xba2>
    assert(alloc_pages(2) != NULL);      // best fit feature
ffffffffc0200b40:	4509                	li	a0,2
ffffffffc0200b42:	271000ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0200b46:	140506e3          	beqz	a0,ffffffffc0201492 <best_fit_run_checks+0xb82>
    assert(p0 + 4 == p1);
ffffffffc0200b4a:	133c14e3          	bne	s8,s3,ffffffffc0201472 <best_fit_run_checks+0xb62>
    free_pages(p0, 5);
ffffffffc0200b4e:	854a                	mv	a0,s2
ffffffffc0200b50:	4595                	li	a1,5
ffffffffc0200b52:	26d000ef          	jal	ra,ffffffffc02015be <free_pages>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc0200b56:	4515                	li	a0,5
ffffffffc0200b58:	25b000ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0200b5c:	892a                	mv	s2,a0
ffffffffc0200b5e:	0e050ae3          	beqz	a0,ffffffffc0201452 <best_fit_run_checks+0xb42>
    assert(alloc_page() == NULL);
ffffffffc0200b62:	4505                	li	a0,1
ffffffffc0200b64:	24f000ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0200b68:	0c0515e3          	bnez	a0,ffffffffc0201432 <best_fit_run_checks+0xb22>
    assert(nr_free == 0);
ffffffffc0200b6c:	010b2783          	lw	a5,16(s6)
ffffffffc0200b70:	0a0791e3          	bnez	a5,ffffffffc0201412 <best_fit_run_checks+0xb02>
    free_pages(p0, 5);
ffffffffc0200b74:	4595                	li	a1,5
ffffffffc0200b76:	854a                	mv	a0,s2
    nr_free = nr_free_store;
ffffffffc0200b78:	017b2823          	sw	s7,16(s6)
    free_list = free_list_store;
ffffffffc0200b7c:	015b3023          	sd	s5,0(s6)
ffffffffc0200b80:	014b3423          	sd	s4,8(s6)
    free_pages(p0, 5);
ffffffffc0200b84:	23b000ef          	jal	ra,ffffffffc02015be <free_pages>
    return listelm->next;
ffffffffc0200b88:	008b3783          	ld	a5,8(s6)
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200b8c:	01678963          	beq	a5,s6,ffffffffc0200b9e <best_fit_run_checks+0x28e>
        count --, total -= p->property;
ffffffffc0200b90:	ff87a703          	lw	a4,-8(a5)
ffffffffc0200b94:	679c                	ld	a5,8(a5)
ffffffffc0200b96:	34fd                	addiw	s1,s1,-1
ffffffffc0200b98:	9c19                	subw	s0,s0,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200b9a:	ff679be3          	bne	a5,s6,ffffffffc0200b90 <best_fit_run_checks+0x280>
    assert(count == 0);
ffffffffc0200b9e:	64049a63          	bnez	s1,ffffffffc02011f2 <best_fit_run_checks+0x8e2>
    assert(total == 0);
ffffffffc0200ba2:	72041863          	bnez	s0,ffffffffc02012d2 <best_fit_run_checks+0x9c2>
    struct Page *arena = best_fit_alloc_pages(64);
ffffffffc0200ba6:	04000513          	li	a0,64
    size_t original = nr_free;
ffffffffc0200baa:	010b2903          	lw	s2,16(s6)
    struct Page *arena = best_fit_alloc_pages(64);
ffffffffc0200bae:	b55ff0ef          	jal	ra,ffffffffc0200702 <best_fit_alloc_pages>
ffffffffc0200bb2:	8baa                	mv	s7,a0
    assert(arena != NULL);
ffffffffc0200bb4:	6e050f63          	beqz	a0,ffffffffc02012b2 <best_fit_run_checks+0x9a2>
    unsigned int saved_count = nr_free;
ffffffffc0200bb8:	010b2483          	lw	s1,16(s6)
    nr_free = 0;
ffffffffc0200bbc:	00006797          	auipc	a5,0x6
ffffffffc0200bc0:	4607a623          	sw	zero,1132(a5) # ffffffffc0207028 <free_area+0x10>
    const size_t starts[] = {0, 16, 32};
ffffffffc0200bc4:	47c1                	li	a5,16
ffffffffc0200bc6:	e43e                	sd	a5,8(sp)
    const size_t sizes[] = {9, 5, 5};
ffffffffc0200bc8:	47a5                	li	a5,9
ffffffffc0200bca:	ec3e                	sd	a5,24(sp)
ffffffffc0200bcc:	4795                	li	a5,5
    list_entry_t saved = free_list;
ffffffffc0200bce:	000b3a03          	ld	s4,0(s6)
ffffffffc0200bd2:	008b3983          	ld	s3,8(s6)
    elm->prev = elm->next = elm;
ffffffffc0200bd6:	016b3023          	sd	s6,0(s6)
ffffffffc0200bda:	016b3423          	sd	s6,8(s6)
    const size_t starts[] = {0, 16, 32};
ffffffffc0200bde:	e002                	sd	zero,0(sp)
    const size_t sizes[] = {9, 5, 5};
ffffffffc0200be0:	f03e                	sd	a5,32(sp)
    for (int k = 2; k >= 0; --k) {
ffffffffc0200be2:	8a8a                	mv	s5,sp
ffffffffc0200be4:	02010c13          	addi	s8,sp,32
ffffffffc0200be8:	fe810413          	addi	s0,sp,-24
    const size_t sizes[] = {9, 5, 5};
ffffffffc0200bec:	4595                	li	a1,5
ffffffffc0200bee:	02000513          	li	a0,32
        for (size_t j = 0; j < sizes[k]; ++j) SetPageReserved(arena + starts[k] + j);
ffffffffc0200bf2:	00251613          	slli	a2,a0,0x2
ffffffffc0200bf6:	c59d                	beqz	a1,ffffffffc0200c24 <best_fit_run_checks+0x314>
ffffffffc0200bf8:	00b50733          	add	a4,a0,a1
ffffffffc0200bfc:	00251613          	slli	a2,a0,0x2
ffffffffc0200c00:	00271693          	slli	a3,a4,0x2
ffffffffc0200c04:	00a607b3          	add	a5,a2,a0
ffffffffc0200c08:	96ba                	add	a3,a3,a4
ffffffffc0200c0a:	078e                	slli	a5,a5,0x3
ffffffffc0200c0c:	068e                	slli	a3,a3,0x3
ffffffffc0200c0e:	97de                	add	a5,a5,s7
ffffffffc0200c10:	96de                	add	a3,a3,s7
ffffffffc0200c12:	6798                	ld	a4,8(a5)
ffffffffc0200c14:	02878793          	addi	a5,a5,40
ffffffffc0200c18:	00176713          	ori	a4,a4,1
ffffffffc0200c1c:	fee7b023          	sd	a4,-32(a5)
ffffffffc0200c20:	fed799e3          	bne	a5,a3,ffffffffc0200c12 <best_fit_run_checks+0x302>
        best_fit_init_memmap(arena + starts[k], sizes[k]);
ffffffffc0200c24:	962a                	add	a2,a2,a0
ffffffffc0200c26:	00361513          	slli	a0,a2,0x3
    for (int k = 2; k >= 0; --k) {
ffffffffc0200c2a:	1ae1                	addi	s5,s5,-8
        best_fit_init_memmap(arena + starts[k], sizes[k]);
ffffffffc0200c2c:	955e                	add	a0,a0,s7
ffffffffc0200c2e:	c4bff0ef          	jal	ra,ffffffffc0200878 <best_fit_init_memmap>
    for (int k = 2; k >= 0; --k) {
ffffffffc0200c32:	008a8863          	beq	s5,s0,ffffffffc0200c42 <best_fit_run_checks+0x332>
        for (size_t j = 0; j < sizes[k]; ++j) SetPageReserved(arena + starts[k] + j);
ffffffffc0200c36:	000c3583          	ld	a1,0(s8) # ff0000 <kern_entry-0xffffffffbf210000>
        best_fit_init_memmap(arena + starts[k], sizes[k]);
ffffffffc0200c3a:	010ab503          	ld	a0,16(s5)
ffffffffc0200c3e:	1c61                	addi	s8,s8,-8
ffffffffc0200c40:	bf4d                	j	ffffffffc0200bf2 <best_fit_run_checks+0x2e2>
    assert(nr_free == 19);
ffffffffc0200c42:	010b2703          	lw	a4,16(s6)
ffffffffc0200c46:	47cd                	li	a5,19
ffffffffc0200c48:	64f71563          	bne	a4,a5,ffffffffc0201292 <best_fit_run_checks+0x982>
    assert(best_fit_alloc_pages(4) == arena + 16); /* equal-size tie: lower address */
ffffffffc0200c4c:	4511                	li	a0,4
ffffffffc0200c4e:	ab5ff0ef          	jal	ra,ffffffffc0200702 <best_fit_alloc_pages>
ffffffffc0200c52:	280b8c13          	addi	s8,s7,640
ffffffffc0200c56:	60ac1e63          	bne	s8,a0,ffffffffc0201272 <best_fit_run_checks+0x962>
    assert(best_fit_alloc_pages(5) == arena + 32); /* exact fit */
ffffffffc0200c5a:	4515                	li	a0,5
ffffffffc0200c5c:	aa7ff0ef          	jal	ra,ffffffffc0200702 <best_fit_alloc_pages>
ffffffffc0200c60:	500b8413          	addi	s0,s7,1280
ffffffffc0200c64:	5ea41763          	bne	s0,a0,ffffffffc0201252 <best_fit_run_checks+0x942>
    assert(best_fit_alloc_pages(6) == arena);
ffffffffc0200c68:	4519                	li	a0,6
ffffffffc0200c6a:	a99ff0ef          	jal	ra,ffffffffc0200702 <best_fit_alloc_pages>
ffffffffc0200c6e:	5cab9263          	bne	s7,a0,ffffffffc0201232 <best_fit_run_checks+0x922>
    assert(nr_free == 4 && best_fit_alloc_pages(4) == NULL);
ffffffffc0200c72:	010b2a83          	lw	s5,16(s6)
ffffffffc0200c76:	4791                	li	a5,4
ffffffffc0200c78:	58fa9d63          	bne	s5,a5,ffffffffc0201212 <best_fit_run_checks+0x902>
ffffffffc0200c7c:	4511                	li	a0,4
ffffffffc0200c7e:	a85ff0ef          	jal	ra,ffffffffc0200702 <best_fit_alloc_pages>
ffffffffc0200c82:	58051863          	bnez	a0,ffffffffc0201212 <best_fit_run_checks+0x902>
    assert(best_fit_alloc_pages((size_t)-1) == NULL && nr_free == 4);
ffffffffc0200c86:	557d                	li	a0,-1
ffffffffc0200c88:	a7bff0ef          	jal	ra,ffffffffc0200702 <best_fit_alloc_pages>
ffffffffc0200c8c:	6e051363          	bnez	a0,ffffffffc0201372 <best_fit_run_checks+0xa62>
ffffffffc0200c90:	010b2783          	lw	a5,16(s6)
ffffffffc0200c94:	6d579f63          	bne	a5,s5,ffffffffc0201372 <best_fit_run_checks+0xa62>
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200c98:	320b8693          	addi	a3,s7,800
ffffffffc0200c9c:	87e2                	mv	a5,s8
ffffffffc0200c9e:	02dc7463          	bgeu	s8,a3,ffffffffc0200cc6 <best_fit_run_checks+0x3b6>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200ca2:	6798                	ld	a4,8(a5)
ffffffffc0200ca4:	8b0d                	andi	a4,a4,3
ffffffffc0200ca6:	32071663          	bnez	a4,ffffffffc0200fd2 <best_fit_run_checks+0x6c2>
        p->flags = 0;
ffffffffc0200caa:	01878713          	addi	a4,a5,24
ffffffffc0200cae:	0007b423          	sd	zero,8(a5)
        p->property = 0;
ffffffffc0200cb2:	0007a823          	sw	zero,16(a5)
static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0200cb6:	0007a023          	sw	zero,0(a5)
ffffffffc0200cba:	f398                	sd	a4,32(a5)
ffffffffc0200cbc:	ef98                	sd	a4,24(a5)
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200cbe:	02878793          	addi	a5,a5,40
ffffffffc0200cc2:	fef690e3          	bne	a3,a5,ffffffffc0200ca2 <best_fit_run_checks+0x392>
    SetPageProperty(base);
ffffffffc0200cc6:	288bb783          	ld	a5,648(s7)
    base->property = n;
ffffffffc0200cca:	4711                	li	a4,4
ffffffffc0200ccc:	28eba823          	sw	a4,656(s7)
    SetPageProperty(base);
ffffffffc0200cd0:	0027e793          	ori	a5,a5,2
ffffffffc0200cd4:	28fbb423          	sd	a5,648(s7)
    best_fit_insert_merge(base);
ffffffffc0200cd8:	8562                	mv	a0,s8
    nr_free += n;
ffffffffc0200cda:	47a1                	li	a5,8
ffffffffc0200cdc:	00fb2823          	sw	a5,16(s6)
    best_fit_insert_merge(base);
ffffffffc0200ce0:	915ff0ef          	jal	ra,ffffffffc02005f4 <best_fit_insert_merge>
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200ce4:	5c8b8693          	addi	a3,s7,1480
ffffffffc0200ce8:	87a2                	mv	a5,s0
ffffffffc0200cea:	02d47463          	bgeu	s0,a3,ffffffffc0200d12 <best_fit_run_checks+0x402>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200cee:	6798                	ld	a4,8(a5)
ffffffffc0200cf0:	8b0d                	andi	a4,a4,3
ffffffffc0200cf2:	2e071063          	bnez	a4,ffffffffc0200fd2 <best_fit_run_checks+0x6c2>
        p->flags = 0;
ffffffffc0200cf6:	01878713          	addi	a4,a5,24
ffffffffc0200cfa:	0007b423          	sd	zero,8(a5)
        p->property = 0;
ffffffffc0200cfe:	0007a823          	sw	zero,16(a5)
ffffffffc0200d02:	0007a023          	sw	zero,0(a5)
ffffffffc0200d06:	f398                	sd	a4,32(a5)
ffffffffc0200d08:	ef98                	sd	a4,24(a5)
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200d0a:	02878793          	addi	a5,a5,40
ffffffffc0200d0e:	fed790e3          	bne	a5,a3,ffffffffc0200cee <best_fit_run_checks+0x3de>
    SetPageProperty(base);
ffffffffc0200d12:	508bb703          	ld	a4,1288(s7)
    nr_free += n;
ffffffffc0200d16:	010b2783          	lw	a5,16(s6)
    base->property = n;
ffffffffc0200d1a:	4695                	li	a3,5
    SetPageProperty(base);
ffffffffc0200d1c:	00276713          	ori	a4,a4,2
    nr_free += n;
ffffffffc0200d20:	2795                	addiw	a5,a5,5
    base->property = n;
ffffffffc0200d22:	50dba823          	sw	a3,1296(s7)
    SetPageProperty(base);
ffffffffc0200d26:	50ebb423          	sd	a4,1288(s7)
    best_fit_insert_merge(base);
ffffffffc0200d2a:	8522                	mv	a0,s0
    nr_free += n;
ffffffffc0200d2c:	00fb2823          	sw	a5,16(s6)
    best_fit_insert_merge(base);
ffffffffc0200d30:	8c5ff0ef          	jal	ra,ffffffffc02005f4 <best_fit_insert_merge>
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200d34:	0f0b8693          	addi	a3,s7,240
ffffffffc0200d38:	87de                	mv	a5,s7
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200d3a:	6798                	ld	a4,8(a5)
ffffffffc0200d3c:	8b0d                	andi	a4,a4,3
ffffffffc0200d3e:	28071a63          	bnez	a4,ffffffffc0200fd2 <best_fit_run_checks+0x6c2>
        p->flags = 0;
ffffffffc0200d42:	01878713          	addi	a4,a5,24
ffffffffc0200d46:	0007b423          	sd	zero,8(a5)
        p->property = 0;
ffffffffc0200d4a:	0007a823          	sw	zero,16(a5)
ffffffffc0200d4e:	0007a023          	sw	zero,0(a5)
ffffffffc0200d52:	f398                	sd	a4,32(a5)
ffffffffc0200d54:	ef98                	sd	a4,24(a5)
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200d56:	02878793          	addi	a5,a5,40
ffffffffc0200d5a:	fed790e3          	bne	a5,a3,ffffffffc0200d3a <best_fit_run_checks+0x42a>
    SetPageProperty(base);
ffffffffc0200d5e:	008bb703          	ld	a4,8(s7)
    nr_free += n;
ffffffffc0200d62:	010b2783          	lw	a5,16(s6)
    base->property = n;
ffffffffc0200d66:	4699                	li	a3,6
    SetPageProperty(base);
ffffffffc0200d68:	00276713          	ori	a4,a4,2
ffffffffc0200d6c:	00ebb423          	sd	a4,8(s7)
    nr_free += n;
ffffffffc0200d70:	2799                	addiw	a5,a5,6
    base->property = n;
ffffffffc0200d72:	00dba823          	sw	a3,16(s7)
    best_fit_insert_merge(base);
ffffffffc0200d76:	855e                	mv	a0,s7
    nr_free += n;
ffffffffc0200d78:	00fb2823          	sw	a5,16(s6)
    best_fit_insert_merge(base);
ffffffffc0200d7c:	879ff0ef          	jal	ra,ffffffffc02005f4 <best_fit_insert_merge>
    assert(nr_free == 19);
ffffffffc0200d80:	010b2703          	lw	a4,16(s6)
ffffffffc0200d84:	47cd                	li	a5,19
ffffffffc0200d86:	58f71663          	bne	a4,a5,ffffffffc0201312 <best_fit_run_checks+0xa02>
ffffffffc0200d8a:	6a85                	lui	s5,0x1
ffffffffc0200d8c:	008b8413          	addi	s0,s7,8
    nr_free = 0;
ffffffffc0200d90:	00006797          	auipc	a5,0x6
ffffffffc0200d94:	2807ac23          	sw	zero,664(a5) # ffffffffc0207028 <free_area+0x10>
ffffffffc0200d98:	a08a8a93          	addi	s5,s5,-1528 # a08 <kern_entry-0xffffffffc01ff5f8>
ffffffffc0200d9c:	016b3423          	sd	s6,8(s6)
ffffffffc0200da0:	016b3023          	sd	s6,0(s6)
    for (unsigned i = 0; i < 64; ++i) {
ffffffffc0200da4:	9ade                	add	s5,s5,s7
    nr_free = 0;
ffffffffc0200da6:	87a2                	mv	a5,s0
        arena[i].flags = 0;
ffffffffc0200da8:	0007b023          	sd	zero,0(a5)
        arena[i].property = 0;
ffffffffc0200dac:	0007a423          	sw	zero,8(a5)
    for (unsigned i = 0; i < 64; ++i) {
ffffffffc0200db0:	02878793          	addi	a5,a5,40
ffffffffc0200db4:	ff579ae3          	bne	a5,s5,ffffffffc0200da8 <best_fit_run_checks+0x498>
    best_fit_free_pages(arena + 8, 4);
ffffffffc0200db8:	140b8d13          	addi	s10,s7,320
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200dbc:	1e0b8c93          	addi	s9,s7,480
ffffffffc0200dc0:	87ea                	mv	a5,s10
ffffffffc0200dc2:	039d7463          	bgeu	s10,s9,ffffffffc0200dea <best_fit_run_checks+0x4da>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200dc6:	6798                	ld	a4,8(a5)
ffffffffc0200dc8:	8b0d                	andi	a4,a4,3
ffffffffc0200dca:	20071463          	bnez	a4,ffffffffc0200fd2 <best_fit_run_checks+0x6c2>
        p->flags = 0;
ffffffffc0200dce:	01878713          	addi	a4,a5,24
ffffffffc0200dd2:	0007b423          	sd	zero,8(a5)
        p->property = 0;
ffffffffc0200dd6:	0007a823          	sw	zero,16(a5)
ffffffffc0200dda:	0007a023          	sw	zero,0(a5)
ffffffffc0200dde:	f398                	sd	a4,32(a5)
ffffffffc0200de0:	ef98                	sd	a4,24(a5)
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200de2:	02878793          	addi	a5,a5,40
ffffffffc0200de6:	fefc90e3          	bne	s9,a5,ffffffffc0200dc6 <best_fit_run_checks+0x4b6>
    SetPageProperty(base);
ffffffffc0200dea:	148bb783          	ld	a5,328(s7)
    base->property = n;
ffffffffc0200dee:	4711                	li	a4,4
ffffffffc0200df0:	14eba823          	sw	a4,336(s7)
    SetPageProperty(base);
ffffffffc0200df4:	0027e793          	ori	a5,a5,2
ffffffffc0200df8:	14fbb423          	sd	a5,328(s7)
    best_fit_insert_merge(base);
ffffffffc0200dfc:	856a                	mv	a0,s10
    nr_free += n;
ffffffffc0200dfe:	00eb2823          	sw	a4,16(s6)
    best_fit_insert_merge(base);
ffffffffc0200e02:	ff2ff0ef          	jal	ra,ffffffffc02005f4 <best_fit_insert_merge>
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200e06:	0a0b8d93          	addi	s11,s7,160
ffffffffc0200e0a:	87de                	mv	a5,s7
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200e0c:	6798                	ld	a4,8(a5)
ffffffffc0200e0e:	8b0d                	andi	a4,a4,3
ffffffffc0200e10:	1c071163          	bnez	a4,ffffffffc0200fd2 <best_fit_run_checks+0x6c2>
        p->flags = 0;
ffffffffc0200e14:	01878713          	addi	a4,a5,24
ffffffffc0200e18:	0007b423          	sd	zero,8(a5)
        p->property = 0;
ffffffffc0200e1c:	0007a823          	sw	zero,16(a5)
ffffffffc0200e20:	0007a023          	sw	zero,0(a5)
ffffffffc0200e24:	f398                	sd	a4,32(a5)
ffffffffc0200e26:	ef98                	sd	a4,24(a5)
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200e28:	02878793          	addi	a5,a5,40
ffffffffc0200e2c:	fefd90e3          	bne	s11,a5,ffffffffc0200e0c <best_fit_run_checks+0x4fc>
    SetPageProperty(base);
ffffffffc0200e30:	008bb703          	ld	a4,8(s7)
    nr_free += n;
ffffffffc0200e34:	010b2783          	lw	a5,16(s6)
    base->property = n;
ffffffffc0200e38:	4691                	li	a3,4
    SetPageProperty(base);
ffffffffc0200e3a:	00276713          	ori	a4,a4,2
    nr_free += n;
ffffffffc0200e3e:	2791                	addiw	a5,a5,4
    base->property = n;
ffffffffc0200e40:	00dba823          	sw	a3,16(s7)
    SetPageProperty(base);
ffffffffc0200e44:	00ebb423          	sd	a4,8(s7)
    best_fit_insert_merge(base);
ffffffffc0200e48:	855e                	mv	a0,s7
    nr_free += n;
ffffffffc0200e4a:	00fb2823          	sw	a5,16(s6)
    best_fit_insert_merge(base);
ffffffffc0200e4e:	fa6ff0ef          	jal	ra,ffffffffc02005f4 <best_fit_insert_merge>
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200e52:	87ee                	mv	a5,s11
ffffffffc0200e54:	03adf463          	bgeu	s11,s10,ffffffffc0200e7c <best_fit_run_checks+0x56c>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200e58:	6798                	ld	a4,8(a5)
ffffffffc0200e5a:	8b0d                	andi	a4,a4,3
ffffffffc0200e5c:	16071b63          	bnez	a4,ffffffffc0200fd2 <best_fit_run_checks+0x6c2>
        p->flags = 0;
ffffffffc0200e60:	01878713          	addi	a4,a5,24
ffffffffc0200e64:	0007b423          	sd	zero,8(a5)
        p->property = 0;
ffffffffc0200e68:	0007a823          	sw	zero,16(a5)
ffffffffc0200e6c:	0007a023          	sw	zero,0(a5)
ffffffffc0200e70:	f398                	sd	a4,32(a5)
ffffffffc0200e72:	ef98                	sd	a4,24(a5)
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200e74:	02878793          	addi	a5,a5,40
ffffffffc0200e78:	fefd10e3          	bne	s10,a5,ffffffffc0200e58 <best_fit_run_checks+0x548>
    SetPageProperty(base);
ffffffffc0200e7c:	0a8bb703          	ld	a4,168(s7)
    nr_free += n;
ffffffffc0200e80:	010b2783          	lw	a5,16(s6)
    base->property = n;
ffffffffc0200e84:	4691                	li	a3,4
    SetPageProperty(base);
ffffffffc0200e86:	00276713          	ori	a4,a4,2
    nr_free += n;
ffffffffc0200e8a:	2791                	addiw	a5,a5,4
    SetPageProperty(base);
ffffffffc0200e8c:	0aebb423          	sd	a4,168(s7)
    base->property = n;
ffffffffc0200e90:	0adba823          	sw	a3,176(s7)
    best_fit_insert_merge(base);
ffffffffc0200e94:	856e                	mv	a0,s11
    nr_free += n;
ffffffffc0200e96:	00fb2823          	sw	a5,16(s6)
    best_fit_insert_merge(base);
ffffffffc0200e9a:	f5aff0ef          	jal	ra,ffffffffc02005f4 <best_fit_insert_merge>
    assert(arena->property == 12 && nr_free == 12);
ffffffffc0200e9e:	010ba783          	lw	a5,16(s7)
ffffffffc0200ea2:	4731                	li	a4,12
ffffffffc0200ea4:	4ae79763          	bne	a5,a4,ffffffffc0201352 <best_fit_run_checks+0xa42>
ffffffffc0200ea8:	010b2703          	lw	a4,16(s6)
ffffffffc0200eac:	4af71363          	bne	a4,a5,ffffffffc0201352 <best_fit_run_checks+0xa42>
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200eb0:	87e6                	mv	a5,s9
ffffffffc0200eb2:	038cf463          	bgeu	s9,s8,ffffffffc0200eda <best_fit_run_checks+0x5ca>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200eb6:	6798                	ld	a4,8(a5)
ffffffffc0200eb8:	8b0d                	andi	a4,a4,3
ffffffffc0200eba:	10071c63          	bnez	a4,ffffffffc0200fd2 <best_fit_run_checks+0x6c2>
        p->flags = 0;
ffffffffc0200ebe:	01878713          	addi	a4,a5,24
ffffffffc0200ec2:	0007b423          	sd	zero,8(a5)
        p->property = 0;
ffffffffc0200ec6:	0007a823          	sw	zero,16(a5)
ffffffffc0200eca:	0007a023          	sw	zero,0(a5)
ffffffffc0200ece:	f398                	sd	a4,32(a5)
ffffffffc0200ed0:	ef98                	sd	a4,24(a5)
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200ed2:	02878793          	addi	a5,a5,40
ffffffffc0200ed6:	fefc10e3          	bne	s8,a5,ffffffffc0200eb6 <best_fit_run_checks+0x5a6>
    SetPageProperty(base);
ffffffffc0200eda:	1e8bb783          	ld	a5,488(s7)
    base->property = n;
ffffffffc0200ede:	4711                	li	a4,4
ffffffffc0200ee0:	1eeba823          	sw	a4,496(s7)
    SetPageProperty(base);
ffffffffc0200ee4:	0027e793          	ori	a5,a5,2
ffffffffc0200ee8:	1efbb423          	sd	a5,488(s7)
    nr_free += n;
ffffffffc0200eec:	4c41                	li	s8,16
    best_fit_insert_merge(base);
ffffffffc0200eee:	8566                	mv	a0,s9
    nr_free += n;
ffffffffc0200ef0:	018b2823          	sw	s8,16(s6)
    best_fit_insert_merge(base);
ffffffffc0200ef4:	f00ff0ef          	jal	ra,ffffffffc02005f4 <best_fit_insert_merge>
    assert(arena->property == 16 && nr_free == 16);
ffffffffc0200ef8:	010ba783          	lw	a5,16(s7)
ffffffffc0200efc:	43879b63          	bne	a5,s8,ffffffffc0201332 <best_fit_run_checks+0xa22>
ffffffffc0200f00:	010b2703          	lw	a4,16(s6)
ffffffffc0200f04:	42f71763          	bne	a4,a5,ffffffffc0201332 <best_fit_run_checks+0xa22>
    assert(best_fit_alloc_pages(16) == arena && nr_free == 0);
ffffffffc0200f08:	4541                	li	a0,16
ffffffffc0200f0a:	ff8ff0ef          	jal	ra,ffffffffc0200702 <best_fit_alloc_pages>
ffffffffc0200f0e:	10ab9263          	bne	s7,a0,ffffffffc0201012 <best_fit_run_checks+0x702>
ffffffffc0200f12:	010b2783          	lw	a5,16(s6)
ffffffffc0200f16:	0e079e63          	bnez	a5,ffffffffc0201012 <best_fit_run_checks+0x702>
    assert(best_fit_alloc_pages(1) == NULL);
ffffffffc0200f1a:	4505                	li	a0,1
ffffffffc0200f1c:	fe6ff0ef          	jal	ra,ffffffffc0200702 <best_fit_alloc_pages>
ffffffffc0200f20:	3c051963          	bnez	a0,ffffffffc02012f2 <best_fit_run_checks+0x9e2>
        arena[i].flags = 0;
ffffffffc0200f24:	00043023          	sd	zero,0(s0)
        arena[i].property = 0;
ffffffffc0200f28:	00042423          	sw	zero,8(s0)
    for (unsigned i = 0; i < 64; ++i) {
ffffffffc0200f2c:	02840413          	addi	s0,s0,40
ffffffffc0200f30:	ff541ae3          	bne	s0,s5,ffffffffc0200f24 <best_fit_run_checks+0x614>
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200f34:	6685                	lui	a3,0x1
ffffffffc0200f36:	a0068693          	addi	a3,a3,-1536 # a00 <kern_entry-0xffffffffc01ff600>
    free_list = saved;
ffffffffc0200f3a:	014b3023          	sd	s4,0(s6)
ffffffffc0200f3e:	013b3423          	sd	s3,8(s6)
    nr_free = saved_count;
ffffffffc0200f42:	009b2823          	sw	s1,16(s6)
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200f46:	96de                	add	a3,a3,s7
ffffffffc0200f48:	87de                	mv	a5,s7
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200f4a:	6798                	ld	a4,8(a5)
ffffffffc0200f4c:	8b0d                	andi	a4,a4,3
ffffffffc0200f4e:	e351                	bnez	a4,ffffffffc0200fd2 <best_fit_run_checks+0x6c2>
        p->flags = 0;
ffffffffc0200f50:	01878713          	addi	a4,a5,24
ffffffffc0200f54:	0007b423          	sd	zero,8(a5)
        p->property = 0;
ffffffffc0200f58:	0007a823          	sw	zero,16(a5)
ffffffffc0200f5c:	0007a023          	sw	zero,0(a5)
ffffffffc0200f60:	f398                	sd	a4,32(a5)
ffffffffc0200f62:	ef98                	sd	a4,24(a5)
    for (struct Page *p = base; p < base + n; ++p) {
ffffffffc0200f64:	02878793          	addi	a5,a5,40
ffffffffc0200f68:	fef691e3          	bne	a3,a5,ffffffffc0200f4a <best_fit_run_checks+0x63a>
    SetPageProperty(base);
ffffffffc0200f6c:	008bb783          	ld	a5,8(s7)
    base->property = n;
ffffffffc0200f70:	04000713          	li	a4,64
ffffffffc0200f74:	00eba823          	sw	a4,16(s7)
    SetPageProperty(base);
ffffffffc0200f78:	0027e793          	ori	a5,a5,2
ffffffffc0200f7c:	00fbb423          	sd	a5,8(s7)
    nr_free += n;
ffffffffc0200f80:	0404849b          	addiw	s1,s1,64
    best_fit_insert_merge(base);
ffffffffc0200f84:	855e                	mv	a0,s7
    nr_free += n;
ffffffffc0200f86:	009b2823          	sw	s1,16(s6)
    best_fit_insert_merge(base);
ffffffffc0200f8a:	e6aff0ef          	jal	ra,ffffffffc02005f4 <best_fit_insert_merge>
    assert(nr_free == original);
ffffffffc0200f8e:	010b2783          	lw	a5,16(s6)
ffffffffc0200f92:	43279063          	bne	a5,s2,ffffffffc02013b2 <best_fit_run_checks+0xaa2>
    cprintf("Best-Fit: minimum choice, tie, split, bridge merge, failure PASS\n");
ffffffffc0200f96:	00002517          	auipc	a0,0x2
ffffffffc0200f9a:	f4250513          	addi	a0,a0,-190 # ffffffffc0202ed8 <etext+0x790>
ffffffffc0200f9e:	9b6ff0ef          	jal	ra,ffffffffc0200154 <cprintf>
    best_fit_check();
    best_fit_extra_check();
    cprintf("Best-Fit: original and additional checks passed\n");
}
ffffffffc0200fa2:	644a                	ld	s0,144(sp)
ffffffffc0200fa4:	60ea                	ld	ra,152(sp)
ffffffffc0200fa6:	64aa                	ld	s1,136(sp)
ffffffffc0200fa8:	690a                	ld	s2,128(sp)
ffffffffc0200faa:	79e6                	ld	s3,120(sp)
ffffffffc0200fac:	7a46                	ld	s4,112(sp)
ffffffffc0200fae:	7aa6                	ld	s5,104(sp)
ffffffffc0200fb0:	7b06                	ld	s6,96(sp)
ffffffffc0200fb2:	6be6                	ld	s7,88(sp)
ffffffffc0200fb4:	6c46                	ld	s8,80(sp)
ffffffffc0200fb6:	6ca6                	ld	s9,72(sp)
ffffffffc0200fb8:	6d06                	ld	s10,64(sp)
ffffffffc0200fba:	7de2                	ld	s11,56(sp)
    cprintf("Best-Fit: original and additional checks passed\n");
ffffffffc0200fbc:	00002517          	auipc	a0,0x2
ffffffffc0200fc0:	f6450513          	addi	a0,a0,-156 # ffffffffc0202f20 <etext+0x7d8>
}
ffffffffc0200fc4:	610d                	addi	sp,sp,160
    cprintf("Best-Fit: original and additional checks passed\n");
ffffffffc0200fc6:	98eff06f          	j	ffffffffc0200154 <cprintf>
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200fca:	4901                	li	s2,0
    int count = 0, total = 0;
ffffffffc0200fcc:	4401                	li	s0,0
ffffffffc0200fce:	4481                	li	s1,0
ffffffffc0200fd0:	b269                	j	ffffffffc020095a <best_fit_run_checks+0x4a>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200fd2:	00002697          	auipc	a3,0x2
ffffffffc0200fd6:	a4668693          	addi	a3,a3,-1466 # ffffffffc0202a18 <etext+0x2d0>
ffffffffc0200fda:	00002617          	auipc	a2,0x2
ffffffffc0200fde:	9e660613          	addi	a2,a2,-1562 # ffffffffc02029c0 <etext+0x278>
ffffffffc0200fe2:	05e00593          	li	a1,94
ffffffffc0200fe6:	00002517          	auipc	a0,0x2
ffffffffc0200fea:	9f250513          	addi	a0,a0,-1550 # ffffffffc02029d8 <etext+0x290>
ffffffffc0200fee:	9dcff0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert(PageProperty(p));
ffffffffc0200ff2:	00002697          	auipc	a3,0x2
ffffffffc0200ff6:	a5e68693          	addi	a3,a3,-1442 # ffffffffc0202a50 <etext+0x308>
ffffffffc0200ffa:	00002617          	auipc	a2,0x2
ffffffffc0200ffe:	9c660613          	addi	a2,a2,-1594 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201002:	0aa00593          	li	a1,170
ffffffffc0201006:	00002517          	auipc	a0,0x2
ffffffffc020100a:	9d250513          	addi	a0,a0,-1582 # ffffffffc02029d8 <etext+0x290>
ffffffffc020100e:	9bcff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(best_fit_alloc_pages(16) == arena && nr_free == 0);
ffffffffc0201012:	00002697          	auipc	a3,0x2
ffffffffc0201016:	e5668693          	addi	a3,a3,-426 # ffffffffc0202e68 <etext+0x720>
ffffffffc020101a:	00002617          	auipc	a2,0x2
ffffffffc020101e:	9a660613          	addi	a2,a2,-1626 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201022:	11a00593          	li	a1,282
ffffffffc0201026:	00002517          	auipc	a0,0x2
ffffffffc020102a:	9b250513          	addi	a0,a0,-1614 # ffffffffc02029d8 <etext+0x290>
ffffffffc020102e:	99cff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0201032:	00002697          	auipc	a3,0x2
ffffffffc0201036:	a6e68693          	addi	a3,a3,-1426 # ffffffffc0202aa0 <etext+0x358>
ffffffffc020103a:	00002617          	auipc	a2,0x2
ffffffffc020103e:	98660613          	addi	a2,a2,-1658 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201042:	07300593          	li	a1,115
ffffffffc0201046:	00002517          	auipc	a0,0x2
ffffffffc020104a:	99250513          	addi	a0,a0,-1646 # ffffffffc02029d8 <etext+0x290>
ffffffffc020104e:	97cff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0201052:	00002697          	auipc	a3,0x2
ffffffffc0201056:	a2e68693          	addi	a3,a3,-1490 # ffffffffc0202a80 <etext+0x338>
ffffffffc020105a:	00002617          	auipc	a2,0x2
ffffffffc020105e:	96660613          	addi	a2,a2,-1690 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201062:	07200593          	li	a1,114
ffffffffc0201066:	00002517          	auipc	a0,0x2
ffffffffc020106a:	97250513          	addi	a0,a0,-1678 # ffffffffc02029d8 <etext+0x290>
ffffffffc020106e:	95cff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc0201072:	00002697          	auipc	a3,0x2
ffffffffc0201076:	ad668693          	addi	a3,a3,-1322 # ffffffffc0202b48 <etext+0x400>
ffffffffc020107a:	00002617          	auipc	a2,0x2
ffffffffc020107e:	94660613          	addi	a2,a2,-1722 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201082:	07900593          	li	a1,121
ffffffffc0201086:	00002517          	auipc	a0,0x2
ffffffffc020108a:	95250513          	addi	a0,a0,-1710 # ffffffffc02029d8 <etext+0x290>
ffffffffc020108e:	93cff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0201092:	00002697          	auipc	a3,0x2
ffffffffc0201096:	a7668693          	addi	a3,a3,-1418 # ffffffffc0202b08 <etext+0x3c0>
ffffffffc020109a:	00002617          	auipc	a2,0x2
ffffffffc020109e:	92660613          	addi	a2,a2,-1754 # ffffffffc02029c0 <etext+0x278>
ffffffffc02010a2:	07700593          	li	a1,119
ffffffffc02010a6:	00002517          	auipc	a0,0x2
ffffffffc02010aa:	93250513          	addi	a0,a0,-1742 # ffffffffc02029d8 <etext+0x290>
ffffffffc02010ae:	91cff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc02010b2:	00002697          	auipc	a3,0x2
ffffffffc02010b6:	a2e68693          	addi	a3,a3,-1490 # ffffffffc0202ae0 <etext+0x398>
ffffffffc02010ba:	00002617          	auipc	a2,0x2
ffffffffc02010be:	90660613          	addi	a2,a2,-1786 # ffffffffc02029c0 <etext+0x278>
ffffffffc02010c2:	07600593          	li	a1,118
ffffffffc02010c6:	00002517          	auipc	a0,0x2
ffffffffc02010ca:	91250513          	addi	a0,a0,-1774 # ffffffffc02029d8 <etext+0x290>
ffffffffc02010ce:	8fcff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc02010d2:	00002697          	auipc	a3,0x2
ffffffffc02010d6:	9ee68693          	addi	a3,a3,-1554 # ffffffffc0202ac0 <etext+0x378>
ffffffffc02010da:	00002617          	auipc	a2,0x2
ffffffffc02010de:	8e660613          	addi	a2,a2,-1818 # ffffffffc02029c0 <etext+0x278>
ffffffffc02010e2:	07400593          	li	a1,116
ffffffffc02010e6:	00002517          	auipc	a0,0x2
ffffffffc02010ea:	8f250513          	addi	a0,a0,-1806 # ffffffffc02029d8 <etext+0x290>
ffffffffc02010ee:	8dcff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(alloc_page() == NULL);
ffffffffc02010f2:	00002697          	auipc	a3,0x2
ffffffffc02010f6:	ab668693          	addi	a3,a3,-1354 # ffffffffc0202ba8 <etext+0x460>
ffffffffc02010fa:	00002617          	auipc	a2,0x2
ffffffffc02010fe:	8c660613          	addi	a2,a2,-1850 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201102:	08f00593          	li	a1,143
ffffffffc0201106:	00002517          	auipc	a0,0x2
ffffffffc020110a:	8d250513          	addi	a0,a0,-1838 # ffffffffc02029d8 <etext+0x290>
ffffffffc020110e:	8bcff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0201112:	00002697          	auipc	a3,0x2
ffffffffc0201116:	9ae68693          	addi	a3,a3,-1618 # ffffffffc0202ac0 <etext+0x378>
ffffffffc020111a:	00002617          	auipc	a2,0x2
ffffffffc020111e:	8a660613          	addi	a2,a2,-1882 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201122:	08d00593          	li	a1,141
ffffffffc0201126:	00002517          	auipc	a0,0x2
ffffffffc020112a:	8b250513          	addi	a0,a0,-1870 # ffffffffc02029d8 <etext+0x290>
ffffffffc020112e:	89cff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0201132:	00002697          	auipc	a3,0x2
ffffffffc0201136:	96e68693          	addi	a3,a3,-1682 # ffffffffc0202aa0 <etext+0x358>
ffffffffc020113a:	00002617          	auipc	a2,0x2
ffffffffc020113e:	88660613          	addi	a2,a2,-1914 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201142:	08c00593          	li	a1,140
ffffffffc0201146:	00002517          	auipc	a0,0x2
ffffffffc020114a:	89250513          	addi	a0,a0,-1902 # ffffffffc02029d8 <etext+0x290>
ffffffffc020114e:	87cff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0201152:	00002697          	auipc	a3,0x2
ffffffffc0201156:	92e68693          	addi	a3,a3,-1746 # ffffffffc0202a80 <etext+0x338>
ffffffffc020115a:	00002617          	auipc	a2,0x2
ffffffffc020115e:	86660613          	addi	a2,a2,-1946 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201162:	08b00593          	li	a1,139
ffffffffc0201166:	00002517          	auipc	a0,0x2
ffffffffc020116a:	87250513          	addi	a0,a0,-1934 # ffffffffc02029d8 <etext+0x290>
ffffffffc020116e:	85cff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free == 3);
ffffffffc0201172:	00002697          	auipc	a3,0x2
ffffffffc0201176:	a4e68693          	addi	a3,a3,-1458 # ffffffffc0202bc0 <etext+0x478>
ffffffffc020117a:	00002617          	auipc	a2,0x2
ffffffffc020117e:	84660613          	addi	a2,a2,-1978 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201182:	08900593          	li	a1,137
ffffffffc0201186:	00002517          	auipc	a0,0x2
ffffffffc020118a:	85250513          	addi	a0,a0,-1966 # ffffffffc02029d8 <etext+0x290>
ffffffffc020118e:	83cff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(alloc_page() == NULL);
ffffffffc0201192:	00002697          	auipc	a3,0x2
ffffffffc0201196:	a1668693          	addi	a3,a3,-1514 # ffffffffc0202ba8 <etext+0x460>
ffffffffc020119a:	00002617          	auipc	a2,0x2
ffffffffc020119e:	82660613          	addi	a2,a2,-2010 # ffffffffc02029c0 <etext+0x278>
ffffffffc02011a2:	08400593          	li	a1,132
ffffffffc02011a6:	00002517          	auipc	a0,0x2
ffffffffc02011aa:	83250513          	addi	a0,a0,-1998 # ffffffffc02029d8 <etext+0x290>
ffffffffc02011ae:	81cff0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc02011b2:	00002697          	auipc	a3,0x2
ffffffffc02011b6:	9d668693          	addi	a3,a3,-1578 # ffffffffc0202b88 <etext+0x440>
ffffffffc02011ba:	00002617          	auipc	a2,0x2
ffffffffc02011be:	80660613          	addi	a2,a2,-2042 # ffffffffc02029c0 <etext+0x278>
ffffffffc02011c2:	07b00593          	li	a1,123
ffffffffc02011c6:	00002517          	auipc	a0,0x2
ffffffffc02011ca:	81250513          	addi	a0,a0,-2030 # ffffffffc02029d8 <etext+0x290>
ffffffffc02011ce:	ffdfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc02011d2:	00002697          	auipc	a3,0x2
ffffffffc02011d6:	99668693          	addi	a3,a3,-1642 # ffffffffc0202b68 <etext+0x420>
ffffffffc02011da:	00001617          	auipc	a2,0x1
ffffffffc02011de:	7e660613          	addi	a2,a2,2022 # ffffffffc02029c0 <etext+0x278>
ffffffffc02011e2:	07a00593          	li	a1,122
ffffffffc02011e6:	00001517          	auipc	a0,0x1
ffffffffc02011ea:	7f250513          	addi	a0,a0,2034 # ffffffffc02029d8 <etext+0x290>
ffffffffc02011ee:	fddfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(count == 0);
ffffffffc02011f2:	00002697          	auipc	a3,0x2
ffffffffc02011f6:	afe68693          	addi	a3,a3,-1282 # ffffffffc0202cf0 <etext+0x5a8>
ffffffffc02011fa:	00001617          	auipc	a2,0x1
ffffffffc02011fe:	7c660613          	addi	a2,a2,1990 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201202:	0eb00593          	li	a1,235
ffffffffc0201206:	00001517          	auipc	a0,0x1
ffffffffc020120a:	7d250513          	addi	a0,a0,2002 # ffffffffc02029d8 <etext+0x290>
ffffffffc020120e:	fbdfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free == 4 && best_fit_alloc_pages(4) == NULL);
ffffffffc0201212:	00002697          	auipc	a3,0x2
ffffffffc0201216:	b9668693          	addi	a3,a3,-1130 # ffffffffc0202da8 <etext+0x660>
ffffffffc020121a:	00001617          	auipc	a2,0x1
ffffffffc020121e:	7a660613          	addi	a2,a2,1958 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201222:	10700593          	li	a1,263
ffffffffc0201226:	00001517          	auipc	a0,0x1
ffffffffc020122a:	7b250513          	addi	a0,a0,1970 # ffffffffc02029d8 <etext+0x290>
ffffffffc020122e:	f9dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(best_fit_alloc_pages(6) == arena);
ffffffffc0201232:	00002697          	auipc	a3,0x2
ffffffffc0201236:	b4e68693          	addi	a3,a3,-1202 # ffffffffc0202d80 <etext+0x638>
ffffffffc020123a:	00001617          	auipc	a2,0x1
ffffffffc020123e:	78660613          	addi	a2,a2,1926 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201242:	10600593          	li	a1,262
ffffffffc0201246:	00001517          	auipc	a0,0x1
ffffffffc020124a:	79250513          	addi	a0,a0,1938 # ffffffffc02029d8 <etext+0x290>
ffffffffc020124e:	f7dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(best_fit_alloc_pages(5) == arena + 32); /* exact fit */
ffffffffc0201252:	00002697          	auipc	a3,0x2
ffffffffc0201256:	b0668693          	addi	a3,a3,-1274 # ffffffffc0202d58 <etext+0x610>
ffffffffc020125a:	00001617          	auipc	a2,0x1
ffffffffc020125e:	76660613          	addi	a2,a2,1894 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201262:	10500593          	li	a1,261
ffffffffc0201266:	00001517          	auipc	a0,0x1
ffffffffc020126a:	77250513          	addi	a0,a0,1906 # ffffffffc02029d8 <etext+0x290>
ffffffffc020126e:	f5dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(best_fit_alloc_pages(4) == arena + 16); /* equal-size tie: lower address */
ffffffffc0201272:	00002697          	auipc	a3,0x2
ffffffffc0201276:	abe68693          	addi	a3,a3,-1346 # ffffffffc0202d30 <etext+0x5e8>
ffffffffc020127a:	00001617          	auipc	a2,0x1
ffffffffc020127e:	74660613          	addi	a2,a2,1862 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201282:	10400593          	li	a1,260
ffffffffc0201286:	00001517          	auipc	a0,0x1
ffffffffc020128a:	75250513          	addi	a0,a0,1874 # ffffffffc02029d8 <etext+0x290>
ffffffffc020128e:	f3dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free == 19);
ffffffffc0201292:	00002697          	auipc	a3,0x2
ffffffffc0201296:	a8e68693          	addi	a3,a3,-1394 # ffffffffc0202d20 <etext+0x5d8>
ffffffffc020129a:	00001617          	auipc	a2,0x1
ffffffffc020129e:	72660613          	addi	a2,a2,1830 # ffffffffc02029c0 <etext+0x278>
ffffffffc02012a2:	10300593          	li	a1,259
ffffffffc02012a6:	00001517          	auipc	a0,0x1
ffffffffc02012aa:	73250513          	addi	a0,a0,1842 # ffffffffc02029d8 <etext+0x290>
ffffffffc02012ae:	f1dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(arena != NULL);
ffffffffc02012b2:	00002697          	auipc	a3,0x2
ffffffffc02012b6:	a5e68693          	addi	a3,a3,-1442 # ffffffffc0202d10 <etext+0x5c8>
ffffffffc02012ba:	00001617          	auipc	a2,0x1
ffffffffc02012be:	70660613          	addi	a2,a2,1798 # ffffffffc02029c0 <etext+0x278>
ffffffffc02012c2:	0f700593          	li	a1,247
ffffffffc02012c6:	00001517          	auipc	a0,0x1
ffffffffc02012ca:	71250513          	addi	a0,a0,1810 # ffffffffc02029d8 <etext+0x290>
ffffffffc02012ce:	efdfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(total == 0);
ffffffffc02012d2:	00002697          	auipc	a3,0x2
ffffffffc02012d6:	a2e68693          	addi	a3,a3,-1490 # ffffffffc0202d00 <etext+0x5b8>
ffffffffc02012da:	00001617          	auipc	a2,0x1
ffffffffc02012de:	6e660613          	addi	a2,a2,1766 # ffffffffc02029c0 <etext+0x278>
ffffffffc02012e2:	0ec00593          	li	a1,236
ffffffffc02012e6:	00001517          	auipc	a0,0x1
ffffffffc02012ea:	6f250513          	addi	a0,a0,1778 # ffffffffc02029d8 <etext+0x290>
ffffffffc02012ee:	eddfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(best_fit_alloc_pages(1) == NULL);
ffffffffc02012f2:	00002697          	auipc	a3,0x2
ffffffffc02012f6:	bae68693          	addi	a3,a3,-1106 # ffffffffc0202ea0 <etext+0x758>
ffffffffc02012fa:	00001617          	auipc	a2,0x1
ffffffffc02012fe:	6c660613          	addi	a2,a2,1734 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201302:	11b00593          	li	a1,283
ffffffffc0201306:	00001517          	auipc	a0,0x1
ffffffffc020130a:	6d250513          	addi	a0,a0,1746 # ffffffffc02029d8 <etext+0x290>
ffffffffc020130e:	ebdfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free == 19);
ffffffffc0201312:	00002697          	auipc	a3,0x2
ffffffffc0201316:	a0e68693          	addi	a3,a3,-1522 # ffffffffc0202d20 <etext+0x5d8>
ffffffffc020131a:	00001617          	auipc	a2,0x1
ffffffffc020131e:	6a660613          	addi	a2,a2,1702 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201322:	10c00593          	li	a1,268
ffffffffc0201326:	00001517          	auipc	a0,0x1
ffffffffc020132a:	6b250513          	addi	a0,a0,1714 # ffffffffc02029d8 <etext+0x290>
ffffffffc020132e:	e9dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(arena->property == 16 && nr_free == 16);
ffffffffc0201332:	00002697          	auipc	a3,0x2
ffffffffc0201336:	b0e68693          	addi	a3,a3,-1266 # ffffffffc0202e40 <etext+0x6f8>
ffffffffc020133a:	00001617          	auipc	a2,0x1
ffffffffc020133e:	68660613          	addi	a2,a2,1670 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201342:	11900593          	li	a1,281
ffffffffc0201346:	00001517          	auipc	a0,0x1
ffffffffc020134a:	69250513          	addi	a0,a0,1682 # ffffffffc02029d8 <etext+0x290>
ffffffffc020134e:	e7dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(arena->property == 12 && nr_free == 12);
ffffffffc0201352:	00002697          	auipc	a3,0x2
ffffffffc0201356:	ac668693          	addi	a3,a3,-1338 # ffffffffc0202e18 <etext+0x6d0>
ffffffffc020135a:	00001617          	auipc	a2,0x1
ffffffffc020135e:	66660613          	addi	a2,a2,1638 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201362:	11700593          	li	a1,279
ffffffffc0201366:	00001517          	auipc	a0,0x1
ffffffffc020136a:	67250513          	addi	a0,a0,1650 # ffffffffc02029d8 <etext+0x290>
ffffffffc020136e:	e5dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(best_fit_alloc_pages((size_t)-1) == NULL && nr_free == 4);
ffffffffc0201372:	00002697          	auipc	a3,0x2
ffffffffc0201376:	a6668693          	addi	a3,a3,-1434 # ffffffffc0202dd8 <etext+0x690>
ffffffffc020137a:	00001617          	auipc	a2,0x1
ffffffffc020137e:	64660613          	addi	a2,a2,1606 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201382:	10800593          	li	a1,264
ffffffffc0201386:	00001517          	auipc	a0,0x1
ffffffffc020138a:	65250513          	addi	a0,a0,1618 # ffffffffc02029d8 <etext+0x290>
ffffffffc020138e:	e3dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(total == nr_free_pages());
ffffffffc0201392:	00001697          	auipc	a3,0x1
ffffffffc0201396:	6ce68693          	addi	a3,a3,1742 # ffffffffc0202a60 <etext+0x318>
ffffffffc020139a:	00001617          	auipc	a2,0x1
ffffffffc020139e:	62660613          	addi	a2,a2,1574 # ffffffffc02029c0 <etext+0x278>
ffffffffc02013a2:	0ad00593          	li	a1,173
ffffffffc02013a6:	00001517          	auipc	a0,0x1
ffffffffc02013aa:	63250513          	addi	a0,a0,1586 # ffffffffc02029d8 <etext+0x290>
ffffffffc02013ae:	e1dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free == original);
ffffffffc02013b2:	00002697          	auipc	a3,0x2
ffffffffc02013b6:	b0e68693          	addi	a3,a3,-1266 # ffffffffc0202ec0 <etext+0x778>
ffffffffc02013ba:	00001617          	auipc	a2,0x1
ffffffffc02013be:	60660613          	addi	a2,a2,1542 # ffffffffc02029c0 <etext+0x278>
ffffffffc02013c2:	12300593          	li	a1,291
ffffffffc02013c6:	00001517          	auipc	a0,0x1
ffffffffc02013ca:	61250513          	addi	a0,a0,1554 # ffffffffc02029d8 <etext+0x290>
ffffffffc02013ce:	dfdfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(alloc_page() == NULL);
ffffffffc02013d2:	00001697          	auipc	a3,0x1
ffffffffc02013d6:	7d668693          	addi	a3,a3,2006 # ffffffffc0202ba8 <etext+0x460>
ffffffffc02013da:	00001617          	auipc	a2,0x1
ffffffffc02013de:	5e660613          	addi	a2,a2,1510 # ffffffffc02029c0 <etext+0x278>
ffffffffc02013e2:	09600593          	li	a1,150
ffffffffc02013e6:	00001517          	auipc	a0,0x1
ffffffffc02013ea:	5f250513          	addi	a0,a0,1522 # ffffffffc02029d8 <etext+0x290>
ffffffffc02013ee:	dddfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((p = alloc_page()) == p0);
ffffffffc02013f2:	00001697          	auipc	a3,0x1
ffffffffc02013f6:	7f668693          	addi	a3,a3,2038 # ffffffffc0202be8 <etext+0x4a0>
ffffffffc02013fa:	00001617          	auipc	a2,0x1
ffffffffc02013fe:	5c660613          	addi	a2,a2,1478 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201402:	09500593          	li	a1,149
ffffffffc0201406:	00001517          	auipc	a0,0x1
ffffffffc020140a:	5d250513          	addi	a0,a0,1490 # ffffffffc02029d8 <etext+0x290>
ffffffffc020140e:	dbdfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free == 0);
ffffffffc0201412:	00001697          	auipc	a3,0x1
ffffffffc0201416:	7f668693          	addi	a3,a3,2038 # ffffffffc0202c08 <etext+0x4c0>
ffffffffc020141a:	00001617          	auipc	a2,0x1
ffffffffc020141e:	5a660613          	addi	a2,a2,1446 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201422:	0e000593          	li	a1,224
ffffffffc0201426:	00001517          	auipc	a0,0x1
ffffffffc020142a:	5b250513          	addi	a0,a0,1458 # ffffffffc02029d8 <etext+0x290>
ffffffffc020142e:	d9dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(alloc_page() == NULL);
ffffffffc0201432:	00001697          	auipc	a3,0x1
ffffffffc0201436:	77668693          	addi	a3,a3,1910 # ffffffffc0202ba8 <etext+0x460>
ffffffffc020143a:	00001617          	auipc	a2,0x1
ffffffffc020143e:	58660613          	addi	a2,a2,1414 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201442:	0da00593          	li	a1,218
ffffffffc0201446:	00001517          	auipc	a0,0x1
ffffffffc020144a:	59250513          	addi	a0,a0,1426 # ffffffffc02029d8 <etext+0x290>
ffffffffc020144e:	d7dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc0201452:	00002697          	auipc	a3,0x2
ffffffffc0201456:	87e68693          	addi	a3,a3,-1922 # ffffffffc0202cd0 <etext+0x588>
ffffffffc020145a:	00001617          	auipc	a2,0x1
ffffffffc020145e:	56660613          	addi	a2,a2,1382 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201462:	0d900593          	li	a1,217
ffffffffc0201466:	00001517          	auipc	a0,0x1
ffffffffc020146a:	57250513          	addi	a0,a0,1394 # ffffffffc02029d8 <etext+0x290>
ffffffffc020146e:	d5dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(p0 + 4 == p1);
ffffffffc0201472:	00002697          	auipc	a3,0x2
ffffffffc0201476:	84e68693          	addi	a3,a3,-1970 # ffffffffc0202cc0 <etext+0x578>
ffffffffc020147a:	00001617          	auipc	a2,0x1
ffffffffc020147e:	54660613          	addi	a2,a2,1350 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201482:	0d100593          	li	a1,209
ffffffffc0201486:	00001517          	auipc	a0,0x1
ffffffffc020148a:	55250513          	addi	a0,a0,1362 # ffffffffc02029d8 <etext+0x290>
ffffffffc020148e:	d3dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(alloc_pages(2) != NULL);      // best fit feature
ffffffffc0201492:	00002697          	auipc	a3,0x2
ffffffffc0201496:	81668693          	addi	a3,a3,-2026 # ffffffffc0202ca8 <etext+0x560>
ffffffffc020149a:	00001617          	auipc	a2,0x1
ffffffffc020149e:	52660613          	addi	a2,a2,1318 # ffffffffc02029c0 <etext+0x278>
ffffffffc02014a2:	0d000593          	li	a1,208
ffffffffc02014a6:	00001517          	auipc	a0,0x1
ffffffffc02014aa:	53250513          	addi	a0,a0,1330 # ffffffffc02029d8 <etext+0x290>
ffffffffc02014ae:	d1dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc02014b2:	00001697          	auipc	a3,0x1
ffffffffc02014b6:	7d668693          	addi	a3,a3,2006 # ffffffffc0202c88 <etext+0x540>
ffffffffc02014ba:	00001617          	auipc	a2,0x1
ffffffffc02014be:	50660613          	addi	a2,a2,1286 # ffffffffc02029c0 <etext+0x278>
ffffffffc02014c2:	0cf00593          	li	a1,207
ffffffffc02014c6:	00001517          	auipc	a0,0x1
ffffffffc02014ca:	51250513          	addi	a0,a0,1298 # ffffffffc02029d8 <etext+0x290>
ffffffffc02014ce:	cfdfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(PageProperty(p0 + 1) && p0[1].property == 2);
ffffffffc02014d2:	00001697          	auipc	a3,0x1
ffffffffc02014d6:	78668693          	addi	a3,a3,1926 # ffffffffc0202c58 <etext+0x510>
ffffffffc02014da:	00001617          	auipc	a2,0x1
ffffffffc02014de:	4e660613          	addi	a2,a2,1254 # ffffffffc02029c0 <etext+0x278>
ffffffffc02014e2:	0cd00593          	li	a1,205
ffffffffc02014e6:	00001517          	auipc	a0,0x1
ffffffffc02014ea:	4f250513          	addi	a0,a0,1266 # ffffffffc02029d8 <etext+0x290>
ffffffffc02014ee:	cddfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(alloc_pages(4) == NULL);
ffffffffc02014f2:	00001697          	auipc	a3,0x1
ffffffffc02014f6:	74e68693          	addi	a3,a3,1870 # ffffffffc0202c40 <etext+0x4f8>
ffffffffc02014fa:	00001617          	auipc	a2,0x1
ffffffffc02014fe:	4c660613          	addi	a2,a2,1222 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201502:	0cc00593          	li	a1,204
ffffffffc0201506:	00001517          	auipc	a0,0x1
ffffffffc020150a:	4d250513          	addi	a0,a0,1234 # ffffffffc02029d8 <etext+0x290>
ffffffffc020150e:	cbdfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(alloc_page() == NULL);
ffffffffc0201512:	00001697          	auipc	a3,0x1
ffffffffc0201516:	69668693          	addi	a3,a3,1686 # ffffffffc0202ba8 <etext+0x460>
ffffffffc020151a:	00001617          	auipc	a2,0x1
ffffffffc020151e:	4a660613          	addi	a2,a2,1190 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201522:	0c000593          	li	a1,192
ffffffffc0201526:	00001517          	auipc	a0,0x1
ffffffffc020152a:	4b250513          	addi	a0,a0,1202 # ffffffffc02029d8 <etext+0x290>
ffffffffc020152e:	c9dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(!PageProperty(p0));
ffffffffc0201532:	00001697          	auipc	a3,0x1
ffffffffc0201536:	6f668693          	addi	a3,a3,1782 # ffffffffc0202c28 <etext+0x4e0>
ffffffffc020153a:	00001617          	auipc	a2,0x1
ffffffffc020153e:	48660613          	addi	a2,a2,1158 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201542:	0b700593          	li	a1,183
ffffffffc0201546:	00001517          	auipc	a0,0x1
ffffffffc020154a:	49250513          	addi	a0,a0,1170 # ffffffffc02029d8 <etext+0x290>
ffffffffc020154e:	c7dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(p0 != NULL);
ffffffffc0201552:	00001697          	auipc	a3,0x1
ffffffffc0201556:	6c668693          	addi	a3,a3,1734 # ffffffffc0202c18 <etext+0x4d0>
ffffffffc020155a:	00001617          	auipc	a2,0x1
ffffffffc020155e:	46660613          	addi	a2,a2,1126 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201562:	0b600593          	li	a1,182
ffffffffc0201566:	00001517          	auipc	a0,0x1
ffffffffc020156a:	47250513          	addi	a0,a0,1138 # ffffffffc02029d8 <etext+0x290>
ffffffffc020156e:	c5dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free == 0);
ffffffffc0201572:	00001697          	auipc	a3,0x1
ffffffffc0201576:	69668693          	addi	a3,a3,1686 # ffffffffc0202c08 <etext+0x4c0>
ffffffffc020157a:	00001617          	auipc	a2,0x1
ffffffffc020157e:	44660613          	addi	a2,a2,1094 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201582:	09800593          	li	a1,152
ffffffffc0201586:	00001517          	auipc	a0,0x1
ffffffffc020158a:	45250513          	addi	a0,a0,1106 # ffffffffc02029d8 <etext+0x290>
ffffffffc020158e:	c3dfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(!list_empty(&free_list));
ffffffffc0201592:	00001697          	auipc	a3,0x1
ffffffffc0201596:	63e68693          	addi	a3,a3,1598 # ffffffffc0202bd0 <etext+0x488>
ffffffffc020159a:	00001617          	auipc	a2,0x1
ffffffffc020159e:	42660613          	addi	a2,a2,1062 # ffffffffc02029c0 <etext+0x278>
ffffffffc02015a2:	09200593          	li	a1,146
ffffffffc02015a6:	00001517          	auipc	a0,0x1
ffffffffc02015aa:	43250513          	addi	a0,a0,1074 # ffffffffc02029d8 <etext+0x290>
ffffffffc02015ae:	c1dfe0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc02015b2 <alloc_pages>:
}

// alloc_pages - call pmm->alloc_pages to allocate a continuous n*PAGESIZE
// memory
struct Page *alloc_pages(size_t n) {
    return pmm_manager->alloc_pages(n);
ffffffffc02015b2:	00006797          	auipc	a5,0x6
ffffffffc02015b6:	4867b783          	ld	a5,1158(a5) # ffffffffc0207a38 <pmm_manager>
ffffffffc02015ba:	6f9c                	ld	a5,24(a5)
ffffffffc02015bc:	8782                	jr	a5

ffffffffc02015be <free_pages>:
}

// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n) {
    pmm_manager->free_pages(base, n);
ffffffffc02015be:	00006797          	auipc	a5,0x6
ffffffffc02015c2:	47a7b783          	ld	a5,1146(a5) # ffffffffc0207a38 <pmm_manager>
ffffffffc02015c6:	739c                	ld	a5,32(a5)
ffffffffc02015c8:	8782                	jr	a5

ffffffffc02015ca <nr_free_pages>:
}

// nr_free_pages - call pmm->nr_free_pages to get the size (nr*PAGESIZE)
// of current free memory
size_t nr_free_pages(void) {
    return pmm_manager->nr_free_pages();
ffffffffc02015ca:	00006797          	auipc	a5,0x6
ffffffffc02015ce:	46e7b783          	ld	a5,1134(a5) # ffffffffc0207a38 <pmm_manager>
ffffffffc02015d2:	779c                	ld	a5,40(a5)
ffffffffc02015d4:	8782                	jr	a5

ffffffffc02015d6 <pmm_init>:
    pmm_manager = &best_fit_pmm_manager;
ffffffffc02015d6:	00002797          	auipc	a5,0x2
ffffffffc02015da:	99a78793          	addi	a5,a5,-1638 # ffffffffc0202f70 <best_fit_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc02015de:	638c                	ld	a1,0(a5)
        init_memmap(pa2page(free_begin), (maxpa - free_begin) / PGSIZE);
    }
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
ffffffffc02015e0:	7179                	addi	sp,sp,-48
ffffffffc02015e2:	f022                	sd	s0,32(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc02015e4:	00002517          	auipc	a0,0x2
ffffffffc02015e8:	9c450513          	addi	a0,a0,-1596 # ffffffffc0202fa8 <best_fit_pmm_manager+0x38>
    pmm_manager = &best_fit_pmm_manager;
ffffffffc02015ec:	00006417          	auipc	s0,0x6
ffffffffc02015f0:	44c40413          	addi	s0,s0,1100 # ffffffffc0207a38 <pmm_manager>
void pmm_init(void) {
ffffffffc02015f4:	f406                	sd	ra,40(sp)
ffffffffc02015f6:	ec26                	sd	s1,24(sp)
ffffffffc02015f8:	e44e                	sd	s3,8(sp)
ffffffffc02015fa:	e84a                	sd	s2,16(sp)
ffffffffc02015fc:	e052                	sd	s4,0(sp)
    pmm_manager = &best_fit_pmm_manager;
ffffffffc02015fe:	e01c                	sd	a5,0(s0)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0201600:	b55fe0ef          	jal	ra,ffffffffc0200154 <cprintf>
    pmm_manager->init();
ffffffffc0201604:	601c                	ld	a5,0(s0)
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0201606:	00006497          	auipc	s1,0x6
ffffffffc020160a:	44a48493          	addi	s1,s1,1098 # ffffffffc0207a50 <va_pa_offset>
    pmm_manager->init();
ffffffffc020160e:	679c                	ld	a5,8(a5)
ffffffffc0201610:	9782                	jalr	a5
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0201612:	57f5                	li	a5,-3
ffffffffc0201614:	07fa                	slli	a5,a5,0x1e
ffffffffc0201616:	e09c                	sd	a5,0(s1)
    uint64_t mem_begin = get_memory_base();
ffffffffc0201618:	fadfe0ef          	jal	ra,ffffffffc02005c4 <get_memory_base>
ffffffffc020161c:	89aa                	mv	s3,a0
    uint64_t mem_size = get_memory_size();
ffffffffc020161e:	fb1fe0ef          	jal	ra,ffffffffc02005ce <get_memory_size>
    if (mem_size == 0 || mem_begin > ~(uint64_t)0 - mem_size) {
ffffffffc0201622:	1c050163          	beqz	a0,ffffffffc02017e4 <pmm_init+0x20e>
ffffffffc0201626:	fff54793          	not	a5,a0
ffffffffc020162a:	8a2a                	mv	s4,a0
ffffffffc020162c:	1b37ec63          	bltu	a5,s3,ffffffffc02017e4 <pmm_init+0x20e>
    cprintf("physical memory map:\n");
ffffffffc0201630:	00002517          	auipc	a0,0x2
ffffffffc0201634:	9c050513          	addi	a0,a0,-1600 # ffffffffc0202ff0 <best_fit_pmm_manager+0x80>
ffffffffc0201638:	b1dfe0ef          	jal	ra,ffffffffc0200154 <cprintf>
    uint64_t mem_end = mem_begin + mem_size; /* exclusive physical end */
ffffffffc020163c:	01498933          	add	s2,s3,s4
    cprintf("  memory: 0x%016lx, [0x%016lx, 0x%016lx].\n",
ffffffffc0201640:	85d2                	mv	a1,s4
ffffffffc0201642:	fff90693          	addi	a3,s2,-1
ffffffffc0201646:	864e                	mv	a2,s3
ffffffffc0201648:	00002517          	auipc	a0,0x2
ffffffffc020164c:	9c050513          	addi	a0,a0,-1600 # ffffffffc0203008 <best_fit_pmm_manager+0x98>
ffffffffc0201650:	b05fe0ef          	jal	ra,ffffffffc0200154 <cprintf>
    if (mem_end < maxpa) {
ffffffffc0201654:	45c5                	li	a1,17
    if (mem_begin > KERNEL_BEGIN_PADDR || maxpa <= KERNEL_BEGIN_PADDR) {
ffffffffc0201656:	40100793          	li	a5,1025
    if (mem_end < maxpa) {
ffffffffc020165a:	05ee                	slli	a1,a1,0x1b
    if (mem_begin > KERNEL_BEGIN_PADDR || maxpa <= KERNEL_BEGIN_PADDR) {
ffffffffc020165c:	07d6                	slli	a5,a5,0x15
    if (mem_end < maxpa) {
ffffffffc020165e:	10b96663          	bltu	s2,a1,ffffffffc020176a <pmm_init+0x194>
    if (mem_begin > KERNEL_BEGIN_PADDR || maxpa <= KERNEL_BEGIN_PADDR) {
ffffffffc0201662:	1137eb63          	bltu	a5,s3,ffffffffc0201778 <pmm_init+0x1a2>
    uintptr_t maxpa = PHYSICAL_MEMORY_END;
ffffffffc0201666:	892e                	mv	s2,a1
    uintptr_t kernel_end_pa = PADDR(end);
ffffffffc0201668:	00006697          	auipc	a3,0x6
ffffffffc020166c:	3f068693          	addi	a3,a3,1008 # ffffffffc0207a58 <end>
ffffffffc0201670:	c02008b7          	lui	a7,0xc0200
ffffffffc0201674:	1b16e063          	bltu	a3,a7,ffffffffc0201814 <pmm_init+0x23e>
ffffffffc0201678:	609c                	ld	a5,0(s1)
    if (kernel_end_pa < KERNEL_BEGIN_PADDR || kernel_end_pa > maxpa) {
ffffffffc020167a:	40100713          	li	a4,1025
ffffffffc020167e:	0756                	slli	a4,a4,0x15
    uintptr_t kernel_end_pa = PADDR(end);
ffffffffc0201680:	8e9d                	sub	a3,a3,a5
    if (kernel_end_pa < KERNEL_BEGIN_PADDR || kernel_end_pa > maxpa) {
ffffffffc0201682:	12e6e963          	bltu	a3,a4,ffffffffc02017b4 <pmm_init+0x1de>
ffffffffc0201686:	12d5e763          	bltu	a1,a3,ffffffffc02017b4 <pmm_init+0x1de>
    npage = maxpa / PGSIZE;
ffffffffc020168a:	737d                	lui	t1,0xfffff
ffffffffc020168c:	00007697          	auipc	a3,0x7
ffffffffc0201690:	3cb68693          	addi	a3,a3,971 # ffffffffc0208a57 <end+0xfff>
ffffffffc0201694:	00c95813          	srli	a6,s2,0xc
ffffffffc0201698:	0066f6b3          	and	a3,a3,t1
ffffffffc020169c:	00006717          	auipc	a4,0x6
ffffffffc02016a0:	39073623          	sd	a6,908(a4) # ffffffffc0207a28 <npage>
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc02016a4:	00006717          	auipc	a4,0x6
ffffffffc02016a8:	38d73623          	sd	a3,908(a4) # ffffffffc0207a30 <pages>
    size_t nr_pages = npage - nbase;
ffffffffc02016ac:	fff80637          	lui	a2,0xfff80
ffffffffc02016b0:	00c80733          	add	a4,a6,a2
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc02016b4:	8536                	mv	a0,a3
    uintptr_t pages_pa = PADDR(pages);
ffffffffc02016b6:	1916e863          	bltu	a3,a7,ffffffffc0201846 <pmm_init+0x270>
ffffffffc02016ba:	40f688b3          	sub	a7,a3,a5
    if (pages_pa > maxpa ||
ffffffffc02016be:	1115e763          	bltu	a1,a7,ffffffffc02017cc <pmm_init+0x1f6>
        nr_pages > (maxpa - pages_pa) / sizeof(struct Page)) {
ffffffffc02016c2:	8f95                	sub	a5,a5,a3
ffffffffc02016c4:	97ae                	add	a5,a5,a1
ffffffffc02016c6:	02800613          	li	a2,40
ffffffffc02016ca:	02c7d7b3          	divu	a5,a5,a2
    if (pages_pa > maxpa ||
ffffffffc02016ce:	0ee7ef63          	bltu	a5,a4,ffffffffc02017cc <pmm_init+0x1f6>
        pages_pa + nr_pages * sizeof(struct Page);
ffffffffc02016d2:	00271613          	slli	a2,a4,0x2
    uintptr_t free_begin = ROUNDUP(descriptors_end_pa, PGSIZE);
ffffffffc02016d6:	6785                	lui	a5,0x1
        pages_pa + nr_pages * sizeof(struct Page);
ffffffffc02016d8:	963a                	add	a2,a2,a4
    uintptr_t free_begin = ROUNDUP(descriptors_end_pa, PGSIZE);
ffffffffc02016da:	17fd                	addi	a5,a5,-1
ffffffffc02016dc:	00281713          	slli	a4,a6,0x2
ffffffffc02016e0:	98be                	add	a7,a7,a5
        pages_pa + nr_pages * sizeof(struct Page);
ffffffffc02016e2:	060e                	slli	a2,a2,0x3
ffffffffc02016e4:	9742                	add	a4,a4,a6
ffffffffc02016e6:	fec007b7          	lui	a5,0xfec00
    uintptr_t free_begin = ROUNDUP(descriptors_end_pa, PGSIZE);
ffffffffc02016ea:	9646                	add	a2,a2,a7
ffffffffc02016ec:	070e                	slli	a4,a4,0x3
ffffffffc02016ee:	97b6                	add	a5,a5,a3
ffffffffc02016f0:	00667633          	and	a2,a2,t1
    for (size_t i = 0; i < nr_pages; i++) {
ffffffffc02016f4:	973e                	add	a4,a4,a5
        SetPageReserved(p);
ffffffffc02016f6:	4885                	li	a7,1
        p->ref = 0;
ffffffffc02016f8:	01868793          	addi	a5,a3,24
ffffffffc02016fc:	0006a023          	sw	zero,0(a3)
        p->property = 0;
ffffffffc0201700:	0006a823          	sw	zero,16(a3)
ffffffffc0201704:	f29c                	sd	a5,32(a3)
ffffffffc0201706:	ee9c                	sd	a5,24(a3)
        SetPageReserved(p);
ffffffffc0201708:	0116b423          	sd	a7,8(a3)
    for (size_t i = 0; i < nr_pages; i++) {
ffffffffc020170c:	02868693          	addi	a3,a3,40
ffffffffc0201710:	fee694e3          	bne	a3,a4,ffffffffc02016f8 <pmm_init+0x122>
    if (free_begin < maxpa) {
ffffffffc0201714:	06b66e63          	bltu	a2,a1,ffffffffc0201790 <pmm_init+0x1ba>
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
ffffffffc0201718:	601c                	ld	a5,0(s0)
ffffffffc020171a:	7b9c                	ld	a5,48(a5)
ffffffffc020171c:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc020171e:	00002517          	auipc	a0,0x2
ffffffffc0201722:	9ea50513          	addi	a0,a0,-1558 # ffffffffc0203108 <best_fit_pmm_manager+0x198>
ffffffffc0201726:	a2ffe0ef          	jal	ra,ffffffffc0200154 <cprintf>
    satp_virtual = (pte_t*)boot_page_table_sv39;
ffffffffc020172a:	00005597          	auipc	a1,0x5
ffffffffc020172e:	8d658593          	addi	a1,a1,-1834 # ffffffffc0206000 <boot_page_table_sv39>
ffffffffc0201732:	00006797          	auipc	a5,0x6
ffffffffc0201736:	30b7bb23          	sd	a1,790(a5) # ffffffffc0207a48 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc020173a:	c02007b7          	lui	a5,0xc0200
ffffffffc020173e:	0ef5e763          	bltu	a1,a5,ffffffffc020182c <pmm_init+0x256>
ffffffffc0201742:	6090                	ld	a2,0(s1)
}
ffffffffc0201744:	7402                	ld	s0,32(sp)
ffffffffc0201746:	70a2                	ld	ra,40(sp)
ffffffffc0201748:	64e2                	ld	s1,24(sp)
ffffffffc020174a:	6942                	ld	s2,16(sp)
ffffffffc020174c:	69a2                	ld	s3,8(sp)
ffffffffc020174e:	6a02                	ld	s4,0(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc0201750:	40c58633          	sub	a2,a1,a2
ffffffffc0201754:	00006797          	auipc	a5,0x6
ffffffffc0201758:	2ec7b623          	sd	a2,748(a5) # ffffffffc0207a40 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc020175c:	00002517          	auipc	a0,0x2
ffffffffc0201760:	9cc50513          	addi	a0,a0,-1588 # ffffffffc0203128 <best_fit_pmm_manager+0x1b8>
}
ffffffffc0201764:	6145                	addi	sp,sp,48
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0201766:	9effe06f          	j	ffffffffc0200154 <cprintf>
    maxpa = ROUNDDOWN(maxpa, PGSIZE);
ffffffffc020176a:	75fd                	lui	a1,0xfffff
ffffffffc020176c:	00b975b3          	and	a1,s2,a1
    if (mem_begin > KERNEL_BEGIN_PADDR || maxpa <= KERNEL_BEGIN_PADDR) {
ffffffffc0201770:	0137e463          	bltu	a5,s3,ffffffffc0201778 <pmm_init+0x1a2>
ffffffffc0201774:	eeb7eae3          	bltu	a5,a1,ffffffffc0201668 <pmm_init+0x92>
        panic("DTB memory does not cover the kernel");
ffffffffc0201778:	00002617          	auipc	a2,0x2
ffffffffc020177c:	8c060613          	addi	a2,a2,-1856 # ffffffffc0203038 <best_fit_pmm_manager+0xc8>
ffffffffc0201780:	05a00593          	li	a1,90
ffffffffc0201784:	00002517          	auipc	a0,0x2
ffffffffc0201788:	85c50513          	addi	a0,a0,-1956 # ffffffffc0202fe0 <best_fit_pmm_manager+0x70>
ffffffffc020178c:	a3ffe0ef          	jal	ra,ffffffffc02001ca <__panic>
static inline int page_ref_dec(struct Page *page) {
    page->ref -= 1;
    return page->ref;
}
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
ffffffffc0201790:	00c65793          	srli	a5,a2,0xc
ffffffffc0201794:	0707f463          	bgeu	a5,a6,ffffffffc02017fc <pmm_init+0x226>
    pmm_manager->init_memmap(base, n);
ffffffffc0201798:	6014                	ld	a3,0(s0)
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
ffffffffc020179a:	fff80737          	lui	a4,0xfff80
ffffffffc020179e:	973e                	add	a4,a4,a5
ffffffffc02017a0:	00271793          	slli	a5,a4,0x2
ffffffffc02017a4:	97ba                	add	a5,a5,a4
ffffffffc02017a6:	6a98                	ld	a4,16(a3)
        init_memmap(pa2page(free_begin), (maxpa - free_begin) / PGSIZE);
ffffffffc02017a8:	8d91                	sub	a1,a1,a2
ffffffffc02017aa:	078e                	slli	a5,a5,0x3
    pmm_manager->init_memmap(base, n);
ffffffffc02017ac:	81b1                	srli	a1,a1,0xc
ffffffffc02017ae:	953e                	add	a0,a0,a5
ffffffffc02017b0:	9702                	jalr	a4
}
ffffffffc02017b2:	b79d                	j	ffffffffc0201718 <pmm_init+0x142>
        panic("kernel image lies outside usable memory");
ffffffffc02017b4:	00002617          	auipc	a2,0x2
ffffffffc02017b8:	8d460613          	addi	a2,a2,-1836 # ffffffffc0203088 <best_fit_pmm_manager+0x118>
ffffffffc02017bc:	06000593          	li	a1,96
ffffffffc02017c0:	00002517          	auipc	a0,0x2
ffffffffc02017c4:	82050513          	addi	a0,a0,-2016 # ffffffffc0202fe0 <best_fit_pmm_manager+0x70>
ffffffffc02017c8:	a03fe0ef          	jal	ra,ffffffffc02001ca <__panic>
        panic("not enough memory for page descriptors");
ffffffffc02017cc:	00002617          	auipc	a2,0x2
ffffffffc02017d0:	8e460613          	addi	a2,a2,-1820 # ffffffffc02030b0 <best_fit_pmm_manager+0x140>
ffffffffc02017d4:	06f00593          	li	a1,111
ffffffffc02017d8:	00002517          	auipc	a0,0x2
ffffffffc02017dc:	80850513          	addi	a0,a0,-2040 # ffffffffc0202fe0 <best_fit_pmm_manager+0x70>
ffffffffc02017e0:	9ebfe0ef          	jal	ra,ffffffffc02001ca <__panic>
        panic("invalid DTB memory range");
ffffffffc02017e4:	00001617          	auipc	a2,0x1
ffffffffc02017e8:	7dc60613          	addi	a2,a2,2012 # ffffffffc0202fc0 <best_fit_pmm_manager+0x50>
ffffffffc02017ec:	04800593          	li	a1,72
ffffffffc02017f0:	00001517          	auipc	a0,0x1
ffffffffc02017f4:	7f050513          	addi	a0,a0,2032 # ffffffffc0202fe0 <best_fit_pmm_manager+0x70>
ffffffffc02017f8:	9d3fe0ef          	jal	ra,ffffffffc02001ca <__panic>
        panic("pa2page called with invalid pa");
ffffffffc02017fc:	00002617          	auipc	a2,0x2
ffffffffc0201800:	8dc60613          	addi	a2,a2,-1828 # ffffffffc02030d8 <best_fit_pmm_manager+0x168>
ffffffffc0201804:	06b00593          	li	a1,107
ffffffffc0201808:	00002517          	auipc	a0,0x2
ffffffffc020180c:	8f050513          	addi	a0,a0,-1808 # ffffffffc02030f8 <best_fit_pmm_manager+0x188>
ffffffffc0201810:	9bbfe0ef          	jal	ra,ffffffffc02001ca <__panic>
    uintptr_t kernel_end_pa = PADDR(end);
ffffffffc0201814:	00002617          	auipc	a2,0x2
ffffffffc0201818:	84c60613          	addi	a2,a2,-1972 # ffffffffc0203060 <best_fit_pmm_manager+0xf0>
ffffffffc020181c:	05e00593          	li	a1,94
ffffffffc0201820:	00001517          	auipc	a0,0x1
ffffffffc0201824:	7c050513          	addi	a0,a0,1984 # ffffffffc0202fe0 <best_fit_pmm_manager+0x70>
ffffffffc0201828:	9a3fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc020182c:	86ae                	mv	a3,a1
ffffffffc020182e:	00002617          	auipc	a2,0x2
ffffffffc0201832:	83260613          	addi	a2,a2,-1998 # ffffffffc0203060 <best_fit_pmm_manager+0xf0>
ffffffffc0201836:	09800593          	li	a1,152
ffffffffc020183a:	00001517          	auipc	a0,0x1
ffffffffc020183e:	7a650513          	addi	a0,a0,1958 # ffffffffc0202fe0 <best_fit_pmm_manager+0x70>
ffffffffc0201842:	989fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    uintptr_t pages_pa = PADDR(pages);
ffffffffc0201846:	00002617          	auipc	a2,0x2
ffffffffc020184a:	81a60613          	addi	a2,a2,-2022 # ffffffffc0203060 <best_fit_pmm_manager+0xf0>
ffffffffc020184e:	06a00593          	li	a1,106
ffffffffc0201852:	00001517          	auipc	a0,0x1
ffffffffc0201856:	78e50513          	addi	a0,a0,1934 # ffffffffc0202fe0 <best_fit_pmm_manager+0x70>
ffffffffc020185a:	971fe0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc020185e <unlink_partial.part.0>:
    s->next = cache->partial;
    if (s->next) s->next->prev = s;
    cache->partial = s;
}

static void unlink_partial(struct object_cache *cache, struct slab_header *s) {
ffffffffc020185e:	1141                	addi	sp,sp,-16
    if (s->prev) s->prev->next = s->next;
    else {
        assert(cache->partial == s);
ffffffffc0201860:	00002697          	auipc	a3,0x2
ffffffffc0201864:	90868693          	addi	a3,a3,-1784 # ffffffffc0203168 <best_fit_pmm_manager+0x1f8>
ffffffffc0201868:	00001617          	auipc	a2,0x1
ffffffffc020186c:	15860613          	addi	a2,a2,344 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201870:	02800593          	li	a1,40
ffffffffc0201874:	00002517          	auipc	a0,0x2
ffffffffc0201878:	90c50513          	addi	a0,a0,-1780 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
static void unlink_partial(struct object_cache *cache, struct slab_header *s) {
ffffffffc020187c:	e406                	sd	ra,8(sp)
        assert(cache->partial == s);
ffffffffc020187e:	94dfe0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc0201882 <kmalloc.part.0>:
    }
    link_partial(&caches[index], s);
    return s;
}

void *kmalloc(size_t size) {
ffffffffc0201882:	7179                	addi	sp,sp,-48
ffffffffc0201884:	e84a                	sd	s2,16(sp)
ffffffffc0201886:	00005917          	auipc	s2,0x5
ffffffffc020188a:	7aa90913          	addi	s2,s2,1962 # ffffffffc0207030 <caches>
ffffffffc020188e:	f022                	sd	s0,32(sp)
ffffffffc0201890:	f406                	sd	ra,40(sp)
ffffffffc0201892:	ec26                	sd	s1,24(sp)
ffffffffc0201894:	e44e                	sd	s3,8(sp)
ffffffffc0201896:	842a                	mv	s0,a0
ffffffffc0201898:	874a                	mv	a4,s2
    if (!size) return NULL;
    unsigned index = 0;
ffffffffc020189a:	4781                	li	a5,0
    while (index < CACHE_COUNT && caches[index].stride < size) ++index;
ffffffffc020189c:	4621                	li	a2,8
ffffffffc020189e:	6314                	ld	a3,0(a4)
ffffffffc02018a0:	0686ff63          	bgeu	a3,s0,ffffffffc020191e <kmalloc.part.0+0x9c>
ffffffffc02018a4:	2785                	addiw	a5,a5,1
ffffffffc02018a6:	0741                	addi	a4,a4,16
ffffffffc02018a8:	fec79be3          	bne	a5,a2,ffffffffc020189e <kmalloc.part.0+0x1c>
    if (index == CACHE_COUNT) {
        /* Check addition before rounding up. */
        if (size > (size_t)-1 - LARGE_OFFSET - (PGSIZE - 1)) return NULL;
ffffffffc02018ac:	77fd                	lui	a5,0xfffff
ffffffffc02018ae:	1781                	addi	a5,a5,-32
ffffffffc02018b0:	0e87e563          	bltu	a5,s0,ffffffffc020199a <kmalloc.part.0+0x118>
        size_t n = (size + LARGE_OFFSET + PGSIZE - 1) / PGSIZE;
ffffffffc02018b4:	6485                	lui	s1,0x1
ffffffffc02018b6:	04fd                	addi	s1,s1,31
ffffffffc02018b8:	94a2                	add	s1,s1,s0
ffffffffc02018ba:	80b1                	srli	s1,s1,0xc
        if (n > nr_free_pages()) return NULL;
ffffffffc02018bc:	d0fff0ef          	jal	ra,ffffffffc02015ca <nr_free_pages>
ffffffffc02018c0:	0c956d63          	bltu	a0,s1,ffffffffc020199a <kmalloc.part.0+0x118>
        struct Page *p = alloc_pages(n);
ffffffffc02018c4:	8526                	mv	a0,s1
ffffffffc02018c6:	cedff0ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
        if (!p) return NULL;
ffffffffc02018ca:	c961                	beqz	a0,ffffffffc020199a <kmalloc.part.0+0x118>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc02018cc:	00006797          	auipc	a5,0x6
ffffffffc02018d0:	1647b783          	ld	a5,356(a5) # ffffffffc0207a30 <pages>
ffffffffc02018d4:	8d1d                	sub	a0,a0,a5
ffffffffc02018d6:	850d                	srai	a0,a0,0x3
ffffffffc02018d8:	00002797          	auipc	a5,0x2
ffffffffc02018dc:	f787b783          	ld	a5,-136(a5) # ffffffffc0203850 <error_string+0x38>
ffffffffc02018e0:	02f50533          	mul	a0,a0,a5
ffffffffc02018e4:	00002797          	auipc	a5,0x2
ffffffffc02018e8:	f847b783          	ld	a5,-124(a5) # ffffffffc0203868 <nbase>
ffffffffc02018ec:	953e                	add	a0,a0,a5
    return page2ppn(page) << PGSHIFT;
ffffffffc02018ee:	0532                	slli	a0,a0,0xc
    return (void *)(page2pa(page) + va_pa_offset);
ffffffffc02018f0:	00006797          	auipc	a5,0x6
ffffffffc02018f4:	1607b783          	ld	a5,352(a5) # ffffffffc0207a50 <va_pa_offset>
ffffffffc02018f8:	953e                	add	a0,a0,a5
        struct large_header *h = page2kva(p);
        h->magic = LARGE_MAGIC;
ffffffffc02018fa:	00002797          	auipc	a5,0x2
ffffffffc02018fe:	f5e7b783          	ld	a5,-162(a5) # ffffffffc0203858 <error_string+0x40>
ffffffffc0201902:	e11c                	sd	a5,0(a0)
        h->npages = n;
ffffffffc0201904:	e504                	sd	s1,8(a0)
        h->requested = size;
ffffffffc0201906:	e900                	sd	s0,16(a0)
        h->padding = 0;
ffffffffc0201908:	00053c23          	sd	zero,24(a0)
        return (unsigned char *)h + LARGE_OFFSET;
ffffffffc020190c:	02050513          	addi	a0,a0,32
    size_t slot = ((uintptr_t)object - (uintptr_t)s - SLAB_OFFSET) / cache->stride;
    assert(!(s->used[slot / 64] & (1ULL << (slot % 64))));
    s->used[slot / 64] |= 1ULL << (slot % 64);
    if (++s->inuse == s->total) unlink_partial(cache, s);
    return object;
}
ffffffffc0201910:	70a2                	ld	ra,40(sp)
ffffffffc0201912:	7402                	ld	s0,32(sp)
ffffffffc0201914:	64e2                	ld	s1,24(sp)
ffffffffc0201916:	6942                	ld	s2,16(sp)
ffffffffc0201918:	69a2                	ld	s3,8(sp)
ffffffffc020191a:	6145                	addi	sp,sp,48
ffffffffc020191c:	8082                	ret
    struct slab_header *s = cache->partial;
ffffffffc020191e:	02079413          	slli	s0,a5,0x20
ffffffffc0201922:	9001                	srli	s0,s0,0x20
ffffffffc0201924:	00441993          	slli	s3,s0,0x4
ffffffffc0201928:	99ca                	add	s3,s3,s2
ffffffffc020192a:	0089b603          	ld	a2,8(s3)
    if (!s) s = new_slab(index);
ffffffffc020192e:	ce35                	beqz	a2,ffffffffc02019aa <kmalloc.part.0+0x128>
    void *object = s->free;
ffffffffc0201930:	6e08                	ld	a0,24(a2)
    size_t slot = ((uintptr_t)object - (uintptr_t)s - SLAB_OFFSET) / cache->stride;
ffffffffc0201932:	84b2                	mv	s1,a2
    assert(object != NULL);
ffffffffc0201934:	14050c63          	beqz	a0,ffffffffc0201a8c <kmalloc.part.0+0x20a>
    size_t slot = ((uintptr_t)object - (uintptr_t)s - SLAB_OFFSET) / cache->stride;
ffffffffc0201938:	409504b3          	sub	s1,a0,s1
ffffffffc020193c:	fa048493          	addi	s1,s1,-96 # fa0 <kern_entry-0xffffffffc01ff060>
ffffffffc0201940:	02d4d6b3          	divu	a3,s1,a3
    s->free = *(void **)object;
ffffffffc0201944:	611c                	ld	a5,0(a0)
ffffffffc0201946:	ee1c                	sd	a5,24(a2)
    assert(!(s->used[slot / 64] & (1ULL << (slot % 64))));
ffffffffc0201948:	0066d793          	srli	a5,a3,0x6
ffffffffc020194c:	078e                	slli	a5,a5,0x3
ffffffffc020194e:	97b2                	add	a5,a5,a2
ffffffffc0201950:	7f8c                	ld	a1,56(a5)
ffffffffc0201952:	03f6f693          	andi	a3,a3,63
ffffffffc0201956:	00d5d733          	srl	a4,a1,a3
ffffffffc020195a:	8b05                	andi	a4,a4,1
ffffffffc020195c:	10071663          	bnez	a4,ffffffffc0201a68 <kmalloc.part.0+0x1e6>
    s->used[slot / 64] |= 1ULL << (slot % 64);
ffffffffc0201960:	4705                	li	a4,1
ffffffffc0201962:	00d716b3          	sll	a3,a4,a3
ffffffffc0201966:	8ecd                	or	a3,a3,a1
ffffffffc0201968:	ff94                	sd	a3,56(a5)
    if (++s->inuse == s->total) unlink_partial(cache, s);
ffffffffc020196a:	7a1c                	ld	a5,48(a2)
ffffffffc020196c:	7618                	ld	a4,40(a2)
ffffffffc020196e:	0785                	addi	a5,a5,1
ffffffffc0201970:	fa1c                	sd	a5,48(a2)
ffffffffc0201972:	f8e79fe3          	bne	a5,a4,ffffffffc0201910 <kmalloc.part.0+0x8e>
    if (s->prev) s->prev->next = s->next;
ffffffffc0201976:	6618                	ld	a4,8(a2)
ffffffffc0201978:	cf69                	beqz	a4,ffffffffc0201a52 <kmalloc.part.0+0x1d0>
ffffffffc020197a:	6a1c                	ld	a5,16(a2)
ffffffffc020197c:	eb1c                	sd	a5,16(a4)
    if (s->next) s->next->prev = s->prev;
ffffffffc020197e:	6a1c                	ld	a5,16(a2)
ffffffffc0201980:	c391                	beqz	a5,ffffffffc0201984 <kmalloc.part.0+0x102>
ffffffffc0201982:	e798                	sd	a4,8(a5)
}
ffffffffc0201984:	70a2                	ld	ra,40(sp)
ffffffffc0201986:	7402                	ld	s0,32(sp)
    s->prev = s->next = NULL;
ffffffffc0201988:	00063823          	sd	zero,16(a2)
ffffffffc020198c:	00063423          	sd	zero,8(a2)
}
ffffffffc0201990:	64e2                	ld	s1,24(sp)
ffffffffc0201992:	6942                	ld	s2,16(sp)
ffffffffc0201994:	69a2                	ld	s3,8(sp)
ffffffffc0201996:	6145                	addi	sp,sp,48
ffffffffc0201998:	8082                	ret
ffffffffc020199a:	70a2                	ld	ra,40(sp)
ffffffffc020199c:	7402                	ld	s0,32(sp)
ffffffffc020199e:	64e2                	ld	s1,24(sp)
ffffffffc02019a0:	6942                	ld	s2,16(sp)
ffffffffc02019a2:	69a2                	ld	s3,8(sp)
        if (n > nr_free_pages()) return NULL;
ffffffffc02019a4:	4501                	li	a0,0
}
ffffffffc02019a6:	6145                	addi	sp,sp,48
ffffffffc02019a8:	8082                	ret
    struct Page *page = alloc_page();
ffffffffc02019aa:	4505                	li	a0,1
ffffffffc02019ac:	c07ff0ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
    if (!page) return NULL;
ffffffffc02019b0:	d56d                	beqz	a0,ffffffffc020199a <kmalloc.part.0+0x118>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc02019b2:	00006497          	auipc	s1,0x6
ffffffffc02019b6:	07e4b483          	ld	s1,126(s1) # ffffffffc0207a30 <pages>
ffffffffc02019ba:	409504b3          	sub	s1,a0,s1
ffffffffc02019be:	00002797          	auipc	a5,0x2
ffffffffc02019c2:	e927b783          	ld	a5,-366(a5) # ffffffffc0203850 <error_string+0x38>
ffffffffc02019c6:	848d                	srai	s1,s1,0x3
ffffffffc02019c8:	02f484b3          	mul	s1,s1,a5
ffffffffc02019cc:	00002797          	auipc	a5,0x2
ffffffffc02019d0:	e9c7b783          	ld	a5,-356(a5) # ffffffffc0203868 <nbase>
    memset(s, 0, SLAB_OFFSET);
ffffffffc02019d4:	06000613          	li	a2,96
ffffffffc02019d8:	4581                	li	a1,0
ffffffffc02019da:	94be                	add	s1,s1,a5
    return page2ppn(page) << PGSHIFT;
ffffffffc02019dc:	04b2                	slli	s1,s1,0xc
    return (void *)(page2pa(page) + va_pa_offset);
ffffffffc02019de:	00006797          	auipc	a5,0x6
ffffffffc02019e2:	0727b783          	ld	a5,114(a5) # ffffffffc0207a50 <va_pa_offset>
ffffffffc02019e6:	94be                	add	s1,s1,a5
ffffffffc02019e8:	8526                	mv	a0,s1
ffffffffc02019ea:	54d000ef          	jal	ra,ffffffffc0202736 <memset>
    s->total = (PGSIZE - SLAB_OFFSET) / caches[index].stride;
ffffffffc02019ee:	0009b583          	ld	a1,0(s3)
ffffffffc02019f2:	6685                	lui	a3,0x1
ffffffffc02019f4:	fa068693          	addi	a3,a3,-96 # fa0 <kern_entry-0xffffffffc01ff060>
ffffffffc02019f8:	02b6d6b3          	divu	a3,a3,a1
    s->magic = SLAB_MAGIC;
ffffffffc02019fc:	00002797          	auipc	a5,0x2
ffffffffc0201a00:	e647b783          	ld	a5,-412(a5) # ffffffffc0203860 <error_string+0x48>
ffffffffc0201a04:	e09c                	sd	a5,0(s1)
    s->cache_index = index;
ffffffffc0201a06:	f080                	sd	s0,32(s1)
    assert(s->total > 0 && s->total <= 256);
ffffffffc0201a08:	0ff00793          	li	a5,255
ffffffffc0201a0c:	8626                	mv	a2,s1
    s->total = (PGSIZE - SLAB_OFFSET) / caches[index].stride;
ffffffffc0201a0e:	f494                	sd	a3,40(s1)
    assert(s->total > 0 && s->total <= 256);
ffffffffc0201a10:	16fd                	addi	a3,a3,-1
ffffffffc0201a12:	08d7ed63          	bltu	a5,a3,ffffffffc0201aac <kmalloc.part.0+0x22a>
ffffffffc0201a16:	02d587b3          	mul	a5,a1,a3
        *(void **)object = s->free;
ffffffffc0201a1a:	6c98                	ld	a4,24(s1)
ffffffffc0201a1c:	06078793          	addi	a5,a5,96
ffffffffc0201a20:	97a6                	add	a5,a5,s1
ffffffffc0201a22:	a011                	j	ffffffffc0201a26 <kmalloc.part.0+0x1a4>
ffffffffc0201a24:	16fd                	addi	a3,a3,-1
ffffffffc0201a26:	e398                	sd	a4,0(a5)
        s->free = object;
ffffffffc0201a28:	ec9c                	sd	a5,24(s1)
        void *object = objects + (i - 1) * caches[index].stride;
ffffffffc0201a2a:	873e                	mv	a4,a5
    for (size_t i = s->total; i > 0; --i) {
ffffffffc0201a2c:	8f8d                	sub	a5,a5,a1
ffffffffc0201a2e:	fafd                	bnez	a3,ffffffffc0201a24 <kmalloc.part.0+0x1a2>
    s->next = cache->partial;
ffffffffc0201a30:	00441793          	slli	a5,s0,0x4
ffffffffc0201a34:	97ca                	add	a5,a5,s2
ffffffffc0201a36:	679c                	ld	a5,8(a5)
    s->prev = NULL;
ffffffffc0201a38:	0004b423          	sd	zero,8(s1)
        void *object = objects + (i - 1) * caches[index].stride;
ffffffffc0201a3c:	06048513          	addi	a0,s1,96
    s->next = cache->partial;
ffffffffc0201a40:	e89c                	sd	a5,16(s1)
    if (s->next) s->next->prev = s;
ffffffffc0201a42:	c391                	beqz	a5,ffffffffc0201a46 <kmalloc.part.0+0x1c4>
ffffffffc0201a44:	e784                	sd	s1,8(a5)
    cache->partial = s;
ffffffffc0201a46:	00441793          	slli	a5,s0,0x4
ffffffffc0201a4a:	97ca                	add	a5,a5,s2
    size_t slot = ((uintptr_t)object - (uintptr_t)s - SLAB_OFFSET) / cache->stride;
ffffffffc0201a4c:	6394                	ld	a3,0(a5)
    cache->partial = s;
ffffffffc0201a4e:	e784                	sd	s1,8(a5)
    assert(object != NULL);
ffffffffc0201a50:	b5e5                	j	ffffffffc0201938 <kmalloc.part.0+0xb6>
        assert(cache->partial == s);
ffffffffc0201a52:	00441793          	slli	a5,s0,0x4
ffffffffc0201a56:	993e                	add	s2,s2,a5
ffffffffc0201a58:	00893783          	ld	a5,8(s2)
ffffffffc0201a5c:	02f61663          	bne	a2,a5,ffffffffc0201a88 <kmalloc.part.0+0x206>
        cache->partial = s->next;
ffffffffc0201a60:	6a1c                	ld	a5,16(a2)
ffffffffc0201a62:	00f93423          	sd	a5,8(s2)
ffffffffc0201a66:	bf29                	j	ffffffffc0201980 <kmalloc.part.0+0xfe>
    assert(!(s->used[slot / 64] & (1ULL << (slot % 64))));
ffffffffc0201a68:	00001697          	auipc	a3,0x1
ffffffffc0201a6c:	75868693          	addi	a3,a3,1880 # ffffffffc02031c0 <best_fit_pmm_manager+0x250>
ffffffffc0201a70:	00001617          	auipc	a2,0x1
ffffffffc0201a74:	f5060613          	addi	a2,a2,-176 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201a78:	06400593          	li	a1,100
ffffffffc0201a7c:	00001517          	auipc	a0,0x1
ffffffffc0201a80:	70450513          	addi	a0,a0,1796 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0201a84:	f46fe0ef          	jal	ra,ffffffffc02001ca <__panic>
ffffffffc0201a88:	dd7ff0ef          	jal	ra,ffffffffc020185e <unlink_partial.part.0>
    assert(object != NULL);
ffffffffc0201a8c:	00001697          	auipc	a3,0x1
ffffffffc0201a90:	72468693          	addi	a3,a3,1828 # ffffffffc02031b0 <best_fit_pmm_manager+0x240>
ffffffffc0201a94:	00001617          	auipc	a2,0x1
ffffffffc0201a98:	f2c60613          	addi	a2,a2,-212 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201a9c:	06100593          	li	a1,97
ffffffffc0201aa0:	00001517          	auipc	a0,0x1
ffffffffc0201aa4:	6e050513          	addi	a0,a0,1760 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0201aa8:	f22fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(s->total > 0 && s->total <= 256);
ffffffffc0201aac:	00001697          	auipc	a3,0x1
ffffffffc0201ab0:	6e468693          	addi	a3,a3,1764 # ffffffffc0203190 <best_fit_pmm_manager+0x220>
ffffffffc0201ab4:	00001617          	auipc	a2,0x1
ffffffffc0201ab8:	f0c60613          	addi	a2,a2,-244 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201abc:	03f00593          	li	a1,63
ffffffffc0201ac0:	00001517          	auipc	a0,0x1
ffffffffc0201ac4:	6c050513          	addi	a0,a0,1728 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0201ac8:	f02fe0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc0201acc <slub_init>:
    for (unsigned i = 0; i < CACHE_COUNT; ++i) {
ffffffffc0201acc:	00005717          	auipc	a4,0x5
ffffffffc0201ad0:	56470713          	addi	a4,a4,1380 # ffffffffc0207030 <caches>
ffffffffc0201ad4:	4781                	li	a5,0
        caches[i].stride = (size_t)16 << i;
ffffffffc0201ad6:	45c1                	li	a1,16
    for (unsigned i = 0; i < CACHE_COUNT; ++i) {
ffffffffc0201ad8:	4621                	li	a2,8
        caches[i].stride = (size_t)16 << i;
ffffffffc0201ada:	00f596b3          	sll	a3,a1,a5
ffffffffc0201ade:	e314                	sd	a3,0(a4)
        caches[i].partial = NULL;
ffffffffc0201ae0:	00073423          	sd	zero,8(a4)
    for (unsigned i = 0; i < CACHE_COUNT; ++i) {
ffffffffc0201ae4:	2785                	addiw	a5,a5,1
ffffffffc0201ae6:	0741                	addi	a4,a4,16
ffffffffc0201ae8:	fec799e3          	bne	a5,a2,ffffffffc0201ada <slub_init+0xe>
}
ffffffffc0201aec:	8082                	ret

ffffffffc0201aee <kfree>:

void kfree(void *ptr) {
    if (!ptr) return;
ffffffffc0201aee:	16050763          	beqz	a0,ffffffffc0201c5c <kfree+0x16e>
    uintptr_t page_va = ROUNDDOWN((uintptr_t)ptr, PGSIZE);
ffffffffc0201af2:	76fd                	lui	a3,0xfffff
ffffffffc0201af4:	8ee9                	and	a3,a3,a0
    uint64_t magic = *(uint64_t *)page_va;
ffffffffc0201af6:	629c                	ld	a5,0(a3)
void kfree(void *ptr) {
ffffffffc0201af8:	1141                	addi	sp,sp,-16
ffffffffc0201afa:	e406                	sd	ra,8(sp)
    if (magic == LARGE_MAGIC) {
ffffffffc0201afc:	00002717          	auipc	a4,0x2
ffffffffc0201b00:	d5c73703          	ld	a4,-676(a4) # ffffffffc0203858 <error_string+0x40>
ffffffffc0201b04:	08e78663          	beq	a5,a4,ffffffffc0201b90 <kfree+0xa2>
        assert(n > 0);
        h->magic = 0;
        free_pages(pa2page(PADDR(page_va)), n);
        return;
    }
    assert(magic == SLAB_MAGIC);
ffffffffc0201b08:	00002717          	auipc	a4,0x2
ffffffffc0201b0c:	d5873703          	ld	a4,-680(a4) # ffffffffc0203860 <error_string+0x48>
ffffffffc0201b10:	18e79b63          	bne	a5,a4,ffffffffc0201ca6 <kfree+0x1b8>
    struct slab_header *s = (struct slab_header *)page_va;
    assert(s->cache_index < CACHE_COUNT);
ffffffffc0201b14:	7298                	ld	a4,32(a3)
ffffffffc0201b16:	479d                	li	a5,7
ffffffffc0201b18:	22e7e763          	bltu	a5,a4,ffffffffc0201d46 <kfree+0x258>
    struct object_cache *cache = &caches[s->cache_index];
    uintptr_t first = page_va + SLAB_OFFSET;
ffffffffc0201b1c:	06068793          	addi	a5,a3,96 # fffffffffffff060 <end+0x3fdf7608>
    assert((uintptr_t)ptr >= first);
ffffffffc0201b20:	16f56363          	bltu	a0,a5,ffffffffc0201c86 <kfree+0x198>
    size_t offset = (uintptr_t)ptr - first;
    assert(offset % cache->stride == 0);
ffffffffc0201b24:	00471593          	slli	a1,a4,0x4
ffffffffc0201b28:	00005317          	auipc	t1,0x5
ffffffffc0201b2c:	50830313          	addi	t1,t1,1288 # ffffffffc0207030 <caches>
ffffffffc0201b30:	00b30e33          	add	t3,t1,a1
ffffffffc0201b34:	000e3703          	ld	a4,0(t3)
    size_t offset = (uintptr_t)ptr - first;
ffffffffc0201b38:	40f507b3          	sub	a5,a0,a5
    assert(offset % cache->stride == 0);
ffffffffc0201b3c:	02e7f633          	remu	a2,a5,a4
ffffffffc0201b40:	1c061363          	bnez	a2,ffffffffc0201d06 <kfree+0x218>
    size_t slot = offset / cache->stride;
ffffffffc0201b44:	02e7d7b3          	divu	a5,a5,a4
    assert(slot < s->total);
ffffffffc0201b48:	0286b803          	ld	a6,40(a3)
ffffffffc0201b4c:	1907fd63          	bgeu	a5,a6,ffffffffc0201ce6 <kfree+0x1f8>
    uint64_t mask = 1ULL << (slot % 64);
    assert(s->used[slot / 64] & mask);
ffffffffc0201b50:	0067d613          	srli	a2,a5,0x6
ffffffffc0201b54:	060e                	slli	a2,a2,0x3
ffffffffc0201b56:	9636                	add	a2,a2,a3
ffffffffc0201b58:	03863883          	ld	a7,56(a2)
    uint64_t mask = 1ULL << (slot % 64);
ffffffffc0201b5c:	4705                	li	a4,1
ffffffffc0201b5e:	00f717b3          	sll	a5,a4,a5
    assert(s->used[slot / 64] & mask);
ffffffffc0201b62:	00f8f733          	and	a4,a7,a5
ffffffffc0201b66:	16070063          	beqz	a4,ffffffffc0201cc6 <kfree+0x1d8>
    s->used[slot / 64] &= ~mask;
ffffffffc0201b6a:	fff7c793          	not	a5,a5
ffffffffc0201b6e:	0117f7b3          	and	a5,a5,a7
ffffffffc0201b72:	fe1c                	sd	a5,56(a2)
    if (s->inuse == s->total) link_partial(cache, s);
ffffffffc0201b74:	7a9c                	ld	a5,48(a3)
ffffffffc0201b76:	06f80863          	beq	a6,a5,ffffffffc0201be6 <kfree+0xf8>
    assert(s->inuse > 0);
ffffffffc0201b7a:	1a078663          	beqz	a5,ffffffffc0201d26 <kfree+0x238>
    --s->inuse;
    *(void **)ptr = s->free;
ffffffffc0201b7e:	6e98                	ld	a4,24(a3)
    --s->inuse;
ffffffffc0201b80:	17fd                	addi	a5,a5,-1
ffffffffc0201b82:	fa9c                	sd	a5,48(a3)
    *(void **)ptr = s->free;
ffffffffc0201b84:	e118                	sd	a4,0(a0)
    s->free = ptr;
ffffffffc0201b86:	ee88                	sd	a0,24(a3)
    if (s->inuse == 0) {
ffffffffc0201b88:	cbb5                	beqz	a5,ffffffffc0201bfc <kfree+0x10e>
        unlink_partial(cache, s);
        s->magic = 0;
        free_page(pa2page(PADDR(page_va)));
    }
}
ffffffffc0201b8a:	60a2                	ld	ra,8(sp)
ffffffffc0201b8c:	0141                	addi	sp,sp,16
ffffffffc0201b8e:	8082                	ret
        assert((uintptr_t)ptr == page_va + LARGE_OFFSET);
ffffffffc0201b90:	02068793          	addi	a5,a3,32
ffffffffc0201b94:	1ca79963          	bne	a5,a0,ffffffffc0201d66 <kfree+0x278>
        size_t n = h->npages;
ffffffffc0201b98:	668c                	ld	a1,8(a3)
        assert(n > 0);
ffffffffc0201b9a:	20058263          	beqz	a1,ffffffffc0201d9e <kfree+0x2b0>
        h->magic = 0;
ffffffffc0201b9e:	0006b023          	sd	zero,0(a3)
        free_pages(pa2page(PADDR(page_va)), n);
ffffffffc0201ba2:	c02007b7          	lui	a5,0xc0200
ffffffffc0201ba6:	20f6ec63          	bltu	a3,a5,ffffffffc0201dbe <kfree+0x2d0>
ffffffffc0201baa:	00006797          	auipc	a5,0x6
ffffffffc0201bae:	ea67b783          	ld	a5,-346(a5) # ffffffffc0207a50 <va_pa_offset>
ffffffffc0201bb2:	8e9d                	sub	a3,a3,a5
    if (PPN(pa) >= npage) {
ffffffffc0201bb4:	82b1                	srli	a3,a3,0xc
ffffffffc0201bb6:	00006797          	auipc	a5,0x6
ffffffffc0201bba:	e727b783          	ld	a5,-398(a5) # ffffffffc0207a28 <npage>
ffffffffc0201bbe:	0af6f863          	bgeu	a3,a5,ffffffffc0201c6e <kfree+0x180>
    return &pages[PPN(pa) - nbase];
ffffffffc0201bc2:	00002517          	auipc	a0,0x2
ffffffffc0201bc6:	ca653503          	ld	a0,-858(a0) # ffffffffc0203868 <nbase>
ffffffffc0201bca:	8e89                	sub	a3,a3,a0
ffffffffc0201bcc:	00269513          	slli	a0,a3,0x2
}
ffffffffc0201bd0:	60a2                	ld	ra,8(sp)
ffffffffc0201bd2:	96aa                	add	a3,a3,a0
ffffffffc0201bd4:	068e                	slli	a3,a3,0x3
        free_page(pa2page(PADDR(page_va)));
ffffffffc0201bd6:	00006517          	auipc	a0,0x6
ffffffffc0201bda:	e5a53503          	ld	a0,-422(a0) # ffffffffc0207a30 <pages>
ffffffffc0201bde:	9536                	add	a0,a0,a3
}
ffffffffc0201be0:	0141                	addi	sp,sp,16
        free_page(pa2page(PADDR(page_va)));
ffffffffc0201be2:	9ddff06f          	j	ffffffffc02015be <free_pages>
    s->next = cache->partial;
ffffffffc0201be6:	008e3703          	ld	a4,8(t3)
    s->prev = NULL;
ffffffffc0201bea:	0006b423          	sd	zero,8(a3)
    s->next = cache->partial;
ffffffffc0201bee:	ea98                	sd	a4,16(a3)
    if (s->next) s->next->prev = s;
ffffffffc0201bf0:	c311                	beqz	a4,ffffffffc0201bf4 <kfree+0x106>
ffffffffc0201bf2:	e714                	sd	a3,8(a4)
    cache->partial = s;
ffffffffc0201bf4:	00b30733          	add	a4,t1,a1
ffffffffc0201bf8:	e714                	sd	a3,8(a4)
}
ffffffffc0201bfa:	b741                	j	ffffffffc0201b7a <kfree+0x8c>
    if (s->prev) s->prev->next = s->next;
ffffffffc0201bfc:	669c                	ld	a5,8(a3)
ffffffffc0201bfe:	c3a5                	beqz	a5,ffffffffc0201c5e <kfree+0x170>
ffffffffc0201c00:	6a98                	ld	a4,16(a3)
ffffffffc0201c02:	eb98                	sd	a4,16(a5)
    if (s->next) s->next->prev = s->prev;
ffffffffc0201c04:	6a90                	ld	a2,16(a3)
ffffffffc0201c06:	c211                	beqz	a2,ffffffffc0201c0a <kfree+0x11c>
ffffffffc0201c08:	e61c                	sd	a5,8(a2)
    s->prev = s->next = NULL;
ffffffffc0201c0a:	0006b823          	sd	zero,16(a3)
ffffffffc0201c0e:	0006b423          	sd	zero,8(a3)
        s->magic = 0;
ffffffffc0201c12:	0006b023          	sd	zero,0(a3)
        free_page(pa2page(PADDR(page_va)));
ffffffffc0201c16:	c02007b7          	lui	a5,0xc0200
ffffffffc0201c1a:	16f6e663          	bltu	a3,a5,ffffffffc0201d86 <kfree+0x298>
ffffffffc0201c1e:	00006797          	auipc	a5,0x6
ffffffffc0201c22:	e327b783          	ld	a5,-462(a5) # ffffffffc0207a50 <va_pa_offset>
ffffffffc0201c26:	8e9d                	sub	a3,a3,a5
    if (PPN(pa) >= npage) {
ffffffffc0201c28:	82b1                	srli	a3,a3,0xc
ffffffffc0201c2a:	00006797          	auipc	a5,0x6
ffffffffc0201c2e:	dfe7b783          	ld	a5,-514(a5) # ffffffffc0207a28 <npage>
ffffffffc0201c32:	02f6fe63          	bgeu	a3,a5,ffffffffc0201c6e <kfree+0x180>
    return &pages[PPN(pa) - nbase];
ffffffffc0201c36:	00002517          	auipc	a0,0x2
ffffffffc0201c3a:	c3253503          	ld	a0,-974(a0) # ffffffffc0203868 <nbase>
ffffffffc0201c3e:	8e89                	sub	a3,a3,a0
ffffffffc0201c40:	00269513          	slli	a0,a3,0x2
}
ffffffffc0201c44:	60a2                	ld	ra,8(sp)
ffffffffc0201c46:	96aa                	add	a3,a3,a0
ffffffffc0201c48:	068e                	slli	a3,a3,0x3
        free_page(pa2page(PADDR(page_va)));
ffffffffc0201c4a:	00006517          	auipc	a0,0x6
ffffffffc0201c4e:	de653503          	ld	a0,-538(a0) # ffffffffc0207a30 <pages>
ffffffffc0201c52:	4585                	li	a1,1
ffffffffc0201c54:	9536                	add	a0,a0,a3
}
ffffffffc0201c56:	0141                	addi	sp,sp,16
        free_page(pa2page(PADDR(page_va)));
ffffffffc0201c58:	967ff06f          	j	ffffffffc02015be <free_pages>
ffffffffc0201c5c:	8082                	ret
        assert(cache->partial == s);
ffffffffc0201c5e:	00b30733          	add	a4,t1,a1
ffffffffc0201c62:	6710                	ld	a2,8(a4)
ffffffffc0201c64:	16d61963          	bne	a2,a3,ffffffffc0201dd6 <kfree+0x2e8>
        cache->partial = s->next;
ffffffffc0201c68:	6a90                	ld	a2,16(a3)
ffffffffc0201c6a:	e710                	sd	a2,8(a4)
ffffffffc0201c6c:	bf69                	j	ffffffffc0201c06 <kfree+0x118>
        panic("pa2page called with invalid pa");
ffffffffc0201c6e:	00001617          	auipc	a2,0x1
ffffffffc0201c72:	46a60613          	addi	a2,a2,1130 # ffffffffc02030d8 <best_fit_pmm_manager+0x168>
ffffffffc0201c76:	06b00593          	li	a1,107
ffffffffc0201c7a:	00001517          	auipc	a0,0x1
ffffffffc0201c7e:	47e50513          	addi	a0,a0,1150 # ffffffffc02030f8 <best_fit_pmm_manager+0x188>
ffffffffc0201c82:	d48fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert((uintptr_t)ptr >= first);
ffffffffc0201c86:	00001697          	auipc	a3,0x1
ffffffffc0201c8a:	5d268693          	addi	a3,a3,1490 # ffffffffc0203258 <best_fit_pmm_manager+0x2e8>
ffffffffc0201c8e:	00001617          	auipc	a2,0x1
ffffffffc0201c92:	d3260613          	addi	a2,a2,-718 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201c96:	07c00593          	li	a1,124
ffffffffc0201c9a:	00001517          	auipc	a0,0x1
ffffffffc0201c9e:	4e650513          	addi	a0,a0,1254 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0201ca2:	d28fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(magic == SLAB_MAGIC);
ffffffffc0201ca6:	00001697          	auipc	a3,0x1
ffffffffc0201caa:	57a68693          	addi	a3,a3,1402 # ffffffffc0203220 <best_fit_pmm_manager+0x2b0>
ffffffffc0201cae:	00001617          	auipc	a2,0x1
ffffffffc0201cb2:	d1260613          	addi	a2,a2,-750 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201cb6:	07700593          	li	a1,119
ffffffffc0201cba:	00001517          	auipc	a0,0x1
ffffffffc0201cbe:	4c650513          	addi	a0,a0,1222 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0201cc2:	d08fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(s->used[slot / 64] & mask);
ffffffffc0201cc6:	00001697          	auipc	a3,0x1
ffffffffc0201cca:	5da68693          	addi	a3,a3,1498 # ffffffffc02032a0 <best_fit_pmm_manager+0x330>
ffffffffc0201cce:	00001617          	auipc	a2,0x1
ffffffffc0201cd2:	cf260613          	addi	a2,a2,-782 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201cd6:	08200593          	li	a1,130
ffffffffc0201cda:	00001517          	auipc	a0,0x1
ffffffffc0201cde:	4a650513          	addi	a0,a0,1190 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0201ce2:	ce8fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(slot < s->total);
ffffffffc0201ce6:	00001697          	auipc	a3,0x1
ffffffffc0201cea:	5aa68693          	addi	a3,a3,1450 # ffffffffc0203290 <best_fit_pmm_manager+0x320>
ffffffffc0201cee:	00001617          	auipc	a2,0x1
ffffffffc0201cf2:	cd260613          	addi	a2,a2,-814 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201cf6:	08000593          	li	a1,128
ffffffffc0201cfa:	00001517          	auipc	a0,0x1
ffffffffc0201cfe:	48650513          	addi	a0,a0,1158 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0201d02:	cc8fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(offset % cache->stride == 0);
ffffffffc0201d06:	00001697          	auipc	a3,0x1
ffffffffc0201d0a:	56a68693          	addi	a3,a3,1386 # ffffffffc0203270 <best_fit_pmm_manager+0x300>
ffffffffc0201d0e:	00001617          	auipc	a2,0x1
ffffffffc0201d12:	cb260613          	addi	a2,a2,-846 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201d16:	07e00593          	li	a1,126
ffffffffc0201d1a:	00001517          	auipc	a0,0x1
ffffffffc0201d1e:	46650513          	addi	a0,a0,1126 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0201d22:	ca8fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(s->inuse > 0);
ffffffffc0201d26:	00001697          	auipc	a3,0x1
ffffffffc0201d2a:	59a68693          	addi	a3,a3,1434 # ffffffffc02032c0 <best_fit_pmm_manager+0x350>
ffffffffc0201d2e:	00001617          	auipc	a2,0x1
ffffffffc0201d32:	c9260613          	addi	a2,a2,-878 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201d36:	08500593          	li	a1,133
ffffffffc0201d3a:	00001517          	auipc	a0,0x1
ffffffffc0201d3e:	44650513          	addi	a0,a0,1094 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0201d42:	c88fe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(s->cache_index < CACHE_COUNT);
ffffffffc0201d46:	00001697          	auipc	a3,0x1
ffffffffc0201d4a:	4f268693          	addi	a3,a3,1266 # ffffffffc0203238 <best_fit_pmm_manager+0x2c8>
ffffffffc0201d4e:	00001617          	auipc	a2,0x1
ffffffffc0201d52:	c7260613          	addi	a2,a2,-910 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201d56:	07900593          	li	a1,121
ffffffffc0201d5a:	00001517          	auipc	a0,0x1
ffffffffc0201d5e:	42650513          	addi	a0,a0,1062 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0201d62:	c68fe0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert((uintptr_t)ptr == page_va + LARGE_OFFSET);
ffffffffc0201d66:	00001697          	auipc	a3,0x1
ffffffffc0201d6a:	48a68693          	addi	a3,a3,1162 # ffffffffc02031f0 <best_fit_pmm_manager+0x280>
ffffffffc0201d6e:	00001617          	auipc	a2,0x1
ffffffffc0201d72:	c5260613          	addi	a2,a2,-942 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201d76:	07000593          	li	a1,112
ffffffffc0201d7a:	00001517          	auipc	a0,0x1
ffffffffc0201d7e:	40650513          	addi	a0,a0,1030 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0201d82:	c48fe0ef          	jal	ra,ffffffffc02001ca <__panic>
        free_page(pa2page(PADDR(page_va)));
ffffffffc0201d86:	00001617          	auipc	a2,0x1
ffffffffc0201d8a:	2da60613          	addi	a2,a2,730 # ffffffffc0203060 <best_fit_pmm_manager+0xf0>
ffffffffc0201d8e:	08c00593          	li	a1,140
ffffffffc0201d92:	00001517          	auipc	a0,0x1
ffffffffc0201d96:	3ee50513          	addi	a0,a0,1006 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0201d9a:	c30fe0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert(n > 0);
ffffffffc0201d9e:	00001697          	auipc	a3,0x1
ffffffffc0201da2:	c7268693          	addi	a3,a3,-910 # ffffffffc0202a10 <etext+0x2c8>
ffffffffc0201da6:	00001617          	auipc	a2,0x1
ffffffffc0201daa:	c1a60613          	addi	a2,a2,-998 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201dae:	07200593          	li	a1,114
ffffffffc0201db2:	00001517          	auipc	a0,0x1
ffffffffc0201db6:	3ce50513          	addi	a0,a0,974 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0201dba:	c10fe0ef          	jal	ra,ffffffffc02001ca <__panic>
        free_pages(pa2page(PADDR(page_va)), n);
ffffffffc0201dbe:	00001617          	auipc	a2,0x1
ffffffffc0201dc2:	2a260613          	addi	a2,a2,674 # ffffffffc0203060 <best_fit_pmm_manager+0xf0>
ffffffffc0201dc6:	07400593          	li	a1,116
ffffffffc0201dca:	00001517          	auipc	a0,0x1
ffffffffc0201dce:	3b650513          	addi	a0,a0,950 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0201dd2:	bf8fe0ef          	jal	ra,ffffffffc02001ca <__panic>
ffffffffc0201dd6:	a89ff0ef          	jal	ra,ffffffffc020185e <unlink_partial.part.0>

ffffffffc0201dda <slub_check>:

void slub_check(void) {
ffffffffc0201dda:	714d                	addi	sp,sp,-336
ffffffffc0201ddc:	e686                	sd	ra,328(sp)
ffffffffc0201dde:	e2a2                	sd	s0,320(sp)
ffffffffc0201de0:	fe26                	sd	s1,312(sp)
ffffffffc0201de2:	fa4a                	sd	s2,304(sp)
ffffffffc0201de4:	f64e                	sd	s3,296(sp)
ffffffffc0201de6:	f252                	sd	s4,288(sp)
ffffffffc0201de8:	ee56                	sd	s5,280(sp)
ffffffffc0201dea:	ea5a                	sd	s6,272(sp)
ffffffffc0201dec:	e65e                	sd	s7,264(sp)
ffffffffc0201dee:	e262                	sd	s8,256(sp)
ffffffffc0201df0:	fde6                	sd	s9,248(sp)
ffffffffc0201df2:	f9ea                	sd	s10,240(sp)
    static void *objects[300];
    const size_t sizes[] = {
ffffffffc0201df4:	00001797          	auipc	a5,0x1
ffffffffc0201df8:	72478793          	addi	a5,a5,1828 # ffffffffc0203518 <best_fit_pmm_manager+0x5a8>
ffffffffc0201dfc:	870a                	mv	a4,sp
ffffffffc0201dfe:	00002897          	auipc	a7,0x2
ffffffffc0201e02:	80a88893          	addi	a7,a7,-2038 # ffffffffc0203608 <best_fit_pmm_manager+0x698>
ffffffffc0201e06:	0007b803          	ld	a6,0(a5)
ffffffffc0201e0a:	6788                	ld	a0,8(a5)
ffffffffc0201e0c:	6b8c                	ld	a1,16(a5)
ffffffffc0201e0e:	6f90                	ld	a2,24(a5)
ffffffffc0201e10:	7394                	ld	a3,32(a5)
ffffffffc0201e12:	01073023          	sd	a6,0(a4)
ffffffffc0201e16:	e708                	sd	a0,8(a4)
ffffffffc0201e18:	eb0c                	sd	a1,16(a4)
ffffffffc0201e1a:	ef10                	sd	a2,24(a4)
ffffffffc0201e1c:	f314                	sd	a3,32(a4)
ffffffffc0201e1e:	02878793          	addi	a5,a5,40
ffffffffc0201e22:	02870713          	addi	a4,a4,40
ffffffffc0201e26:	ff1790e3          	bne	a5,a7,ffffffffc0201e06 <slub_check+0x2c>
        1, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128, 129,
        255, 256, 257, 511, 512, 513, 1023, 1024, 1025, 2047,
        2048, 2049, 4095, 4096, 4097, 8192, 17000
    };
    size_t baseline = nr_free_pages();
ffffffffc0201e2a:	fa0ff0ef          	jal	ra,ffffffffc02015ca <nr_free_pages>
ffffffffc0201e2e:	84aa                	mv	s1,a0
ffffffffc0201e30:	557d                	li	a0,-1
    if (!size) return NULL;
ffffffffc0201e32:	a51ff0ef          	jal	ra,ffffffffc0201882 <kmalloc.part.0>
    assert(kmalloc(0) == NULL);
    assert(kmalloc((size_t)-1) == NULL);
ffffffffc0201e36:	30051f63          	bnez	a0,ffffffffc0202154 <slub_check+0x37a>
    kfree(NULL);
    assert(nr_free_pages() == baseline);
ffffffffc0201e3a:	f90ff0ef          	jal	ra,ffffffffc02015ca <nr_free_pages>
ffffffffc0201e3e:	40951b63          	bne	a0,s1,ffffffffc0202254 <slub_check+0x47a>
ffffffffc0201e42:	890a                	mv	s2,sp
    unsigned length = sizeof(sizes) / sizeof(sizes[0]);
    for (unsigned i = 0; i < length; ++i) {
        objects[i] = kmalloc(sizes[i]);
ffffffffc0201e44:	00093c03          	ld	s8,0(s2)
ffffffffc0201e48:	00005417          	auipc	s0,0x5
ffffffffc0201e4c:	26840413          	addi	s0,s0,616 # ffffffffc02070b0 <objects.0>
ffffffffc0201e50:	8a0a                	mv	s4,sp
    assert(nr_free_pages() == baseline);
ffffffffc0201e52:	8ba2                	mv	s7,s0
ffffffffc0201e54:	89a2                	mv	s3,s0
ffffffffc0201e56:	4d05                	li	s10,1
ffffffffc0201e58:	4c81                	li	s9,0
ffffffffc0201e5a:	00005b17          	auipc	s6,0x5
ffffffffc0201e5e:	25eb0b13          	addi	s6,s6,606 # ffffffffc02070b8 <objects.0+0x8>
    for (unsigned i = 0; i < length; ++i) {
ffffffffc0201e62:	4af9                	li	s5,30
    if (!size) return NULL;
ffffffffc0201e64:	060c0563          	beqz	s8,ffffffffc0201ece <slub_check+0xf4>
ffffffffc0201e68:	8562                	mv	a0,s8
ffffffffc0201e6a:	a19ff0ef          	jal	ra,ffffffffc0201882 <kmalloc.part.0>
        objects[i] = kmalloc(sizes[i]);
ffffffffc0201e6e:	00a9b023          	sd	a0,0(s3)
ffffffffc0201e72:	832a                	mv	t1,a0
        assert(objects[i] && ((uintptr_t)objects[i] % ALIGNMENT) == 0);
ffffffffc0201e74:	c525                	beqz	a0,ffffffffc0201edc <slub_check+0x102>
ffffffffc0201e76:	00f57793          	andi	a5,a0,15
ffffffffc0201e7a:	e3ad                	bnez	a5,ffffffffc0201edc <slub_check+0x102>
        for (unsigned j = 0; j < i; ++j) {
ffffffffc0201e7c:	080c8063          	beqz	s9,ffffffffc0201efc <slub_check+0x122>
ffffffffc0201e80:	fffc859b          	addiw	a1,s9,-1
ffffffffc0201e84:	02059793          	slli	a5,a1,0x20
ffffffffc0201e88:	01d7d593          	srli	a1,a5,0x1d
            uintptr_t a = (uintptr_t)objects[i], b = (uintptr_t)objects[j];
            assert(a + sizes[i] <= b || b + sizes[j] <= a);
ffffffffc0201e8c:	00ac0833          	add	a6,s8,a0
ffffffffc0201e90:	95da                	add	a1,a1,s6
ffffffffc0201e92:	868a                	mv	a3,sp
ffffffffc0201e94:	87a2                	mv	a5,s0
            uintptr_t a = (uintptr_t)objects[i], b = (uintptr_t)objects[j];
ffffffffc0201e96:	6398                	ld	a4,0(a5)
            assert(a + sizes[i] <= b || b + sizes[j] <= a);
ffffffffc0201e98:	01077763          	bgeu	a4,a6,ffffffffc0201ea6 <slub_check+0xcc>
ffffffffc0201e9c:	0006b883          	ld	a7,0(a3)
ffffffffc0201ea0:	9746                	add	a4,a4,a7
ffffffffc0201ea2:	28e36963          	bltu	t1,a4,ffffffffc0202134 <slub_check+0x35a>
        for (unsigned j = 0; j < i; ++j) {
ffffffffc0201ea6:	07a1                	addi	a5,a5,8
ffffffffc0201ea8:	06a1                	addi	a3,a3,8
ffffffffc0201eaa:	feb796e3          	bne	a5,a1,ffffffffc0201e96 <slub_check+0xbc>
        }
        memset(objects[i], i + 1, sizes[i]);
ffffffffc0201eae:	8662                	mv	a2,s8
ffffffffc0201eb0:	0ffd7593          	zext.b	a1,s10
ffffffffc0201eb4:	851a                	mv	a0,t1
ffffffffc0201eb6:	081000ef          	jal	ra,ffffffffc0202736 <memset>
    for (unsigned i = 0; i < length; ++i) {
ffffffffc0201eba:	055d0763          	beq	s10,s5,ffffffffc0201f08 <slub_check+0x12e>
        objects[i] = kmalloc(sizes[i]);
ffffffffc0201ebe:	00893c03          	ld	s8,8(s2)
ffffffffc0201ec2:	0921                	addi	s2,s2,8
ffffffffc0201ec4:	2c85                	addiw	s9,s9,1
ffffffffc0201ec6:	2d05                	addiw	s10,s10,1
ffffffffc0201ec8:	09a1                	addi	s3,s3,8
    if (!size) return NULL;
ffffffffc0201eca:	f80c1fe3          	bnez	s8,ffffffffc0201e68 <slub_check+0x8e>
        objects[i] = kmalloc(sizes[i]);
ffffffffc0201ece:	020c9793          	slli	a5,s9,0x20
ffffffffc0201ed2:	01d7dc93          	srli	s9,a5,0x1d
ffffffffc0201ed6:	9cde                	add	s9,s9,s7
ffffffffc0201ed8:	000cb023          	sd	zero,0(s9)
        assert(objects[i] && ((uintptr_t)objects[i] % ALIGNMENT) == 0);
ffffffffc0201edc:	00001697          	auipc	a3,0x1
ffffffffc0201ee0:	43468693          	addi	a3,a3,1076 # ffffffffc0203310 <best_fit_pmm_manager+0x3a0>
ffffffffc0201ee4:	00001617          	auipc	a2,0x1
ffffffffc0201ee8:	adc60613          	addi	a2,a2,-1316 # ffffffffc02029c0 <etext+0x278>
ffffffffc0201eec:	09f00593          	li	a1,159
ffffffffc0201ef0:	00001517          	auipc	a0,0x1
ffffffffc0201ef4:	29050513          	addi	a0,a0,656 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0201ef8:	ad2fe0ef          	jal	ra,ffffffffc02001ca <__panic>
        memset(objects[i], i + 1, sizes[i]);
ffffffffc0201efc:	8662                	mv	a2,s8
ffffffffc0201efe:	0ffd7593          	zext.b	a1,s10
ffffffffc0201f02:	035000ef          	jal	ra,ffffffffc0202736 <memset>
    for (unsigned i = 0; i < length; ++i) {
ffffffffc0201f06:	bf65                	j	ffffffffc0201ebe <slub_check+0xe4>
ffffffffc0201f08:	00005597          	auipc	a1,0x5
ffffffffc0201f0c:	1a858593          	addi	a1,a1,424 # ffffffffc02070b0 <objects.0>
    }
    for (unsigned i = 0; i < length; ++i) {
ffffffffc0201f10:	4601                	li	a2,0
ffffffffc0201f12:	4579                	li	a0,30
        unsigned char *data = objects[i];
        for (size_t j = 0; j < sizes[i]; ++j) assert(data[j] == i + 1);
ffffffffc0201f14:	000a3683          	ld	a3,0(s4)
        unsigned char *data = objects[i];
ffffffffc0201f18:	619c                	ld	a5,0(a1)
    for (unsigned i = 0; i < length; ++i) {
ffffffffc0201f1a:	2605                	addiw	a2,a2,1
        for (size_t j = 0; j < sizes[i]; ++j) assert(data[j] == i + 1);
ffffffffc0201f1c:	ca89                	beqz	a3,ffffffffc0201f2e <slub_check+0x154>
ffffffffc0201f1e:	96be                	add	a3,a3,a5
ffffffffc0201f20:	0007c703          	lbu	a4,0(a5)
ffffffffc0201f24:	1ec71863          	bne	a4,a2,ffffffffc0202114 <slub_check+0x33a>
ffffffffc0201f28:	0785                	addi	a5,a5,1
ffffffffc0201f2a:	fed79be3          	bne	a5,a3,ffffffffc0201f20 <slub_check+0x146>
    for (unsigned i = 0; i < length; ++i) {
ffffffffc0201f2e:	05a1                	addi	a1,a1,8
ffffffffc0201f30:	0a21                	addi	s4,s4,8
ffffffffc0201f32:	fea611e3          	bne	a2,a0,ffffffffc0201f14 <slub_check+0x13a>
ffffffffc0201f36:	00005917          	auipc	s2,0x5
ffffffffc0201f3a:	26290913          	addi	s2,s2,610 # ffffffffc0207198 <objects.0+0xe8>
    }
    for (unsigned i = 0; i < length; ++i) kfree(objects[length - 1 - i]);
ffffffffc0201f3e:	00093503          	ld	a0,0(s2)
ffffffffc0201f42:	badff0ef          	jal	ra,ffffffffc0201aee <kfree>
ffffffffc0201f46:	87ca                	mv	a5,s2
ffffffffc0201f48:	1961                	addi	s2,s2,-8
ffffffffc0201f4a:	fe879ae3          	bne	a5,s0,ffffffffc0201f3e <slub_check+0x164>
    assert(nr_free_pages() == baseline);
ffffffffc0201f4e:	e7cff0ef          	jal	ra,ffffffffc02015ca <nr_free_pages>
ffffffffc0201f52:	2c951163          	bne	a0,s1,ffffffffc0202214 <slub_check+0x43a>
    cprintf("SLUB: size boundaries, alignment, full writes, non-overlap PASS\n");
ffffffffc0201f56:	00001517          	auipc	a0,0x1
ffffffffc0201f5a:	43250513          	addi	a0,a0,1074 # ffffffffc0203388 <best_fit_pmm_manager+0x418>
ffffffffc0201f5e:	9f6fe0ef          	jal	ra,ffffffffc0200154 <cprintf>
ffffffffc0201f62:	00005997          	auipc	s3,0x5
ffffffffc0201f66:	14e98993          	addi	s3,s3,334 # ffffffffc02070b0 <objects.0>

    for (unsigned i = 0; i < 300; ++i) {
ffffffffc0201f6a:	4901                	li	s2,0
        objects[i] = kmalloc(16);
        assert(objects[i]);
        memset(objects[i], i % 251, 16);
ffffffffc0201f6c:	0fb00a93          	li	s5,251
    for (unsigned i = 0; i < 300; ++i) {
ffffffffc0201f70:	12c00a13          	li	s4,300
    if (!size) return NULL;
ffffffffc0201f74:	4541                	li	a0,16
ffffffffc0201f76:	90dff0ef          	jal	ra,ffffffffc0201882 <kmalloc.part.0>
        objects[i] = kmalloc(16);
ffffffffc0201f7a:	00a9b023          	sd	a0,0(s3)
        assert(objects[i]);
ffffffffc0201f7e:	26050b63          	beqz	a0,ffffffffc02021f4 <slub_check+0x41a>
        memset(objects[i], i % 251, 16);
ffffffffc0201f82:	035975bb          	remuw	a1,s2,s5
ffffffffc0201f86:	4641                	li	a2,16
    for (unsigned i = 0; i < 300; ++i) {
ffffffffc0201f88:	2905                	addiw	s2,s2,1
ffffffffc0201f8a:	09a1                	addi	s3,s3,8
        memset(objects[i], i % 251, 16);
ffffffffc0201f8c:	0ff5f593          	zext.b	a1,a1
ffffffffc0201f90:	7a6000ef          	jal	ra,ffffffffc0202736 <memset>
    for (unsigned i = 0; i < 300; ++i) {
ffffffffc0201f94:	ff4910e3          	bne	s2,s4,ffffffffc0201f74 <slub_check+0x19a>
    }
    assert(nr_free_pages() <= baseline - 2);
ffffffffc0201f98:	e32ff0ef          	jal	ra,ffffffffc02015ca <nr_free_pages>
ffffffffc0201f9c:	ffe48793          	addi	a5,s1,-2
ffffffffc0201fa0:	00005817          	auipc	a6,0x5
ffffffffc0201fa4:	11080813          	addi	a6,a6,272 # ffffffffc02070b0 <objects.0>
    for (unsigned i = 0; i < 300; ++i) {
ffffffffc0201fa8:	4581                	li	a1,0
        unsigned char *data = objects[i];
        for (unsigned j = 0; j < 16; ++j) assert(data[j] == i % 251);
ffffffffc0201faa:	0fb00893          	li	a7,251
    for (unsigned i = 0; i < 300; ++i) {
ffffffffc0201fae:	12c00313          	li	t1,300
    assert(nr_free_pages() <= baseline - 2);
ffffffffc0201fb2:	28a7e163          	bltu	a5,a0,ffffffffc0202234 <slub_check+0x45a>
        for (unsigned j = 0; j < 16; ++j) assert(data[j] == i % 251);
ffffffffc0201fb6:	0315f6bb          	remuw	a3,a1,a7
ffffffffc0201fba:	00083783          	ld	a5,0(a6)
ffffffffc0201fbe:	01078613          	addi	a2,a5,16
ffffffffc0201fc2:	0007c703          	lbu	a4,0(a5)
ffffffffc0201fc6:	10d71763          	bne	a4,a3,ffffffffc02020d4 <slub_check+0x2fa>
ffffffffc0201fca:	0785                	addi	a5,a5,1
ffffffffc0201fcc:	fef61be3          	bne	a2,a5,ffffffffc0201fc2 <slub_check+0x1e8>
    for (unsigned i = 0; i < 300; ++i) {
ffffffffc0201fd0:	2585                	addiw	a1,a1,1
ffffffffc0201fd2:	0821                	addi	a6,a6,8
ffffffffc0201fd4:	fe6591e3          	bne	a1,t1,ffffffffc0201fb6 <slub_check+0x1dc>
ffffffffc0201fd8:	00006997          	auipc	s3,0x6
ffffffffc0201fdc:	a3898993          	addi	s3,s3,-1480 # ffffffffc0207a10 <is_panic>
ffffffffc0201fe0:	00005917          	auipc	s2,0x5
ffffffffc0201fe4:	0d090913          	addi	s2,s2,208 # ffffffffc02070b0 <objects.0>
    }
    for (unsigned i = 0; i < 300; i += 2) kfree(objects[i]);
ffffffffc0201fe8:	00093503          	ld	a0,0(s2)
ffffffffc0201fec:	0941                	addi	s2,s2,16
ffffffffc0201fee:	b01ff0ef          	jal	ra,ffffffffc0201aee <kfree>
ffffffffc0201ff2:	ff299be3          	bne	s3,s2,ffffffffc0201fe8 <slub_check+0x20e>
ffffffffc0201ff6:	00005917          	auipc	s2,0x5
ffffffffc0201ffa:	0ba90913          	addi	s2,s2,186 # ffffffffc02070b0 <objects.0>
    if (!size) return NULL;
ffffffffc0201ffe:	4541                	li	a0,16
ffffffffc0202000:	883ff0ef          	jal	ra,ffffffffc0201882 <kmalloc.part.0>
    for (unsigned i = 0; i < 300; i += 2) {
        objects[i] = kmalloc(16);
ffffffffc0202004:	00a93023          	sd	a0,0(s2)
        assert(objects[i]);
ffffffffc0202008:	28050663          	beqz	a0,ffffffffc0202294 <slub_check+0x4ba>
    for (unsigned i = 0; i < 300; i += 2) {
ffffffffc020200c:	0941                	addi	s2,s2,16
        memset(objects[i], 0xa5, 16);
ffffffffc020200e:	4641                	li	a2,16
ffffffffc0202010:	0a500593          	li	a1,165
ffffffffc0202014:	722000ef          	jal	ra,ffffffffc0202736 <memset>
    for (unsigned i = 0; i < 300; i += 2) {
ffffffffc0202018:	ff3913e3          	bne	s2,s3,ffffffffc0201ffe <slub_check+0x224>
ffffffffc020201c:	00005517          	auipc	a0,0x5
ffffffffc0202020:	09c50513          	addi	a0,a0,156 # ffffffffc02070b8 <objects.0+0x8>
    }
    for (unsigned i = 1; i < 300; i += 2) {
ffffffffc0202024:	4585                	li	a1,1
        unsigned char *data = objects[i];
        for (unsigned j = 0; j < 16; ++j) assert(data[j] == i % 251);
ffffffffc0202026:	0fb00893          	li	a7,251
    for (unsigned i = 1; i < 300; i += 2) {
ffffffffc020202a:	12d00813          	li	a6,301
        for (unsigned j = 0; j < 16; ++j) assert(data[j] == i % 251);
ffffffffc020202e:	0315f63b          	remuw	a2,a1,a7
ffffffffc0202032:	611c                	ld	a5,0(a0)
ffffffffc0202034:	01078693          	addi	a3,a5,16
ffffffffc0202038:	0007c703          	lbu	a4,0(a5)
ffffffffc020203c:	0ac71c63          	bne	a4,a2,ffffffffc02020f4 <slub_check+0x31a>
ffffffffc0202040:	0785                	addi	a5,a5,1
ffffffffc0202042:	fef69be3          	bne	a3,a5,ffffffffc0202038 <slub_check+0x25e>
    for (unsigned i = 1; i < 300; i += 2) {
ffffffffc0202046:	2589                	addiw	a1,a1,2
ffffffffc0202048:	0541                	addi	a0,a0,16
ffffffffc020204a:	ff0592e3          	bne	a1,a6,ffffffffc020202e <slub_check+0x254>
    }
    for (unsigned i = 0; i < 300; ++i) kfree(objects[i]);
ffffffffc020204e:	6008                	ld	a0,0(s0)
ffffffffc0202050:	0421                	addi	s0,s0,8
ffffffffc0202052:	a9dff0ef          	jal	ra,ffffffffc0201aee <kfree>
ffffffffc0202056:	ff341ce3          	bne	s0,s3,ffffffffc020204e <slub_check+0x274>
    assert(nr_free_pages() == baseline);
ffffffffc020205a:	d70ff0ef          	jal	ra,ffffffffc02015ca <nr_free_pages>
ffffffffc020205e:	10951b63          	bne	a0,s1,ffffffffc0202174 <slub_check+0x39a>
    cprintf("SLUB: multi-slab growth, full/partial transition, reuse/reclaim PASS\n");
ffffffffc0202062:	00001517          	auipc	a0,0x1
ffffffffc0202066:	3b650513          	addi	a0,a0,950 # ffffffffc0203418 <best_fit_pmm_manager+0x4a8>
ffffffffc020206a:	8eafe0ef          	jal	ra,ffffffffc0200154 <cprintf>

    /* The teaching kernel starts with one contiguous free physical interval. */
    struct Page *all = alloc_pages(baseline);
ffffffffc020206e:	8526                	mv	a0,s1
ffffffffc0202070:	d42ff0ef          	jal	ra,ffffffffc02015b2 <alloc_pages>
ffffffffc0202074:	842a                	mv	s0,a0
    assert(all != NULL && nr_free_pages() == 0);
ffffffffc0202076:	10050f63          	beqz	a0,ffffffffc0202194 <slub_check+0x3ba>
ffffffffc020207a:	d50ff0ef          	jal	ra,ffffffffc02015ca <nr_free_pages>
ffffffffc020207e:	10051b63          	bnez	a0,ffffffffc0202194 <slub_check+0x3ba>
    if (!size) return NULL;
ffffffffc0202082:	4541                	li	a0,16
ffffffffc0202084:	ffeff0ef          	jal	ra,ffffffffc0201882 <kmalloc.part.0>
    assert(kmalloc(16) == NULL && kmalloc(8192) == NULL);
ffffffffc0202088:	12051663          	bnez	a0,ffffffffc02021b4 <slub_check+0x3da>
    if (!size) return NULL;
ffffffffc020208c:	6509                	lui	a0,0x2
ffffffffc020208e:	ff4ff0ef          	jal	ra,ffffffffc0201882 <kmalloc.part.0>
    assert(kmalloc(16) == NULL && kmalloc(8192) == NULL);
ffffffffc0202092:	12051163          	bnez	a0,ffffffffc02021b4 <slub_check+0x3da>
    assert(nr_free_pages() == 0);
ffffffffc0202096:	d34ff0ef          	jal	ra,ffffffffc02015ca <nr_free_pages>
ffffffffc020209a:	12051d63          	bnez	a0,ffffffffc02021d4 <slub_check+0x3fa>
    free_pages(all, baseline);
ffffffffc020209e:	85a6                	mv	a1,s1
ffffffffc02020a0:	8522                	mv	a0,s0
ffffffffc02020a2:	d1cff0ef          	jal	ra,ffffffffc02015be <free_pages>
    assert(nr_free_pages() == baseline);
ffffffffc02020a6:	d24ff0ef          	jal	ra,ffffffffc02015ca <nr_free_pages>
ffffffffc02020aa:	1c951563          	bne	a0,s1,ffffffffc0202274 <slub_check+0x49a>
    cprintf("SLUB: zero/overflow/OOM, all checks passed; page count restored\n");
}
ffffffffc02020ae:	6416                	ld	s0,320(sp)
ffffffffc02020b0:	60b6                	ld	ra,328(sp)
ffffffffc02020b2:	74f2                	ld	s1,312(sp)
ffffffffc02020b4:	7952                	ld	s2,304(sp)
ffffffffc02020b6:	79b2                	ld	s3,296(sp)
ffffffffc02020b8:	7a12                	ld	s4,288(sp)
ffffffffc02020ba:	6af2                	ld	s5,280(sp)
ffffffffc02020bc:	6b52                	ld	s6,272(sp)
ffffffffc02020be:	6bb2                	ld	s7,264(sp)
ffffffffc02020c0:	6c12                	ld	s8,256(sp)
ffffffffc02020c2:	7cee                	ld	s9,248(sp)
ffffffffc02020c4:	7d4e                	ld	s10,240(sp)
    cprintf("SLUB: zero/overflow/OOM, all checks passed; page count restored\n");
ffffffffc02020c6:	00001517          	auipc	a0,0x1
ffffffffc02020ca:	40a50513          	addi	a0,a0,1034 # ffffffffc02034d0 <best_fit_pmm_manager+0x560>
}
ffffffffc02020ce:	6171                	addi	sp,sp,336
    cprintf("SLUB: zero/overflow/OOM, all checks passed; page count restored\n");
ffffffffc02020d0:	884fe06f          	j	ffffffffc0200154 <cprintf>
        for (unsigned j = 0; j < 16; ++j) assert(data[j] == i % 251);
ffffffffc02020d4:	00001697          	auipc	a3,0x1
ffffffffc02020d8:	32c68693          	addi	a3,a3,812 # ffffffffc0203400 <best_fit_pmm_manager+0x490>
ffffffffc02020dc:	00001617          	auipc	a2,0x1
ffffffffc02020e0:	8e460613          	addi	a2,a2,-1820 # ffffffffc02029c0 <etext+0x278>
ffffffffc02020e4:	0b600593          	li	a1,182
ffffffffc02020e8:	00001517          	auipc	a0,0x1
ffffffffc02020ec:	09850513          	addi	a0,a0,152 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc02020f0:	8dafe0ef          	jal	ra,ffffffffc02001ca <__panic>
        for (unsigned j = 0; j < 16; ++j) assert(data[j] == i % 251);
ffffffffc02020f4:	00001697          	auipc	a3,0x1
ffffffffc02020f8:	30c68693          	addi	a3,a3,780 # ffffffffc0203400 <best_fit_pmm_manager+0x490>
ffffffffc02020fc:	00001617          	auipc	a2,0x1
ffffffffc0202100:	8c460613          	addi	a2,a2,-1852 # ffffffffc02029c0 <etext+0x278>
ffffffffc0202104:	0c000593          	li	a1,192
ffffffffc0202108:	00001517          	auipc	a0,0x1
ffffffffc020210c:	07850513          	addi	a0,a0,120 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0202110:	8bafe0ef          	jal	ra,ffffffffc02001ca <__panic>
        for (size_t j = 0; j < sizes[i]; ++j) assert(data[j] == i + 1);
ffffffffc0202114:	00001697          	auipc	a3,0x1
ffffffffc0202118:	25c68693          	addi	a3,a3,604 # ffffffffc0203370 <best_fit_pmm_manager+0x400>
ffffffffc020211c:	00001617          	auipc	a2,0x1
ffffffffc0202120:	8a460613          	addi	a2,a2,-1884 # ffffffffc02029c0 <etext+0x278>
ffffffffc0202124:	0a800593          	li	a1,168
ffffffffc0202128:	00001517          	auipc	a0,0x1
ffffffffc020212c:	05850513          	addi	a0,a0,88 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0202130:	89afe0ef          	jal	ra,ffffffffc02001ca <__panic>
            assert(a + sizes[i] <= b || b + sizes[j] <= a);
ffffffffc0202134:	00001697          	auipc	a3,0x1
ffffffffc0202138:	21468693          	addi	a3,a3,532 # ffffffffc0203348 <best_fit_pmm_manager+0x3d8>
ffffffffc020213c:	00001617          	auipc	a2,0x1
ffffffffc0202140:	88460613          	addi	a2,a2,-1916 # ffffffffc02029c0 <etext+0x278>
ffffffffc0202144:	0a200593          	li	a1,162
ffffffffc0202148:	00001517          	auipc	a0,0x1
ffffffffc020214c:	03850513          	addi	a0,a0,56 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0202150:	87afe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(kmalloc((size_t)-1) == NULL);
ffffffffc0202154:	00001697          	auipc	a3,0x1
ffffffffc0202158:	17c68693          	addi	a3,a3,380 # ffffffffc02032d0 <best_fit_pmm_manager+0x360>
ffffffffc020215c:	00001617          	auipc	a2,0x1
ffffffffc0202160:	86460613          	addi	a2,a2,-1948 # ffffffffc02029c0 <etext+0x278>
ffffffffc0202164:	09900593          	li	a1,153
ffffffffc0202168:	00001517          	auipc	a0,0x1
ffffffffc020216c:	01850513          	addi	a0,a0,24 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0202170:	85afe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == baseline);
ffffffffc0202174:	00001697          	auipc	a3,0x1
ffffffffc0202178:	17c68693          	addi	a3,a3,380 # ffffffffc02032f0 <best_fit_pmm_manager+0x380>
ffffffffc020217c:	00001617          	auipc	a2,0x1
ffffffffc0202180:	84460613          	addi	a2,a2,-1980 # ffffffffc02029c0 <etext+0x278>
ffffffffc0202184:	0c300593          	li	a1,195
ffffffffc0202188:	00001517          	auipc	a0,0x1
ffffffffc020218c:	ff850513          	addi	a0,a0,-8 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0202190:	83afe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(all != NULL && nr_free_pages() == 0);
ffffffffc0202194:	00001697          	auipc	a3,0x1
ffffffffc0202198:	2cc68693          	addi	a3,a3,716 # ffffffffc0203460 <best_fit_pmm_manager+0x4f0>
ffffffffc020219c:	00001617          	auipc	a2,0x1
ffffffffc02021a0:	82460613          	addi	a2,a2,-2012 # ffffffffc02029c0 <etext+0x278>
ffffffffc02021a4:	0c800593          	li	a1,200
ffffffffc02021a8:	00001517          	auipc	a0,0x1
ffffffffc02021ac:	fd850513          	addi	a0,a0,-40 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc02021b0:	81afe0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(kmalloc(16) == NULL && kmalloc(8192) == NULL);
ffffffffc02021b4:	00001697          	auipc	a3,0x1
ffffffffc02021b8:	2d468693          	addi	a3,a3,724 # ffffffffc0203488 <best_fit_pmm_manager+0x518>
ffffffffc02021bc:	00001617          	auipc	a2,0x1
ffffffffc02021c0:	80460613          	addi	a2,a2,-2044 # ffffffffc02029c0 <etext+0x278>
ffffffffc02021c4:	0c900593          	li	a1,201
ffffffffc02021c8:	00001517          	auipc	a0,0x1
ffffffffc02021cc:	fb850513          	addi	a0,a0,-72 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc02021d0:	ffbfd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == 0);
ffffffffc02021d4:	00001697          	auipc	a3,0x1
ffffffffc02021d8:	2e468693          	addi	a3,a3,740 # ffffffffc02034b8 <best_fit_pmm_manager+0x548>
ffffffffc02021dc:	00000617          	auipc	a2,0x0
ffffffffc02021e0:	7e460613          	addi	a2,a2,2020 # ffffffffc02029c0 <etext+0x278>
ffffffffc02021e4:	0ca00593          	li	a1,202
ffffffffc02021e8:	00001517          	auipc	a0,0x1
ffffffffc02021ec:	f9850513          	addi	a0,a0,-104 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc02021f0:	fdbfd0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert(objects[i]);
ffffffffc02021f4:	00001697          	auipc	a3,0x1
ffffffffc02021f8:	1dc68693          	addi	a3,a3,476 # ffffffffc02033d0 <best_fit_pmm_manager+0x460>
ffffffffc02021fc:	00000617          	auipc	a2,0x0
ffffffffc0202200:	7c460613          	addi	a2,a2,1988 # ffffffffc02029c0 <etext+0x278>
ffffffffc0202204:	0b000593          	li	a1,176
ffffffffc0202208:	00001517          	auipc	a0,0x1
ffffffffc020220c:	f7850513          	addi	a0,a0,-136 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0202210:	fbbfd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == baseline);
ffffffffc0202214:	00001697          	auipc	a3,0x1
ffffffffc0202218:	0dc68693          	addi	a3,a3,220 # ffffffffc02032f0 <best_fit_pmm_manager+0x380>
ffffffffc020221c:	00000617          	auipc	a2,0x0
ffffffffc0202220:	7a460613          	addi	a2,a2,1956 # ffffffffc02029c0 <etext+0x278>
ffffffffc0202224:	0ab00593          	li	a1,171
ffffffffc0202228:	00001517          	auipc	a0,0x1
ffffffffc020222c:	f5850513          	addi	a0,a0,-168 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0202230:	f9bfd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() <= baseline - 2);
ffffffffc0202234:	00001697          	auipc	a3,0x1
ffffffffc0202238:	1ac68693          	addi	a3,a3,428 # ffffffffc02033e0 <best_fit_pmm_manager+0x470>
ffffffffc020223c:	00000617          	auipc	a2,0x0
ffffffffc0202240:	78460613          	addi	a2,a2,1924 # ffffffffc02029c0 <etext+0x278>
ffffffffc0202244:	0b300593          	li	a1,179
ffffffffc0202248:	00001517          	auipc	a0,0x1
ffffffffc020224c:	f3850513          	addi	a0,a0,-200 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0202250:	f7bfd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == baseline);
ffffffffc0202254:	00001697          	auipc	a3,0x1
ffffffffc0202258:	09c68693          	addi	a3,a3,156 # ffffffffc02032f0 <best_fit_pmm_manager+0x380>
ffffffffc020225c:	00000617          	auipc	a2,0x0
ffffffffc0202260:	76460613          	addi	a2,a2,1892 # ffffffffc02029c0 <etext+0x278>
ffffffffc0202264:	09b00593          	li	a1,155
ffffffffc0202268:	00001517          	auipc	a0,0x1
ffffffffc020226c:	f1850513          	addi	a0,a0,-232 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0202270:	f5bfd0ef          	jal	ra,ffffffffc02001ca <__panic>
    assert(nr_free_pages() == baseline);
ffffffffc0202274:	00001697          	auipc	a3,0x1
ffffffffc0202278:	07c68693          	addi	a3,a3,124 # ffffffffc02032f0 <best_fit_pmm_manager+0x380>
ffffffffc020227c:	00000617          	auipc	a2,0x0
ffffffffc0202280:	74460613          	addi	a2,a2,1860 # ffffffffc02029c0 <etext+0x278>
ffffffffc0202284:	0cc00593          	li	a1,204
ffffffffc0202288:	00001517          	auipc	a0,0x1
ffffffffc020228c:	ef850513          	addi	a0,a0,-264 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc0202290:	f3bfd0ef          	jal	ra,ffffffffc02001ca <__panic>
        assert(objects[i]);
ffffffffc0202294:	00001697          	auipc	a3,0x1
ffffffffc0202298:	13c68693          	addi	a3,a3,316 # ffffffffc02033d0 <best_fit_pmm_manager+0x460>
ffffffffc020229c:	00000617          	auipc	a2,0x0
ffffffffc02022a0:	72460613          	addi	a2,a2,1828 # ffffffffc02029c0 <etext+0x278>
ffffffffc02022a4:	0bb00593          	li	a1,187
ffffffffc02022a8:	00001517          	auipc	a0,0x1
ffffffffc02022ac:	ed850513          	addi	a0,a0,-296 # ffffffffc0203180 <best_fit_pmm_manager+0x210>
ffffffffc02022b0:	f1bfd0ef          	jal	ra,ffffffffc02001ca <__panic>

ffffffffc02022b4 <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc02022b4:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc02022b8:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc02022ba:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc02022be:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc02022c0:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc02022c4:	f022                	sd	s0,32(sp)
ffffffffc02022c6:	ec26                	sd	s1,24(sp)
ffffffffc02022c8:	e84a                	sd	s2,16(sp)
ffffffffc02022ca:	f406                	sd	ra,40(sp)
ffffffffc02022cc:	e44e                	sd	s3,8(sp)
ffffffffc02022ce:	84aa                	mv	s1,a0
ffffffffc02022d0:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc02022d2:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc02022d6:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc02022d8:	03067e63          	bgeu	a2,a6,ffffffffc0202314 <printnum+0x60>
ffffffffc02022dc:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc02022de:	00805763          	blez	s0,ffffffffc02022ec <printnum+0x38>
ffffffffc02022e2:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc02022e4:	85ca                	mv	a1,s2
ffffffffc02022e6:	854e                	mv	a0,s3
ffffffffc02022e8:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc02022ea:	fc65                	bnez	s0,ffffffffc02022e2 <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02022ec:	1a02                	slli	s4,s4,0x20
ffffffffc02022ee:	00001797          	auipc	a5,0x1
ffffffffc02022f2:	31a78793          	addi	a5,a5,794 # ffffffffc0203608 <best_fit_pmm_manager+0x698>
ffffffffc02022f6:	020a5a13          	srli	s4,s4,0x20
ffffffffc02022fa:	9a3e                	add	s4,s4,a5
}
ffffffffc02022fc:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02022fe:	000a4503          	lbu	a0,0(s4)
}
ffffffffc0202302:	70a2                	ld	ra,40(sp)
ffffffffc0202304:	69a2                	ld	s3,8(sp)
ffffffffc0202306:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0202308:	85ca                	mv	a1,s2
ffffffffc020230a:	87a6                	mv	a5,s1
}
ffffffffc020230c:	6942                	ld	s2,16(sp)
ffffffffc020230e:	64e2                	ld	s1,24(sp)
ffffffffc0202310:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0202312:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc0202314:	03065633          	divu	a2,a2,a6
ffffffffc0202318:	8722                	mv	a4,s0
ffffffffc020231a:	f9bff0ef          	jal	ra,ffffffffc02022b4 <printnum>
ffffffffc020231e:	b7f9                	j	ffffffffc02022ec <printnum+0x38>

ffffffffc0202320 <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc0202320:	7119                	addi	sp,sp,-128
ffffffffc0202322:	f4a6                	sd	s1,104(sp)
ffffffffc0202324:	f0ca                	sd	s2,96(sp)
ffffffffc0202326:	ecce                	sd	s3,88(sp)
ffffffffc0202328:	e8d2                	sd	s4,80(sp)
ffffffffc020232a:	e4d6                	sd	s5,72(sp)
ffffffffc020232c:	e0da                	sd	s6,64(sp)
ffffffffc020232e:	fc5e                	sd	s7,56(sp)
ffffffffc0202330:	f06a                	sd	s10,32(sp)
ffffffffc0202332:	fc86                	sd	ra,120(sp)
ffffffffc0202334:	f8a2                	sd	s0,112(sp)
ffffffffc0202336:	f862                	sd	s8,48(sp)
ffffffffc0202338:	f466                	sd	s9,40(sp)
ffffffffc020233a:	ec6e                	sd	s11,24(sp)
ffffffffc020233c:	892a                	mv	s2,a0
ffffffffc020233e:	84ae                	mv	s1,a1
ffffffffc0202340:	8d32                	mv	s10,a2
ffffffffc0202342:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0202344:	02500993          	li	s3,37
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
ffffffffc0202348:	5b7d                	li	s6,-1
ffffffffc020234a:	00001a97          	auipc	s5,0x1
ffffffffc020234e:	2f2a8a93          	addi	s5,s5,754 # ffffffffc020363c <best_fit_pmm_manager+0x6cc>
        case 'e':
            err = va_arg(ap, int);
            if (err < 0) {
                err = -err;
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0202352:	00001b97          	auipc	s7,0x1
ffffffffc0202356:	4c6b8b93          	addi	s7,s7,1222 # ffffffffc0203818 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc020235a:	000d4503          	lbu	a0,0(s10)
ffffffffc020235e:	001d0413          	addi	s0,s10,1
ffffffffc0202362:	01350a63          	beq	a0,s3,ffffffffc0202376 <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc0202366:	c121                	beqz	a0,ffffffffc02023a6 <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc0202368:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc020236a:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc020236c:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc020236e:	fff44503          	lbu	a0,-1(s0)
ffffffffc0202372:	ff351ae3          	bne	a0,s3,ffffffffc0202366 <vprintfmt+0x46>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0202376:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc020237a:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc020237e:	4c81                	li	s9,0
ffffffffc0202380:	4881                	li	a7,0
        width = precision = -1;
ffffffffc0202382:	5c7d                	li	s8,-1
ffffffffc0202384:	5dfd                	li	s11,-1
ffffffffc0202386:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc020238a:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020238c:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0202390:	0ff5f593          	zext.b	a1,a1
ffffffffc0202394:	00140d13          	addi	s10,s0,1
ffffffffc0202398:	04b56263          	bltu	a0,a1,ffffffffc02023dc <vprintfmt+0xbc>
ffffffffc020239c:	058a                	slli	a1,a1,0x2
ffffffffc020239e:	95d6                	add	a1,a1,s5
ffffffffc02023a0:	4194                	lw	a3,0(a1)
ffffffffc02023a2:	96d6                	add	a3,a3,s5
ffffffffc02023a4:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc02023a6:	70e6                	ld	ra,120(sp)
ffffffffc02023a8:	7446                	ld	s0,112(sp)
ffffffffc02023aa:	74a6                	ld	s1,104(sp)
ffffffffc02023ac:	7906                	ld	s2,96(sp)
ffffffffc02023ae:	69e6                	ld	s3,88(sp)
ffffffffc02023b0:	6a46                	ld	s4,80(sp)
ffffffffc02023b2:	6aa6                	ld	s5,72(sp)
ffffffffc02023b4:	6b06                	ld	s6,64(sp)
ffffffffc02023b6:	7be2                	ld	s7,56(sp)
ffffffffc02023b8:	7c42                	ld	s8,48(sp)
ffffffffc02023ba:	7ca2                	ld	s9,40(sp)
ffffffffc02023bc:	7d02                	ld	s10,32(sp)
ffffffffc02023be:	6de2                	ld	s11,24(sp)
ffffffffc02023c0:	6109                	addi	sp,sp,128
ffffffffc02023c2:	8082                	ret
            padc = '0';
ffffffffc02023c4:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc02023c6:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02023ca:	846a                	mv	s0,s10
ffffffffc02023cc:	00140d13          	addi	s10,s0,1
ffffffffc02023d0:	fdd6059b          	addiw	a1,a2,-35
ffffffffc02023d4:	0ff5f593          	zext.b	a1,a1
ffffffffc02023d8:	fcb572e3          	bgeu	a0,a1,ffffffffc020239c <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc02023dc:	85a6                	mv	a1,s1
ffffffffc02023de:	02500513          	li	a0,37
ffffffffc02023e2:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc02023e4:	fff44783          	lbu	a5,-1(s0)
ffffffffc02023e8:	8d22                	mv	s10,s0
ffffffffc02023ea:	f73788e3          	beq	a5,s3,ffffffffc020235a <vprintfmt+0x3a>
ffffffffc02023ee:	ffed4783          	lbu	a5,-2(s10)
ffffffffc02023f2:	1d7d                	addi	s10,s10,-1
ffffffffc02023f4:	ff379de3          	bne	a5,s3,ffffffffc02023ee <vprintfmt+0xce>
ffffffffc02023f8:	b78d                	j	ffffffffc020235a <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc02023fa:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc02023fe:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0202402:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc0202404:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc0202408:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc020240c:	02d86463          	bltu	a6,a3,ffffffffc0202434 <vprintfmt+0x114>
                ch = *fmt;
ffffffffc0202410:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc0202414:	002c169b          	slliw	a3,s8,0x2
ffffffffc0202418:	0186873b          	addw	a4,a3,s8
ffffffffc020241c:	0017171b          	slliw	a4,a4,0x1
ffffffffc0202420:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc0202422:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc0202426:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc0202428:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc020242c:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0202430:	fed870e3          	bgeu	a6,a3,ffffffffc0202410 <vprintfmt+0xf0>
            if (width < 0)
ffffffffc0202434:	f40ddce3          	bgez	s11,ffffffffc020238c <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc0202438:	8de2                	mv	s11,s8
ffffffffc020243a:	5c7d                	li	s8,-1
ffffffffc020243c:	bf81                	j	ffffffffc020238c <vprintfmt+0x6c>
            if (width < 0)
ffffffffc020243e:	fffdc693          	not	a3,s11
ffffffffc0202442:	96fd                	srai	a3,a3,0x3f
ffffffffc0202444:	00ddfdb3          	and	s11,s11,a3
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0202448:	00144603          	lbu	a2,1(s0)
ffffffffc020244c:	2d81                	sext.w	s11,s11
ffffffffc020244e:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0202450:	bf35                	j	ffffffffc020238c <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc0202452:	000a2c03          	lw	s8,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0202456:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc020245a:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020245c:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc020245e:	bfd9                	j	ffffffffc0202434 <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc0202460:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0202462:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0202466:	01174463          	blt	a4,a7,ffffffffc020246e <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc020246a:	1a088e63          	beqz	a7,ffffffffc0202626 <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc020246e:	000a3603          	ld	a2,0(s4)
ffffffffc0202472:	46c1                	li	a3,16
ffffffffc0202474:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc0202476:	2781                	sext.w	a5,a5
ffffffffc0202478:	876e                	mv	a4,s11
ffffffffc020247a:	85a6                	mv	a1,s1
ffffffffc020247c:	854a                	mv	a0,s2
ffffffffc020247e:	e37ff0ef          	jal	ra,ffffffffc02022b4 <printnum>
            break;
ffffffffc0202482:	bde1                	j	ffffffffc020235a <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc0202484:	000a2503          	lw	a0,0(s4)
ffffffffc0202488:	85a6                	mv	a1,s1
ffffffffc020248a:	0a21                	addi	s4,s4,8
ffffffffc020248c:	9902                	jalr	s2
            break;
ffffffffc020248e:	b5f1                	j	ffffffffc020235a <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0202490:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0202492:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0202496:	01174463          	blt	a4,a7,ffffffffc020249e <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc020249a:	18088163          	beqz	a7,ffffffffc020261c <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc020249e:	000a3603          	ld	a2,0(s4)
ffffffffc02024a2:	46a9                	li	a3,10
ffffffffc02024a4:	8a2e                	mv	s4,a1
ffffffffc02024a6:	bfc1                	j	ffffffffc0202476 <vprintfmt+0x156>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02024a8:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc02024ac:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02024ae:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc02024b0:	bdf1                	j	ffffffffc020238c <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc02024b2:	85a6                	mv	a1,s1
ffffffffc02024b4:	02500513          	li	a0,37
ffffffffc02024b8:	9902                	jalr	s2
            break;
ffffffffc02024ba:	b545                	j	ffffffffc020235a <vprintfmt+0x3a>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02024bc:	00144603          	lbu	a2,1(s0)
            lflag ++;
ffffffffc02024c0:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02024c2:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc02024c4:	b5e1                	j	ffffffffc020238c <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc02024c6:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc02024c8:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc02024cc:	01174463          	blt	a4,a7,ffffffffc02024d4 <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc02024d0:	14088163          	beqz	a7,ffffffffc0202612 <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc02024d4:	000a3603          	ld	a2,0(s4)
ffffffffc02024d8:	46a1                	li	a3,8
ffffffffc02024da:	8a2e                	mv	s4,a1
ffffffffc02024dc:	bf69                	j	ffffffffc0202476 <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc02024de:	03000513          	li	a0,48
ffffffffc02024e2:	85a6                	mv	a1,s1
ffffffffc02024e4:	e03e                	sd	a5,0(sp)
ffffffffc02024e6:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc02024e8:	85a6                	mv	a1,s1
ffffffffc02024ea:	07800513          	li	a0,120
ffffffffc02024ee:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc02024f0:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc02024f2:	6782                	ld	a5,0(sp)
ffffffffc02024f4:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc02024f6:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc02024fa:	bfb5                	j	ffffffffc0202476 <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc02024fc:	000a3403          	ld	s0,0(s4)
ffffffffc0202500:	008a0713          	addi	a4,s4,8
ffffffffc0202504:	e03a                	sd	a4,0(sp)
ffffffffc0202506:	14040263          	beqz	s0,ffffffffc020264a <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc020250a:	0fb05763          	blez	s11,ffffffffc02025f8 <vprintfmt+0x2d8>
ffffffffc020250e:	02d00693          	li	a3,45
ffffffffc0202512:	0cd79163          	bne	a5,a3,ffffffffc02025d4 <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0202516:	00044783          	lbu	a5,0(s0)
ffffffffc020251a:	0007851b          	sext.w	a0,a5
ffffffffc020251e:	cf85                	beqz	a5,ffffffffc0202556 <vprintfmt+0x236>
ffffffffc0202520:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0202524:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0202528:	000c4563          	bltz	s8,ffffffffc0202532 <vprintfmt+0x212>
ffffffffc020252c:	3c7d                	addiw	s8,s8,-1
ffffffffc020252e:	036c0263          	beq	s8,s6,ffffffffc0202552 <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc0202532:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0202534:	0e0c8e63          	beqz	s9,ffffffffc0202630 <vprintfmt+0x310>
ffffffffc0202538:	3781                	addiw	a5,a5,-32
ffffffffc020253a:	0ef47b63          	bgeu	s0,a5,ffffffffc0202630 <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc020253e:	03f00513          	li	a0,63
ffffffffc0202542:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0202544:	000a4783          	lbu	a5,0(s4)
ffffffffc0202548:	3dfd                	addiw	s11,s11,-1
ffffffffc020254a:	0a05                	addi	s4,s4,1
ffffffffc020254c:	0007851b          	sext.w	a0,a5
ffffffffc0202550:	ffe1                	bnez	a5,ffffffffc0202528 <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc0202552:	01b05963          	blez	s11,ffffffffc0202564 <vprintfmt+0x244>
ffffffffc0202556:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc0202558:	85a6                	mv	a1,s1
ffffffffc020255a:	02000513          	li	a0,32
ffffffffc020255e:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc0202560:	fe0d9be3          	bnez	s11,ffffffffc0202556 <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0202564:	6a02                	ld	s4,0(sp)
ffffffffc0202566:	bbd5                	j	ffffffffc020235a <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0202568:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc020256a:	008a0c93          	addi	s9,s4,8
    if (lflag >= 2) {
ffffffffc020256e:	01174463          	blt	a4,a7,ffffffffc0202576 <vprintfmt+0x256>
    else if (lflag) {
ffffffffc0202572:	08088d63          	beqz	a7,ffffffffc020260c <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc0202576:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc020257a:	0a044d63          	bltz	s0,ffffffffc0202634 <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc020257e:	8622                	mv	a2,s0
ffffffffc0202580:	8a66                	mv	s4,s9
ffffffffc0202582:	46a9                	li	a3,10
ffffffffc0202584:	bdcd                	j	ffffffffc0202476 <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc0202586:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc020258a:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc020258c:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc020258e:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc0202592:	8fb5                	xor	a5,a5,a3
ffffffffc0202594:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0202598:	02d74163          	blt	a4,a3,ffffffffc02025ba <vprintfmt+0x29a>
ffffffffc020259c:	00369793          	slli	a5,a3,0x3
ffffffffc02025a0:	97de                	add	a5,a5,s7
ffffffffc02025a2:	639c                	ld	a5,0(a5)
ffffffffc02025a4:	cb99                	beqz	a5,ffffffffc02025ba <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc02025a6:	86be                	mv	a3,a5
ffffffffc02025a8:	00001617          	auipc	a2,0x1
ffffffffc02025ac:	09060613          	addi	a2,a2,144 # ffffffffc0203638 <best_fit_pmm_manager+0x6c8>
ffffffffc02025b0:	85a6                	mv	a1,s1
ffffffffc02025b2:	854a                	mv	a0,s2
ffffffffc02025b4:	0ce000ef          	jal	ra,ffffffffc0202682 <printfmt>
ffffffffc02025b8:	b34d                	j	ffffffffc020235a <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc02025ba:	00001617          	auipc	a2,0x1
ffffffffc02025be:	06e60613          	addi	a2,a2,110 # ffffffffc0203628 <best_fit_pmm_manager+0x6b8>
ffffffffc02025c2:	85a6                	mv	a1,s1
ffffffffc02025c4:	854a                	mv	a0,s2
ffffffffc02025c6:	0bc000ef          	jal	ra,ffffffffc0202682 <printfmt>
ffffffffc02025ca:	bb41                	j	ffffffffc020235a <vprintfmt+0x3a>
                p = "(null)";
ffffffffc02025cc:	00001417          	auipc	s0,0x1
ffffffffc02025d0:	05440413          	addi	s0,s0,84 # ffffffffc0203620 <best_fit_pmm_manager+0x6b0>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02025d4:	85e2                	mv	a1,s8
ffffffffc02025d6:	8522                	mv	a0,s0
ffffffffc02025d8:	e43e                	sd	a5,8(sp)
ffffffffc02025da:	0fc000ef          	jal	ra,ffffffffc02026d6 <strnlen>
ffffffffc02025de:	40ad8dbb          	subw	s11,s11,a0
ffffffffc02025e2:	01b05b63          	blez	s11,ffffffffc02025f8 <vprintfmt+0x2d8>
                    putch(padc, putdat);
ffffffffc02025e6:	67a2                	ld	a5,8(sp)
ffffffffc02025e8:	00078a1b          	sext.w	s4,a5
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02025ec:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc02025ee:	85a6                	mv	a1,s1
ffffffffc02025f0:	8552                	mv	a0,s4
ffffffffc02025f2:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02025f4:	fe0d9ce3          	bnez	s11,ffffffffc02025ec <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02025f8:	00044783          	lbu	a5,0(s0)
ffffffffc02025fc:	00140a13          	addi	s4,s0,1
ffffffffc0202600:	0007851b          	sext.w	a0,a5
ffffffffc0202604:	d3a5                	beqz	a5,ffffffffc0202564 <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0202606:	05e00413          	li	s0,94
ffffffffc020260a:	bf39                	j	ffffffffc0202528 <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc020260c:	000a2403          	lw	s0,0(s4)
ffffffffc0202610:	b7ad                	j	ffffffffc020257a <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc0202612:	000a6603          	lwu	a2,0(s4)
ffffffffc0202616:	46a1                	li	a3,8
ffffffffc0202618:	8a2e                	mv	s4,a1
ffffffffc020261a:	bdb1                	j	ffffffffc0202476 <vprintfmt+0x156>
ffffffffc020261c:	000a6603          	lwu	a2,0(s4)
ffffffffc0202620:	46a9                	li	a3,10
ffffffffc0202622:	8a2e                	mv	s4,a1
ffffffffc0202624:	bd89                	j	ffffffffc0202476 <vprintfmt+0x156>
ffffffffc0202626:	000a6603          	lwu	a2,0(s4)
ffffffffc020262a:	46c1                	li	a3,16
ffffffffc020262c:	8a2e                	mv	s4,a1
ffffffffc020262e:	b5a1                	j	ffffffffc0202476 <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc0202630:	9902                	jalr	s2
ffffffffc0202632:	bf09                	j	ffffffffc0202544 <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc0202634:	85a6                	mv	a1,s1
ffffffffc0202636:	02d00513          	li	a0,45
ffffffffc020263a:	e03e                	sd	a5,0(sp)
ffffffffc020263c:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc020263e:	6782                	ld	a5,0(sp)
ffffffffc0202640:	8a66                	mv	s4,s9
ffffffffc0202642:	40800633          	neg	a2,s0
ffffffffc0202646:	46a9                	li	a3,10
ffffffffc0202648:	b53d                	j	ffffffffc0202476 <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc020264a:	03b05163          	blez	s11,ffffffffc020266c <vprintfmt+0x34c>
ffffffffc020264e:	02d00693          	li	a3,45
ffffffffc0202652:	f6d79de3          	bne	a5,a3,ffffffffc02025cc <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc0202656:	00001417          	auipc	s0,0x1
ffffffffc020265a:	fca40413          	addi	s0,s0,-54 # ffffffffc0203620 <best_fit_pmm_manager+0x6b0>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc020265e:	02800793          	li	a5,40
ffffffffc0202662:	02800513          	li	a0,40
ffffffffc0202666:	00140a13          	addi	s4,s0,1
ffffffffc020266a:	bd6d                	j	ffffffffc0202524 <vprintfmt+0x204>
ffffffffc020266c:	00001a17          	auipc	s4,0x1
ffffffffc0202670:	fb5a0a13          	addi	s4,s4,-75 # ffffffffc0203621 <best_fit_pmm_manager+0x6b1>
ffffffffc0202674:	02800513          	li	a0,40
ffffffffc0202678:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc020267c:	05e00413          	li	s0,94
ffffffffc0202680:	b565                	j	ffffffffc0202528 <vprintfmt+0x208>

ffffffffc0202682 <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0202682:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc0202684:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0202688:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc020268a:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc020268c:	ec06                	sd	ra,24(sp)
ffffffffc020268e:	f83a                	sd	a4,48(sp)
ffffffffc0202690:	fc3e                	sd	a5,56(sp)
ffffffffc0202692:	e0c2                	sd	a6,64(sp)
ffffffffc0202694:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc0202696:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0202698:	c89ff0ef          	jal	ra,ffffffffc0202320 <vprintfmt>
}
ffffffffc020269c:	60e2                	ld	ra,24(sp)
ffffffffc020269e:	6161                	addi	sp,sp,80
ffffffffc02026a0:	8082                	ret

ffffffffc02026a2 <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc02026a2:	4781                	li	a5,0
ffffffffc02026a4:	00005717          	auipc	a4,0x5
ffffffffc02026a8:	96c73703          	ld	a4,-1684(a4) # ffffffffc0207010 <SBI_CONSOLE_PUTCHAR>
ffffffffc02026ac:	88ba                	mv	a7,a4
ffffffffc02026ae:	852a                	mv	a0,a0
ffffffffc02026b0:	85be                	mv	a1,a5
ffffffffc02026b2:	863e                	mv	a2,a5
ffffffffc02026b4:	00000073          	ecall
ffffffffc02026b8:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc02026ba:	8082                	ret

ffffffffc02026bc <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc02026bc:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc02026c0:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc02026c2:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc02026c4:	cb81                	beqz	a5,ffffffffc02026d4 <strlen+0x18>
        cnt ++;
ffffffffc02026c6:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc02026c8:	00a707b3          	add	a5,a4,a0
ffffffffc02026cc:	0007c783          	lbu	a5,0(a5)
ffffffffc02026d0:	fbfd                	bnez	a5,ffffffffc02026c6 <strlen+0xa>
ffffffffc02026d2:	8082                	ret
    }
    return cnt;
}
ffffffffc02026d4:	8082                	ret

ffffffffc02026d6 <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc02026d6:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc02026d8:	e589                	bnez	a1,ffffffffc02026e2 <strnlen+0xc>
ffffffffc02026da:	a811                	j	ffffffffc02026ee <strnlen+0x18>
        cnt ++;
ffffffffc02026dc:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc02026de:	00f58863          	beq	a1,a5,ffffffffc02026ee <strnlen+0x18>
ffffffffc02026e2:	00f50733          	add	a4,a0,a5
ffffffffc02026e6:	00074703          	lbu	a4,0(a4)
ffffffffc02026ea:	fb6d                	bnez	a4,ffffffffc02026dc <strnlen+0x6>
ffffffffc02026ec:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc02026ee:	852e                	mv	a0,a1
ffffffffc02026f0:	8082                	ret

ffffffffc02026f2 <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc02026f2:	00054783          	lbu	a5,0(a0)
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02026f6:	0005c703          	lbu	a4,0(a1)
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc02026fa:	cb89                	beqz	a5,ffffffffc020270c <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc02026fc:	0505                	addi	a0,a0,1
ffffffffc02026fe:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0202700:	fee789e3          	beq	a5,a4,ffffffffc02026f2 <strcmp>
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0202704:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc0202708:	9d19                	subw	a0,a0,a4
ffffffffc020270a:	8082                	ret
ffffffffc020270c:	4501                	li	a0,0
ffffffffc020270e:	bfed                	j	ffffffffc0202708 <strcmp+0x16>

ffffffffc0202710 <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0202710:	c20d                	beqz	a2,ffffffffc0202732 <strncmp+0x22>
ffffffffc0202712:	962e                	add	a2,a2,a1
ffffffffc0202714:	a031                	j	ffffffffc0202720 <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc0202716:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0202718:	00e79a63          	bne	a5,a4,ffffffffc020272c <strncmp+0x1c>
ffffffffc020271c:	00b60b63          	beq	a2,a1,ffffffffc0202732 <strncmp+0x22>
ffffffffc0202720:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc0202724:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0202726:	fff5c703          	lbu	a4,-1(a1)
ffffffffc020272a:	f7f5                	bnez	a5,ffffffffc0202716 <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc020272c:	40e7853b          	subw	a0,a5,a4
}
ffffffffc0202730:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0202732:	4501                	li	a0,0
ffffffffc0202734:	8082                	ret

ffffffffc0202736 <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc0202736:	ca01                	beqz	a2,ffffffffc0202746 <memset+0x10>
ffffffffc0202738:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc020273a:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc020273c:	0785                	addi	a5,a5,1
ffffffffc020273e:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc0202742:	fec79de3          	bne	a5,a2,ffffffffc020273c <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc0202746:	8082                	ret
