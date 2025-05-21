#+feature dynamic-literals
package main

import "core:encoding/json"
import "core:os/os2"
import "core:fmt"
import "core:slice"
import "core:strings"
import "core:mem/virtual"
import "core:mem"
import "base:runtime"

Basic_Info :: struct {
    sprite_ingame: string,
    sprite_inv:    string,
    description:   string,
    category:      string,
    scrap:         string,
    name:          string,

    quest_item:  bool,
    can_be_sold: bool,

    stack_max: int,
    value:     int,
    weight:    f32,
}

Ammo_Info :: struct {
    caliber: string,
    eff_range: string,
    
    acc:    int,
    pen:    int,
    dur:    f32,
    shell:  int,
    damage: int,
    number: int,
    recoil: int,
}

Armor_Info :: struct {
    dur_damage: int,
    anomaly: int, 
    class:   int,
    pierce: f32,
    radiation: int,
    s_dead: string,
    s_idle: string,
    s_run:  string,

    //__unused: f32 `json:firearm__UNUSED`,
}

Item_Category :: enum {
    Ammo,
    Armor,
}

Game_Item_Entry :: struct {
    item_info: union {
        Ammo_Info,
        Armor_Info,
    },
    basic: Basic_Info,
}

skipped_files :: []string {
    // has multiple duplicate keys and isnt needed anyways
    "item_category.json",
}

Game_Data :: struct {
    // Item category -> items
    items: [][dynamic]Game_Item_Entry,

    arena: virtual.Arena,
    allocator: mem.Allocator,
}

create_game_data :: proc() -> Game_Data {
    game_data : Game_Data
    _ = virtual.arena_init_growing(&game_data.arena)
    game_data.allocator = virtual.arena_allocator(&game_data.arena)

    game_data.items = make([][dynamic]Game_Item_Entry, len(Item_Category), allocator = game_data.allocator)
    for category in Item_Category {
        game_data.items[category] = make([dynamic]Game_Item_Entry, 0, allocator = game_data.allocator)
    }

    return game_data
}

delete_game_data :: proc(game_data: ^Game_Data) {
    free_all(game_data.allocator)
}

remarshal_into :: proc(obj: json.Object, val: ^$T, allocator := context.allocator) {
    v, _ := json.marshal(obj)
    json.unmarshal(v, val, allocator = allocator)  
    delete(v)
}

load_item_entry :: proc(game_data: ^Game_Data, basic: Basic_Info, name: string, obj: json.Object, category: Item_Category, $Entry_Type: typeid, allocator := context.allocator) {
    entry_data: Entry_Type
    remarshal_into(obj, &entry_data, allocator)
    append(&game_data.items[category], Game_Item_Entry {
        item_info = entry_data,
        basic = basic
    })
}

load_item_entries :: proc(game_data: ^Game_Data, data_json: json.Object) {
    for game_id in data_json {
        obj := data_json[game_id].(json.Object)

        basic_info : Basic_Info
        remarshal_into(obj["basic"].(json.Object), &basic_info, game_data.allocator)

        item_type := basic_info.category
        cloned_id := strings.clone(game_id, game_data.allocator)

        switch item_type {
            case "ammo": {
                load_item_entry(game_data, basic_info, cloned_id, obj, .Ammo, Ammo_Info, game_data.allocator)
            }
            case "armor": {
                load_item_entry(game_data, basic_info, cloned_id, obj, .Armor, Armor_Info, game_data.allocator)
            }
            case: {

            }
        }
    }
}

load_game_data :: proc(game_data: ^Game_Data, path: string) {
    fn_walker := os2.walker_create(path)
	for fi in os2.walker_walk(&fn_walker) {
        if _, found := slice.linear_search(skipped_files, fi.name); found {
            continue
        } 

        data, read_err := os2.read_entire_file_from_path(fi.fullpath, context.allocator)
        defer delete(data)

        if read_err != os2.ERROR_NONE {
            fmt.println("Error reading path at", fi.fullpath, read_err)
            os2.exit(1)
        }

        final_data : string
        defer delete(final_data)

        // This file has malformed json (duplicate att_1)
        if fi.name == "w_mod.json" {
            // Had a hard time finding it when it was all on different lines so i remove all indentation
            delim_1, _ := strings.remove_all(string(data[:]), "\t")
            delim_2, _ := strings.remove_all(delim_1[:], "\r\n")
            fixed, _ := strings.remove(delim_2[:], `"att_1" : {"x" : 25,"y" : -1},`, 1)
            delete(delim_1)
            delete(delim_2)

            final_data = fixed
        } else {
            final_data = strings.clone(string(data))
        }

        loaded_json_root, parse_err := json.parse_string(final_data)
        defer json.destroy_value(loaded_json_root)
        if parse_err != .None {
            fmt.println("Error parsing json at", fi.fullpath, parse_err)
            continue
        }

        loaded_json := loaded_json_root.(json.Object)
        usage := loaded_json["usage"].(json.String)
        loaded_json_data := loaded_json["data"].(json.Object)
        switch usage {
            case "item": {
                load_item_entries(game_data, loaded_json_data)
            }
        }
	}

    
}