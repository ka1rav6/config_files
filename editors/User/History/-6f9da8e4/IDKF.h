#pragma once
#include "rule.h"
#include "ConditionTree.h"
#include "jsonParser.h"
#include "ActionEntry.h"
#include "arena.h"

typedef struct Engine{
    FactDB* db;
    RuleEngine *r_engine;
    const char* json_file;
    ActionEntry* action_registry;
} Engine;

Engine* createEngine(const char*);
void deleteEngine(Engine*);
void registerTheAction(Engine*, const char* name, Action_f, void*);
void runEngine(Engine*);