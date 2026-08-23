//custom includes
#include "../include/gameState.h"
#include <vector>


size_t n = 8;
std::vector<Point> INITIAL_POS;

const std::vector<int> initialPoints ={
    // team red
    10,10,
    30, 30,
    30, 50,
    10, 70,

    // team blue
    300, 300,
    290, 290,
    270, 250,
    290, 230,
    
    // flags
    5, 40,
    305, 270    
};

void initializePosition(){
    for (int i = 0; i < 8; i++){
        Point p;
        p.x = initialPoints.at(i);
        p.y = initialPoints.at(i + 1);
        INITIAL_POS.emplace_back(p);
    }
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