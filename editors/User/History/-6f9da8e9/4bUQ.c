#include "engine.h"

Engine* createEngine(const char* json_file){
    Engine* temp = (Engine*)malloc(sizeof(Engine));
    if (!temp){
        fprintf(stderr, "The engine memory could not be allocated\n");
        perror("");
        exit(EXIT_FAILURE);
    }
    memset(temp, 0, sizeof(Engine));
    if (json_file == NULL){
        fprintf(stderr, "ERROR: the engine cannot be created with a NULL json file\n");
        perror("");
        exit(EXIT_FAILURE);
    }
    temp->json_file = json_file;
    temp->db = createFactDB();
    temp->r_engine = build_ast(parseJSON(json_file), temp->db, temp->action_registry);
    return temp;
}

void deleteEngine(Engine* e){
    deleteFactDB(e->db);
    deleteRuleEngine(e->r_engine);
    freeRegistry(&e->action_registry);
    free(e);
}

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

void runEngine(Engine* e){
    runRuleEngine(e->r_engine, e->db);
}