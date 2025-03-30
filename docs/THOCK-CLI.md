<a name="readme-top"></a>


# thock-cli

`thock-cli` is a simple command-line interface for controlling Thock from your terminal, scripts or automation tools like Raycast.

It sends commands to Thock via a macOS named pipe. This allows you to toggle modes, set parameters or trigger app behavior without interacting with the GUI.



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
brew install thock
```

The CLI will be available globally via:

```sh
thock-cli
```

If installed manually, make sure `thock-cli` is executable and somewhere in your `$PATH`.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



## Usage

> [!IMPORTANT]  
> Requires Thock to be running in the background.

```sh
thock-cli <command> [arguments]
```

All arguments are automatically wrapped in quotes before being passed into Thock.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



## Available Commands

Below is a list of supported commands you can use with `thock-cli`:

### `set-mode`
Sets the active sound mode.

**Arguments:**
- `modeName` - the name of the mode (required)
- `--brand <brand>` - Brand name of the sound mode (required)
- `--author <author>` - author name of the sound mode (required)

**Example:**
```sh
thock-cli set-mode "oreo" --brand "everglide" --author "mechvibes"
```

*(More commands may be added in future releases.)*

<p align="right">(<a href="#readme-top">back to top</a>)</p>



### Examples

Set a mode with metadata:

```sh
thock-cli set-mode "oreo" --brand "everglide" --author "mechvibes"
```

You can also script this:

```sh
#!/bin/bash
thock-cli set-mode "oreo" --brand "everglide" --author "mechvibes"
```

Or use it inside an automation (e.g. Raycast, launchd, etc.)

<p align="right">(<a href="#readme-top">back to top</a>)</p>



## How It Works

`thock-cli` communicates with the Thock app by writing to a named pipe:

```sh
~/Library/Application Support/thock/thock.pipe
```

This pipe is created when Thock launches. If it doesn't exist, the CLI will exit with an error.

You can see the raw command being sent by printing the output before piping:

```sh
echo 'set-mode "Muted" --brand "Cherry MX"' > ~/Library/Application\ Support/thock/thock.pipe
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>



## Troubleshooting

- Make sure Thock is running before using `thock-cli`
- If you see: `Error: Thock pipe not found`, that means the named pipe hasn't been created yet
- You may need to open the app manually after install, then try again

<p align="right">(<a href="#readme-top">back to top</a>)</p>



## Tips

- Pair with tools like Raycast, Alfred or Automator for quick-access macros
- Combine with Apple Shortcuts to bind mode switching to key combos
- Use in scripts to auto-switch modes based on time of day or app context

<p align="right">(<a href="#readme-top">back to top</a>)</p>



## Contribute

Got an idea for more CLI features or arguments?  
Feel free to open a [feature request](https://github.com/kamillobinski/thock/issues) or contribute directly.  
See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.



<p align="right">(<a href="#readme-top">back to top</a>)</p>

