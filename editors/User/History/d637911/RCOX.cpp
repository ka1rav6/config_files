#include "./include/common.h"
#include "./include/chunk.h"
#include "include/OpCode.h"

int main(int argc, const char** argv){
    Chunk *c = new Chunk();
    c->write(OpCode::OP_RETURN);
    
}