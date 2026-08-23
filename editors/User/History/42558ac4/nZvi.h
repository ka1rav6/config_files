#pragma once

#include <string.h>
#include <math.h>
// custom includes
#include "ConditionTree.h"
 
#define MAX_FACTS 300
#define NOT_FOUND NAN

typedef struct{
    char *name;
    double val;
} NumFact;

typedef struct{
    char *name;
    bool val;
} BoolFact;

typedef struct{
    BoolFact boolFacts[MAX_FACTS];
    NumFact numFacts[MAX_FACTS];
    size_t boolCount;
    size_t numCount;
}FactDB;

double getNumFact(FactDB*, const char*);
bool getBoolFact(FactDB*, const char*);
bool evaluate(FactDB*, Node*);
FactDB*createFactDB();
void deleteFactDB(FactDB*);
void setBoolFact(FactDB*, const char*, bool);
void setNumFact(FactDB* db, const char*, double);
