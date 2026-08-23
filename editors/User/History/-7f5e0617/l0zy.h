#pragma once


#include <yyjson.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include "factdb.h"
#include "rule.h"

bool isOperator(const char*);
bool isComparisonCorrect(FactDB*, const char*);
bool factExists(FactDB*, const char*, factType);
bool duplicateRule(RuleEngine*, const char*);
