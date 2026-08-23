/*
* PRIVATE header: defines the real layout of Arena.
* Only arena.c (and tests that intentionally need internals) should include this.
*/


#pragma once
#include "arena.h"
#include <pthread.h>
#include <sys/mman.h>

#define ARENA_ALIGNMENT 8

struct Arena {
    size_t size;
    size_t used;
    char*  start;
    pthread_mutex_t lock;   // protects 'used' (and the bump pointer) across threads 
};

/* Internal-only helper, not part of the public API */
char* ask_memory(size_t size);