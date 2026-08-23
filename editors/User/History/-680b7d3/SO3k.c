#include "../include/board.h"


Board* initBoard(){
    logg("Board initialization begins");
    // the whole board is initialized and every position is made. All pieces are made and fixed
    Board* board = (Board*)malloc(sizeof(Board));
    if (!board){
        logg("Initialization of board pointer failed\n");
        exit(EXIT_FAILURE);
    }
    logg("Board pointer initialized\n");

    board->state = DEFAULT;
    // assigning points to all the squares

    for (int i = 0; i < 8; i++){
        for (int j = 0; j < 8; j ++){
            board->arr[i][j].p = createPoint((char)('a' + j), i + 1);
        }
    }
    logg("Points assigned to each sqaure");

    // Creating and placing pieces there
    for (int i = 0; i < 8; i++){
        for (int j = 0; j < 8; j ++){
            Point sq_pnt = board->arr[i][j].p;
            if (sq_pnt.row == 1 || sq_pnt.row == 8){
                Color col = sq_pnt.row == 1 ? WHITE : BLACK;
                board->arr[i][j].color = col;
                switch(sq_pnt.col){
                    case 'a':
                    case 'h':
                        board->arr[i][j].piecePtr = initPiece(ROOK, col);
                        board->arr[i][j].type = ROOK;
                        break;
                    case 'b':
                    case 'g':
                        board->arr[i][j].piecePtr = initPiece(KNIGHT, col);
                        board->arr[i][j].type = KNIGHT;
                        break;
                    case 'c':
                    case 'f':
                        board->arr[i][j].piecePtr = initPiece(BISHOP, col);
                        board->arr[i][j].type = BISHOP;
                        break;
                    case 'd':
                        board->arr[i][j].piecePtr = initPiece(QUEEN, col);
                        board->arr[i][j].type = QUEEN;
                        break;
                    case 'e':
                        board->arr[i][j].piecePtr = initPiece(KING, col);
                        board->arr[i][j].type = KING;
                        break;
                    default:
                        break;
                }
            }
            else if (sq_pnt.row == 2 || sq_pnt.row == 7){
                Color col = sq_pnt.row == 2 ? WHITE : BLACK;
                board->arr[i][j].color = col;
                board->arr[i][j].piecePtr = initPiece(PAWN, col);
                board->arr[i][j].type = PAWN;
            }
            else{
                board->arr[i][j].color = WHITE;
                board->arr[i][j].piecePtr = initPiece(EMPTY, WHITE);
                board->arr[i][j].type = EMPTY;
            }
        }
    }
    logg("All pieces placed on the board correctly\n");
    return board;
}

void destroyBoard(Board* b) {
    if (!b) return;
    for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8; j++) {
            if (b->arr[i][j].piecePtr) {
                free(b->arr[i][j].piecePtr);
            }
        }
    }
    free(b);
    logg("Board destroyed successfully");
}


Square* getPossiblePieces(Board* b, PieceType type, Move* m){
    logg("Getting possible pieces");

    Color col;
    if (b->state == WHITE_PLAY)
        col = WHITE;
    else if (b->state == BLACK_PLAY)
        col = BLACK;
    else{
        printf("Not a valid printable state");
        logg("Unable to find a state for finding possible pieces");
        exit(EXIT_FAILURE);
    }

    Square* possible = (Square*)malloc(16 * sizeof(Square));
    int k = 0;
    for (int i = 0; i < 8; i++){
        for (int j = 0; j < 8; j ++){
            Square s = b->arr[i][j];
            if (s.type == type && s.color == col)
                possible[k++] = s;
        }
    }

    for (int i = 0; i < k; i++){
        Piece* piece = (Piece*)possible[i].piecePtr;
        Move* moves = piece->validMoves;
        for (int j = 0; j < piece->moves; j++){
            if (moves[j].end == m->end){
                logg("Found possible piece");
                Square* result = (Square*)malloc(sizeof(Square));
                *result = possible[i];
                free(possible);
                return result;
            }
        }
    }

    logg("Could not find the possible piece");
    free(possible);
    return NULL;
}


void getValidMoves(Board* b, Square* s){
    logg("Fetching valid moves of a piece");
    Piece* p = (Piece*) s->piecePtr;
    switch(p->type){
        case KING:{
            King* k = (King*) p;
            getKingValidMoves(b, s);
            break;
        }
        case QUEEN:{
            Queen* k = (Queen*) p;
            getQueenValidMoves(b, s);
            break;
        }
        case BISHOP:{
            Bishop* k = (Bishop*) p;
            getBishopValidMoves(b, s);
            break;
        }
        case KNIGHT:{
            Knight* k = (Knight*) p;
            getKnightValidMoves(b, s);
            break;
        }
        case PAWN:{
            Pawn* k = (Pawn*) p;
            getPawnValidMoves(b, s);
            break;
        }
        case ROOK:{
            Rook* k = (Rook*) p;
            getRookValidMoves(b, s);
            break;
        }
        default:
            logg("Tried accessing valid possible moves of unknown piece");
    }
}

void getKingValidMoves(Board* b, Square* s) { logg("getKingValidMoves stub"); }
void getQueenValidMoves(Board* b, Square* s) { logg("getQueenValidMoves stub"); }
void getPawnValidMoves(Board* b, Square* s) { logg("getPawnValidMoves stub"); }
void getKnightValidMoves(Board* b, Square* s) { logg("getKnightValidMoves stub"); }
void getBishopValidMoves(Board* b, Square* s) { logg("getBishopValidMoves stub"); }
void getRookValidMoves(Board* b, Square* s) { logg("getRookValidMoves stub"); }
