#include "../../include/rule_internal.h"
#include "../../include/arena.h"
#include "../../include/bytecode.h"


// ----------- ACTUAL FUNCTIONS -------------//


void runRuleEngine(RuleEngine* e, FactDB* db)
{
    printf("=== RUNNING RULE ENGINE ===\n");
    pthread_mutex_lock(&e->lock);
    Rule *cr, *tmp;
    int evaluated = 0;
    HASH_ITER(hh, e->rules, cr, tmp)
    {
        if (!cr->dirty) continue;
        evaluated++;
        VMResult result = runBytecode(db, cr->bc);
        cr->dirty = false;
        if (result == VM_ERROR)
        {
            fprintf(stderr, "VM error evaluating rule: %s\n", cr->ruleName);
        }
        else if (result == VM_TRUE)
        {
            if (cr->func)
            {
                cr->func(db, cr->ctx);
                printf("Action Triggered: %s\n", cr->action);
            }
            else
            {
                printf("As no function is linked, no action was triggered"
                        ". The action that should have been triggered was : %s\n", cr->action);
            }
        }
    }
    pthread_mutex_unlock(&e->lock);
    if (evaluated == 0)
        printf("  (no dirty rules to evaluate)\n");
}

// simple rule constructor
Rule* createRule(RuleEngine* e, Node* n, const char* action, const char* name, void* ctx)
{
    Rule* temp      = (Rule*)arena_alloc(e->arena, sizeof(Rule));
    memset(temp, 0, sizeof(Rule));
    temp->condition = n;
    temp->bc        = compileNode(e->arena, n);
    temp->action    = arena_strdup(e->arena, action);
    strncpy(temp->ruleName, name, MAX_RULE_NAME - 1);
    temp->ruleName[MAX_RULE_NAME - 1] = '\0';
    temp->ctx       = ctx;
    temp->dirty     = true;
    collectBytecodeDeps(temp->bc, e->arena, &temp->deps, &temp->dep_count);
    return temp;
}

RuleEngine* createRuleEngine()
{
    RuleEngine* temp = (RuleEngine*)malloc(sizeof(RuleEngine));
    if (!temp)
        return NULL;

    memset(temp, 0, sizeof(RuleEngine));
    temp->arena = createArena(RULE_ENGINE_ARENA_SIZE);
    if (!temp->arena)
    {
        free(temp);
        return NULL;
    }
    if (pthread_mutex_init(&temp->lock, NULL) != 0)
    {
        destroyArena(temp->arena);
        free(temp);
        return NULL;
    }
    return temp;
}

void deleteRuleEngine(RuleEngine* RE)
{
    if (!RE) return;
    HASH_CLEAR(hh, RE->rules);
    destroyArena(RE->arena);
    pthread_mutex_destroy(&RE->lock);
    free(RE);
}

// ------------ FUNCTIONS FOR ADDING/ FINDING stuff in the hash tables --------------

// adds the rule to the rule engine
void addRule(RuleEngine* e, Rule* r)
{
    pthread_mutex_lock(&e->lock);
    HASH_ADD_STR(e->rules, ruleName, r);
    pthread_mutex_unlock(&e->lock);
}

// searches for and finds the rule in the search engine
Rule* findRule(RuleEngine* e, const char * name)
{
    pthread_mutex_lock(&e->lock);
    Rule* r;
    HASH_FIND_STR(e->rules, name, r);
    pthread_mutex_unlock(&e->lock);
    return r;
}

// Binds/rebinds the action function and context for every rule whose
// 'action' name matches. Replaces direct field-poking from outside this file.
void rule_engine_bind_action(RuleEngine* e, const char* action_name, Action_f f, void* ctx)
{
    pthread_mutex_lock(&e->lock);
    Rule *r, *tmp;
    HASH_ITER(hh, e->rules, r, tmp)
    {
        if (strcmp(r->action, action_name) == 0)
        {
            r->func = f;
            r->ctx  = ctx;
        }
    }
    pthread_mutex_unlock(&e->lock);
}

void rule_engine_mark_fact_dirty(RuleEngine* e, const char* fact_name)
{
    pthread_mutex_lock(&e->lock);
    Rule *r, *tmp;
    HASH_ITER(hh, e->rules, r, tmp)
    {
        for (int i = 0; i < r->dep_count; i++)
        {
            if (strcmp(r->deps[i], fact_name) == 0)
            {
                r->dirty = true;
                break;
            }
        }
    }
    pthread_mutex_unlock(&e->lock);
}

void rule_engine_mark_all_dirty(RuleEngine* e)
{
    pthread_mutex_lock(&e->lock);
    Rule *r, *tmp;
    HASH_ITER(hh, e->rules, r, tmp)
    {
        r->dirty = true;
    }
    pthread_mutex_unlock(&e->lock);
}

const char* rule_name(const Rule* r)
{
    return r ? r->ruleName : NULL;
}

const char* rule_action(const Rule* r)
{
    return r ? r->action : NULL;
}

Node* rule_condition(const Rule* r)
{
    return r ? r->condition : NULL;
}

// Thread-safe iteration: locks the engine once
// then calls cb() for every rule.
void rule_engine_for_each(RuleEngine* e, RuleVisitor cb, void* user_ctx)
{
    if (!e || !cb) return;
    pthread_mutex_lock(&e->lock);
    Rule *r, *tmp;
    HASH_ITER(hh, e->rules, r, tmp)
    {
        cb(r, user_ctx);
    }
    pthread_mutex_unlock(&e->lock);
}
