#include "ConditionTree.h"

// Node destructor that recursively frees the memory allocated for the nodes in the AST
void deleteNode(Node* n){
    switch (n->type){
        case (NODE_AND) :
            deleteNode(n->data.op.left);
            deleteNode(n->data.op.right);
            break;
        case (NODE_OR):
            deleteNode(n->data.op.left);
            deleteNode(n->data.op.right);
            break;
        case NODE_NOT:
            deleteNode(n->data.unary.child);
            break;
        case NODE_FACT:
            free(n->data.Fact.factName);
            break;
        case NODE_COMPARE:
            free(n->data.Compare.factName);
            break;
    }
    free(n);
    n = NULL;
}

// Node constructor that allocates memory for a new node and initializes its type and data
Node* createNode(Arena* ar, Type t) {
    Node* temp = (Node*)arena_alloc(ar, sizeof(Node));
    if (temp == NULL) {
        // arena_alloc already handles the error message, just return NULL or exit
        exit(EXIT_FAILURE);
    }
    memset(temp, 0, sizeof(Node));
    temp->type = t;
    return temp;
}