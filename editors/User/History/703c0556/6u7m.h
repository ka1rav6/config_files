#pragma once

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdbool.h>

#include "factdb.h"

#define MAX_ACTION_NAME 64
#define MAX_RULES 1000

typedef struct {
    Node* condition;
    char action[MAX_ACTION_NAME];
}Rule;

typedef struct{
    Rule rules[MAX_RULES];
    int ruleCount;
} RuleEngine;

void run(RuleEngine*, FactDB*);
