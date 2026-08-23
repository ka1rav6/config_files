#pragma once

#include "common.h"
#include "ConditionTree.h"
#include <math.h>

#define MAX_FACTS 300
#define NOT_FOUND NAN

typedef enum{
    BOOL, NUM
} factType;

/* Opaque handle. Internals (hash tables, locking) are hidden in factdb_internal.h. */
typedef struct FactDB FactDB;

double  getNumFact  (FactDB*, const char*);
bool    getBoolFact (FactDB*, const char*);
bool    evaluate    (FactDB*, Node*);
FactDB* createFactDB(void);
void    deleteFactDB(FactDB*);
void    setBoolFact (FactDB*, const char*, bool);
void    setNumFact  (FactDB* db, const char*, double);