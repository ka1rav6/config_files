#include "factdb.h"
#include "uthash.h"

/*
 * gets the value of a numeric fact from the fact DB by searching for its name
 * @param 1 : pointer to the fact DB (to search for the fact)
 * @param 2 : name of the fact (string)
 * @return : value of the fact (double) or NOT_FOUND (NAN) if the fact does not exist
*/
double getNumFact(FactDB* db, const char* name){
    NumFact* f;
    HASH_FIND_STR(db->numFacts, name, f);
    if (!f){
        return NOT_FOUND;
    }
    return f->val;
}
// Similar to getNumFact but for boolean facts
bool getBoolFact(FactDB* db, const char* name){
    BoolFact* f;
    HASH_FIND_STR(db->boolFacts, name, f);
    if (!f){
        return false;
    }
    return f->val;
}
/*
 * evaluates a node in the AST by recursively evaluating its children and applying the appropriate logic
 * @param 1 : pointer to the fact DB (to access fact values)
 * @param 2 : pointer to the node to be evaluated
 * @return : result of the evaluation (boolean)
 */
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
    tempBool = NULL; // to prevent dangling ptrs
    currNum = NULL;
    tempNum = NULL;
    free(db);
    db = NULL;// to prevent dangling ptrs
}

/*
 * sets the value of a fact in the fact DB by searching for its name and UPDATING THE VALUE IF IT EXISTS, or adding a new fact if it does not exist
 * @param 1 : pointer to the fact DB (to search for the fact and update/add it)
 * @param 2 : name of the fact (string)
 * @param 3 : value of the fact (bool or double) 
*/
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

// Similar to setBoolFact but for numeric facts
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
