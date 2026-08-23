#include "arena.h"

Arena* create_arena(size_t size){
    Arena* ar = (Arena*) malloc(sizeof(Arena));
    ar->start = ask_memory(size);
    ar->used = 0;
    ar->size = size;
    return ar;
}
static inline size_t align_up(size_t n, size_t alignment){
    return (n + alignment - 1) & ~(alignment - 1);
}
char* ask_memory(size_t size){
    void* ptr = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (ptr == MAP_FAILED){
        fprintf(stderr, "Arena memory mapping failed\n");
        exit(EXIT_FAILURE);
    }
    return (char*) ptr;
}

void destory_arena(Arena* ar){
    if (munmap(ar->start, ar->size) == -1){
        fprintf(stderr, "MUNMAP FAILED!\n");
    }
    free(ar);
    ar = NULL;
}

void* arena_alloc(Arena* ar, size_t size){
     size_t aligned = align_up(ar->used, ARENA_ALIGNMENT);

    if (aligned + size > ar->size){
        fprintf(stderr, "Arena out of memory: %zu size requested", size);
        return NULL;
    }
    void* start_loc = ar->start + aligned;
    ar->used = aligned + size;
    return start_loc;
}
