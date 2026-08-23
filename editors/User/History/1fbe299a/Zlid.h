#pragma once

#include "common.h"
#include "rule.h"

/* Opaque handle. Internals are hidden in ActionEntry_internal.h. */
typedef struct ActionEntry ActionEntry;

void registerAction(ActionEntry**, const char* action, Action_f func, void* ctx);
ActionEntry* lookupAction(ActionEntry*, const char* action);
void freeRegistry(ActionEntry**);

/* Accessors -- callers cannot read ActionEntry fields directly since the
 * struct is opaque, so lookupAction's result must go through these. */
Action_f action_entry_func(const ActionEntry*);
void*    action_entry_ctx(const ActionEntry*);