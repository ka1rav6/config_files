#pragma once

#include <iostream>
#include <string>
#include <sstream>
#include <vector>
#include <stdint.h>
#include <sys/types.h>
#include <cstdint>

#define GROW_CAPACITY(capacity) ((capacity) < 8 ? 8 : (capacity) * 2)
#define GROW_ARRAY(type, pointer, oldCount, newCount) \    (type*)realloc((pointer), sizeof(type) * (newCount))