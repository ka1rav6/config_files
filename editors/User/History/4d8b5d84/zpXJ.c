#include "../../include/engine_internal.h"

/* Callback: a fact changed in the FactDB → mark dependent rules dirty. */
static void on_fact_change(const char* name, void* ctx)
{
    rule_engine_mark_fact_dirty((RuleEngine*)ctx, name);
}

const char* engine_strerror(EngineError err)
{
    switch (err)
    {
        case ENGINE_SUCCESS:                     return "success";
        case ENGINE_ERR_NULL_ARG:                return "null argument";
        case ENGINE_ERR_CANT_OPEN_FILE:          return "cannot open file";
        case ENGINE_ERR_FILE_TOO_SMALL:          return "file too small";
        case ENGINE_ERR_INVALID_JSON:            return "invalid JSON";
        case ENGINE_ERR_OUT_OF_MEMORY:           return "out of memory";
        case ENGINE_ERR_ARENA_OOM:               return "arena out of memory";
        case ENGINE_ERR_MMAP:                    return "mmap failed";
        case ENGINE_ERR_MUNMAP:                  return "munmap failed";
        case ENGINE_ERR_MUTEX:                   return "mutex init failed";
        case ENGINE_ERR_DUPLICATE_RULE:          return "duplicate rule name";
        case ENGINE_ERR_INVALID_OPERATOR:        return "invalid operator";
        case ENGINE_ERR_MISSING_RULE_NAME:       return "rule missing name";
        case ENGINE_ERR_MISSING_RULE_ACTION:     return "rule missing action";
        case ENGINE_ERR_FACT_NOT_FOUND:          return "fact not found";
        case ENGINE_ERR_BOOL_COMPARED:           return "bool compared with number";
        case ENGINE_ERR_EMPTY_ARRAY:             return "empty operator array";
        case ENGINE_ERR_INVALID_VALUE:           return "invalid comparison value";
        case ENGINE_ERR_INVALID_MAGIC:           return "invalid bytecode magic";
        case ENGINE_ERR_INVALID_VERSION:         return "invalid bytecode version";
        case ENGINE_ERR_INVALID_RULE_COUNT:      return "invalid rule count";
        case ENGINE_ERR_INVALID_INSTR_COUNT:     return "invalid instruction count";
        case ENGINE_ERR_TRUNCATED_FILE:          return "truncated bytecode file";
        case ENGINE_ERR_INSTRUCTION_COUNT_MISMATCH: return "instruction count mismatch";
        case ENGINE_ERR_ACTION_NAME_TOO_LONG:    return "action name too long";
        case ENGINE_ERR_FACT_NAME_TOO_LONG:      return "fact name too long";
        case ENGINE_ERR_RULE_NAME_TOO_LONG:      return "rule name too long";
        case ENGINE_ERR_STACK_OVERFLOW:          return "VM stack overflow";
        case ENGINE_ERR_STACK_UNDERFLOW:         return "VM stack underflow";
        case ENGINE_ERR_VM:                      return "VM execution error";
        case ENGINE_ERR_PARSE:                   return "parse error";
        case ENGINE_ERR_STRING_CMP_NOT_EQ_NE:    return "string comparison only supports == and !=";
    }
    return "unknown error";
}

Engine* createEngine(const char* file, FileType type)
{
    Engine* temp = (Engine*)malloc(sizeof(Engine));
    if (!temp)
        return NULL;

    memset(temp, 0, sizeof(Engine));
    temp->last_error = ENGINE_SUCCESS;

    if (!file)
    {
        temp->last_error = ENGINE_ERR_NULL_ARG;
        free(temp);
        return NULL;
    }
    temp->file = file;
    temp->db = createFactDB();
    if (!temp->db)
    {
        temp->last_error = ENGINE_ERR_OUT_OF_MEMORY;
        free(temp);
        return NULL;
    }
    if (type == JSON)
    {
        yyjson_doc* doc = parseJSON(file);
        if (!doc)
        {
            temp->last_error = ENGINE_ERR_INVALID_JSON;
            deleteFactDB(temp->db);
            temp->db = NULL;
            free(temp);
            return NULL;
        }
        EngineError parse_err = ENGINE_SUCCESS;
        temp->r_engine = build_ast(doc, temp->db, &parse_err);
        if (!temp->r_engine)
        {
            temp->last_error = parse_err;
            deleteFactDB(temp->db);
            temp->db = NULL;
            free(temp);
            return NULL;
        }
    }
    else
    {
        EngineError load_err = ENGINE_SUCCESS;
        temp->r_engine = loadBytecode(file, temp->db, &load_err);
        if (!temp->r_engine)
        {
            temp->last_error = load_err;
            deleteFactDB(temp->db);
            temp->db = NULL;
            free(temp);
            return NULL;
        }
    }
    factdb_on_change(temp->db, on_fact_change, temp->r_engine);

    if (pthread_mutex_init(&temp->lock, NULL) != 0)
    {
        temp->last_error = ENGINE_ERR_MUTEX;
        deleteFactDB(temp->db);
        temp->db = NULL;
        deleteRuleEngine(temp->r_engine);
        free(temp);
        return NULL;
    }
    return temp;
}

void deleteEngine(Engine* e)
{
    deleteFactDB(e->db);
    deleteRuleEngine(e->r_engine);
    freeRegistry(&e->action_registry);
    pthread_mutex_destroy(&e->lock);
    free(e);
}

EngineError registerTheAction(Engine* e, const char* name, Action_f f, void* ctx)
{
    if (!e || !name || !f)
        return ENGINE_ERR_NULL_ARG;

    pthread_mutex_lock(&e->lock);
    EngineError err = ENGINE_SUCCESS;
    if (registerAction(&e->action_registry, name, f, ctx) != 0)
        err = ENGINE_ERR_OUT_OF_MEMORY;
    rule_engine_bind_action(e->r_engine, name, f, ctx);
    pthread_mutex_unlock(&e->lock);

    e->last_error = err;
    return err;
}

EngineError runEngine(Engine* e)
{
    if (!e) return ENGINE_ERR_NULL_ARG;
    runRuleEngine(e->r_engine, e->db);
    return ENGINE_SUCCESS;
}

EngineError engine_set_bool_fact(Engine* e, const char* name, bool val)
{
    if (!e || !name) return ENGINE_ERR_NULL_ARG;
    setBoolFact(e->db, name, val);
    rule_engine_mark_fact_dirty(e->r_engine, name);
    return ENGINE_SUCCESS;
}

EngineError engine_set_num_fact(Engine* e, const char* name, double val)
{
    if (!e || !name) return ENGINE_ERR_NULL_ARG;
    setNumFact(e->db, name, val);
    rule_engine_mark_fact_dirty(e->r_engine, name);
    return ENGINE_SUCCESS;
}

EngineError engine_set_string_fact(Engine* e, const char* name, const char* val)
{
    if (!e || !name) return ENGINE_ERR_NULL_ARG;
    setStringFact(e->db, name, val);
    rule_engine_mark_fact_dirty(e->r_engine, name);
    return ENGINE_SUCCESS;
}

EngineError engine_get_last_error(const Engine* e)
{
    return e ? e->last_error : ENGINE_ERR_NULL_ARG;
}

FactDB* engine_get_factdb(Engine* e)
{
    assert(e != NULL);
    return e->db;
}

RuleEngine* engine_get_rule_engine(Engine* e)
{
    assert(e != NULL);
    return e->r_engine;
}
