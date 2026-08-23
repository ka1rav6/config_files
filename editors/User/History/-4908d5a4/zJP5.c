#include <stdio.h>
#include <stdlib.h>
#include "../include/board.h"
#include "../include/piece.h"
#include "../include/point.h"
#include "../include/debugger.h"
#include "../include/moveParser.h"

void testPointCreation() {
    printf("\n=== Testing Point Creation ===\n");
    Point p = createPoint('a', 1);
    printf("Created point: col=%c, row=%d\n", p.col, p.row);
    logg("testPointCreation completed");
}

void testPieceInitialization() {
    printf("\n=== Testing Piece Initialization ===\n");

    King* king = (King*) initPiece(KING, WHITE);
    if (king) {
        printf("King created: type=%d, color=%d, moves=%zu\n", king->type, king->color, king->moves);
        logg("King initialized successfully");
        free(king);
    }

    Pawn* pawn = (Pawn*) initPiece(PAWN, BLACK);
    if (pawn) {
        printf("Pawn created: type=%d, color=%d, moves=%zu\n", pawn->type, pawn->color, pawn->moves);
        logg("Pawn initialized successfully");
        free(pawn);
    }

    Rook* rook = (Rook*) initPiece(ROOK, WHITE);
    if (rook) {
        printf("Rook created: type=%d, color=%d, moves=%zu\n", rook->type, rook->color, rook->moves);
        logg("Rook initialized successfully");
        free(rook);
    }

    Queen* queen = (Queen*) initPiece(QUEEN, BLACK);
    if (queen) {
        printf("Queen created: type=%d, color=%d, moves=%zu\n", queen->type, queen->color, queen->moves);
        logg("Queen initialized successfully");
        free(queen);
    }

    Knight* knight = (Knight*) initPiece(KNIGHT, WHITE);
    if (knight) {
        printf("Knight created: type=%d, color=%d, moves=%zu\n", knight->type, knight->color, knight->moves);
        logg("Knight initialized successfully");
        free(knight);
    }

    Bishop* bishop = (Bishop*) initPiece(BISHOP, BLACK);
    if (bishop) {
        printf("Bishop created: type=%d, color=%d, moves=%zu\n", bishop->type, bishop->color, bishop->moves);
        logg("Bishop initialized successfully");
        free(bishop);
    }

    Empty* empty = (Empty*) initPiece(EMPTY, WHITE);
    if (empty) {
        printf("Empty created: type=%d\n", empty->type);
        logg("Empty initialized successfully");
        free(empty);
    }
}

void testBoardInitialization() {
    printf("\n=== Testing Board Initialization ===\n");

    Board* board = initBoard();
    if (board) {
        printf("Board created successfully\n");
        printf("Board state: %d\n", board->state);

        // Check a few key positions
        printf("\nChecking initial positions:\n");
        printf("a1 (WHITE ROOK): type=%d, color=%d\n", board->arr[0][0].type, board->arr[0][0].color);
        printf("e1 (WHITE KING): type=%d, color=%d\n", board->arr[0][4].type, board->arr[0][4].color);
        printf("a8 (BLACK ROOK): type=%d, color=%d\n", board->arr[7][0].type, board->arr[7][0].color);
        printf("e8 (BLACK KING): type=%d, color=%d\n", board->arr[7][4].type, board->arr[7][4].color);
        printf("a2 (WHITE PAWN): type=%d, color=%d\n", board->arr[1][0].type, board->arr[1][0].color);
        printf("e4 (EMPTY): type=%d\n", board->arr[3][4].type);

        logg("Board initialization test completed");
        destroyBoard(board);
    } else {
        printf("Board initialization failed\n");
        logg("Board initialization failed");
    }
}

static int colIndex(char col) {
    return col - 'a';
}

static Square* squareAt(Board* board, char col, int row) {
    if (col < 'a' || col > 'h' || row < 1 || row > 8) {
        return NULL;
    }
    return &board->arr[row - 1][colIndex(col)];
}

static void setSquare(Board* board, char col, int row, PieceType type, Color color) {
    Square* sq = squareAt(board, col, row);
    if (!sq) {
        return;
    }
    if (sq->piecePtr) {
        destroyPiece((Piece*) sq->piecePtr);
    }
    sq->p = createPoint(col, row);
    sq->type = type;
    sq->color = color;
    sq->piecePtr = initPiece(type, color);
}

