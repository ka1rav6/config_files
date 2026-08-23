#include "rule.h"
#include "uthash.h"

void run(RuleEngine* e, FactDB* db){
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

Rule* createRule(Node* n, char* action, char* name, void* ctx){
    Rule* temp = (Rule*)malloc(sizeof(Rule));
    if (temp == NULL){
        printf("COULD NOT ALLOCATE SPACE FOR RULE\n");
        exit(1);
    }
    memset(temp, 0, sizeof(Rule));
    temp->condition = n;
    temp->action = action;
    strcpy(temp->ruleName, name);
    temp->ctx = ctx;
    return temp;
}

RuleEngine* createEngine(){
    RuleEngine* temp = (RuleEngine*)malloc(sizeof(RuleEngine));
    if (temp == NULL){
    printf("COULD NOT ALLOCATE SPACE FOR RULE\n");
    exit(1);
    }
    memset(temp, 0, sizeof(RuleEngine));
    temp->rules = NULL;
    return temp;
}
void deleteRule(Rule* r){
    deleteNode(r->condition);
    free(r->action);
    r->action = NULL;
    free(r);
    r = NULL;
}

void deleteEngine(RuleEngine* RE){
    Rule* cr, *tmp;
    HASH_ITER(hh, RE->rules, cr, tmp){
        HASH_DEL(RE->rules, cr);
        deleteNode(cr->condition);
        free(cr->action);
        free(cr);
    }
    free(RE);
}

void addRule(RuleEngine* e, Rule* r){
    HASH_ADD_STR(e->rules, ruleName, r);
}

Rule* findRule(RuleEngine* e, const char * name){
    Rule* r;
    HASH_FIND_STR(e->rules, name, r);
    if (r)
        return r;
    return NULL;
}
