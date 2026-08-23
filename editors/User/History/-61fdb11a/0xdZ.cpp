#include<iostream>
#include "sudoku.h"
#include "sudokusolver.h"
#include "boxsolver.h"
#include "columnsolver.h"
#include "rowsolver.h"
#include "validation.h"
#include "xcounter.h"


void sudokuSolver(Sudoku *s){
    loop:
    for(int i=0; i<9; i++){
        if(xCounter(s)!=0){
        BoxSolver *b = new BoxSolver(s);
        
        b->Box1('1' + i);
        b->Box2('1' + i);
        b->Box3('1' + i);
        b->Box4('1' + i);
        b->Box5('1' + i);
        b->Box6('1' + i);
        b->Box7('1' + i);
        b->Box8('1' + i);
        b->Box9('1' + i);
        delete b;
        }
        else{
            std::cout<<"Sudoku is completed"<<std::endl;
            return;
        }
        goto loop;
}
}