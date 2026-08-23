#pragma once

#include <yyjson.h>

#include "common.h"
#include "factdb.h"
#include "rule.h"

bool isOperator(const char*);
bool isComparisonCorrect(FactDB*, const char*);
bool factExists(FactDB*, const char*, factType);
bool duplicateRule(RuleEngine*, const char*);
bool isMixedBoolNumArray(FactDB*, yyjson_val*);
bool isEmptyOrUndersizedArray(yyjson_val*, const char*);