//custom includes
#include "../include/gameState.h"



std::ostream& operator<<(std::ostream& os, const State& p) {
    return os << "X position: " << p.x << " Y position: " << p.y << "\n";
}

std::istream& operator>>(std::istream& is, State& p) {
    return is >> p.x >> p.y;
}