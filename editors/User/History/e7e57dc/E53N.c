#include "../include/arena_internal.h"

// aligns the allocator memory to align up (3 bytes -> 8 bytes)
static inline size_t align_up(size_t n, size_t alignment) {
    return (n + alignment - 1) & ~(alignment - 1);
}

// asks the system for memory of size "size"
char* ask_memory(size_t size) {
    void* ptr = mmap(NULL, size, PROT_READ | PROT_WRITE,
                      MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (ptr == MAP_FAILED) {
        FATAL("Arena memory mapping failed\n");
    }
    return (char*)ptr;
}

// constructor for the arena of size "size"
Arena* createArena(size_t size) {
    Arena* ar = (Arena*)malloc(sizeof(Arena));
    if (!ar) {
        FATAL("Could not allocate Arena struct\n");
    }
    ar->start = ask_memory(size);
    ar->used = 0;
    ar->size = size;
    if (pthread_mutex_init(&ar->lock, NULL) != 0) {
        FATAL("Could not initialize arena mutex\n");
    }
    return ar;
}

// allocates memory of size "size" to the arena's memory.
// Thread-safe: a per-arena mutex serializes access to the bump pointer ('used'),
// since multiple threads may try to allocate from the same arena concurrently.
void* arena_alloc(Arena* ar, size_t size) {
    if (!ar || size == 0) return NULL;

    pthread_mutex_lock(&ar->lock);

    size_t aligned = align_up(ar->used, ARENA_ALIGNMENT);
    if (size > ar->size - aligned) {
        pthread_mutex_unlock(&ar->lock);
        FATAL("Arena out of memory: %zu bytes requested\n", size);
    }
    void* loc = ar->start + aligned;
    ar->used = aligned + size;

    pthread_mutex_unlock(&ar->lock);
    return loc;
}

// the same function as normal strdup() but it allocates the new string inside the arena and
// then duplicates the string using memcpy and stores it in the arena
char* arena_strdup(Arena* ar, const char* s) {
    size_t len = strlen(s) + 1;
    // arena_alloc already takes the lock; no extra locking needed here.
    char* copy = (char*)arena_alloc(ar, len);
    if (copy) memcpy(copy, s, len);
    return copy;
}

// resets the whole arena so it is basically cleared and can be used again
void arena_reset(Arena* ar) {
    if (!ar) return;
    pthread_mutex_lock(&ar->lock);
    ar->used = 0;
    pthread_mutex_unlock(&ar->lock);
}

// destroys the arena and frees all the memory
void destroyArena(Arena* ar) {
    if (!ar) return;
    if (munmap(ar->start, ar->size) == -1)
        FATAL("MUNMAP FAILED!\n");
    pthread_mutex_destroy(&ar->lock);
    free(ar);
}