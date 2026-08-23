#include "ConditionTree.h"

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

Node* createNode(Type t){
    Node* temp = (Node*)malloc(sizeof(Node));
    if (temp == NULL){
        fprintf(stderr, "Memory allocation failed\n");
        exit(EXIT_FAILURE);
    }
    memset(temp, 0, sizeof(Node));
    temp->type = t;
    return temp;
}
