#include "../include/semanticChecker.h"
#include "../include/rule.h"
#include "../include/factdb_internal.h"

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
    // checking if factname [ a numfact ] is being compared to a bool [ bool fact ]
    return !factdb_has_bool(db, factname);
}
// checks if the fact exists in the database already
bool factExists(FactDB* db, const char* fact, factType t){
    switch (t){ // hence it only has to search through one type
        case BOOL:
            return factdb_has_bool(db, fact);
        case NUM:
            return factdb_has_num(db, fact);
    }
    return false;
}
// checks if the rule name already exists in the database ()
bool duplicateRule(RuleEngine* e, const char* name){
    return findRule(e, name) != NULL;
}



/*
 * checks if the array contains a mix of bool and num facts
 * usage : to check if by accident a user is comparing a bool fact to a num fact or vice versa
 * e.g. "fact1" > "fact2" where fact1 is a bool and fact2 is a num
*/
bool isMixedBoolNumArray(FactDB* db, yyjson_val* arr){
    size_t len = yyjson_arr_size(arr);
    bool hasBool = false;
    bool hasNum  = false;

    for (size_t i = 0; i < len; i++){
        yyjson_val* elem = yyjson_arr_get(arr, i);
        if (!yyjson_is_str(elem))
            continue;
        const char* name = yyjson_get_str(elem);
        if (factExists(db, name, BOOL)) 
            hasBool = true;
        if (factExists(db, name, NUM))  
            hasNum  = true;
        if (hasBool && hasNum)
            return true;
    }
    return false;
}

/*
 * checks if the array is empty or undersized
 * usage : to check if a user is trying to apply an operator to an insufficient number of operands
 * e.g. "not" operator applied to an empty array or an array with more than 1 element
*/
bool isEmptyOrUndersizedArray(yyjson_val* arr, const char* op){
    size_t len = yyjson_arr_size(arr);
    if (strcmp(op, "not") == 0)
        return len < 1;
    return len < 2;
}