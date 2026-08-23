#include "rule.h"
#include "jsonParser.h"
#include "semanticChecker.h"

bool fileExists(const char* filename) {
    FILE* file = fopen(filename, "r");
    if (file) { fclose(file); return true; }
    return false;
}

yyjson_doc* parseJSON(const char * file){
    if (!fileExists(file)) {
       fprintf(stderr, "File not found: %s\n", file);
        exit(1);
    }
    yyjson_doc * doc = yyjson_read_file(file, 0, NULL, NULL);
    if (!doc){
        fprintf(stderr, "Invalid JSON format!\n");
        exit(1);
    }
    return doc;
}

RuleEngine* build_ast(yyjson_doc* doc, FactDB* db, ActionEntry* g_registry){
    yyjson_val* root = yyjson_doc_get_root(doc);
    
    // Keeps FactDB completely on the standard heap
    build_factdb(db, root);
    
    yyjson_val* rulesArr = yyjson_obj_get(root, "rules");
    RuleEngine* engine = createRuleEngine();

    size_t idx = 0, max = 0;
    yyjson_val* rule;

    yyjson_arr_foreach(rulesArr, idx, max, rule){
        yyjson_val* name = yyjson_obj_get(rule, "name");
        if (!name){
            fprintf(stderr, "A RULE DOES NOT HAVE A NAME!\n");
            exit(EXIT_FAILURE);
        }
        yyjson_val* action = yyjson_obj_get(rule, "action");
        if (!action){
            fprintf(stderr, "The action for the rule name %s does not exist\n", yyjson_get_str(name));
            exit(EXIT_FAILURE);
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
        if (duplicateRule(engine, r->ruleName)){
            fprintf(stderr, "Two different rules have the same name : %s", r->ruleName);
            exit(EXIT_FAILURE);
        }
        addRule(engine, r);
    }
    yyjson_doc_free(doc);
    return engine;
}

Node* build_node(Arena* ar, FactDB* db, yyjson_val* v){
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
            fprintf(stderr, "Not a valid operator : %s\n", op);
            exit(EXIT_FAILURE);
        }
        if (strcmp(op, "and") == 0) return build_and_or(ar, db, val, NODE_AND);
        if (strcmp(op, "or") == 0)  return build_and_or(ar, db, val, NODE_OR);
        if (strcmp(op, "not") == 0) return build_not(ar, db, val);

        if (strcmp(op, ">") == 0 || strcmp(op, "<") == 0 ||
            strcmp(op, ">=") == 0 || strcmp(op, "<=") == 0 ||
            strcmp(op, "==") == 0 || strcmp(op, "!=") == 0)
        {
            return build_compare(ar, db, op, val);
        }
    }
    return NULL;
}

Node* build_fact(Arena* ar, FactDB* db, yyjson_val* v){
    Node* n = createNode(ar, NODE_FACT); // Pass ar
    n->data.Fact.factName = arena_strdup(ar, yyjson_get_str(v)); // Use arena_strdup
    if (!factExists(db, n->data.Fact.factName, BOOL) && !factExists(db, n->data.Fact.factName, NUM)){
        fprintf(stderr, "The fact : %s , does not exist but is used\n", n->data.Fact.factName);
        exit(EXIT_FAILURE);
    }
    return n;
}

Node* build_compare(Arena* ar, FactDB* db, const char* op, yyjson_val* arr){
    Node* n = createNode(ar, NODE_COMPARE); // Pass ar
    n->data.Compare.val = NAN;  
    yyjson_val* left = yyjson_arr_get(arr, 0);
    yyjson_val* right = yyjson_arr_get(arr, 1);
    n->data.Compare.factName = arena_strdup(ar, yyjson_get_str(left)); 
    if (!isComparisonCorrect(db, n->data.Compare.factName)){
        fprintf(stderr, "Incorrect: Tried comparing bool with number : %s\n", n->data.Compare.factName);
        exit(EXIT_FAILURE);
    }
    if (yyjson_is_int(right))  n->data.Compare.val = (double)yyjson_get_int(right);
    if (yyjson_is_real(right)) n->data.Compare.val = (double)yyjson_get_real(right);

    if (isnan(n->data.Compare.val)){
        fprintf(stderr, "Invalid comparison value (NAN) for fact '%s'\n", n->data.Compare.factName);
        exit(EXIT_FAILURE);
    }
    if (strcmp(op, ">") == 0)       n->data.Compare.op = OP_GT;
    else if (strcmp(op, "<") == 0)  n->data.Compare.op = OP_LT;
    else if (strcmp(op, ">=") == 0) n->data.Compare.op = OP_GE;
    else if (strcmp(op, "<=") == 0) n->data.Compare.op = OP_LE;
    else if (strcmp(op, "==") == 0) n->data.Compare.op = OP_EQ;
    else if (strcmp(op, "!=") == 0) n->data.Compare.op = OP_NE;
 
    return n;
}

Node* build_and_or(Arena* ar, FactDB* db, yyjson_val* arr, Type t){
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

Node* build_not(Arena* ar, FactDB* db, yyjson_val* v){
    if (yyjson_is_arr(v) && isEmptyOrUndersizedArray(v, "not")){
        fprintf(stderr, "Empty array for 'not'\n");
        exit(EXIT_FAILURE);
    }
    Node* n = createNode(ar, NODE_NOT); // Pass ar
    n->data.unary.child = build_node(ar, db, v);
    return n;
}

void build_factdb(FactDB* db, yyjson_val* root){
    yyjson_val* facts = yyjson_obj_get(root, "facts");
    if (!facts || !yyjson_is_obj(facts)) return;

    yyjson_obj_iter iter;
    yyjson_obj_iter_init(facts, &iter);
    yyjson_val *key, *val;

    while ((key = yyjson_obj_iter_next(&iter))) {
        const char* name = yyjson_get_str(key);
        val = yyjson_obj_iter_get_val(key);
        if (yyjson_is_bool(val))        setBoolFact(db, name, yyjson_get_bool(val));
        else if (yyjson_is_int(val))    setNumFact(db, name, (double)yyjson_get_int(val));
        else if (yyjson_is_real(val))   setNumFact(db, name, yyjson_get_real(val));
    }
}