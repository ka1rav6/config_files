
#pragma once

#include "piece.h"
#include "point.h"
#include <string.h>
#include <stdbool.h>    
#include "debugger.h"

typedef enum State{
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
void getValidMoves(Board*, Square*);

Square* getPossiblePieces(Board*, PieceType, Move*);
