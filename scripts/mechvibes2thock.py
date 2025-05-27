import os
import shutil
import json
import uuid
import re

DARWIN_KEYCODES = {
    1: "esc", 59: "f1", 60: "f2", 61: "f3", 62: "f4", 63: "f5", 64: "f6",
    65: "f7", 66: "f8", 67: "f9", 68: "f10", 87: "f11", 88: "f12", 41: "`",
    2: "1", 3: "2", 4: "3", 5: "4", 6: "5", 7: "6", 8: "7", 9: "8", 10: "9",
    11: "0", 12: "-", 13: "=", 14: "backspace", 15: "tab", 58: "capsLock",
    30: "a", 48: "b", 46: "c", 32: "d", 18: "e", 33: "f", 34: "g", 35: "h",
    23: "i", 36: "j", 37: "k", 38: "l", 50: "m", 49: "n", 24: "o", 25: "p",
    16: "q", 19: "r", 31: "s", 20: "t", 22: "u", 47: "v", 17: "w", 45: "x",
    21: "y", 44: "z", 26: "[", 27: "]", 43: "\\", 39: ";", 40: "'", 28: "enter",
    51: ",", 52: ".", 53: "/", 57: "space", 3666: "fn", 3667: "del", 3655: "home",
    3663: "end", 3657: "pgUp", 3665: "pgDn", 57416: "arrUp", 57419: "arrLeft",
    57421: "arrRight", 57424: "arrDown", 42: "shiftLeft", 54: "shiftRight",
    29: "ctrlLeft", 56: "optionLeft", 3640: "optionRight", 3675: "command",
    3676: "command",
}


def sanitize_name(name: str) -> str:
    """
    Sanitize pack name for filesystem: lowercase, underscores, no weird chars.
    """
    return re.sub(r'[^a-z0-9_-]', '_', name.lower())


def load_mechvibes_config(path: str) -> dict:
    """
    Load MechVibes JSON config from disk.
    """
    with open(path, "r") as f:
        return json.load(f)


def convert_to_thock(mechvibes_data: dict) -> dict:
    """
    Convert MechVibes config dict into Thock format.
    - Maps keycodes to key names.
    - Filters nulls and invalids.
    - Sets up default sound if missing.
    """
    defines = mechvibes_data.get("defines", {})
    default_sound = mechvibes_data.get("sound")
    sounds = {"default": {"down": [], "up": []}}
    key_sounds = {}

    if default_sound:
        sounds["default"]["down"].append(default_sound)

    for keycode_str, sound in defines.items():
        if not sound or sound.lower() == "null":
            continue
        try:
            keycode = int(keycode_str)
        except ValueError:
            continue
        keyname = DARWIN_KEYCODES.get(keycode)
        if not keyname:
            continue
        key_sounds[keyname] = {"down": [sound], "up": []}

    if not sounds["default"]["down"] and key_sounds:
        first_sound = next(iter(key_sounds.values()))["down"][0]
        sounds["default"]["down"].append(first_sound)

    sounds.update(key_sounds)

    return {
        "id": str(uuid.uuid4()),
        "name": mechvibes_data.get("name", "converted_sound_pack"),
        "isNew": True,
        "source": "converted from MechVibes",
        "license": {"type": "unknown", "url": ""},
        "supportsKeyUp": False,
        "sounds": sounds,
    }


def get_sound_source_dir(script_dir: str, pack_name_safe: str) -> str:
    """
    Determine where to get sound files:
    - Prefer folder named after sanitized pack name.
    - Fall back to script dir if missing.
    """
    sound_src_dir = os.path.join(script_dir, pack_name_safe)
    if not os.path.isdir(sound_src_dir):
        print(f"Sounds folder '{sound_src_dir}' missing. Falling back to script directory.")
        return script_dir
    return sound_src_dir


def copy_sounds(sounds_set: set, src_dir: str, dst_dir: str):
    """
    Copy all required sound files from src_dir to dst_dir, warn if missing.
    """
    for sound_file in sounds_set:
        src = os.path.join(src_dir, sound_file)
        dst = os.path.join(dst_dir, sound_file)
        if os.path.isfile(src):
            shutil.copy2(src, dst)
        else:
            print(f"Warning: sound file '{sound_file}' missing in '{src_dir}'")


def write_thock_config(thock_data: dict, output_dir: str):
    """
    Write Thock config.json into output directory.
    """
    with open(os.path.join(output_dir, "config.json"), "w") as f:
        json.dump(thock_data, f, indent=4)


def create_thock_pack(mechvibes_path: str):
    """
    Master function to convert MechVibes config into Thock pack folder.
    """
    mechvibes_data = load_mechvibes_config(mechvibes_path)
    thock_data = convert_to_thock(mechvibes_data)

    pack_name_safe = sanitize_name(thock_data["name"])
    script_dir = os.path.dirname(os.path.abspath(__file__))
    sound_src_dir = get_sound_source_dir(script_dir, pack_name_safe)

    output_dir = os.path.join(script_dir, f"{pack_name_safe}_thock_{str(uuid.uuid4())[:8]}")
    os.makedirs(output_dir, exist_ok=True)

    sounds_set = set()
    for sound_obj in thock_data["sounds"].values():
        sounds_set.update(sound_obj.get("down", []))
        sounds_set.update(sound_obj.get("up", []))

    copy_sounds(sounds_set, sound_src_dir, output_dir)
    write_thock_config(thock_data, output_dir)

    print(f"Thock soundpack created at: {output_dir}")


def main():
    mechvibes_path = input("Enter the filename of the MechVibes JSON config (e.g. config.json): ").strip()
    if not os.path.isfile(mechvibes_path):
        print(f"File '{mechvibes_path}' not found in current directory.")
        return
    create_thock_pack(mechvibes_path)


if __name__ == "__main__":
    main()
