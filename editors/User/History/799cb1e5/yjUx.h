#pragma once

typedef enum{
    PAWN,
    ROOK,
    KNIGHT,
    BISHOP,
    QUEEN,
    KING
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


Piece initPiece(PieceType type, );