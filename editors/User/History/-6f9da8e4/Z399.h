#pragma once
#include "rule.h"
#include "ConditionTree.h"
#include "jsonParser.h"
#include "ActionEntry.h"

typedef struct Engine{
    FactDB* db;
    RuleEngine *r_engine;
    const char* json_file;
    ActionEntry* action_registry;
} Engine;

Engine* createMainEngine(const char*);
void destroyMainEngine(Engine*);
void registerTheAction(Engine*, const char* name, Action_f, void*);
void runMainEngine(Engine*);