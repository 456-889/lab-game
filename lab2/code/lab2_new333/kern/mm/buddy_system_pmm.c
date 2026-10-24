#include <buddy_system_pmm.h>
#include <stdio.h>
#include <string.h>

/* Private flags; PG_reserved and PG_property retain their framework meaning. */
#define B_MANAGED (1ULL << 2)
#define B_HEAD    (1ULL << 3)
#define B_TAIL    (1ULL << 4)
#define B_REQUEST_SHIFT 32
#define B_MAX_ORDER 20
static list_entry_t buddy_lists[B_MAX_ORDER + 1];
static size_t buddy_free_count;

static size_t block_size(unsigned order) { return (size_t)1 << order; }

static int request_order(size_t n) {
    if (!n || n > block_size(B_MAX_ORDER)) return -1;
    unsigned order = 0;
    while (block_size(order) < n) ++order;
    return (int)order;
}

static void buddy_init(void) {
    for (unsigned i = 0; i <= B_MAX_ORDER; ++i) list_init(&buddy_lists[i]);
    buddy_free_count = 0;
}

static void add_block(struct Page *p, unsigned order) {
    p->flags = B_MANAGED;
    p->property = block_size(order);
    SetPageProperty(p);
    list_add_before(&buddy_lists[order], &p->page_link);
}

static void remove_block(struct Page *p) {
    list_del_init(&p->page_link);
    ClearPageProperty(p);
    p->property = 0;
}

/* XOR is applied to the absolute physical page number, not a virtual address. */
static void release_block(struct Page *p, unsigned order) {
    while (order < B_MAX_ORDER) {
        size_t count = block_size(order);
        ppn_t other_ppn = page2ppn(p) ^ count;
        if (other_ppn < nbase || other_ppn >= npage ||
            count > npage - other_ppn) break;
        struct Page *other = pages + other_ppn - nbase;
        if (!(other->flags & B_MANAGED) || !PageProperty(other) ||
            other->property != count) break;
        remove_block(other);
        p->flags = B_MANAGED;
        p->property = 0;
        if (other < p) p = other;
        ++order;
    }
    add_block(p, order);
}

static void buddy_init_memmap(struct Page *base, size_t n) {
    assert(n > 0 && base >= pages);
    assert((size_t)(base - pages) < npage - nbase);
    assert(n <= npage - nbase - (size_t)(base - pages));
    for (size_t i = 0; i < n; ++i) {
        assert(PageReserved(base + i));
        base[i].flags = B_MANAGED;
        base[i].property = 0;
        base[i].ref = 0;
        list_init(&base[i].page_link);
    }
    buddy_free_count += n;
    while (n) {
        unsigned order = 0;
        ppn_t ppn = page2ppn(base);
        while (order < B_MAX_ORDER && block_size(order + 1) <= n &&
               (ppn & (block_size(order + 1) - 1)) == 0) ++order;
        size_t count = block_size(order);
        release_block(base, order);
        base += count;
        n -= count;
    }
}

static void mark_allocated(struct Page *base, size_t actual, size_t requested) {
    for (size_t i = 0; i < actual; ++i) {
        base[i].flags = B_MANAGED | B_TAIL;
        base[i].property = 0;
        base[i].ref = 0;
        list_init(&base[i].page_link);
    }
    base->flags = B_MANAGED | B_HEAD | ((uint64_t)requested << B_REQUEST_SHIFT);
    base->property = actual;
}

static struct Page *buddy_alloc_pages(size_t n) {
    int target = request_order(n);
    if (target < 0 || block_size(target) > buddy_free_count) return NULL;
    unsigned found = target;
    while (found <= B_MAX_ORDER && list_empty(&buddy_lists[found])) ++found;
    if (found > B_MAX_ORDER) return NULL;
    struct Page *p = le2page(list_next(&buddy_lists[found]), page_link);
    remove_block(p);
    while (found > (unsigned)target) {
        --found;
        add_block(p + block_size(found), found);
    }
    size_t actual = block_size(target);
    mark_allocated(p, actual, n);
    buddy_free_count -= actual;
    return p;
}

static void buddy_free_pages(struct Page *base, size_t n) {
    int order = request_order(n);
    assert(order >= 0 && base >= pages);
    assert((size_t)(base - pages) < npage - nbase);
    assert(base->flags & B_HEAD);
    assert((base->flags >> B_REQUEST_SHIFT) == n);
    size_t actual = block_size(order);
    assert(actual == base->property && actual <= npage - page2ppn(base));
    for (size_t i = 0; i < actual; ++i) {
        assert(base[i].flags & B_MANAGED);
        assert(!PageReserved(base + i) && !PageProperty(base + i));
        assert(i == 0 || (base[i].flags & B_TAIL));
    }
    for (size_t i = 0; i < actual; ++i) {
        base[i].flags = B_MANAGED;
        base[i].property = 0;
        base[i].ref = 0;
    }
    buddy_free_count += actual;
    release_block(base, order);
}

static size_t buddy_nr_free_pages(void) { return buddy_free_count; }

