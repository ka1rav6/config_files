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
    BoolFact* boolFacts;
    NumFact* numFacts;
    size_t boolCount;
    size_t numCount;
}FactDB;

double getNumFact(FactDB* db, const char* name);
bool getBoolFact(FactDB* db, const char* name);
bool evaluate(FactDB* db, Node* n);
FactDB*createFactDB();
void deleteFactDB(FactDB* db);

