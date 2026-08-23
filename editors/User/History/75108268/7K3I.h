#pragma once

#include "common.h"
#include "OpCode.h"
#include <sys/types.h>

class Chunk{
public:
    u_int8_t* code;
    
    Chunk();
    ~Chunk();
};