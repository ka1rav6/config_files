#pragma once

#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>


typedef enum{
    WHITE,
    BLACK
}Color;

typedef struct{
    char** validMoves;
    Color color;
}King;


Piece* initPiece(PieceType, Color);