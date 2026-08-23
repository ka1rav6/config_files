#include "rule.h"
#include "arena.h"
#include "uthash.h"

void runRuleEngine(RuleEngine* e, FactDB* db) {
    printf("=== RUNNING RULE ENGINE ===\n");
    Rule *cr, *tmp;
    HASH_ITER(hh, e->rules, cr, tmp) {
        if (evaluate(db, cr->condition)) {
            if (cr->func) {
                cr->func(db, cr->ctx);
                printf("Action Triggered: %s\n", cr->action);
            } else {
                printf("As no function is linked, no action was triggered"
                       ". The action that should have been triggered was : %s\n", cr->action);
            }
        }
    }
}

Rule* createRule(RuleEngine* e, Node* n, char* action, char* name, void* ctx) {
    Rule* temp = (Rule*)arena_alloc(e->arena, sizeof(Rule));
    temp->condition = n;
    temp->action = arena_strdup(e->arena, action); // Allocate action string inside arena
    strcpy(temp->ruleName, name);
    temp->ctx = ctx;
    return temp;
}



RuleEngine* createRuleEngine() {
    RuleEngine* temp = (RuleEngine*)malloc(sizeof(RuleEngine));
    if (!temp) { 
        printf("COULD NOT ALLOCATE SPACE FOR RULE\n"); 
        exit(EXIT_FAILURE); 
    }
    memset(temp, 0, sizeof(RuleEngine));
    temp->arena = createArena(RULE_ENGINE_ARENA_SIZE);
    return temp;
}

void deleteRuleEngine(RuleEngine* RE) {
    if (!RE) return;

    // 1. Tell uthash to free its internal hash routing infrastructure from the heap.
    // It will NOT touch the Rules themselves because we aren't calling free() on them.
    Rule *current_rule, *tmp;
    HASH_ITER(hh, RE->rules, current_rule, tmp) {
        HASH_DEL(RE->rules, current_rule);
    }

    // 2. Erase all Nodes, Strings, and Rules in one single step via the arena mapping!
    destroyArena(RE->arena);
    
    // 3. Free the rule engine envelope
    free(RE);
}