void testPieceDestruction() {
    printf("\n=== Testing Piece Destruction ===\n");

    Piece* piece = (Piece*) initPiece(QUEEN, WHITE);
    if (piece) {
        printf("Piece created before destruction\n");
        destroyPiece(piece);
        printf("Piece destroyed successfully\n");
        logg("Piece destruction test completed");
    }
}

void testPawnForwardMoves() {
    printf("=== Testing Pawn Forward Moves ===\n");

    Board* board = initBoard();
    board->state = WHITE_PLAY;

    Square* pawn = squareAt(board, 'e', 2);
    getValidMoves(board, pawn);
    Piece* p = (Piece*) pawn->piecePtr;
    printf("Pawn at e2 found %zu valid move(s)\n", p->moves);
    for (size_t i = 0; i < p->moves; i++) {
        printf("  Move %zu: %c%d captured=%d\n", i + 1, p->validMoves[i].end.col, p->validMoves[i].end.row, p->validMoves[i].isCaptured);
    }
    destroyBoard(board);
}

void testPawnCaptureMoves() {
    printf("=== Testing Pawn Capture Moves ===\n");

    Board* board = initBoard();
    board->state = WHITE_PLAY;

    setSquare(board, 'e', 5, PAWN, WHITE);
    setSquare(board, 'f', 6, PAWN, BLACK);
    Square* pawn = squareAt(board, 'e', 5);
    getValidMoves(board, pawn);
    Piece* p = (Piece*) pawn->piecePtr;
    printf("Pawn at e5 found %zu valid move(s)\n", p->moves);
    for (size_t i = 0; i < p->moves; i++) {
        printf("  Move %zu: %c%d captured=%d\n", i + 1, p->validMoves[i].end.col, p->validMoves[i].end.row, p->validMoves[i].isCaptured);
    }
    destroyBoard(board);
}

void testPawnEnPassantMove() {
    printf("=== Testing Pawn En Passant Moves ===\n");

    Board* board = initBoard();
    board->state = WHITE_PLAY;
    board->hasEnPassantTarget = true;
    board->enPassantTarget = createPoint('d', 6);

    setSquare(board, 'e', 5, PAWN, WHITE);
    setSquare(board, 'd', 5, PAWN, BLACK);
    Square* pawn = squareAt(board, 'e', 5);
    getValidMoves(board, pawn);
    Piece* p = (Piece*) pawn->piecePtr;
    printf("Pawn at e5 found %zu valid move(s)\n", p->moves);
    for (size_t i = 0; i < p->moves; i++) {
        printf("  Move %zu: %c%d captured=%d\n", i + 1, p->validMoves[i].end.col, p->validMoves[i].end.row, p->validMoves[i].isCaptured);
    }
    destroyBoard(board);
}

void testMoveParserDisambiguation() {
    printf("=== Testing Move Parser Disambiguation ===\n");

    Board* board = initBoard();
    board->state = WHITE_PLAY;
    board->hasEnPassantTarget = false;

    setSquare(board, 'g', 1, KNIGHT, WHITE);
    setSquare(board, 'e', 5, KNIGHT, WHITE);
    setSquare(board, 'f', 3, PAWN, BLACK);

    Move* move = convertToMove(board, "N1xf3");
    if (move) {
        printf("Parsed move: start=%c%d end=%c%d captured=%d\n", move->start.col, move->start.row, move->end.col, move->end.row, move->isCaptured);
        free(move);
    } else {
        printf("Move parser failed to disambiguate N1xf3\n");
    }
    destroyBoard(board);
}

int main() {
    printf("========================================\n");
    printf("Chess Engine - Function Testing\n");
    printf("========================================\n");

    testPointCreation();
    testPieceInitialization();
    testBoardInitialization();
    testPieceDestruction();
    testPawnForwardMoves();
    testPawnCaptureMoves();
    testPawnEnPassantMove();
    testMoveParserDisambiguation();

    printf("\n========================================\n");
    printf("All tests completed\n");
    printf("Check logs.txt for detailed logging\n");
    printf("========================================\n");

    return 0;
}
