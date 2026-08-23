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

void initializePosition(State& state){
    INITIAL_POS.clear();
    for (int i = 0; i < initialPoints.size() / 2; i++){
        Point p;
        p.x = initialPoints.at(2 * i);
        p.y = initialPoints.at(2 * i + 1);
        INITIAL_POS.emplace_back(p);
    }
    int i = 0;
    while (i < n){
        Player player(i, INITIAL_POS.at(i));
        state.players.emplace_back(player);
        i++;
    }
    state.flags.first.position = INITIAL_POS.at(i++);
    state.flags.second.position = INITIAL_POS.at(i++);
}


std::ostream& operator<<(std::ostream& os, const State& s) {
    os << "Players:\n";
    for (const auto& player : s.players) {
        os << player;
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
    is >> s.flags.first;
    is >> s.flags.second;

    return is;
}

std::string serializeState(const State& s) {
    std::ostringstream oss;
    oss << s.players.size() << "\n";
    for (const auto& player : s.players) {
        oss << player.getId() << " " << player.position.x << " " << player.position.y << "\n";
    }
    oss << s.flags.first.position.x << " " << s.flags.first.position.y << " " << s.flags.first.color << "\n";
    oss << s.flags.second.position.x << " " << s.flags.second.position.y << " " << s.flags.second.color << "\n";
    return oss.str();
}

State deserializeState(const std::string& data) {
    State s;
    std::istringstream iss(data);
    size_t count = 0;
    iss >> count;
    for (size_t i = 0; i < count; i++) {
        unsigned int uid;
        float x, y;
        iss >> uid >> x >> y;
        Player p(uid, x, y);
        s.players.push_back(p);
    }
    iss >> s.flags.first.position.x >> s.flags.first.position.y >> s.flags.first.color;
    iss >> s.flags.second.position.x >> s.flags.second.position.y >> s.flags.second.color;
    return s;
}