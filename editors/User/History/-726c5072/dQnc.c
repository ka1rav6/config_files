#include "../include/ConditionTree.h"


// Node constructor that allocates memory for a new node and initializes its type and data
Node* createNode(Arena* ar, Type t){
    Node* temp = (Node*)arena_alloc(ar, sizeof(Node));
    if (temp == NULL){
        FATAL("Memory allocation failed\n");
    }
    memset(temp, 0, sizeof(Node));
    temp->type = t;
    return temp;
}
