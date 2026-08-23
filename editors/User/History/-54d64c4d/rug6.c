//
// Created by kairav on 5/30/26.
//

#include "../include/moveParser.h"


static bool isFileChar(char c) {
    return c >= 'a' && c <= 'h';
}

static bool isRankChar(char c) {
    return c >= '1' && c <= '8';
}

Move* convertToMove(Board* b, char* inp) {
    char piece = inp[0];
    size_t len = strlen(inp);
    bool isCapturing = false;
    for (size_t i = 0; i < len; i++) {
        if (inp[i] == 'x') {
            isCapturing = true;
            break;
        }
    }
    bool isPawn = (piece >= 'a' && piece <= 'z');
    Move * move = (Move*) malloc(sizeof(Move));
    if (!move) {
        logg("Unable to allocate Move in MoveParser");
        exit(EXIT_FAILURE);
    }
    move->isCaptured = isCapturing;
    PieceType ptype = EMPTY;
    if (!isPawn) {
        switch (piece) {
            case 'K':
                ptype = KING;
                break;
            case 'Q':
                ptype = QUEEN;
                break;
            case 'R':
                ptype = ROOK;
                break;
            case 'B':
                ptype = BISHOP;
                break;
            case 'N':
                ptype = KNIGHT;
                break;
            default:
                logg("Tried accessing pieceType of unknown piece in MoveParser");
                break;
        }
    } else {
        ptype = PAWN;
    }

    move->end = createPoint(inp[len - 2], inp[len - 1] - '0');
    char disambFile = 0;
    char disambRank = 0;
    if (!isPawn && len > 3) {
        for (size_t i = 1; i < len - 2; i++) {
            if (inp[i] == 'x') {
                continue;
            }
            if (!disambFile && isFileChar(inp[i])) {
                disambFile = inp[i];
                continue;
            }
            if (!disambRank && isRankChar(inp[i])) {
                disambRank = inp[i];
                continue;
            }
        }
    }

    Square* source = getPossiblePieces(b, ptype, move, disambFile, disambRank);
    if (!source) {
        logg("Unable to resolve exact piece for move in MoveParser");
        free(move);
        return NULL;
    }
    move->start = source->p;
    free(source);

    return move;
}