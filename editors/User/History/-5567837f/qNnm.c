#include "rule.h"
#include "jsonParser.h"
#include "semanticChecker.h"

/*
 * Checks if file exists in file system 
 * by manually opening it and checking
 *
 * @param : filename (string)
 * @return : [bool] : true (file exists) && false (file does not exist)
 */
bool fileExists(const char* filename) {
    FILE* file = fopen(filename, "r");
    if (file) {
        fclose(file);
        return true;
    }
    return false;
}

/*
 * Parses the json with the yyjson method
 * 
 * @param : filename (string)
 * @return : a pointer to the yyjson doc
 */
yyjson_doc* parseJSON(const char * file){
    if (!fileExists(file)) {
       fprintf(stderr, "File not found: %s\n", file);
        exit(1); // exist if file does not exist
    }
    yyjson_doc * doc = yyjson_read_file(file, 0, NULL, NULL);
    if (!doc){
        fprintf(stderr, "Invalid JSON format!\n");
        exit(1); // exit if the JSON format is incorrect
    }
    return doc;
}

/*
 * the main AST (rule engine is built here)
 * parses the json doc and calls a function to build the fact database (hence passed as reference)
 * and creates the rule and adds it to the engine
 *
 * @param 1 : the yyjson_doc ptr that stores all the json data to be parsed
 * @param 2 : pointer to the fact DB that is changed in place.
 * @return : the complete engine (AST)
 */
RuleEngine* build_ast(yyjson_doc* doc, FactDB* db, ActionEntry* g_registry){
    // 1. Builds the fact DB:
    yyjson_val* root = yyjson_doc_get_root(doc);
    build_factdb(db, root);
    
    // 2. RULE ENGINE CREATION: 
    yyjson_val* rulesArr = yyjson_obj_get(root, "rules");
    RuleEngine* engine = createRuleEngine();

    size_t idx = 0, max = 0; // assigned in the foreach loop below
    yyjson_val* rule;

    yyjson_arr_foreach(rulesArr, idx, max, rule){
        yyjson_val* name = yyjson_obj_get(rule, "name"); // get key = "name" here
        if (!name){
            fprintf(stderr, "A RULE DOES NOT HAVE A NAME!\n");
            perror("");
            exit(EXIT_FAILURE);
        }
        yyjson_val* action = yyjson_obj_get(rule, "action");
        if (!action){
            fprintf(stderr, "The action for the rule name %s does not exist\n", yyjson_get_str(name));
            perror("");
            exit(EXIT_FAILURE);
        }
        yyjson_val* cond = yyjson_obj_get(rule, "if");
        if (!cond){
            fprintf(stderr, "The rule : %s, does not contain a condition!\n", yyjson_get_str(name));
        }

        Rule* r = (Rule*)malloc(sizeof(Rule));
        memset(r, 0, sizeof(Rule));
        strcpy(r->ruleName, yyjson_get_str(name));
        r->action = strdup(yyjson_get_str(action));
        ActionEntry* ae = lookupAction(g_registry, r->action);
        if (ae) {
            r->func = ae->func;
            r->ctx  = ae->ctx;
        }
        r->condition = build_node(db, cond);
        if (duplicateRule(engine, r->ruleName)){
            fprintf(stderr, "Two different rules have the same name : %s", r->ruleName);
            perror("");
            exit(EXIT_FAILURE);
        }
        addRule(engine, r);
    }
    yyjson_doc_free(doc); // free it as it is no longer needed: everything is now stored in the AST
    return engine;
}

/*
 * main node builder function that checks the type of the node to be built and calls the appropriate function to build it
 * @param 1 : pointer to the fact DB (to passing on to functions that need it to check for fact existence and type etc..)
 * @param 2 : pointer to the yyjson_val that represents the node to be built
 * @return : pointer to the built node 
 */

Node* build_node(FactDB* db, yyjson_val* v){
    // FACT STRING
    if (yyjson_is_str(v))
        return build_fact(db, v);
    if (!yyjson_is_obj(v))
        return NULL;

    yyjson_obj_iter iter;
    yyjson_obj_iter_init(v, &iter);
    yyjson_val* key;
    while ((key = yyjson_obj_iter_next(&iter))){
        const char* op = yyjson_get_str(key);
        yyjson_val* val = yyjson_obj_iter_get_val(key);
        if (!isOperator(op)){
            fprintf(stderr, "Not a valid operator : %s\n", op);
            perror("");
            exit(EXIT_FAILURE);
        }
        if (strcmp(op, "and") == 0)
            return build_and_or(db, val, NODE_AND);

        if (strcmp(op, "or") == 0)
            return build_and_or(db, val, NODE_OR);

        if (strcmp(op, "not") == 0)
            return build_not(db, val);

        if (strcmp(op, ">") == 0 ||
            strcmp(op, "<") == 0 ||
            strcmp(op, ">=") == 0 ||
            strcmp(op, "<=") == 0 ||
            strcmp(op, "==") == 0 ||
            strcmp(op, "!=") == 0)
        {
            return build_compare(db, op, val);
        }
    }
    return NULL;
}

