#include <iostream>
#include <fstream>
#include "sudoku.h"
#include "xcounter.h"
#include "sudokusolver.h"
#include "display.h"

int main()
{   
    Sudoku s("source.txt");
    std::ifstream source("source.txt");

    if (!s.isValid){
        std::cout<<"The Sudoku is not valid"<<std::endl;
    }
    else{
        sudokuSolver(&s);
        display(&s);
    }
}