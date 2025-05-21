package main

import im "odin-imgui"

import "core:strconv"
import "core:fmt"

initialze_search := true
searched_data : Game_Data

draw_gui :: proc(game_data: Game_Data, opened: ^bool) {
    if im.Begin("Test", opened, {.NoSavedSettings}) {
        // Found entries tab
        
    }
    im.End()
}