#pragma once

#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>


#define MAX_VALID 64



typedef enum{
    PAWN,
    ROOK,
    KNIGHT,
    BISHOP,
    QUEEN,
    KING,
    EMPTY
}PieceType;

typedef enum{
    WHITE,
    BLACK
}Color;

typedef struct{
    char** validMoves;
    PieceType type;
    Color color;
}Piece;


Piece* initPiece(PieceType, Color);