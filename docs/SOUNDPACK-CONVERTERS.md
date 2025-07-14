<a name="soundpack-converters-top"></a>



# Soundpack Converters

Because nobody wants to rewrite their whole damn soundpack just to switch apps.
This doc is your survival guide for turning other soundpack formats into Thock-compatible custom modes without losing your sanity.



<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#mechvibes-to-thock">MechVibes to Thock</a></li>
    <li><a href="#future-converters">Future Converters</a></li>
  </ol>
</details>



## MechVibes to Thock 

The **`mechvibes2thock`** a Python script that takes your dusty MechVibes JSON and sound files and spits out a ready-to-rock Thock soundpack.

> Grab it here: [mechvibes2thock.py](https://github.com/kamillobinski/thock/blob/main/scripts/mechvibes2thock.py)


### How It Works

- Feeds on your MechVibes JSON + sound files living together.
- Maps cryptic MechVibes keycodes into human-friendly Thock keys.
- Crafts a perfectly formatted `config.json` that Thock actually gets.
- Copies every sound you use into a fresh folder.
- You get a drop-in ready folder for Thock’s `CustomSounds`.

## Folder & File Layout with mechvibes2thock

```sh
my_mechvibes_pack/             # Your original MechVibes pack folder
├── mechvibes2thock.py         # The conversion wizard living inside the pack
├── config.json                # MechVibes config you probably barely understand
├── click1.mp3                 # The sounds you love (or hate)
├── click2.mp3
└── ...
```



# After running the converter:

```sh
my_mechvibes_pack/
├── mechvibes2thock.py
├── config.json
├── click1.mp3
├── click2.mp3
├── ...
└── my_mechvibes_pack_thock_xxxxxxxx/    # The shiny new Thock-ready pack
    ├── config.json                      # Converted Thock config.json
    ├── click1.mp3                       # Sound files copied
    ├── click2.mp3
    └── ...
```



### Conversion Flow (Your checklist for sanity)

1. Drop `mechvibes2thock.py` into your MechVibes pack folder next to `config.json and your sounds.
2. Fire up the terminal, cd into that folder, and run:

    ```sh
    python3 mechvibes2thock.py
    ```

3. Tell it your MechVibes JSON filename when it asks (yes, like `config.json`).
4. Watch it spit out a new folder named something like `my_mechvibes_pack_thock_xxxxxxxx/`.
5. Go to this directory:
```sh
    ~/Library/Application Support/thock/
    ```
6. Create a folder called CustomSounds and drag that fresh folder from step 4 into (the CustomSounds folder):

    ```sh
    ~/Library/Application Support/thock/CustomSounds/
    ```

7. Relaunch Thock, select your pack under Custom, and let your keyboard finally sound right.

<p align="right">(<a href="#soundpack-converters-top">back to top</a>)</p>




## Future Converters

More formats coming. Got a weird soundpack format you want Thock to tame? File an issue or send a PR.



<p align="right">(<a href="#soundpack-converters-top">back to top</a>)</p>
