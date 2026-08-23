#include "../include/piece.h"

void* initPiece(PieceType type, Color color){
    switch(type){
        case KING: {
            King* p = (King*) malloc(sizeof(King));
            p->color = color;
            p->type = type;
            p->moves = 0;
            p->validMoves = NULL;
            return p;
        }
        case QUEEN: {
            Queen* p = (Queen*) malloc(sizeof(Queen));
            p->color = color;
            p->type = type;
            p->moves = 0;
            p->validMoves = NULL;
            return p;
        }
        case ROOK: {
            Rook* p = (Rook*) malloc(sizeof(Rook));
            p->color = color;
            p->type = type;
            p->moves = 0;
            p->validMoves = NULL;
            return p;
        }
        case KNIGHT: {
            Knight* p = (Knight*) malloc(sizeof(Knight));
            p->color = color;
            p->type = type;
            p->moves = 0;
            p->validMoves = NULL;
            return p;
        }
        case PAWN: {
            Pawn* p = (Pawn*) malloc(sizeof(Pawn));
            p->color = color;
            p->type = type;
            p->moves = 0;
            p->validMoves = NULL;
            return p;
        }
        case BISHOP: {
            Bishop* p = (Bishop*) malloc(sizeof(Bishop));
            p->color = color;
            p->type = type;
            p->moves = 0;
            p->validMoves = NULL;
            return p;
        }
        case EMPTY: {
            Empty* p = (Empty*) malloc(sizeof(Empty));
            p->type = type;
            p->moves = 0;
            p->validMoves = NULL;
            return p;
        }
        default:
            return NULL;
    }
}

void destroyPiece(Piece *p){
    free(p->validMoves);
    free(p);
    p = NULL;
// 