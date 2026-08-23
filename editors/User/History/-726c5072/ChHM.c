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
    memset(temp, 0, sizeof(Node));
    temp->type = t;

    switch(t){
        case (NODE_AND) :
            temp->data.op.left = malloc(sizeof(Node));
            temp->data.op.right = malloc(sizeof(Node));
            break;
        case NODE_OR:
            temp->data.op.left = malloc(sizeof(Node));
            temp->data.op.right = malloc(sizeof(Node));
            break;
        case NODE_NOT:
            temp->data.unary.child = malloc(sizeof(Node));
            break;
        case NODE_FACT:
            temp->data.Fact.factName = (char*)malloc(MAX_NAME * sizeof(char));
            break;
        case NODE_COMPARE:
            temp->data.Compare.factName = (char*)malloc(MAX_NAME * sizeof(char));
        break;
    }
    return temp;
}
