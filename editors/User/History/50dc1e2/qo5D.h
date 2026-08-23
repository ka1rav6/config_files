#ifndef POINT_H
#define POINT_H


// other includes
#include <ostream>
#include <istream>

struct Point{
    float x;
    float y;
};
std::ostream& operator<<(std::ostream&, const Point&);
std::istream& operator>>(std::istream&, Point&);

#endif