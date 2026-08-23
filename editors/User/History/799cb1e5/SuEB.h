#pragma once

typedef enum{
    PAWN,
    ROOK,
    KNIGHT,
    BISHOP,
    QUEEN,
    KING
}PieceType;



typedef struct{
    char** validMoves;
    
}Piece;