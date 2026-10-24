#include <slub.h>
#include <pmm.h>
#include <stdio.h>
#include <string.h>

/* Teaching subset of SLUB: per-size caches, in-object freelists, slab pages. */
#define SLAB_MAGIC  0x534c5542534c4142ULL
#define LARGE_MAGIC 0x534c55424c415247ULL
#define ALIGNMENT 16
#define CACHE_COUNT 8
struct slab_header {
    uint64_t magic;
    struct slab_header *prev, *next;
    void *free;
    size_t cache_index, total, inuse;
    uint64_t used[4];
};
struct large_header {
    uint64_t magic;
    size_t npages, requested, padding;
};
struct object_cache {
    size_t stride;
    struct slab_header *partial;
};
static struct object_cache caches[CACHE_COUNT];
#define SLAB_OFFSET ROUNDUP(sizeof(struct slab_header), ALIGNMENT)
#define LARGE_OFFSET ROUNDUP(sizeof(struct large_header), ALIGNMENT)

static void link_partial(struct object_cache *cache, struct slab_header *s) {
    s->prev = NULL;
    s->next = cache->partial;
    if (s->next) s->next->prev = s;
    cache->partial = s;
}

static void unlink_partial(struct object_cache *cache, struct slab_header *s) {
    if (s->prev) s->prev->next = s->next;
    else {
        assert(cache->partial == s);
        cache->partial = s->next;
    }
    if (s->next) s->next->prev = s->prev;
    s->prev = s->next = NULL;
}

void slub_init(void) {
    /* Called once after pmm_init(), before any kmalloc(). */
    for (unsigned i = 0; i < CACHE_COUNT; ++i) {
        caches[i].stride = (size_t)16 << i;
        caches[i].partial = NULL;
    }
}

static struct slab_header *new_slab(unsigned index) {
    struct Page *page = alloc_page();
    if (!page) return NULL;
    struct slab_header *s = page2kva(page);
    memset(s, 0, SLAB_OFFSET);
    s->magic = SLAB_MAGIC;
    s->cache_index = index;
    s->total = (PGSIZE - SLAB_OFFSET) / caches[index].stride;
    assert(s->total > 0 && s->total <= 256);
    unsigned char *objects = (unsigned char *)s + SLAB_OFFSET;
    for (size_t i = s->total; i > 0; --i) {
        void *object = objects + (i - 1) * caches[index].stride;
        *(void **)object = s->free;
        s->free = object;
    }
    link_partial(&caches[index], s);
    return s;
}

void *kmalloc(size_t size) {
    if (!size) return NULL;
    unsigned index = 0;
    while (index < CACHE_COUNT && caches[index].stride < size) ++index;
    if (index == CACHE_COUNT) {
        /* Check addition before rounding up. */
        if (size > (size_t)-1 - LARGE_OFFSET - (PGSIZE - 1)) return NULL;
        size_t n = (size + LARGE_OFFSET + PGSIZE - 1) / PGSIZE;
        if (n > nr_free_pages()) return NULL;
        struct Page *p = alloc_pages(n);
        if (!p) return NULL;
        struct large_header *h = page2kva(p);
        h->magic = LARGE_MAGIC;
        h->npages = n;
        h->requested = size;
        h->padding = 0;
        return (unsigned char *)h + LARGE_OFFSET;
    }
    struct object_cache *cache = &caches[index];
    struct slab_header *s = cache->partial;
    if (!s) s = new_slab(index);
    if (!s) return NULL;
    void *object = s->free;
    assert(object != NULL);
    s->free = *(void **)object;
    size_t slot = ((uintptr_t)object - (uintptr_t)s - SLAB_OFFSET) / cache->stride;
    assert(!(s->used[slot / 64] & (1ULL << (slot % 64))));
    s->used[slot / 64] |= 1ULL << (slot % 64);
    if (++s->inuse == s->total) unlink_partial(cache, s);
    return object;
}

