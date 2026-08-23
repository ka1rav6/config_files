#include "../include/engine.h"

// Engine constructor. To be called by the user.
Engine* createEngine(const char* json_file){
    Engine* temp = (Engine*)malloc(sizeof(Engine));

    if (!temp){
        FATAL("The engine memory could not be allocated\n");
    }
    memset(temp, 0, sizeof(Engine));

    if (json_file == NULL){
        FATAL("ERROR: the engine cannot be created with a NULL json file\n");
    }
    temp->json_file = json_file;
    temp->db = createFactDB();
    temp->r_engine = build_ast(parseJSON(json_file), temp->db, temp->action_registry);
    return temp;
}

// engine destructor. the arena is also deleted through the rule engine
void deleteEngine(Engine* e){
    deleteFactDB(e->db);
    deleteRuleEngine(e->r_engine);
    freeRegistry(&e->action_registry);
    free(e);
}
// to register the action in the action registry
void registerTheAction(Engine* e, const char* name, Action_f f, void* ctx){
    registerAction(&e->action_registry, name, f, ctx);
    Rule *r, *tmp;
    HASH_ITER(hh, e->r_engine->rules, r, tmp) {
        if (strcmp(r->action, name) == 0) {
            r->func = f;
            r->ctx  = ctx;
        }
    }
}
// just internally runs the rule engine
void runEngine(Engine* e){
    runRuleEngine(e->r_engine, e->db);
}
