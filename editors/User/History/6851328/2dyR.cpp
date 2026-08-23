//custom includes
#include "../include/gameState.h"
#include <vector>


size_t n = 8;
const std::vector<int> initialPoints ={
    1,1,
    3, 3,
    3, 5,
    1, 7,
};

void initializePosition(){
    Point p1;
    p1.x = 1;
    p1.y = 1;
    INITIAL_POS.emplace_back(p1);
}


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
    size_t n = 8;
    is >> n;
    s.players.clear();

    for (size_t i = 0; i < n; i++) {
        Player p(i, i+1, i + 2);
        is >> p;
        s.players.push_back(p);
    }
    s.players.resize(n);
    for (auto& player : s.players)
        is >> player;
    is >> s.flags.first;
    is >> s.flags.second;

    return is;
}