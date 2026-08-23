#include "../include/chunk.h"
#include <cstdlib>


Chunk::Chunk(){
    this->count = 0;
    this->capacity = 0;
    this->code = NULL;
}

void Chunk::write(uint8_t byte){
    if (this->capacity < this->count + 1){
        int oldCapacity = this->capacity;
        this->capacity = GROW_CAPACITY(oldCapacity);
        uint8_t* newBlock = (uint8_t*)realloc(this->code, this->capacity * sizeof(uint8_t));
        if (!newBlock) {
            // allocation failed; keep old pointer
            return;
        }
        this->code = newBlock;
    }
    this->code[this->count++] = byte;
}