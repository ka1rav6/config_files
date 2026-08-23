#pragma once
#include "common.h"
#include "ConditionTree.h"
#include "factdb.h"
#include "arena.h"

typedef enum {
    OP_PUSH_FACT,
    OP_PUSH_CMP,
    OP_AND,
    OP_OR,
    OP_NOT,
    OP_HALT
} OpCode;

typedef struct {
    char* factName;
    double val;
    OpCode op;
    CompareOp cmp;
} Instr;

typedef struct {
    Instr* code;
    int count;
    int capacity;
} Bytecode;

Bytecode* compileNode(Arena* ar, Node* n);
bool runBytecode(FactDB* db, Bytecode* bc);