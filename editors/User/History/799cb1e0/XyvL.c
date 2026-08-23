#include "piece.h"

Piece* initPiece(PieceType type, Color color){
    Piece p;
    p.validMoves = (char**) malloc(sizeof(char*) * MAX_VALID);
    
}