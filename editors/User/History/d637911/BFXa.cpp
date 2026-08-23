#include "../include/common.h"
#include "../include/chunk.h"
#include "../include/OpCode.h"

int main(int argc, const char** argv){
    Chunk *c = new Chunk();
    c->write(static_cast<uint8_t>(OpCode::OP_RETURN));
    
    
    return 0;
    
}