/* Validate the full free structure, including absence of mergeable buddies. */
static void buddy_validate(void) {
    size_t total = 0;
    for (unsigned order = 0; order <= B_MAX_ORDER; ++order) {
        size_t count = block_size(order);
        size_t visited = 0;
        for (list_entry_t *le = list_next(&buddy_lists[order]);
             le != &buddy_lists[order]; le = list_next(le)) {
            assert(++visited <= npage - nbase);
            assert(list_next(list_prev(le)) == le);
            assert(list_prev(list_next(le)) == le);
            struct Page *p = le2page(le, page_link);
            assert(PageProperty(p) && p->property == count);
            assert((page2ppn(p) & (count - 1)) == 0);
            assert(page2ppn(p) >= nbase && count <= npage - page2ppn(p));
            for (size_t j = 0; j < count; ++j) {
                assert(p[j].flags & B_MANAGED);
                assert(!PageReserved(p + j) && !(p[j].flags & (B_HEAD | B_TAIL)));
                assert(j == 0 || !PageProperty(p + j));
            }
            ppn_t other = page2ppn(p) ^ count;
            if (order < B_MAX_ORDER && other >= nbase && other < npage) {
                struct Page *b = pages + other - nbase;
                assert(!PageProperty(b) || b->property != count);
            }
            total += count;
        }
    }
    assert(total == buddy_free_count);
}

static void reserve_test_arena(struct Page *arena, size_t n) {
    for (size_t i = 0; i < n; ++i) {
        arena[i].flags = 0;
        SetPageReserved(arena + i);
        arena[i].property = 0;
        arena[i].ref = 0;
    }
    buddy_init();
}

static void buddy_check(void) {
    size_t original = buddy_free_count;
    buddy_validate();
    struct Page *arena = buddy_alloc_pages(128);
    assert(arena != NULL);
    list_entry_t saved[B_MAX_ORDER + 1];
    for (unsigned i = 0; i <= B_MAX_ORDER; ++i) saved[i] = buddy_lists[i];
    size_t saved_count = buddy_free_count;
    struct Page *held[64];

    reserve_test_arena(arena, 128);
    buddy_init_memmap(arena + 1, 61);
    assert(buddy_free_count == 61);
    buddy_validate();
    assert(buddy_alloc_pages(0) == NULL);
    assert(buddy_alloc_pages((size_t)-1) == NULL);
    assert(buddy_alloc_pages(65) == NULL);
    assert(buddy_alloc_pages(17) == NULL); /* 61 free, no aligned 32-page block */
    const size_t requests[] = {1, 2, 3, 5, 8, 9, 16};
    for (unsigned i = 0; i < sizeof(requests) / sizeof(requests[0]); ++i) {
        size_t request = requests[i];
        size_t actual = block_size(request_order(request));
        struct Page *p = buddy_alloc_pages(request);
        assert(p && p->property == actual && page_ref(p) == 0);
        assert((page2ppn(p) & (actual - 1)) == 0);
        assert(buddy_free_count == 61 - actual);
        unsigned char *data = page2kva(p);
        memset(data, 0x5a, request * PGSIZE);
        assert(data[0] == 0x5a && data[request * PGSIZE - 1] == 0x5a);
        buddy_free_pages(p, request);
        assert(buddy_free_count == 61);
        buddy_validate();
    }
    for (unsigned i = 0; i < 61; ++i) {
        held[i] = buddy_alloc_pages(1);
        assert(held[i] >= arena + 1 && held[i] < arena + 62);
        for (unsigned j = 0; j < i; ++j) assert(held[i] != held[j]);
    }
    assert(buddy_alloc_pages(1) == NULL && buddy_free_count == 0);
    for (unsigned i = 0; i < 61; ++i) buddy_free_pages(held[(i * 17) % 61], 1);
    assert(buddy_free_count == 61);
    buddy_validate();
    cprintf("Buddy: unaligned 61-page range, rounding, exhaustion PASS\n");

    reserve_test_arena(arena, 128);
    buddy_init_memmap(arena, 64);
    for (unsigned i = 0; i < 64; ++i) held[i] = buddy_alloc_pages(1);
    for (unsigned i = 0; i < 64; i += 2) buddy_free_pages(held[i], 1);
    assert(buddy_alloc_pages(2) == NULL); /* Only non-adjacent single pages. */
    for (unsigned i = 1; i < 64; i += 2) buddy_free_pages(held[i], 1);
    buddy_validate();
    struct Page *whole = buddy_alloc_pages(64);
    assert(whole == arena && buddy_free_count == 0);
    buddy_free_pages(whole, 64);
    assert(buddy_free_count == 64);
    cprintf("Buddy: recursive split, fragmentation, recursive merge PASS\n");

    reserve_test_arena(arena, 128);
    buddy_init_memmap(arena, 16);
    buddy_init_memmap(arena + 32, 16);
    buddy_validate();
    assert(buddy_free_count == 32 && buddy_alloc_pages(32) == NULL);
    assert(PageReserved(arena + 16) && PageReserved(arena + 31));
    cprintf("Buddy: disjoint ranges and reserved gap PASS\n");

    /* Restore the real allocator and release exactly the original allocation. */
    mark_allocated(arena, 128, 128);
    for (unsigned i = 0; i <= B_MAX_ORDER; ++i) buddy_lists[i] = saved[i];
    buddy_free_count = saved_count;
    buddy_free_pages(arena, 128);
    assert(buddy_free_count == original);
    buddy_validate();
    cprintf("Buddy: all checks passed; free-page count restored\n");
}

const struct pmm_manager buddy_pmm_manager = {
    .name = "buddy_pmm_manager",
    .init = buddy_init,
    .init_memmap = buddy_init_memmap,
    .alloc_pages = buddy_alloc_pages,
    .free_pages = buddy_free_pages,
    .nr_free_pages = buddy_nr_free_pages,
    .check = buddy_check,
};
