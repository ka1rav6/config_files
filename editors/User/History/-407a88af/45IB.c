#include "ActionEntry.h"

void registerAction(ActionEntry* g_registry, const char* action, Action_f func, void* ctx) {
    ActionEntry* e = malloc(sizeof(ActionEntry));
    strcpy(e->action, action);
    e->func = func;
    e->ctx  = ctx;
    HASH_ADD_STR(g_registry, action, e);
}

ActionEntry* lookupAction(ActionEntry* g_registry, const char* action) {
    ActionEntry* e;
    HASH_FIND_STR(g_registry, action, e);
    return e;
}

void freeRegistry(ActionEntry* g_registry) {
    ActionEntry *e, *tmp;
    HASH_ITER(hh, g_registry, e, tmp) {
        HASH_DEL(g_registry, e);
        free(e);
    }
}
void registerActions(ActionEntry* reg){
    g_registry = reg;
}


ActionEntry* createEntry(ActionEntry* g_registry, const char* action, Action_f func, void* ctx){
    ActionEntry* e = (ActionEntry*)malloc(sizeof(ActionEntry));
    if (!e){
        fprintf(stderr, "Memory could not be allocated for the entry\n");
        perror("");
        exit(EXIT_FAILURE);
    }
    memset(e, 0, sizeof(ActionEntry));
    strcpy(e->action, action);
    e->func = func;
    e->ctx = ctx;
    return e;
}
