#pragma once

#include "common.h"
#include "chunk.h"


void disassembleChunk(Chunk c, std::string name);
int disassembleInstruction(Chunk c, int offset);