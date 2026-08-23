// arena.h
#pragma once
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <stddef.h>

#define ARENA_ALIGNMENT 8

typedef struct {
    size_t size;
    size_t used;
    char*  start;
} Arena;

char* ask_memory(size_t size);
Arena* createArena(size_t size);
void* arena_alloc(Arena* ar, size_t size);
char* arena_strdup(Arena* ar, const char* s);
void arena_reset(Arena* ar);
void destroyArena(Arena* ar);