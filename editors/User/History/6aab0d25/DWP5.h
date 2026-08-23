#pragma once
#include "common.h"
#include <stddef.h>

/* Opaque handle: callers cannot see or touch the fields of an Arena.
 * The only way to operate on an Arena is through the functions below. */
typedef struct Arena Arena;

Arena* createArena(size_t size);
void*  arena_alloc(Arena* ar, size_t size);
char*  arena_strdup(Arena* ar, const char* s);
void   arena_reset(Arena* ar);
void   destroyArena(Arena* ar);