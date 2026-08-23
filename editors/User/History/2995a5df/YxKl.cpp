#include "../include/chunk.h"
#include <cstdint>

#define GROW_CAPACITY(capacity) ((capacity) < 8 ? 8 : (capacity) * 2)
#define GROW_ARRAY(type, pointer, oldCount, newCount) \
    (type*)realloc((pointer), sizeof(type) * (newCount))

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