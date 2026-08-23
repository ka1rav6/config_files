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
            double lhs = getNumFact(db, n->data.Fact.factName);
            double rhs = n->data.Compare.val;
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
    temp->boolFacts = NULL;
    temp->numFacts = NULL;
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
    free(db->boolFacts);
    db->boolFacts = NULL;
    free(db->numFacts);
    db->numFacts = NULL;
    free(db);
    db = NULL;
}