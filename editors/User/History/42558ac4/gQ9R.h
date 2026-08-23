#pragma once

#include "uthash.h"

#include "common.h"

#include <math.h>
// custom includes
#include "ConditionTree.h"
 
#define MAX_FACTS 300
#define NOT_FOUND NAN

typedef struct{
    char name[MAX_NAME];
    double val;

    UT_hash_handle hh;
} NumFact; 

typedef struct{
    char name[MAX_NAME];
    bool val;

    UT_hash_handle hh;
} BoolFact;

typedef enum{
    BOOL, NUM
}factType;

typedef struct{
    BoolFact* boolFacts;
    NumFact* numFacts;
}FactDB;

double getNumFact(FactDB*, const char*);
bool getBoolFact(FactDB*, const char*);
bool evaluate(FactDB*, Node*);
FactDB*createFactDB();
void deleteFactDB(FactDB*);
void setBoolFact(FactDB*, const char*, bool);
void setNumFact(FactDB* db, const char*, double);
