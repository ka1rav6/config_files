#include "../include/factdb_internal.h"

// gets the value of a numeric fact from the fact DB by searching for its name.
// Thread-safe: read-locked, since multiple readers can look up facts concurrently.
double getNumFact(FactDB* db, const char* name){
    pthread_rwlock_rdlock(&db->lock);
    NumFact* f;
    HASH_FIND_STR(db->numFacts, name, f);
    double result = f ? f->val : NOT_FOUND;
    pthread_rwlock_unlock(&db->lock);
    return result;
}

// Similar to getNumFact but for boolean facts
bool getBoolFact(FactDB* db, const char* name){
    pthread_rwlock_rdlock(&db->lock);
    BoolFact* f;
    HASH_FIND_STR(db->boolFacts, name, f);
    bool result = f ? f->val : false;
    pthread_rwlock_unlock(&db->lock);
    return result;
}

// evaluates a node in the AST by recursively evaluating its children and applying the appropriate logic
// now not used ever since bytecode has started being used. This was the initial evaluating function
bool evaluate(FactDB* db, Node* n){

    switch(n->type){
        case NODE_AND:
            return evaluate(db, n->data.op.left) && evaluate(db, n->data.op.right);
        case NODE_OR:
            return evaluate(db, n->data.op.left) || evaluate(db, n->data.op.right);
        case NODE_NOT:
            return !evaluate(db, n->data.unary.child);
        case NODE_FACT:
            return getBoolFact(db, n->data.Fact.factName);
        case NODE_COMPARE:{
            double lhs = getNumFact(db, n->data.Compare.factName);
            double rhs = n->data.Compare.val;

            // compare the operator and return whether the comparison is correct
            switch(n->data.Compare.op){
                case OP_LT:
                    return lhs < rhs;
                case OP_GT:
                    return lhs > rhs;
                case OP_LE:
                    return lhs <= rhs;
                case OP_GE:
                    return lhs >= rhs;
                case OP_EQ:
                    return lhs == rhs;
                case OP_NE:
                    return lhs != rhs;
                default:
                    FATAL("UNKNOWN COMPARE OP\n");
            }
        }
    }
    return false;
}

// constructor for factDB
FactDB* createFactDB(){
    FactDB* temp = (FactDB*)malloc(sizeof(FactDB));
    if (temp == NULL){
        printf("COULD NOT ALLOCATE SPACE FOR FACT DB\n");
        exit(1);
    }
    memset(temp, 0, sizeof(FactDB));
    temp->boolFacts = NULL;
    temp->numFacts = NULL;
    if (pthread_rwlock_init(&temp->lock, NULL) != 0){
        FATAL("Could not initialize FactDB lock\n");
    }
    return temp;
}

// destructor for factDB that frees all the memory allocated for the facts and the fact DB itself
void deleteFactDB(FactDB* db){
    NumFact *currNum, *tempNum;
    HASH_ITER(hh, db->numFacts, currNum, tempNum){
        HASH_DEL(db->numFacts, currNum);
        free(currNum);
    }
    BoolFact* currBool, *tempBool;
    HASH_ITER(hh, db->boolFacts, currBool, tempBool){
        HASH_DEL(db->boolFacts, currBool);
        free(currBool);
    }
    currBool = NULL;
    tempBool = NULL;
    currNum = NULL;
    tempNum = NULL;
    pthread_rwlock_destroy(&db->lock);
    free(db);
}

// sets the value of a fact in the fact DB by searching for its name and UPDATING THE VALUE IF IT EXISTS,
// or adding a new fact if it does not exist.
// Thread-safe: write-locked, exclusive against both readers and other writers.
void setBoolFact(FactDB* db, const char* name, bool val){
    pthread_rwlock_wrlock(&db->lock);
    BoolFact *f;
    HASH_FIND_STR(db->boolFacts, name, f);
    if (f){
        f->val = val;
        pthread_rwlock_unlock(&db->lock);
        return;
    }
    f = (BoolFact*) malloc(sizeof(BoolFact));
    memset(f, 0, sizeof(BoolFact));
    if (strlen(name) > MAX_NAME){
        pthread_rwlock_unlock(&db->lock);
        FATAL("Cannot have a fact name that exceeds the cound of %d letters. The action : %s does.", MAX_NAME, name);
    }
    strcpy(f->name, name);
    f->val = val;
    HASH_ADD_STR(db->boolFacts, name, f);
    pthread_rwlock_unlock(&db->lock);
}

// Similar to setBoolFact but for numeric facts
void setNumFact(FactDB* db, const char* name, double val){
    pthread_rwlock_wrlock(&db->lock);
    NumFact* f;
    HASH_FIND_STR(db->numFacts, name, f);
    if (f){
        f->val = val;
        pthread_rwlock_unlock(&db->lock);
        return;
    }
    f = (NumFact*)malloc(sizeof(NumFact));
    memset(f, 0, sizeof(NumFact));
    if (strlen(name) > MAX_NAME){
        pthread_rwlock_unlock(&db->lock);
        FATAL("Cannot have a fact name that exceeds the cound of %d letters. The action : %s does.", MAX_NAME, name);
    }
    strcpy(f->name, name);
    f->val = val;
    HASH_ADD_STR(db->numFacts, name, f);
    pthread_rwlock_unlock(&db->lock);
}

bool factdb_has_bool(FactDB* db, const char* name){
    pthread_rwlock_rdlock(&db->lock);
    BoolFact* f;
    HASH_FIND_STR(db->boolFacts, name, f);
    bool found = (bool)f;
    pthread_rwlock_unlock(&db->lock);
    return found;
}

bool factdb_has_num(FactDB* db, const char* name){
    pthread_rwlock_rdlock(&db->lock);
    NumFact* f;
    HASH_FIND_STR(db->numFacts, name, f);
    bool found = (bool)f;
    pthread_rwlock_unlock(&db->lock);
    return found;
}

// Debug/inspection helper: prints all facts. Read-locked for the whole
void printFactDB(FactDB* db){
    pthread_rwlock_rdlock(&db->lock);
    printf("=== FACT DB ===\n");
    printf("[BOOL FACTS]\n");
    BoolFact* bf, *btmp;
    HASH_ITER(hh, db->boolFacts, bf, btmp)
        printf("  %s = %s\n", bf->name, bf->val ? "true" : "false");
    printf("[NUM FACTS]\n");
    NumFact* nf, *ntmp;
    HASH_ITER(hh, db->numFacts, nf, ntmp)
        printf("  %s = %.2f\n", nf->name, nf->val);
    printf("================\n\n");
    pthread_rwlock_unlock(&db->lock);
}