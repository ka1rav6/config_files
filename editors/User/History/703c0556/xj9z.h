#pragma once

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdbool.h>
#include <stdarg.h>

#include "factdb.h"

#define MAX_ACTION_NAME 64
#define MAX_RULE_NAME 64
#define MAX_RULES 1000

typedef void (*Action_f)(FactDB* db, void* ctx);


typedef struct {
    Node* condition;
    char *action;
    char ruleName[MAX_RULE_NAME];
    Action_f func;
    void* ctx;

    UT_hash_handle hh; // makes this structure hashable [implemented using uthash]
}Rule;

typedef struct{
    Rule *rules; // a hash table of rules, where the key is the rule name and the value is the Rule struct
} RuleEngine;

void runRuleEngine(RuleEngine*, FactDB*);
Rule* createRule(Node*, char*, char*, void*);
RuleEngine* createRuleEngine();
void addRule(RuleEngine*, Rule*);
void deleteRule(Rule*);
void deleteRuleEngine(RuleEngine*);
Rule* findRule(RuleEngine*, const char* name);
