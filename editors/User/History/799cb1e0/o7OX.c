#include "piece.h"

void* initPiece(PieceType type, Color color){
    switch(type){
        case KING: {
            King* p = (King*) malloc(sizeof(King));
            p->color = color;
            p->type = type;
            return p;
        }
        case QUEEN: {
            Queen* p = (Queen*) malloc(sizeof(Queen));
            p->color = color;
            p->type = type;
            return p;
        }
        case ROOK: {
            Rook* p = (Rook*) malloc(sizeof(Rook));
            p->color = color;
            p->type = type;
            return p;
        }
        case KNIGHT: {
            Knight* p = (Knight*) malloc(sizeof(Knight));
            p->color = color;
            p->type = type;
            return p;
        }
        case PAWN: {
            Paw* p = (Paw*) malloc(sizeof(Paw));
            p->color = color;
            p->type = type;
            return p;
        }
        case BISHOP: {
            Queen* p = (Queen*) malloc(sizeof(Queen));
            p->color = color;
            p->type = type;
            return p;
        }
        case EMPTY: {
            Queen* p = (Queen*) malloc(sizeof(Queen));
            p->color = color;
            p->type = type;
            return p;
        }


    }
}