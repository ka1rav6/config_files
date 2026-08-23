#include "rule.h"
#include "arena.h"
#include "uthash.h"

void runRuleEngine(RuleEngine* e, FactDB* db){
    printf("=== RUNNING RULE ENGINE ===\n");
    Rule *cr, *tmp;
    HASH_ITER(hh, e->rules, cr, tmp){
        if (evaluate(db, cr->condition)){
            if (cr->func){
                cr->func(db, cr->ctx);
                printf("Action Triggered: %s\n", cr->action);
            }
            else{
                printf("As no function is linked, no action was triggered"
                        ". The action that should have been triggered was : %s\n", cr->action);
            }
        }
    }
}

Rule* createRule(RuleEngine* e, Node* n, char* action, char* name, void* ctx){
    Rule* temp = (Rule*)arena_alloc(e->arena, sizeof(Rule));
    temp->condition = n;
    temp->action = arena_strdup(e->arena, action); // Safely allocate action string in the arena
    strcpy(temp->ruleName, name);
    temp->ctx = ctx;
    return temp;
}

void deleteRule(Rule* r){
    // Intentionally empty. Managed via RuleEngine teardown.
}

RuleEngine* createRuleEngine(){
    RuleEngine* temp = (RuleEngine*)malloc(sizeof(RuleEngine));
    if (!temp) { 
        printf("COULD NOT ALLOCATE SPACE FOR RULE\n"); 
        exit(EXIT_FAILURE); 
    }
    memset(temp, 0, sizeof(RuleEngine));
    temp->arena = createArena(RULE_ENGINE_ARENA_SIZE);
    return temp;
}

void deleteRuleEngine(RuleEngine* RE){
    if (!RE) return;
    Rule *current_rule, *tmp;
    HASH_ITER(hh, RE->rules, current_rule, tmp) {
        HASH_DEL(RE->rules, current_rule);
    }
    destroyArena(RE->arena);
    free(RE);
}

void addRule(RuleEngine* e, Rule* r){
    HASH_ADD_STR(e->rules, ruleName, r);
}

Rule* findRule(RuleEngine* e, const char * name){
    Rule* r;
    HASH_FIND_STR(e->rules, name, r);
    if (r) return r;
    return NULL;
}