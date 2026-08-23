#include "../include/rule.h"
#include "../include/jsonParser.h"
#include "../include/semanticChecker.h"
#include "../include/bytecode.h"

// Checks if file exists in file system * by manually opening it and checking
static bool fileExists(const char* filename) {
    FILE* file = fopen(filename, "r");
    if (file) { fclose(file); return true; }
    return false;
}

// Parses the json with the yyjson method
static yyjson_doc* parseJSON(const char * file){
    if (!fileExists(file)) {
       FATAL("File not found: %s\n", file);
    }
    yyjson_doc * doc = yyjson_read_file(file, 0, NULL, NULL);
    if (!doc){
        FATAL("Invalid JSON format!\n");
    }
    return doc;
}

// the main AST (rule engine is built here) parses the json doc and 
// calls a function to build the fact database (hence passed as reference) 
// and creates the rule and adds it to the engine
static RuleEngine* build_ast(yyjson_doc* doc, FactDB* db, ActionEntry* g_registry){
    yyjson_val* root = yyjson_doc_get_root(doc);
    
    // Keeps FactDB completely on the standard heap
    build_factdb(db, root);
    
    yyjson_val* rulesArr = yyjson_obj_get(root, "rules");
    RuleEngine* engine = createRuleEngine(); // engine constructor

    size_t idx = 0, max = 0; // these values are modified inside the for each loop
    yyjson_val* rule = NULL;

    yyjson_arr_foreach(rulesArr, idx, max, rule){ // built in iteration of yyjson
        yyjson_val* name = yyjson_obj_get(rule, "name");
        if (!name){
            FATAL("A RULE DOES NOT HAVE A NAME!\n");
        }
        yyjson_val* action = yyjson_obj_get(rule, "action");
        if (!action){
            FATAL("The action for the rule name %s does not exist\n", yyjson_get_str(name));
        }
        yyjson_val* cond = yyjson_obj_get(rule, "if");

        Rule* r = (Rule*)arena_alloc(engine->arena, sizeof(Rule));
        memset(r, 0, sizeof(Rule));
        strcpy(r->ruleName, yyjson_get_str(name));
        r->action = arena_strdup(engine->arena, yyjson_get_str(action));
        
        ActionEntry* ae = lookupAction(g_registry, r->action);
        if (ae) {
            r->func = ae->func;
            r->ctx  = ae->ctx;
        }
        r->condition = build_node(engine->arena, db, cond);
        r->bc = compileNode(engine->arena, r->condition);
        if (duplicateRule(engine, r->ruleName)){
            FATAL("Two different rules have the same name : %s", r->ruleName);
        }
        addRule(engine, r);
    }
    yyjson_doc_free(doc);
    doc = NULL;
    return engine;
}

// main node builder function that checks the type of the node to be built and calls the appropriate function to build it
static Node* build_node(Arena* ar, FactDB* db, yyjson_val* v){
    if (yyjson_is_str(v))
        return build_fact(ar, db, v);
    if (!yyjson_is_obj(v))
        return NULL;

    yyjson_obj_iter iter;
    yyjson_obj_iter_init(v, &iter);
    yyjson_val* key;
    while ((key = yyjson_obj_iter_next(&iter))){
        const char* op = yyjson_get_str(key);
        yyjson_val* val = yyjson_obj_iter_get_val(key);
        if (!isOperator(op)){
            FATAL("Not a valid operator : %s\n", op);
        }
        if (strcmp(op, "and") == 0)
            return build_and_or(ar, db, val, NODE_AND);
        if (strcmp(op, "or") == 0)
            return build_and_or(ar, db, val, NODE_OR);
        if (strcmp(op, "not") == 0)
            return build_not(ar, db, val);

        if (strcmp(op, ">") == 0 || strcmp(op, "<") == 0 ||
            strcmp(op, ">=") == 0 || strcmp(op, "<=") == 0 ||
            strcmp(op, "==") == 0 || strcmp(op, "!=") == 0)
        {
            return build_compare(ar, db, op, val);
        }
    }
    return NULL;
}
// builds the fact node by checking if the fact exists in the fact DB and storing its name in the node
static Node* build_fact(Arena* ar, FactDB* db, yyjson_val* v){
    Node* n = createNode(ar, NODE_FACT); // Pass ar
    n->data.Fact.factName = arena_strdup(ar, yyjson_get_str(v)); // Use arena_strdup
    if (!factExists(db, n->data.Fact.factName, BOOL) && !factExists(db, n->data.Fact.factName, NUM)){
        FATAL("The fact : %s , does not exist but is used\n", n->data.Fact.factName);
    }
    return n;
}

