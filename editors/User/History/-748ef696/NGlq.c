#include "../../include/rule_internal.h"
#include "../../include/parser_engine.h"
#include "../../include/semanticChecker.h"
#include "../../include/bytecode.h"
#include <yyjson.h>

static Node* build_node(Arena*, FactDB*, yyjson_val*, EngineError*);
static Node* build_and_or(Arena*, FactDB*, yyjson_val*, Type, EngineError*);
static Node* build_fact(Arena*, FactDB*, yyjson_val*, EngineError*);
static Node* build_not(Arena*, FactDB*, yyjson_val*, EngineError*);
static Node* build_null(Arena*, FactDB*, yyjson_val*, EngineError*);
static Node* build_compare(Arena*, FactDB*, const char*, yyjson_val*, EngineError*);
static void build_factdb(FactDB*, yyjson_val*);

static bool fileExists(const char* filename)
{
    FILE* file = fopen(filename, "r");
    if (file)
    {
        fclose(file);
        return true;
    }
    return false;
}

yyjson_doc* parseJSON(const char* file)
{
    if (!fileExists(file))
        return NULL;
    yyjson_doc* doc = yyjson_read_file(file, 0, NULL, NULL);
    return doc;
}

RuleEngine* build_ast(yyjson_doc* doc, FactDB* db, EngineError* err)
{
    yyjson_val* root = yyjson_doc_get_root(doc);

    build_factdb(db, root);

    yyjson_val* rulesArr = yyjson_obj_get(root, "rules");
    RuleEngine* engine = createRuleEngine();
    if (!engine)
    {
        if (err) *err = ENGINE_ERR_OUT_OF_MEMORY;
        yyjson_doc_free(doc);
        return NULL;
    }

    size_t idx = 0;
    size_t max = 0;
    yyjson_val* rule = NULL;

    yyjson_arr_foreach(rulesArr, idx, max, rule)
    {
        yyjson_val* name = yyjson_obj_get(rule, "name");
        if (!name)
        {
            if (err) *err = ENGINE_ERR_MISSING_RULE_NAME;
            yyjson_doc_free(doc);
            deleteRuleEngine(engine);
            return NULL;
        }
        yyjson_val* action = yyjson_obj_get(rule, "action");
        if (!action)
        {
            if (err) *err = ENGINE_ERR_MISSING_RULE_ACTION;
            yyjson_doc_free(doc);
            deleteRuleEngine(engine);
            return NULL;
        }
        yyjson_val* cond = yyjson_obj_get(rule, "if");

        Rule* r = (Rule*)arena_alloc(engine->arena, sizeof(Rule));
        if (!r)
        {
            if (err) *err = ENGINE_ERR_ARENA_OOM;
            yyjson_doc_free(doc);
            deleteRuleEngine(engine);
            return NULL;
        }
        memset(r, 0, sizeof(Rule));
        strncpy(r->ruleName, yyjson_get_str(name), MAX_RULE_NAME - 1);
        r->ruleName[MAX_RULE_NAME - 1] = '\0';
        r->action = arena_strdup(engine->arena, yyjson_get_str(action));
        r->dirty  = true;

        r->condition = build_node(engine->arena, db, cond, err);
        if (!r->condition)
        {
            yyjson_doc_free(doc);
            deleteRuleEngine(engine);
            return NULL;
        }
        r->bc = compileNode(engine->arena, r->condition);
        collectBytecodeDeps(r->bc, engine->arena, &r->deps, &r->dep_count);
        if (duplicateRule(engine, r->ruleName))
        {
            if (err) *err = ENGINE_ERR_DUPLICATE_RULE;
            yyjson_doc_free(doc);
            deleteRuleEngine(engine);
            return NULL;
        }
        addRule(engine, r);
    }
    yyjson_doc_free(doc);
    return engine;
}

static Node* build_node(Arena* ar, FactDB* db, yyjson_val* v, EngineError* err)
{
    if (yyjson_is_str(v))
        return build_fact(ar, db, v, err);
    if (!yyjson_is_obj(v))
    {
        if (err) *err = ENGINE_ERR_PARSE;
        return NULL;
    }

    yyjson_obj_iter iter;
    yyjson_obj_iter_init(v, &iter);
    yyjson_val* key;
    while ((key = yyjson_obj_iter_next(&iter)))
    {
        const char* op  = yyjson_get_str(key);
        yyjson_val* val = yyjson_obj_iter_get_val(key);
        if (!isOperator(op))
        {
            if (err) *err = ENGINE_ERR_INVALID_OPERATOR;
            return NULL;
        }
        if (strcmp(op, "and") == 0)
            return build_and_or(ar, db, val, NODE_AND, err);
        if (strcmp(op, "or") == 0)
            return build_and_or(ar, db, val, NODE_OR, err);
        if (strcmp(op, "not") == 0)
            return build_not(ar, db, val, err);
        if (strcmp(op, "null") == 0)
            return build_null(ar, db, val, err);

        if (strcmp(op, ">") == 0 || strcmp(op, "<") == 0 ||
            strcmp(op, ">=") == 0 || strcmp(op, "<=") == 0 ||
            strcmp(op, "==") == 0 || strcmp(op, "!=") == 0)
        {
            return build_compare(ar, db, op, val, err);
        }
    }
    if (err) *err = ENGINE_ERR_PARSE;
    return NULL;
}