/*
 * builds the fact node by checking if the fact exists in the fact DB and storing its name in the node
 * @param 1 : pointer to the fact DB (to check for fact existence)
 * @param 2 : pointer to the yyjson_val that represents the fact (string)
 * @return : pointer to the built fact node
*/
Node* build_fact(FactDB* db, yyjson_val* v){
    Node* n = createNode(NODE_FACT);
    n->data.Fact.factName = strdup(yyjson_get_str(v));
    if (!factExists(db, n->data.Fact.factName, BOOL) && !factExists(db, n->data.Fact.factName, NUM)){
        fprintf(stderr, "The fact : %s , does not exist but is used\n", n->data.Fact.factName);
        perror("");
        exit(EXIT_FAILURE);
    }
    return n;
}
/*
 * builds the compare node by checking the operator and the operands and storing them in the node
 * also checks for the validity of the comparison (e.g. comparing a bool fact with a number is not valid)
 * @param 1 : pointer to the fact DB (to check for fact existence and type)
 * @param 2 : operator (string)
 * @param 3 : pointer to the yyjson_val that represents the array of operands (left and right)
 * @return : pointer to the built compare node
 */    
Node* build_compare(FactDB* db, const char* op, yyjson_val* arr){
    Node* n = createNode(NODE_COMPARE);
    n->data.Compare.val = NAN;  
    yyjson_val* left = yyjson_arr_get(arr, 0);
    yyjson_val* right = yyjson_arr_get(arr, 1);
    n->data.Compare.factName = strdup(yyjson_get_str(left));
    if (!isComparisonCorrect(db, n->data.Compare.factName)){
        fprintf(stderr, "Incorrect: Tried comparing bool with number : %s\n", n->data.Compare.factName);
        perror("");
        exit(EXIT_FAILURE);
    }
    if (yyjson_is_int(right))
       n->data.Compare.val = (double)yyjson_get_int(right);

    if (yyjson_is_real(right))
        n->data.Compare.val = (double)yyjson_get_real(right);

    if (isnan(n->data.Compare.val)){ // NOT_FOUND is a preprocessor macro that is define as NAN, hence NAN is checked using isnan() function from math.
        fprintf(stderr, "Invalid comparison value (NAN) for fact '%s'\n", n->data.Compare.factName);
        perror("");
        exit(EXIT_FAILURE);
    }
    if (strcmp(op, ">") == 0) n->data.Compare.op = OP_GT;
    else if (strcmp(op, "<") == 0) n->data.Compare.op = OP_LT;
    else if (strcmp(op, ">=") == 0) n->data.Compare.op = OP_GE;
    else if (strcmp(op, "<=") == 0) n->data.Compare.op = OP_LE;
    else if (strcmp(op, "==") == 0) n->data.Compare.op = OP_EQ;
    else if (strcmp(op, "!=") == 0) n->data.Compare.op = OP_NE;
 
    return n;
}

/*
 * builds the and/or nodes by iterating through the array of conditions and building the left and right nodes recursively
 * USED TO BE TWO FUNCTIONS BUT THEY WERE VERY SIMILAR SO I COMBINED THEM INTO ONE FUNCTION AND PASSED THE TYPE OF OPERATOR AS A PARAMETER
*/
Node* build_and_or(FactDB* db, yyjson_val* arr, Type t){
    const char* opName = (t == NODE_AND) ? "and" : "or";
    if (isEmptyOrUndersizedArray(arr, opName)){
        fprintf(stderr, "Empty or single-element array for '%s'\n", opName);
        exit(EXIT_FAILURE);
    }
    if (isMixedBoolNumArray(db, arr)){
        fprintf(stderr, "Mixed bool/num facts in '%s' expression\n", opName);
        exit(EXIT_FAILURE);
    }
    size_t len = yyjson_arr_size(arr);

    Node* left = build_node(db, yyjson_arr_get(arr, 0));
    for (size_t i = 1; i < len; i++){
        Node* right = build_node(db, yyjson_arr_get(arr, i));
        Node* parent = createNode(t);
        parent->data.op.left = left;
        parent->data.op.right = right;
        left = parent;
    }
    return left;
}
/*
 * builds the not node 
*/
Node* build_not(FactDB* db, yyjson_val* v){
    if (yyjson_is_arr(v) && isEmptyOrUndersizedArray(v, "not")){
        fprintf(stderr, "Empty array for 'not'\n");
        exit(EXIT_FAILURE);
    }
    Node* n = createNode(NODE_NOT);
    n->data.unary.child = build_node(db, v);
    return n;
}
/*
 * builds the fact database by iterating through the "facts" object in the json and adding each fact to the database with its value and type
 * @param 1 : pointer to the fact DB that is changed in place.
 * @param 2 : pointer to the yyjson_val that represents the root of the json doc (to access the "facts" object)
*/
void build_factdb(FactDB* db, yyjson_val* root){
    yyjson_val* facts = yyjson_obj_get(root, "facts");

    if (!facts || !yyjson_is_obj(facts))
        return;

    yyjson_obj_iter iter;
    yyjson_obj_iter_init(facts, &iter);
    yyjson_val *key, *val;

    while ((key = yyjson_obj_iter_next(&iter))) {
        const char* name = yyjson_get_str(key);
        val = yyjson_obj_iter_get_val(key);

        if (yyjson_is_bool(val))
            setBoolFact(db, name, yyjson_get_bool(val));

        else if (yyjson_is_int(val))
            setNumFact(db, name, (double)yyjson_get_int(val));

        else if (yyjson_is_real(val))
            setNumFact(db, name, yyjson_get_real(val));
    }
}
