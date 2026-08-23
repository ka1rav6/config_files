#pragma once
#include "rule.h"
#include "ConditionTree.h"
#include "parser_engine.h"
#include "ActionEntry.h"
#include "arena.h"

// Opaque handle. Internals are hidden in engine_internal.h.
typedef struct Engine Engine;

Engine* createEngine(const char*, FileType);
void deleteEngine(Engine*);
EngineError registerTheAction(Engine*, const char* name, Action_f, void*);
EngineError runEngine(Engine*);
EngineError engine_get_last_error(const Engine*);
const char* engine_strerror(EngineError);

FactDB*     engine_get_factdb(Engine*);
RuleEngine* engine_get_rule_engine(Engine*);

// Set a fact and automatically mark dependent rules as dirty
EngineError engine_set_bool_fact(Engine*, const char* name, bool val);
EngineError engine_set_num_fact(Engine*, const char* name, double val);
EngineError engine_set_string_fact(Engine*, const char* name, const char* val);
