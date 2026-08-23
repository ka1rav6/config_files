
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
    bool hasEnPassantTarget;
    Point enPassantTarget;
}Board;

Board* initBoard();
void destroyBoard(Board* b);
void getValidMoves(Board*, Square*);

Square* getPossiblePieces(Board*, PieceType, Move*, char, char);

Square* getPossiblePieces(Board*, PieceType, Move*);

void getKingValidMoves(Board* b, Square* s) ;
void getQueenValidMoves(Board* b, Square* s);
void getPawnValidMoves(Board* b, Square* s);
void getKnightValidMoves(Board* b, Square* s) ;
void getBishopValidMoves(Board* b, Square* s);
void getRookValidMoves(Board* b, Square* s);
