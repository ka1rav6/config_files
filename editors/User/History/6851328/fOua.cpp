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
std::istream& operator>>(std::istream& is, State& s) {
    size_t n;
    is >> n;
    s.players.resize(n);
    for (auto& player : s.players)
        is >> player;
    is >> s.flags.first;
    is >> s.flags.second;

    return is;
}