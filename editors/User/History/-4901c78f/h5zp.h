#ifndef GAMESTATE_H
#define GAMESTATE_H

// custom includes
#include "./Flag.h"
#include "./Player.h"
#include "./Point.h"

// other includes
#include <utility>
#include <vector>

struct State{
    std::vector<Player> players;
    std::pair<Flag, Flag> flags;    
};

std::ostream& operator<<(std::ostream&, const State&);
std::istream& operator>>(std::istream&, State&);

#endif