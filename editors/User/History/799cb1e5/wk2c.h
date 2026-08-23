#pragma once

#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>

#include "point.h"
#define MAX_VALID 27 // theoretically max moves

// Color Enum
typedef enum{
    WHITE,
    BLACK
}Color;

// Enum for type of piece
typedef enum{
    PAWN,
    ROOK,
    KNIGHT,
    BISHOP,
    QUEEN,
    KING,
    EMPTY
}PieceType;

// different structures for each possible piece
typedef struct{
    char** validMoves;
    PieceType type;
    Color color;
    Point pos;
}King;

typedef struct{
    char** validMoves;
    PieceType type;
    Color color;
    Point pos;
}Queen;

typedef struct{
    char** validMoves;
    PieceType type;
    Color color;
    Point pos;
}Knight;

typedef struct{
    char** validMoves;
    PieceType type;
    Color color;
    Point pos;
}Bishop;

typedef struct{
    char** validMoves;
    PieceType type;
    Color color;
    Point pos;
}Empty;

typedef struct{
    char** validMoves;
    PieceType type;
    Color color;
    Point pos;
}Rook;
typedef struct{
    char** validMoves;
    PieceType type;
    Color color;
    Point pos;
}Pawn;


// common functions for each piece
void* initPiece(PieceType, Color);
char** validMovies(void*, Color);