// builds the compare node by checking the operator 
// and the operands and storing them in the node also checks for the validity of the comparison
// (e.g. comparing a bool fact with a number is not valid)    
static Node* build_compare(Arena* ar, FactDB* db, const char* op, yyjson_val* arr){
    Node* n = createNode(ar, NODE_COMPARE); // Pass ar
    n->data.Compare.val = NAN;  

    yyjson_val* left  =  yyjson_arr_get(arr, 0);  // LHS of comparison
    yyjson_val* right = yyjson_arr_get(arr, 1); // RHS of comparison

    n->data.Compare.factName = arena_strdup(ar, yyjson_get_str(left)); // string is duplicated and stored in the arena itself

    if (!isComparisonCorrect(db, n->data.Compare.factName)){ // defined in semanticChecker.c 
        FATAL("Incorrect: Tried comparing bool with number : %s\n", n->data.Compare.factName);
    }

    if (yyjson_is_int(right))  // => right is an int
        n->data.Compare.val  = (double)yyjson_get_int(right);
    if (yyjson_is_real(right)) // => right is double
         n->data.Compare.val = (double)yyjson_get_real(right);

    if (isnan(n->data.Compare.val)){
        FATAL("Invalid comparison value (NAN) for fact '%s'\n", n->data.Compare.factName);
    }
    // assigning appropriate enum according to symbol
    if (strcmp(op, ">") == 0)       
        n->data.Compare.op = OP_GT;
    else if (strcmp(op, "<" )  == 0)  
        n->data.Compare.op = OP_LT;
    else if (strcmp(op, ">=") == 0) 
        n->data.Compare.op = OP_GE;
    else if (strcmp(op, "<=") == 0)
         n->data.Compare.op = OP_LE;
    else if (strcmp(op, "==") == 0)
         n->data.Compare.op = OP_EQ;
    else if (strcmp(op, "!=") == 0)
         n->data.Compare.op = OP_NE;
 
    return n;
}

/*
 * builds the and/or nodes by iterating through the array of conditions and building the left and right nodes recursively
 * USED TO BE TWO FUNCTIONS BUT THEY WERE VERY SIMILAR SO I COMBINED THEM INTO ONE FUNCTION AND PASSED THE TYPE OF OPERATOR AS A PARAMETER
*/
static Node* build_and_or(Arena* ar, FactDB* db, yyjson_val* arr, Type t){
    const char* opName = (t == NODE_AND) ? "and" : "or";

    // semantic checking
    if (isEmptyOrUndersizedArray(arr, opName)){
        FATAL("Empty or single-element array for '%s'\n", opName);
    }
    if (isMixedBoolNumArray(db, arr)){
        FATAL("Mixed bool/num facts in '%s' expression\n", opName);
    }

    size_t len = yyjson_arr_size(arr);

    // building the node and assigning the children accordingly
    Node* left = build_node(ar, db, yyjson_arr_get(arr, 0));
    for (size_t i = 1; i < len; i++){
        Node* right = build_node(ar, db, yyjson_arr_get(arr, i));
        Node* parent = createNode(ar, t); // Pass ar
        parent->data.op.left = left;
        parent->data.op.right = right;
        left = parent;
    }
    return left;
}

// builds the not node in the similar way
static Node* build_not(Arena* ar, FactDB* db, yyjson_val* v){
    if (yyjson_is_arr(v) && isEmptyOrUndersizedArray(v, "not")){
        FATAL("Empty array for 'not'\n");
    }
    Node* n = createNode(ar, NODE_NOT); // Pass ar
    n->data.unary.child = build_node(ar, db, v);
    return n;
}

// builds the fact database by iterating through the "facts" object in the json 
// and adding each fact to the database with its value and type

static void build_factdb(FactDB* db, yyjson_val* root){
    yyjson_val* facts = yyjson_obj_get(root, "facts");
    if (!facts || !yyjson_is_obj(facts)) 
        return;

    yyjson_obj_iter iter; // the iterator
    yyjson_obj_iter_init(facts, &iter);
    yyjson_val *key, *val;

    while ((key = yyjson_obj_iter_next(&iter))) { // assigning the key in the loop itself
        const char* name = yyjson_get_str(key);
        val = yyjson_obj_iter_get_val(key);

        // setting the appropriate fact
        if (yyjson_is_bool(val)) 
            setBoolFact(db, name, yyjson_get_bool(val));
        else if (yyjson_is_int(val)) 
            setNumFact(db, name, (double)yyjson_get_int(val));
        else if (yyjson_is_real(val)) 
            setNumFact(db, name, yyjson_get_real(val));
    }
}