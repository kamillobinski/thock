<a name="readme-top"></a>


# Creating a Custom Soundpack

Want your keyboard to sound like a haunted jukebox? Or a typewriter on fire?
Drop in your own `.mp3` or `.wav` files and a `config.json` and Thock will do the rest.



<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#how-it-works">How It Works</a></li>
    <li><a href="#setup">Setup</a></li>
    <li><a href="#configjson-structure">Structure for config.json</a></li>
    <li><a href="#tips">Tips</a></li>
    <li><a href="#troubleshooting">Troubleshooting</a></li>
  </ol>
</details>



## How It Works

Custom soundpacks are loaded from this directory:

```sh
~/Library/Application Support/Thock/Soundpacks/
```

Each soundpack is a folder containing:

- a `config.json` file (format below)
- any number of `.mp3` or `.wav` files referenced in that config

Once it's in place, Thock picks it up automatically on next launch.
No restart needed if you switch soundpacks - Thock reloads the config on every switch.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



## Setup

1. Create a folder inside:

```sh
~/Library/Application Support/Thock/Soundpacks/
```

2. Drop in your `.mp3` or `.wav` files
3. Add a `config.json` file
4. Relaunch Thock or switch soundpacks - it will rescan the directory

Example folder structure:

```sh
Soundpacks/
├── goth_mommy_moan/
│   ├── config.json
│   ├── downbad.mp3
│   ├── sigh1.mp3
│   └── ...others, if you're brave
```
<sub>*Not official. Not supported. Proceed with your own weirdness.</sub>

<p align="right">(<a href="#readme-top">back to top</a>)</p>



## Structure for config.json

Here's a minimal working example of `config.json`:

```json
{
  "id": "a8f98b4e-d7f2-4a13-a3ea-4b0c573b0eee",
  "metadata": {
    "name": "Goth Mommy Moan",
    "brand": "Homemade",
    "author": "you",
    "category": "keyboard",
    "supportsKeyUp": true
  },
  "license": {
    "type": "unholy",
    "url": "https://soundslikejudgment.com"
  },
  "sounds": {
    "default": {
      "down": ["downbad.mp3"],
      "up": ["sigh1.mp3"]
    }
  }
}
```
<sub>*Not official. Not approved. Not asking. She's in the house now-deal with it.</sub>

Only `default` sounds are required.
You can add specific keys like `a`, `space`, `enter`, etc. using the same `down` and `up` structure.

**Heads up:** `id` must be a valid UUID. `category` must be either `keyboard` or `mouse`.
If the config is malformed, Thock will silently skip the soundpack - no crash, no log, just vibes.

### Want to see real examples?

Two easy ways:

- Browse the [thock-soundpacks](https://github.com/kamillobinski/thock-soundpacks/tree/main) repo - download any soundpack and unpack the zip to see how it's structured
- Or install a soundpack directly from the registry in Thock settings, then open the Soundpacks directory from the **Explore** section - they're already unpacked and ready to inspect

<p align="right">(<a href="#readme-top">back to top</a>)</p>



## Tips

- If a key doesn't have a sound, Thock falls back to the `default` mapping
- Add a few variations to your `down`/`up` arrays - Thock will pick one at random
- You can use `.wav` or `.mp3` - whatever you like
- Folder names can be anything, they're not shown in the UI
- Set `supportsKeyUp: false` if you only have `down` sounds

<p align="right">(<a href="#readme-top">back to top</a>)</p>



## Troubleshooting

<details>
<summary><strong>Sound not playing?</strong></summary>
Check that the file names in your <code>config.json</code> exactly match the files in your folder - casing and extension included.
</details>

<details>
<summary><strong>Soundpack not showing up?</strong></summary>
Make sure your <code>config.json</code> is valid JSON with a <code>metadata</code> block and a proper UUID as <code>id</code>. Trailing commas will break it.
</details>

<details>
<summary><strong>Still not working?</strong></summary>
Delete the folder. Breathe. Drop the files again. Sometimes a clean slate is faster than debugging vibes.
</details>



<p align="right">(<a href="#readme-top">back to top</a>)</p>
