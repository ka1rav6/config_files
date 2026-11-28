# CXX must match the compiler Hyprland itself was built with, or the plugin can
# crash the compositor on load (std::format's internals differ between GCC 14
# and 15). The cppiber PPA build works with g++-14; load.sh picks the compiler
# and proves the result in a nested Hyprland before loading it for real.
CXX ?= g++-14
# Where the .so goes; load.sh points this at ~/.cache/qs-pointer.
OUT ?= .

$(OUT)/qs-pointer.so: main.cpp compat/glslang/Include/glslang_c_interface.h /usr/include/hyprland/src/version.h
	$(CXX) -shared -fPIC -std=c++2b -O2 -idirafter compat $< -o $@ `pkg-config --cflags pixman-1 libdrm hyprland pangocairo libinput libudev wayland-server xkbcommon`

clean:
	rm -f $(OUT)/qs-pointer.so
