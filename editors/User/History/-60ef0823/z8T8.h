
#pragma once

#include "piece.h"
#include <string.h>
#include <stdbool.h>

typedef enum{
    PLAY,
    STALEMATE,
    CHECK,
    CHECKMATE,
}State;

typedef struct{
    
}Square;


typedef struct{
    Piece board[8][8];
}Board;

Board* initBoard();