static Node* build_fact(Arena* ar, FactDB* db, yyjson_val* v, EngineError* err)
{
    Node* n = createNode(ar, NODE_FACT);
    if (!n)
    {
        if (err) *err = ENGINE_ERR_ARENA_OOM;
        return NULL;
    }
    n->data.Fact.factName = arena_strdup(ar, yyjson_get_str(v));
    if (!factExists(db, n->data.Fact.factName, BOOL) &&
        !factExists(db, n->data.Fact.factName, NUM) &&
        !factExists(db, n->data.Fact.factName, STR))
    {
        if (err) *err = ENGINE_ERR_FACT_NOT_FOUND;
        return NULL;
    }
    return n;
}

static Node* build_compare(Arena* ar, FactDB* db, const char* op, yyjson_val* arr, EngineError* err)
{
    yyjson_val* left  = yyjson_arr_get(arr, 0);
    yyjson_val* right = yyjson_arr_get(arr, 1);

    const char* factName = yyjson_get_str(left);

    if (!isComparisonCorrect(db, factName))
    {
        if (err) *err = ENGINE_ERR_BOOL_COMPARED;
        return NULL;
    }

    if (yyjson_is_str(right))
    {
        Node* n = createNode(ar, NODE_STR_CMP);
        if (!n)
        {
            if (err) *err = ENGINE_ERR_ARENA_OOM;
            return NULL;
        }
        n->data.StrCmp.factName = arena_strdup(ar, factName);
        n->data.StrCmp.strVal   = arena_strdup(ar, yyjson_get_str(right));

        if (strcmp(op, "==") == 0)
            n->data.StrCmp.op = OP_EQ;
        else if (strcmp(op, "!=") == 0)
            n->data.StrCmp.op = OP_NE;
        else
        {
            if (err) *err = ENGINE_ERR_STRING_CMP_NOT_EQ_NE;
            return NULL;
        }
        return n;
    }

    Node* n = createNode(ar, NODE_COMPARE);
    if (!n)
    {
        if (err) *err = ENGINE_ERR_ARENA_OOM;
        return NULL;
    }
    n->data.Compare.val = 0.0;
    n->data.Compare.factName = arena_strdup(ar, factName);

    bool valSet = false;
    if (yyjson_is_int(right))
    {
        n->data.Compare.val = (double)yyjson_get_int(right);
        valSet = true;
    }
    if (yyjson_is_real(right))
    {
        n->data.Compare.val = yyjson_get_real(right);
        valSet = true;
    }
    if (!valSet)
    {
        if (err) *err = ENGINE_ERR_INVALID_VALUE;
        return NULL;
    }

    if (strcmp(op, ">") == 0)
        n->data.Compare.op = OP_GT;
    else if (strcmp(op, "<") == 0)
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

static Node* build_and_or(Arena* ar, FactDB* db, yyjson_val* arr, Type t, EngineError* err)
{
    const char* opName = (t == NODE_AND) ? "and" : "or";

    if (isEmptyOrUndersizedArray(arr, opName))
    {
        if (err) *err = ENGINE_ERR_EMPTY_ARRAY;
        return NULL;
    }
    if (isMixedBoolNumArray(db, arr, err))
        return NULL;

    size_t len = yyjson_arr_size(arr);
    Node* left = build_node(ar, db, yyjson_arr_get(arr, 0), err);
    if (!left) return NULL;
    for (size_t i = 1; i < len; i++)
    {
        Node* right = build_node(ar, db, yyjson_arr_get(arr, i), err);
        if (!right) return NULL;
        Node* parent = createNode(ar, t);
        if (!parent)
        {
            if (err) *err = ENGINE_ERR_ARENA_OOM;
            return NULL;
        }
        parent->data.op.left = left;
        parent->data.op.right = right;
        left = parent;
    }
    return left;
}

static Node* build_not(Arena* ar, FactDB* db, yyjson_val* v, EngineError* err)
{
    if (yyjson_is_arr(v) && isEmptyOrUndersizedArray(v, "not"))
    {
        if (err) *err = ENGINE_ERR_EMPTY_ARRAY;
        return NULL;
    }
    Node* n = createNode(ar, NODE_NOT);
    if (!n)
    {
        if (err) *err = ENGINE_ERR_ARENA_OOM;
        return NULL;
    }
    n->data.unary.child = build_node(ar, db, v, err);
    if (!n->data.unary.child) return NULL;
    return n;
}

static Node* build_null(Arena* ar, FactDB* db, yyjson_val* v, EngineError* err)
{
    (void)db;
    (void)v;
    Node* n = createNode(ar, NODE_NULL);
    if (!n)
    {
        if (err) *err = ENGINE_ERR_ARENA_OOM;
        return NULL;
    }
    return n;
}

static void build_factdb(FactDB* db, yyjson_val* root)
{
    yyjson_val* facts = yyjson_obj_get(root, "facts");
    if (!facts || !yyjson_is_obj(facts))
        return;

    yyjson_obj_iter iter;
    yyjson_obj_iter_init(facts, &iter);
    yyjson_val *key, *val;

    while ((key = yyjson_obj_iter_next(&iter)))
    {
        const char* name = yyjson_get_str(key);
        val = yyjson_obj_iter_get_val(key);

        if (yyjson_is_bool(val))
            setBoolFact(db, name, yyjson_get_bool(val));
        else if (yyjson_is_int(val))
            setNumFact(db, name, (double)yyjson_get_int(val));
        else if (yyjson_is_real(val))
            setNumFact(db, name, yyjson_get_real(val));
        else if (yyjson_is_str(val))
            setStringFact(db, name, yyjson_get_str(val));
    }
}
