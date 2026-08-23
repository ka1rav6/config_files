#pragma once

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdbool.h>

#include "factdb.h"

#define MAX_ACTION_NAME 64
#define MAX_RULE_NAME 64
#define MAX_RULES 1000

typedef struct {
    Node* condition;
    char *action;
    char ruleName[MAX_RULE_NAME];

    UT_hash_handle hh; // makes this structure hashable [implemented using uthash]
}Rule;

typedef struct{
    Rule *rules; // a hash table of rules, where the key is the rule name and the value is the Rule struct
} RuleEngine;

void run(RuleEngine*, FactDB*);
Rule* createRule(Node*, char*, char*);
RuleEngine* createEngine();
void addRule(RuleEngine*, Rule*);
void deleteRule(Rule*);
void deleteEngine(RuleEngine*);

