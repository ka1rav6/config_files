#include "../include/common.h"
#include "../include/chunk.h"
#include "../include/OpCode.h"
#include "../include/debug.h"

int main(int argc, const char** argv){
    Chunk *c = new Chunk();
    c->write(Chunk::cast(OpCode::OP_RETURN));
    disassembleChunk(*c, "test chunk");
    return 0;
    
}