void kfree(void *ptr) {
    if (!ptr) return;
    uintptr_t page_va = ROUNDDOWN((uintptr_t)ptr, PGSIZE);
    uint64_t magic = *(uint64_t *)page_va;
    if (magic == LARGE_MAGIC) {
        struct large_header *h = (struct large_header *)page_va;
        assert((uintptr_t)ptr == page_va + LARGE_OFFSET);
        size_t n = h->npages;
        assert(n > 0);
        h->magic = 0;
        free_pages(pa2page(PADDR(page_va)), n);
        return;
    }
    assert(magic == SLAB_MAGIC);
    struct slab_header *s = (struct slab_header *)page_va;
    assert(s->cache_index < CACHE_COUNT);
    struct object_cache *cache = &caches[s->cache_index];
    uintptr_t first = page_va + SLAB_OFFSET;
    assert((uintptr_t)ptr >= first);
    size_t offset = (uintptr_t)ptr - first;
    assert(offset % cache->stride == 0);
    size_t slot = offset / cache->stride;
    assert(slot < s->total);
    uint64_t mask = 1ULL << (slot % 64);
    assert(s->used[slot / 64] & mask);
    s->used[slot / 64] &= ~mask;
    if (s->inuse == s->total) link_partial(cache, s);
    assert(s->inuse > 0);
    --s->inuse;
    *(void **)ptr = s->free;
    s->free = ptr;
    if (s->inuse == 0) {
        unlink_partial(cache, s);
        s->magic = 0;
        free_page(pa2page(PADDR(page_va)));
    }
}

void slub_check(void) {
    static void *objects[300];
    const size_t sizes[] = {
        1, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128, 129,
        255, 256, 257, 511, 512, 513, 1023, 1024, 1025, 2047,
        2048, 2049, 4095, 4096, 4097, 8192, 17000
    };
    size_t baseline = nr_free_pages();
    assert(kmalloc(0) == NULL);
    assert(kmalloc((size_t)-1) == NULL);
    kfree(NULL);
    assert(nr_free_pages() == baseline);
    unsigned length = sizeof(sizes) / sizeof(sizes[0]);
    for (unsigned i = 0; i < length; ++i) {
        objects[i] = kmalloc(sizes[i]);
        assert(objects[i] && ((uintptr_t)objects[i] % ALIGNMENT) == 0);
        for (unsigned j = 0; j < i; ++j) {
            uintptr_t a = (uintptr_t)objects[i], b = (uintptr_t)objects[j];
            assert(a + sizes[i] <= b || b + sizes[j] <= a);
        }
        memset(objects[i], i + 1, sizes[i]);
    }
    for (unsigned i = 0; i < length; ++i) {
        unsigned char *data = objects[i];
        for (size_t j = 0; j < sizes[i]; ++j) assert(data[j] == i + 1);
    }
    for (unsigned i = 0; i < length; ++i) kfree(objects[length - 1 - i]);
    assert(nr_free_pages() == baseline);
    cprintf("SLUB: size boundaries, alignment, full writes, non-overlap PASS\n");

    for (unsigned i = 0; i < 300; ++i) {
        objects[i] = kmalloc(16);
        assert(objects[i]);
        memset(objects[i], i % 251, 16);
    }
    assert(nr_free_pages() <= baseline - 2);
    for (unsigned i = 0; i < 300; ++i) {
        unsigned char *data = objects[i];
        for (unsigned j = 0; j < 16; ++j) assert(data[j] == i % 251);
    }
    for (unsigned i = 0; i < 300; i += 2) kfree(objects[i]);
    for (unsigned i = 0; i < 300; i += 2) {
        objects[i] = kmalloc(16);
        assert(objects[i]);
        memset(objects[i], 0xa5, 16);
    }
    for (unsigned i = 1; i < 300; i += 2) {
        unsigned char *data = objects[i];
        for (unsigned j = 0; j < 16; ++j) assert(data[j] == i % 251);
    }
    for (unsigned i = 0; i < 300; ++i) kfree(objects[i]);
    assert(nr_free_pages() == baseline);
    cprintf("SLUB: multi-slab growth, full/partial transition, reuse/reclaim PASS\n");

    /* The teaching kernel starts with one contiguous free physical interval. */
    struct Page *all = alloc_pages(baseline);
    assert(all != NULL && nr_free_pages() == 0);
    assert(kmalloc(16) == NULL && kmalloc(8192) == NULL);
    assert(nr_free_pages() == 0);
    free_pages(all, baseline);
    assert(nr_free_pages() == baseline);
    cprintf("SLUB: zero/overflow/OOM, all checks passed; page count restored\n");
}
