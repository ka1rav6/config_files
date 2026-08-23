#include "../include/rule.h"
#include "../include/arena.h"
#include "../include/uthash.h"
#include "../include/bytecode.h"


// ----------- ACTUAL FUNCTIONS -------------//


// runs the rule engine and triggers the required action
void runRuleEngine(RuleEngine* e, FactDB* db)
{
    printf("=== RUNNING RULE ENGINE ===\n");
    Rule *cr, *tmp;
    HASH_ITER(hh, e->rules, cr, tmp){
        // runBytecode does the whole eval process
        if (runBytecode(db, cr->bc)){ // returns true only if OP_HALT instruction is present at the end.
            if (cr->func){ // if the current rule has a function assigned to it
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

// simple rule constructor
Rule* createRule(RuleEngine* e, Node* n, char* action, char* name, void* ctx)
{
    Rule* temp = (Rule*)arena_alloc(e->arena, sizeof(Rule));
    temp->condition = n;
    temp->bc = compileNode(e->arena, n);
    temp->action = arena_strdup(e->arena, action); // Safely allocate action string in the arena
    strcpy(temp->ruleName, name);
    temp->ctx = ctx;
    return temp;
}

// USED to be a rule destructor
void deleteRule(Rule* r)
{
    // Intentionally empty. Managed via RuleEngine teardown (destroy arena function).
}

// simple rule engine constructor
RuleEngine* createRuleEngine()
{
    RuleEngine* temp = (RuleEngine*)malloc(sizeof(RuleEngine));
    if (!temp) { 
        printf("COULD NOT ALLOCATE SPACE FOR RULE\n"); 
        exit(EXIT_FAILURE); 
    }
    memset(temp, 0, sizeof(RuleEngine));
    temp->arena = createArena(RULE_ENGINE_ARENA_SIZE);
    return temp;
}

// simple rule engine destructor : arena is also destroyed here
void deleteRuleEngine(RuleEngine* RE)
{
    if (!RE) return;
    Rule *current_rule, *tmp;
    HASH_ITER(hh, RE->rules, current_rule, tmp) { // iterates through all rules
        HASH_DEL(RE->rules, current_rule);
    }
    destroyArena(RE->arena);
    free(RE);
}

// ------------ FUNCTIONS FOR ADDING/ FINDING stuff in the hash tables


// adds the rule to the rule engine
void addRule(RuleEngine* e, Rule* r)
{
    HASH_ADD_STR(e->rules, ruleName, r);
}

// searches for and finds the rule in the search engine
Rule* findRule(RuleEngine* e, const char * name)
{
    Rule* r;
    HASH_FIND_STR(e->rules, name, r);
    if (r) 
        return r;
    return NULL;
}