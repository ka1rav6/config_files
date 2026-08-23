#pragma once

#include "common.h"
#include "OpCode.h"


class Chunk{
public:
    std::vector<uint8_t> code;
    Chunk();
    ~Chunk();
    void write(uint8_t);
    static const uint8_t cast(OpCode);
};