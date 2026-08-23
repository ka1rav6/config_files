#pragma once

#include "common.h"
#include "OpCode.h"


class Chunk{
public:
    uint8_t* code;
    int count;
    int capacity;
    Chunk();
    ~Chunk();
    void write(uint8_t);
};