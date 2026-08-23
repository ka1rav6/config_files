#pragma once
/* PRIVATE header: real layout of ActionEntry. Internal use only. */

#include "ActionEntry.h"
#include "uthash.h"
#include <pthread.h>

struct ActionEntry {
    char action[MAX_ACTION_NAME];
    Action_f func;
    void* ctx;
    UT_hash_handle hh;
};

/* The registry is a `ActionEntry**` (hash table head) passed around by the
 * caller, so there's no single struct that "owns" a lock the way Arena or
 * FactDB do. Engine is responsible for serializing access to its own
 * action_registry -- see engine_internal.h. */