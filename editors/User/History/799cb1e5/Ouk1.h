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
    Point pos;
}King;

typedef struct{
    char** validMoves;
    PieceType type = QUEEN;
    Color color;
    Point pos;
}Queen;

typedef struct{
    char** validMoves;
    PieceType type = KNIGHT;
    Color color;
    Point pos;
}Knight;

typedef struct{
    char** validMoves;
    PieceType type = BISHOP;
    Color color;
    Point pos;
}Bishop;

typedef struct{
    char** validMoves;
    PieceType type = EMPTY;
    Color color;
    Point pos;
}Empty;

typedef struct{
    char** validMoves;
    PieceType type = ROOK;
    Color color;
    Point pos;
}Rook;
typedef struct{
    char** validMoves;
    PieceType type = PAWN;
    Color color;
    Point pos;
}Pawn;



void* initPiece(PieceType, Color);
char** validMovies(void*, Color);