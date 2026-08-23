#ifndef FLAG_H
#define FLAG_H

#include "Point.h"


#include <ostream>
#include <istream>

class Flag{
    Point position;
    char color; // R or B

    friend std::ostream& operator<<(std::ostream& os, const Flag& f) {
        return os << f.position << " " << f.color << "\n";
    }    
    friend std::istream& operator>>(std::istream& is, Flag& f) {
        return is >> f.position >> f.color;
    }

};


#endif
