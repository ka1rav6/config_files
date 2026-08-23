#include "factdb.h"

double getNumFact(FactDB* db, const char* name){
    for (int i = 0; i < db->numCount; i++){
        if (strcmp(db->numFacts[i].name, name) == 0)
            return db->numFacts[i].val;
    }
    return NOT_FOUND;
}

bool getBoolFact(FactDB* db, const char* name){
    for (int i = 0; i < db->boolCount; i++){
        if (strcmp(db->boolFacts[i].name, name) == 0)
            return db->boolFacts[i].val;
    }
    return NOT_FOUND;
}

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
            printf("DEBUG COMPARE: %s = %f vs %f\n",
                n->data.Compare.factName, lhs, rhs);
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
                    fprintf(stderr, "UNKNOWN COMPARE OP\n");
                    return false;
            }
        }
    }

}


FactDB* createFactDB(){
    FactDB* temp = (FactDB*)malloc(sizeof(FactDB));
    if (temp == NULL){
        printf("COULD NOT ALLOCATE SPACE FOR FACT DB\n");
        exit(1);
    }
    memset(temp, 0, sizeof(FactDB));
    temp->boolCount = 0;
    temp->numCount = 0;
    return temp;
}
void deleteFactDB(FactDB* db){
    for (int i = 0; i < db->boolCount; i++){
        free(db->boolFacts[i].name);
        db->boolFacts[i].name = NULL;
    }
    for (int i = 0; i < db->numCount; i++){
        free(db->numFacts[i].name);
        db->numFacts[i].name = NULL;
    }
    free(db);
    db = NULL;
}
void setBoolFact(FactDB* db, const char* name, bool val){
    if (db->boolCount >= MAX_FACTS){
        printf("BoolFact overflow: %s\n", name);
        return;
    }
    for (size_t i = 0; i < db->boolCount; i++){
        if (strcmp(db->boolFacts[i].name, name) == 0){
            db->boolFacts[i].val = val;
            return;
        }
    }
    db->boolFacts[db->boolCount].name = strdup(name);
    db->boolFacts[db->boolCount].val = val;
    db->boolCount++;
}
void setNumFact(FactDB* db, const char* name, double val){
    if (db->numCount >= MAX_FACTS){
        printf("NumFact overflow: %s\n", name);
        return;
    }
    for (size_t i = 0; i < db->numCount; i++){
        if (strcmp(db->numFacts[i].name, name) == 0){
            db->numFacts[i].val = val;
            return;
        }
    }
    db->numFacts[db->numCount].name = strdup(name);
    db->numFacts[db->numCount].val = val;
    db->numCount++;
}