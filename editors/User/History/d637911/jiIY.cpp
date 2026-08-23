#include "../include/common.h"
#include "../include/chunk.h"
#include "../include/OpCode.h"

int main(int argc, const char** argv){
    Chunk *c = new Chunk();
    c->write(Chunk::cast(OpCode::OP_RETURN));
    disassembleChunk
    std::cout << "done" <<std::endl;
    return 0;
    
}