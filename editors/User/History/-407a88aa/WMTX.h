#pragma once
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include "rule.h"
#include "uthash.h"

typedef struct {
    char action[MAX_ACTION_NAME];
    Action_f func;
    void* ctx;
    UT_hash_handle hh;
} ActionEntry;

void registerAction(ActionEntry**, const char* action, Action_f func, void* ctx);
ActionEntry* lookupAction(ActionEntry*, const char* action);
void freeRegistry(ActionEntry**);