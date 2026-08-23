#pragma once

#include "common.h"
#include <math.h>

#include "arena.h"
#include "factdb.h"
#include "bytecode.h"
#include "ConditionTree.h"

#define MAX_ACTION_NAME 64
#define MAX_RULE_NAME 64
#define MAX_RULES 1000
#define RULE_ENGINE_ARENA_SIZE (1024 * 1024) // 1MB

typedef void (*Action_f)(FactDB* db, void* ctx);

/* Opaque handles. Internals are hidden in rule_internal.h. */
typedef struct Rule Rule;
typedef struct RuleEngine RuleEngine;

void runRuleEngine(RuleEngine*, FactDB*);
Rule* createRule(RuleEngine*, Node*, char*, char*, void*);
RuleEngine* createRuleEngine(void);
void addRule(RuleEngine*, Rule*);
void deleteRuleEngine(RuleEngine*);
Rule* findRule(RuleEngine*, const char* name);

/* Lets a caller bind/rebind the action function+ctx for every rule whose
 * action name matches, without exposing the Rule struct's fields directly. */
void rule_engine_bind_action(RuleEngine* e, const char* action_name, Action_f f, void* ctx);

/* function to access ruleEngine internals*/
const char* rule_name(const Rule*);
const char* rule_action(const Rule*);
Node* rule_condition(const Rule*);

typedef void (*RuleVisitor)(Rule* r, void* user_ctx);
void rule_engine_for_each(RuleEngine* e, RuleVisitor cb, void* user_ctx);