#include "semanticChecker.h"
#include "rule.h"
#include "uthash.h"

// checks if the operator is valid
bool isOperator(const char* op){
    const char* ops[9] = {">=", "<=","==", "!=", ">", "<", "and", "or", "not"};
    for (int i = 0; i < 9; i++){
        if (strcmp(op, ops[i]) == 0)
            return true;
    }
    return false;
}


bool isComparisonCorrect(FactDB* db, const char* factname){
    // checking if factname [ a numfact ] is being compared to a bool
    BoolFact* f;
    HASH_FIND_STR(db->boolFacts, factname, f);
    if (!f)
        return true;
    return false;
}
// checks if the fact exists in the database already
bool factExists(FactDB* db, const char* fact, factType t){
    switch (t){
        case BOOL:{
            BoolFact* f;
            HASH_FIND_STR(db->boolFacts, fact, f);
            return (bool)f;
        }
        case NUM:{
            NumFact* f;
            HASH_FIND_STR(db->numFacts, fact, f);
            return (bool)f;
        }
    }
    return false;
}
// checks if the rule name already exists in the database ()
bool duplicateRule(RuleEngine* e, const char* name){
    Rule* r;
    HASH_FIND_STR(e->rules, name, r);
    return (bool)r;
}
// 
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
