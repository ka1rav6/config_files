
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
    Color color;
}Square;


typedef struct{
    Square arr[8][8];
    State state;
}Board;

Board* initBoard();
Move* getValidMoves(Piece*);

Square* getPossiblePieces(Board*, PieceType, Move*);
