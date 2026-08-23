//custom includes
#include "../include/Point.h"


std::ostream& operator<<(std::ostream& os, const Point& p) {
    return os << "X position: " << p.x << " Y position: " << p.y << "\n";
}

std::istream& operator>>(std::istream& is, Point& p) {
    return is >> p.x >> p.y;
}