#include "../include/bytecode.h"

// constructor for the bytecode
static Bytecode* createBytecode(Arena* ar)
{
    Bytecode* bc = (Bytecode*)arena_alloc(ar, sizeof(Bytecode));
    bc->capacity = 8;
    bc->count = 0;
    bc->code = (Instr*)arena_alloc(ar, sizeof(Instr) * bc->capacity);
    return bc;
}

// increases capacity on overload, else just adds instruction to the bytecode.
static void emit(Arena* ar, Bytecode* bc, Instr i)
{
    if (bc->count >= bc->capacity)
    {
        Instr* old = bc->code;
        int newCap = bc->capacity * 2;
        Instr* grown = (Instr*)arena_alloc(ar, sizeof(Instr) * newCap);
        memcpy(grown, old, sizeof(Instr) * bc->count);
        bc->code = grown;
        bc->capacity = newCap;
    }
    bc->code[bc->count++] = i;
}
// recursive function that evaluates and creates bytecode accordingly
static void compileWalk(Arena* ar, Bytecode* bc, Node* n)
{
    switch (n->type)
    {
        case NODE_AND:
        {
            compileWalk(ar, bc, n->data.op.left);
            compileWalk(ar, bc, n->data.op.right);
            Instr i;
            i.op = OP_AND; 
            emit(ar, bc, i);
            break;
        }
        case NODE_OR:
        {
            compileWalk(ar, bc, n->data.op.left);
            compileWalk(ar, bc, n->data.op.right);
            Instr i;
            i.op = OP_OR; 
            emit(ar, bc, i);
            break;
        }
        case NODE_NOT:
        {
            compileWalk(ar, bc, n->data.unary.child);
            Instr i;
            i.op = OP_NOT; 
            emit(ar, bc, i);
            break;
        }
        case NODE_FACT:
        {
            Instr i;
            i.op = OP_PUSH_FACT;
            i.factName = n->data.Fact.factName; 
            emit(ar, bc, i);
            break;
        }
        case NODE_COMPARE:
        {
            Instr i;
            i.op = OP_PUSH_CMP;
            i.factName = n->data.Compare.factName;
            i.cmp = n->data.Compare.op;
            i.val = n->data.Compare.val;
            emit(ar, bc, i);
            break;
        }
    }
}
// the actual bytecode creator
Bytecode* compileNode(Arena* ar, Node* n)
{
    Bytecode* bc = createBytecode(ar);
    compileWalk(ar, bc, n);
    Instr i;
    i.op = OP_HALT;
    emit(ar, bc, i);
    return bc;
}

// returns true if the comparison is correct
static bool runCompare(FactDB* db, Instr* i)
{
    double lhs = getNumFact(db, i->factName);
    double rhs = i->val;
    switch (i->cmp)
    {
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
    return false;
}

bool runBytecode(FactDB* db, Bytecode* bc)
{
    bool stack[64];
    int sp = 0;
    for (int pc = 0; pc < bc->count; pc++)
    {
        Instr* i = &bc->code[pc];
        switch (i->op)
        {
            case OP_PUSH_FACT:
                stack[sp++] = getBoolFact(db, i->factName);
                break;
            case OP_PUSH_CMP:
                stack[sp++] = runCompare(db, i);
                break;
            case OP_AND: 
            {
                bool b = stack[--sp];
                bool a = stack[--sp];
                stack[sp++] = a && b;
                break;
            }
            case OP_OR: 
            {
                bool b = stack[--sp];
                bool a = stack[--sp];
                stack[sp++] = a || b;
                break;
            }
            case OP_NOT:
                stack[sp - 1] = !stack[sp - 1];
                break;
            case OP_HALT:
                return stack[sp - 1];
        }
    }
    return false;
}
