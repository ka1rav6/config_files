#ifndef POINT_H
#define POINT_H

struct Point{
    float x;
    float y;
};
std::ostream& operator<<(std::ostream&, const Point&);
std::istream& operator>>(std::istream&, Point&);

#endif