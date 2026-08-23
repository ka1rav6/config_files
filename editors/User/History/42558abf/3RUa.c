#include "factdb.h"
#include "uthash.h"

/
double getNumFact(FactDB* db, const char* name){
    NumFact* f;
    HASH_FIND_STR(db->numFacts, name, f);
    if (!f){
        return NOT_FOUND;
    }
    return f->val;
}

bool getBoolFact(FactDB* db, const char* name){
    BoolFact* f;
    HASH_FIND_STR(db->boolFacts, name, f);
    if (!f){
        return false;
    }
    return f->val;
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
    temp->boolFacts = NULL;
    temp->numFacts = NULL;
    return temp;
}
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
    free(db);
    db = NULL;
}
void setBoolFact(FactDB* db, const char* name, bool val){
    BoolFact *f;
    HASH_FIND_STR(db->boolFacts, name, f);
    if (f){
        f->val = val; // updating the value if the name is found
        return;
    }
    f = (BoolFact*) malloc(sizeof(BoolFact));
    memset(f, 0, sizeof(BoolFact));
    strcpy(f->name, name);
    f->val = val;
    HASH_ADD_STR(db->boolFacts, name, f);
}
void setNumFact(FactDB* db, const char* name, double val){
    NumFact* f;
    HASH_FIND_STR(db->numFacts, name, f);
    if (f){
        f->val = val; // updating the value if the name is found
        return;
    }
    f = (NumFact*)malloc(sizeof(NumFact));
    memset(f, 0, sizeof(NumFact));
    strcpy(f->name, name);
    f->val = val;
    HASH_ADD_STR(db->numFacts, name, f);
}
