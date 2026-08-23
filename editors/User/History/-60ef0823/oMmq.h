
#pragma once

#include "piece.h"
#include <string.h>
#include <stdbool.h>

typedef struct{
    Piece board[8][8];
}Board;

Board* initBoard();