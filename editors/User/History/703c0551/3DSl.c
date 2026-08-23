#include "rule.h"

void run(RuleEngine* e, FactDB* db){
    printf("=== RUNNING RULE ENGINE ===\n");
    for (int i = 0; i < e->ruleCount; i ++){
        if (evaluate(db, e->rules[i].condition)){
            // TRIGGER THE ACTION
            printf("Action Triggered: %s\n", e->rules[i].action);
        }
    }
}


Rule* createRule(Node* n, char* action, char* name){
    Rule* temp = (Rule*)malloc(sizeof(Rule));
    if (temp == NULL){
        printf("COULD NOT ALLOCATE SPACE FOR RULE\n");
        exit(1);
    }
    memset(temp, 0, sizeof(Rule));
    temp->condition = n;
    temp->action = action;
    temp->ruleName = name;
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
    temp->ruleCount = 0;
    return temp;
}
void deleteRule(Rule* r){
    deleteNode(r->condition);
    free(r->action);
    r->action = NULL;
    free(r->ruleName);
    r->ruleName = NULL;
    free(r);
    r = NULL;
}

void deleteEngine(RuleEngine* RE){
    for (int i = 0; i < RE->ruleCount; i++){
        deleteNode(RE->rules[i].condition);
        free(RE->rules[i].action);
        RE->rules[i].action = NULL;
        free(RE->rules[i].ruleName);
        RE->rules[i].ruleName = NULL;
    }
    free(RE->rules);
    RE->rules = NULL;
    free(RE);
    RE = NULL;
}

void addRule(RuleEngine* e, Rule* r){
    e->rules = (Rule*)realloc(e->rules, sizeof(Rule) * (e->ruleCount + 1));
    e->rules[e->ruleCount] = *r;
    e->ruleCount++;
}