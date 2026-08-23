#include "../include/engine_internal.h"

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
    if (pthread_mutex_init(&temp->lock, NULL) != 0) {
        FATAL("Could not initialize Engine mutex\n");
    }
    return temp;
}

// engine destructor. the arena is also deleted through the rule engine
void deleteEngine(Engine* e){
    deleteFactDB(e->db);
    deleteRuleEngine(e->r_engine);
    freeRegistry(&e->action_registry);
    pthread_mutex_destroy(&e->lock);
    free(e);
}

// to register the action in the action registry.
void registerTheAction(Engine* e, const char* name, Action_f f, void* ctx){
    pthread_mutex_lock(&e->lock);
    registerAction(&e->action_registry, name, f, ctx);
    rule_engine_bind_action(e->r_engine, name, f, ctx);
    pthread_mutex_unlock(&e->lock);
}
// just internally runs the rule engine
void runEngine(Engine* e){
    runRuleEngine(e->r_engine, e->db);
}

FactDB* engine_get_factdb(Engine* e) {
    return e ? e->db : NULL;
}
RuleEngine* engine_get_rule_engine(Engine* e) {
    return e ? e->r_engine : NULL;
}