#pragma once
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include "arena.h"

#define MAX_NAME 100

typedef enum {
    NODE_AND,
    NODE_OR,
    NODE_NOT,
    NODE_FACT,
    NODE_COMPARE
} Type;

typedef enum {
    OP_LT, OP_LE, OP_GT, OP_GE, OP_EQ, OP_NE
} CompareOp;

typedef struct Node {
    Type type;
    union {
        struct { struct Node* left; struct Node* right; } op;
        struct { struct Node* child; } unary;
        struct { char *factName; } Fact;
        struct { char *factName; CompareOp op; double val; } Compare;
    } data;
} Node;

void deleteNode(Node*);
Node* createNode(Arena* ar, Type t);