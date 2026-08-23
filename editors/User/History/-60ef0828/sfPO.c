#include "board.h"
#include "piece.h"
#include "point.h"
#include "debugger.h"

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
            board->arr[i][j].p = createPoint(i + 1, (char) ('a' + j));
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
                board->arr[i][j].color = WHITE; // added white arbitrarily
                board->arr[i][j].piecePtr = initPiece(EMPTY, WHITE);
                board->arr[i][j].type = EMPTY;
            }
        }
    }
    logg("All pieces placed on the board correctly\n");
    return board;
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
    bool exists = false;
    int count = 0;
    for (int i = 0; i < k; i ++){
        Piece* piece = (Piece*)possible[i].piecePtr;
        Move* moves = piece->validMoves;
        for (int j = 0; j < piece->moves ; j++){
            if (moves[j].end == m->end){
                exists = true;
                goto found;
            }
        }
        count ++;       
    }
    if (exists){
    found:
        logg("Found possible piece");
        return &possible[count] ;
    }
    logg("Could not find the possible piece");
    return NULL;
}



Move* getValidMoves(Square* s){
    Piece* p = (Piece*) s->piecePtr;
    switch(p->type){
        case KING:{
            King* k = (King*) p;
            getKingValidMoves(k, s);
            break;
        }
        case QUEEN:{
            King* k = (King*) p;
            getQueenValidMoves(k, s);
            break;
        }
        case KING:
            King* k = (King*) p;
            getKingValidMoves(k, s);
            break;
        case KING:
            King* k = (King*) p;
            getKingValidMoves(k, s);
            break;
        case KING:
            King* k = (King*) p;
            getKingValidMoves(k, s);
            break;
        case KING:
            King* k = (King*) p;
            getKingValidMoves(k, s);
            break;
        
    }
}
