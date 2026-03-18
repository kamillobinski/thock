<a name="readme-top"></a>


# thock-cli

`thock-cli` is a simple command-line interface for controlling Thock from your terminal, scripts or automation tools like Raycast.

Most commands communicate with Thock via a macOS named pipe.



<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#installation">Installation</a></li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#available-commands">Available Commands</a></li>
    <li><a href="#examples">Examples</a></li>
    <li><a href="#how-it-works">How It Works</a></li>
    <li><a href="#troubleshooting">Troubleshooting</a></li>
    <li><a href="#tips">Tips</a></li>
    <li><a href="#contribute">Contribute</a></li>
  </ol>
</details>



## Installation

`thock-cli` is bundled automatically when you install Thock via Homebrew:

```sh
brew install --cask kamillobinski/thock/thock
```

The CLI will be available globally via:

```sh
thock-cli
```

If installed manually, make sure `thock-cli` is executable and somewhere in your `$PATH`.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



## Usage

```sh
thock-cli <command> [arguments]
```

> [!IMPORTANT]
> Commands that control the app (`set-enabled`, `set-soundpack`) require Thock to be running. Commands that read local data (`ls`) work without the app.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



## Available Commands

### `ls`

Lists all installed soundpacks. Does not require Thock to be running.

**Arguments:**
- `--json` — output as JSON instead of plain text (optional)

**Example:**
```sh
thock-cli ls
thock-cli ls --json
```

**Plain output:**
```
Keyboard
  Alps SKCM Blue  by tplai    52722920-07ec-45b4-91cc-6f29cad794d2
Mouse
  Pixabay-01      by pixabay  fd09c274-76e2-493a-b3d7-1dbc4add746f
```

**JSON output:**
```json
[
  {
    "id": "52722920-07ec-45b4-91cc-6f29cad794d2",
    "name": "Alps SKCM Blue",
    "brand": "Alps",
    "author": "tplai",
    "category": "keyboard"
  },
  {
    "id": "fd09c274-76e2-493a-b3d7-1dbc4add746f",
    "name": "Pixabay-01",
    "brand": "Unknown",
    "author": "pixabay",
    "category": "mouse"
  }
]
```

---

### `set-soundpack`

Sets the active soundpack by its ID. Requires Thock to be running.

**Arguments:**
- `id` — UUID of the soundpack (required)

**Example:**
```sh
thock-cli set-soundpack "52722920-07ec-45b4-91cc-6f29cad794d2"
```

> [!TIP]
> Use `thock-cli ls` to find the ID of an installed soundpack.

---

### `set-enabled`

Enables or disables Thock. Requires Thock to be running.

**Arguments:**
- `true` / `false` — also accepts `1/0`, `yes/no`, `on/off`

**Example:**
```sh
thock-cli set-enabled true
thock-cli set-enabled false
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>



## Examples

List installed soundpacks and switch to one:

```sh
thock-cli ls
thock-cli set-soundpack "52722920-07ec-45b4-91cc-6f29cad794d2"
```

Use JSON output in a script:

```sh
#!/bin/bash
soundpacks=$(thock-cli ls --json)
echo "$soundpacks" | python3 -c "import json,sys; [print(s['name']) for s in json.load(sys.stdin)]"
```

Or use it inside an automation (e.g. Raycast, launchd, etc.)

<p align="right">(<a href="#readme-top">back to top</a>)</p>



## How It Works

Commands that control the app write to a named pipe:

```sh
~/Library/Application Support/thock/thock.pipe
```

This pipe is created when Thock launches. If it doesn't exist, the CLI will exit with an error.

The `ls` command bypasses the pipe entirely and reads directly from the soundpacks directory:

```sh
~/Library/Application Support/Thock/Soundpacks/
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>



## Troubleshooting

- Make sure Thock is running before using commands that require the pipe
- If you see: `Error: Thock pipe not found`, that means the named pipe hasn't been created yet
- You may need to open the app manually after install, then try again
- `ls` works without the app running (if it returns nothing, no soundpacks are installed yet)

<p align="right">(<a href="#readme-top">back to top</a>)</p>



## Tips

- Pair with tools like Raycast, Alfred or Automator for quick-access macros
- Combine with Apple Shortcuts to bind soundpack switching to key combos
- Use `ls --json` when building integrations (the structured output is easier to parse)
- Use in scripts to auto-switch soundpacks based on time of day or app context

<p align="right">(<a href="#readme-top">back to top</a>)</p>



## Contribute

Got an idea for more CLI features or arguments?
Feel free to open a [feature request](https://github.com/kamillobinski/thock/issues) or contribute directly.
See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.



<p align="right">(<a href="#readme-top">back to top</a>)</p>
