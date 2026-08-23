#pragma once

#include "common.h"
#include "ConditionTree.h"
#include <math.h>

#define MAX_FACTS 300
#define NOT_FOUND NAN

typedef enum {
    BOOL, NUM, STR
} factType;

// Callback invoked after a fact changes (called outside the FactDB lock).
typedef void (*FactChangeCB)(const char* fact_name, void* user_data);

// Opaque handle. Internals (hash tables, locking) are hidden in factdb_internal.h.
typedef struct FactDB FactDB;

double   getNumFact(FactDB*, const char*);
bool     getBoolFact(FactDB*, const char*);
char*    getStringFact(FactDB*, const char*);
FactDB*  createFactDB(void);
void     deleteFactDB(FactDB*);
void     setBoolFact(FactDB*, const char*, bool);
void     setNumFact(FactDB*, const char*, double);
void     setStringFact(FactDB*, const char*, const char*);
bool     factdb_has_fact(FactDB*, const char*, factType);

// Register a callback that fires whenever a fact is set/modified.
void     factdb_on_change(FactDB*, FactChangeCB cb, void* user_data);

void printFactDB(FactDB* db);