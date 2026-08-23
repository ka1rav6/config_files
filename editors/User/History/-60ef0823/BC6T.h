
#pragma once

#include "piece.h"
#include <string.h>
#include <stdbool.h>

typedef struct{
    Piece** board;
}Board;

Board* initBoard();