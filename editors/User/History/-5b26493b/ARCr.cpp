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
        case static_cast<uint8_t>(OpCode::OP_RETURN):
            std::cout << "\tOP_RETURN\n";
            return simpleInstr("OP_RETURN", offset);
        default:
            std::cout << "\tUnknown opcode " << static_cast<int>(instr) << "\n";
            return offset + 1;
    }
}
static int simpleInstr(std::string name, int offset){
    std::cout << name <<std::endl;
    return offset + 1;
}