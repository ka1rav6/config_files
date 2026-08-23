#include "../include/gameState.h"

#include <websocketpp/config/asio_no_tls.hpp>
#include <websocketpp/server.hpp>

#include <iostream>
#include <string>
#include <mutex>
#include <thread>
#include <vector>
#include <sstream>

typedef websocketpp::server<websocketpp::config::asio> ws_server;

State game_state;
std::mutex state_mutex;

void parse_and_execute(const std::string& command) {
    std::istringstream iss(command);
    std::string action, target;
    iss >> action >> target;
    int player_index = -1;
    if (target.rfind("player", 0) == 0) {
        try {
            player_index = std::stoi(target.substr(6));
        } catch (...) {
            std::cerr << "[server] invalid player index in: " << command << "\n";
            return;
        }
    } else {
        std::cerr << "[server] unknown target: " << target << "\n";
        return;
    }
    if (player_index < 0 || player_index >= (int)game_state.players.size()) {
        std::cerr << "[server] player index out of range: " << player_index << "\n";
        return;
    }
    if (action == "moveUp") 
        game_state.players[player_index].moveUp();
    else if (action == "moveDown")
        game_state.players[player_index].moveDown();
    else if (action == "moveLeft")
        game_state.players[player_index].moveLeft();
    else if (action == "moveRight")
        game_state.players[player_index].moveRight();
    else
        std::cerr << "[server] unknown action: " << action << "\n";
}
void on_message(ws_server* s, websocketpp::connection_hdl hdl, ws_server::message_ptr msg) {
    std::string command = msg->get_payload();
    std::cout << "[server][thread:" << std::this_thread::get_id() << "] received: " << command << "\n";
    std::lock_guard<std::mutex> lock(state_mutex);
    parse_and_execute(command);
    auto response = serializeState(game_state);

    try {
        s->send(hdl, response, websocketpp::frame::opcode::text);
    } catch (const websocketpp::exception e) {
        std::cerr << "[server] send failed: " << e.what() << "\n";
    }
}


int main() {
    initializePosition(game_state);
    game_state.flags.first.color = 'R';
    game_state.flags.second.color = 'B';
    std::cout << "[server] initial state:\n" << game_state << "\n";
    ws_server server;
    server.set_access_channels(websocketpp::log::alevel::none);
    server.set_error_channels(websocketpp::log::elevel::all);
    server.init_asio();
    server.set_reuse_addr(true);
    server.set_message_handler( [&server](websocketpp::connection_hdl hdl, ws_server::message_ptr msg){ 
        on_message(&server, hdl, msg);
        }
    );
    server.set_open_handler([](websocketpp::connection_hdl hdl) {
        std::cout << "[server] client connected\n";
    });
    server.set_close_handler([](websocketpp::connection_hdl hdl) {
        std::cout << "[server] client disconnected\n";
    });
    server.listen(9002);
    server.start_accept();

    std::cout << "[server] listening on port 9002 with 8 threads\n";
    const int NUM_THREADS = 8;
    std::vector<std::thread> threads;
    for (int i = 0; i < NUM_THREADS - 1; i++) {
        threads.emplace_back([&server]() {
            server.run();
        });
    }
    server.run();
    for (auto& t : threads) {
        t.join();
    }

    return 0;
}
