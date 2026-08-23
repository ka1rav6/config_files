#pragma once

#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>


typedef enum{
    WHITE,
    BLACK
}Color;


typedef enum{
    PAWN,
    ROOK,
    KNIGHT,
    BISHOP,
    QUEEN,
    KING,
    EMPTY
}PieceType;


typedef struct{
    char** validMoves;
    PieceType type = KING;
    Color color;
}King;



void* initPiece(PieceType, Color);