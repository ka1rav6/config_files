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

typedef struct{
    char** validMoves;
    PieceType type = QUEEN;
    Color color;
}Queen;

typedef struct{
    char** validMoves;
    PieceType type = KNIGHT;
    Color color;
}Knight;

typedef struct{
    char** validMoves;
    PieceType type = BISHOP;
    Color color;
}Bishop;

typedef struct{
    char** validMoves;
    PieceType type = KING;
    Color color;
}Empty;

typedef struct{
    char** validMoves;
    PieceType type = KING;
    Color color;
}Rook;
typedef struct{
    char** validMoves;
    PieceType type = KING;
    Color color;
}Pawn;



void* initPiece(PieceType, Color);