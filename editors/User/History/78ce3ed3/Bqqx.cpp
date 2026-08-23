#include "sudoku.h"
#include<cstring>
#include<string>
#include<fstream>

Sudoku::Sudoku(std::string fileName) {
    isValid = false;
    readFile(fileName);   
    Validator v(this);
    isValid = v.overallCheck();
}

void Sudoku::readFile(std::string fileName)
{
    std::ifstream file(fileName);
    if (!file.is_open())
    {
        std::cerr << "Error opening file: " << fileName << std::endl;
        return;
    }
    std::string text;
    int row = 0;
    while (std::getline(file, text) && row < 9)
    {
        for (int col = 0; col < 9; col++)
        {
            this->box[row][col] = text[col];
        }
        row++;
    }
}
/**
 *
 * Note there is a lot to be still implemented here and this 
 * just shows the basic structure that it should be in.
 *
 */