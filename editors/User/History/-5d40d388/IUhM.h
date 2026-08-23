#pragma once
/* PRIVATE header: real layout of Engine. Internal use only. */

#include "engine.h"
#include <pthread.h>

struct Engine {
    FactDB* db;
    RuleEngine *r_engine;
    const char* json_file;
    ActionEntry* action_registry;
    pthread_mutex_t lock; /* protects action_registry against concurrent registerTheAction calls */
};