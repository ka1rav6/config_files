#pragma once

#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include "Move.h"
#include "point.h"

typedef struct Board Board;
typedef struct Square Square;

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
    Move* validMoves;
    size_t moves;
    PieceType type;
    Color color;
    Point pos;
}King;

typedef struct{
    Move* validMoves;
    size_t moves;
    PieceType type;
    Color color;
    Point pos;
}Queen;

typedef struct{
    Move* validMoves;
    size_t moves;
    PieceType type;
    Color color;
    Point pos;
}Knight;

typedef struct{
    Move* validMoves;
    size_t moves;
    PieceType type;
    Color color;
    Point pos;
}Bishop;

typedef struct{
    PieceType type;
    Point pos;
}Empty;

typedef struct{
    Move* validMoves;
    size_t moves;
    PieceType type;
    Color color;
    Point pos;
}Rook;
typedef struct{
    Move* validMoves;
    size_t moves;
    PieceType type;
    Color color;
    Point pos;
}Pawn;
typedef struct{
    Move* validMoves;
    size_t moves;
    PieceType type;
    Color color;
    Point pos;
}Piece;


// common functions for each piece
void* initPiece(PieceType, Color);
Move* validMovies(void*, Color);
void destroyPiece(Piece* p);


void getKingValidMoves(Board*, Square*);
void getQueenValidMoves(Board*, Square*);
void getPawnValidMoves(Board*, Square*);
void getKnightValidMoves(Board*, Square*);
void getBishopValidMoves(Board*, Square*);
void getRookValidMoves(Board*, Square*);