#include "ActionEntry.h"

void registerAction(ActionEntry** g_registry, const char* action, Action_f func, void* ctx) {
    ActionEntry* e = malloc(sizeof(ActionEntry));
    memset(e, 0, sizeof(ActionEntry));
    strcpy(e->action, action);
    e->func = func;
    e->ctx  = ctx;
    HASH_ADD_STR(*g_registry, action, e);
}

ActionEntry* lookupAction(ActionEntry* g_registry, const char* action) {
    ActionEntry* e;
    HASH_FIND_STR(g_registry, action, e);
    return e;
}

void freeRegistry(ActionEntry** g_registry) {
    ActionEntry *e, *tmp;
    HASH_ITER(hh, *g_registry, e, tmp) {
        HASH_DEL(*g_registry, e);
        free(e);
    }
}