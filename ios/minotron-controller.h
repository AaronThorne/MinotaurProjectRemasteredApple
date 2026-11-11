#pragma once

// The runtime patches four ARM instructions for Minotron's twin-stick mode.
// Keep the original translated code for touch mode and execute the controller
// bridge only when the patch's first instruction is present in guest memory.
inline bool step_minotron_controller(State& state) {
    constexpr uint32_t start = 0x5f4d4;
    constexpr uint32_t end = 0x5f544;
    const uint32_t pc = state.r[15];
    if (pc < start || pc >= start + 16 || (state.cpsr & 0x20u)) {
        return false;
    }
    if (read32(state, start) != 0xe1a00008) {
        return false;
    }
    switch (pc - start) {
    case 0:
        state.r[0] = state.r[8];
        state.r[15] = pc + 4;
        return true;
    case 4:
        state.r[1] = read32(state, start + 16);
        state.r[15] = pc + 4;
        return true;
    case 8:
        bx(state, state.r[1]);
        state.r[14] = pc + 4;
        return true;
    case 12:
        state.r[15] = end;
        return true;
    default:
        return false;
    }
}
