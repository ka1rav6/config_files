//custom includes
#include "../include/gameState.h"



std::ostream& operator<<(std::ostream& os, const State& s) {
    os << "Players:\n";
    for (const auto& player : s.players) {
        os << player << "\n";
    }
    os << "Flag1: " << s.flags.first << "\n";
    os << "Flag2: " << s.flags.second << "\n";
    return os;
}
std::istream& operator>>(std::istream& is, State& p) {
    return is >> p.x >> p.y;
}