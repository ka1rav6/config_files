#pragma once
/* PRIVATE header: real layout of Rule and RuleEngine. Internal use only. */

#include "rule.h"
#include "uthash.h"
#include <pthread.h>

struct Rule {
    Node* condition;
    Bytecode* bc;
    char *action;
    char ruleName[MAX_RULE_NAME];
    Action_f func;
    void* ctx;

    bool dirty;           // needs re-evaluation
    const char** deps;    // fact names this rule reads (arena-allocated)
    int dep_count;
    UT_hash_handle hh;    // makes this structure hashable [implemented using uthash]
};

struct RuleEngine {
    Rule *rules;          // a hash table of rules, where the key is the rule name and the value is the Rule struct
    Arena* arena;
    pthread_mutex_t lock; // protects the 'rules' hash table and rebinding of actions/funcs
};