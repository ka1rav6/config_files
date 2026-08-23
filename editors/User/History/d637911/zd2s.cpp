#include "../include/common.h"
#include "../include/chunk.h"
#include "../include/OpCode.h"

int main(int argc, const char** argv){
    Chunk *c = new Chunk();
    c->write(Chunk::cast(OpCode::OP_RETURN));
    std::cout << "done" <<std::endl;
    return 0;
    
}