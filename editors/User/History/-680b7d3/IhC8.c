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
    board->hasEnPassantTarget = false;
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


static bool isValidPoint(Point p) {
    return p.col >= 'a' && p.col <= 'h' && p.row >= 1 && p.row <= 8;
}

static int colIndex(char col) {
    return col - 'a';
}

static int rowIndex(int row) {
    return row - 1;
}

static Square* getSquare(Board* b, Point p) {
    if (!isValidPoint(p)) {
        return NULL;
    }
    return &b->arr[rowIndex(p.row)][colIndex(p.col)];
}

static void resetPieceMoves(Piece* piece) {
    if (!piece) {
        return;
    }
    free(piece->validMoves);
    piece->validMoves = NULL;
    piece->moves = 0;
}

Square* getPossiblePieces(Board* b, PieceType type, Move* m, char disambFile, char disambRank){
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
        for (int j = 0; j < 8; j++){
            Square s = b->arr[i][j];
            if (s.type == type && s.color == col) {
                possible[k++] = s;
            }
        }
    }

    for (int i = 0; i < k; i++){
        Square candidate = possible[i];
        if (disambFile && candidate.p.col != disambFile) {
            continue;
        }
        if (disambRank && candidate.p.row != disambRank - '0') {
            continue;
        }

        Piece* piece = (Piece*)candidate.piecePtr;
        resetPieceMoves(piece);
        getValidMoves(b, &candidate);
        for (int j = 0; j < (int) piece->moves; j++){
            if (equals(piece->validMoves[j].end, m->end)){
                logg("Found possible piece");
                Square* result = (Square*)malloc(sizeof(Square));
                *result = candidate;
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
        case KING:
            getKingValidMoves(b, s);
            break;
        case QUEEN:
            getQueenValidMoves(b, s);
            break;
        case BISHOP:
            getBishopValidMoves(b, s);
            break;
        case KNIGHT:
            getKnightValidMoves(b, s);
            break;
        case PAWN:
            getPawnValidMoves(b, s);
            break;
        case ROOK:
            getRookValidMoves(b, s);
            break;
        default:
            logg("Tried accessing valid possible moves of unknown piece");
    }
}

static void appendMove(Piece* piece, Move move) {
    piece->moves++;
    piece->validMoves = realloc(piece->validMoves, piece->moves * sizeof(Move));
    if (piece->validMoves == NULL) {
        logg("Unable to assign more memory to moves in piece");
        printf("memory assignment error\n");
        exit(EXIT_FAILURE);
    }
    piece->validMoves[piece->moves - 1] = move;
}

void getKingValidMoves(Board* b, Square* s) { (void)b; (void)s; logg("getKingValidMoves stub"); }
void getQueenValidMoves(Board* b, Square* s) { (void)b; (void)s; logg("getQueenValidMoves stub"); }
void getKnightValidMoves(Board* b, Square* s) {
    Piece* piece = (Piece*) s->piecePtr;
    if (!piece) {
        return;
    }
    resetPieceMoves(piece);

    const int offsets[8][2] = {
        {1, 2}, {2, 1}, {2, -1}, {1, -2},
        {-1, -2}, {-2, -1}, {-2, 1}, {-1, 2}
    };
    for (int i = 0; i < 8; i++) {
        Point target = createPoint(s->p.col + offsets[i][0], s->p.row + offsets[i][1]);
        Square* dest = getSquare(b, target);
        if (!dest) {
            continue;
        }
        if (dest->type == EMPTY || dest->color != s->color) {
            Move move = {.start = s->p, .end = target, .isCaptured = dest->type != EMPTY};
            appendMove(piece, move);
        }
    }
}
void getBishopValidMoves(Board* b, Square* s) { (void)b; (void)s; logg("getBishopValidMoves stub"); }
void getRookValidMoves(Board* b, Square* s) { (void)b; (void)s; logg("getRookValidMoves stub"); }

void getPawnValidMoves(Board* b, Square* s) {
    Pawn* p = (Pawn*) s->piecePtr;
    if (!p) {
        return;
    }

    resetPieceMoves((Piece*) p);

    bool isWhite = (b->state == WHITE_PLAY);
    int direction = isWhite ? 1 : -1;
    int startRow = isWhite ? 2 : 7;
    int enPassantRow = isWhite ? 5 : 4;

    Point forwardOne = createPoint(s->p.col, s->p.row + direction);
    Point forwardTwo = createPoint(s->p.col, s->p.row + direction * 2);
    Point leftDiag = createPoint(s->p.col - 1, s->p.row + direction);
    Point rightDiag = createPoint(s->p.col + 1, s->p.row + direction);

    Square* forwardSquare = getSquare(b, forwardOne);
    if (forwardSquare && forwardSquare->type == EMPTY) {
        Move move = {.start = s->p, .end = forwardOne, .isCaptured = false};
        p->moves++;
        p->validMoves = realloc(p->validMoves, p->moves * sizeof(Move));
        if (p->validMoves == NULL) {
            logg("Unable to assign more memory to Valid moves in pawn struct");
            printf("memory assignment error\n");
            exit(EXIT_FAILURE);
        }
        p->validMoves[p->moves - 1] = move;

        if (s->p.row == startRow) {
            Square* secondSquare = getSquare(b, forwardTwo);
            if (secondSquare && secondSquare->type == EMPTY) {
                Move move2 = {.start = s->p, .end = forwardTwo, .isCaptured = false};
                p->moves++;
                p->validMoves = realloc(p->validMoves, p->moves * sizeof(Move));
                if (p->validMoves == NULL) {
                    logg("Unable to assign more memory to Valid moves in pawn struct");
                    printf("memory assignment error\n");
                    exit(EXIT_FAILURE);
                }
                p->validMoves[p->moves - 1] = move2;
            }
        }
    }

    Point diags[2] = { leftDiag, rightDiag };
    for (int i = 0; i < 2; i++) {
        Square* diagSquare = getSquare(b, diags[i]);
        if (diagSquare && diagSquare->type != EMPTY && diagSquare->color != s->color) {
            Move move = {.start = s->p, .end = diags[i], .isCaptured = true};
            p->moves++;
            p->validMoves = realloc(p->validMoves, p->moves * sizeof(Move));
            if (p->validMoves == NULL) {
                logg("Unable to assign more memory to Valid moves in pawn struct");
                printf("memory assignment error\n");
                exit(EXIT_FAILURE);
            }
            p->validMoves[p->moves - 1] = move;
        }
    }

    if (s->p.row == enPassantRow && b->hasEnPassantTarget) {
        Point target = b->enPassantTarget;
        if (equals(target, leftDiag) || equals(target, rightDiag)) {
            Point pawnToCapture = createPoint(target.col, s->p.row);
            Square* captureSquare = getSquare(b, pawnToCapture);
            if (captureSquare && captureSquare->type == PAWN && captureSquare->color != s->color) {
                Move enPassantMove = {.start = s->p, .end = target, .isCaptured = true};
                p->moves++;
                p->validMoves = realloc(p->validMoves, p->moves * sizeof(Move));
                if (p->validMoves == NULL) {
                    logg("Unable to assign more memory to Valid moves in pawn struct");
                    printf("memory assignment error\n");
                    exit(EXIT_FAILURE);
                }
                p->validMoves[p->moves - 1] = enPassantMove;
            }
        }
    }
}
