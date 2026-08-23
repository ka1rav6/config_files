#include "ConditionTree.h"


// Node constructor that allocates memory for a new node and initializes its type and data
Node* createNode(Arena* ar, Type t){
    Node* temp = (Node*)arena_alloc(ar, sizeof(Node));
    if (temp == NULL){
        fprintf(stderr, "Memory allocation failed\n");
        exit(EXIT_FAILURE);
    }
    memset(temp, 0, sizeof(Node));
    temp->type = t;
    return temp;
}
