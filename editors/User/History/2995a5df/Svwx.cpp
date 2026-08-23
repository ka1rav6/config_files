#include "../include/chunk.h"
#include "../include/memory.h"

Chunk::Chunk(){
    this->count = 0;
    this->capacity = 0;
    this->code = NULL;
}

void Chunk::write(uint8_t byte){
    if (this->capacity < this->count + 1){
        int oldCapacity = this->capacity;
        this->capacity = GROW_CAPACITY(oldCapacity);
        this->code = GROW_ARRAY(uint8_t, this->code, oldCapacity, this->capacity);
    }
}