#include "sudoku.h"
#include "display.h"

void display(Sudoku *s){
    for(int i=0; i<9; i++){
        for(int j=0; j<9; j++){
            std::cout<<s->box[i][j];
        }
        std::cout << std::endl;
    }
}