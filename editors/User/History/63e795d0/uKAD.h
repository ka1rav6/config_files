#pragma once
// PRIVATE header: real layout of FactDB. Internal implementation use only.

#include "factdb.h"
#include "uthash.h"
#include <pthread.h>

typedef struct {
    UT_hash_handle hh;
    double val;
    char name[MAX_NAME];
} NumFact;

typedef struct {
    UT_hash_handle hh;
    char name[MAX_NAME];
    bool val;
} BoolFact;

typedef struct {
    UT_hash_handle hh;
    char name[MAX_NAME];
    char* val;
} StrFact;

struct FactDB {
    pthread_rwlock_t lock; // readers (getX) share, writers (setX) exclusive
    BoolFact* boolFacts;
    NumFact*  numFacts;
    StrFact*  strFacts;
    FactChangeCB on_change;   // NULL unless registered
    void* change_data;
};

bool factdb_has_bool(FactDB* db, const char* name);
bool factdb_has_num (FactDB* db, const char* name);
bool factdb_has_str (FactDB* db, const char* name);