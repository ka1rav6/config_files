
#pragma once

#include "piece.h"
#include "point.h"
#include <string.h>
#include <stdbool.h>

typedef enum{
    DEFAULT,
    WHITE_PLAY,
    BLACK_PLAY,
    STALEMATE,
    CHECK,
    CHECKMATE,
}State;

typedef struct{
    Point p;
    PieceType type;
    void* piecePtr;
}Square;


typedef struct{
    Square board[8][8];
    State state;
}Board;

Board* initBoard();