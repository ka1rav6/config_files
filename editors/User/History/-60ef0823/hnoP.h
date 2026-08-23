
#pragma once

#include "piece.h"
#include <string.h>
#include <stdbool.h>

typedef enum{
    DEFAULT,
    PLAY,
    STALEMATE,
    CHECK,
    CHECKMATE,
}State;

typedef struct{
    Point p;
    King* king;
    Queen* queen;
    

}Square;


typedef struct{
    Piece board[8][8];
}Board;

Board* initBoard();