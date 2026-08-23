#pragma once
/* PRIVATE header: real layout of FactDB. Internal implementation use only. */

#include "factdb.h"
#include "uthash.h"
#include <pthread.h>

typedef struct {
    char name[MAX_NAME];
    double val;
    UT_hash_handle hh;
} NumFact;

typedef struct {
    char name[MAX_NAME];
    bool val;
    UT_hash_handle hh;
} BoolFact;

struct FactDB {
    pthread_rwlock_t lock; /* readers (getX) share, writers (setX) exclusive */
    BoolFact* boolFacts;
    NumFact*  numFacts;
};

// Internal-only accessors needed by semanticChecker.c / jsonParser.c, which
// need to inspect raw hash membership rather than just fact values.
bool factdb_has_bool(FactDB* db, const char* name);
bool factdb_has_num(FactDB* db, const char* name);