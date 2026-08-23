#include "../include/debug.h"

void disassembleChunk(Chunk c, std::string name){
    std::cout << "\t\t\t" << name << "\n";
    for (int offset = 0; offset < c.code.size();){
        offset = disassembleInstruction(c, offset);
    }
}

int disassembleInstruction(Chunk c, int offset){
    std::cout << offset;

    uint8_t instr = c.code.at(offset);

    switch(instr){
        case Chunk::cast(OpCode::OP_RETURN):
        
    }
}