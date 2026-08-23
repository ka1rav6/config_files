#ifndef GAMESTATE_H
#define GAMESTATE_H

// custom includes
#include "./Flag.h"
#include "./Player.h"
#include "./Point.h"

// other includes
#include <utility>
#include <vector>

struct state{
    std::vector<Player> players;
    std::pair<Flag, Flag> flags;    
};

#endif