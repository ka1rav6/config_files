#include "semanticChecker.h"
#include "rule.h"
/*
 * checks to include:
 * 1. factname not in db but in expression [ COMPLETED ]
 * 2. unknown operator [ COMPLETED ]
 * 3. duplicate rule names [ COMPLETED ]
 * 4. and of "age" and "isAdmin" (for example) [ COMPLETED ]
 * 5. empty expressions : "and" : []  [ COMPLETED ]
 * 6. missing action / condition / name [ COMPLETED ]
 */

bool isOperator(const char* op){
    const char* ops[9] = {">=", "<=","==", "!=", ">", "<", "and", "or", "not"};
    for (int i = 0; i < 9; i++){
        if (strcmp(op, ops[i]) == 0)
            return true;
    }
    return false;
}


bool isComparisonCorrect(FactDB* db, const char* factname){
    for (int i = 0; i < db->boolCount; i++){
        if (strcmp(db->boolFacts[i].name, factname) == 0){
            return false;
        }
    }
    return true;
}

bool factExists(FactDB* db, const char* fact, factType t){
    switch (t){
        case BOOL:
            for (int i = 0 ; i < db->boolCount; i++){
                if (strcmp(db->boolFacts[i].name, fact) == 0)
                    return true;
            }
            break;
        case NUM:
            for (int i = 0 ; i < db->numCount; i++){
                if (strcmp(db->numFacts[i].name, fact) == 0)
                    return true;
            }
            break;
    }
    return false;
}

bool duplicateRule(RuleEngine* e, const char* name){
    for (int i = 0; i < e->ruleCount; i++){
        if (strcmp(e->rules[i].ruleName, name) == 0)
            return true;
    }
    return false;
}

bool isMixedBoolNumArray(FactDB* db, yyjson_val* arr){
    size_t len = yyjson_arr_size(arr);
    bool hasBool = false;
    bool hasNum  = false;

    for (size_t i = 0; i < len; i++){
        yyjson_val* elem = yyjson_arr_get(arr, i);
        if (!yyjson_is_str(elem))
            continue;
        const char* name = yyjson_get_str(elem);
        if (factExists(db, name, BOOL)) hasBool = true;
        if (factExists(db, name, NUM))  hasNum  = true;
        if (hasBool && hasNum)
            return true;
    }
    return false;
}

bool isEmptyOrUndersizedArray(yyjson_val* arr, const char* op){
    size_t len = yyjson_arr_size(arr);
    if (strcmp(op, "not") == 0)
        return len < 1;
    return len < 2;
}