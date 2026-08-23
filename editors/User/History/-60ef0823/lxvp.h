
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

typedef struct Square{
    Point p;
    PieceType type;
    void* piecePtr;
    Color color;
}Square;


typedef struct Board{
    Square arr[8][8];
    State state;
}Board;

Board* initBoard();
Move* getValidMoves(Board*, Square*);

Square* getPossiblePieces(Board*, PieceType, Move*);
