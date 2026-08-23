#include "../include/chunk.h"
#include "../include/memory.h"

Chunk::Chunk(){

}
Chunk::~Chunk(){
    
}

void Chunk::write(uint8_t byte){
    this->code.emplace_back(byte);
}

uint8_t Chunk::cast(OpCode opc){
    return static_cast<uint8_t>(opc);
}
