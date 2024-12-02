+++
title = "Advent of Code 2024 / December Adventure"
date = 2024-12-02T08:00:00+11:00
summary = "What I'm doing this December."
card_image = "TODO: crimbas time!"
+++

It's December, and that means it's time for another [Advent of Code](adventofcode.com)! This will be my fifth year participating in the event, though so far the only year I finished all tasks in was 2023.

I'll probably write a blog post or two as I come across I particularly enjoy, or that I find interestin­g solutions to that are worth sharing. I won't share any solutions until at least the next day, but obviously reading anything before solving a task yourself could spoil it for you, just a warning.

# My Process

I figured I'd use this post to share a rough look at my process for AoC (and most other programming puzzles, for that matter).

{{< figure src="terminal.png" title="My usual challenge-coding setup. This is from a previous year." >}}

1. I use a terminal with the ability to display two panes side by side. Right now, this is [WezTerm](https://wezfurlong.org/wezterm/index.html), but I have used others in the past. I could just use separate windows, but built in panes are more convenient.
2. The left pane holds a terminal-based text editor. This was previously [Neovim](https://neovim.io/), but now I use [Helix](https://helix-editor.com/).
3. The right pane is where I run my solution. I use [watchexec](https://watchexec.github.io/) to automatically rerun the code every time I make changes. Specifically `watchexec -c clear -r [command to run code]`, which will clear the screen for me, and automaticaly kill long running processes when a file is saved in case of an infinite loop.

When I set up for a new task, I'll first grab the input data -- usually by copying it then running `pbpaste > dayX.txt` on macOS or `wl-paste > dayX.txt` on Linux (Wayland), then kick off the watchexec process.

Most often for solving these tasks I use Python, since it allows me to be pretty lazy with the actual code, and just think about solving the actual puzzle. I use [PyPy](https://pypy.org/) to run the solutions, as it gives a nice speed boost over CPython.

# December Adventure

There's another December coding not-challenge I've seen, [December Adventure](https://eli.li/december-adventure), where you pick a project (or a few projects), and aim to work on it at least a little bit each day, all while documenting the journey. I'm not participating in it, largely because I don't have many projects that I feel would be interesting to write about at the moment. Maybe next year?

In any case, I will be reading some others' December Adventure updates, and I suggest you do too! It's always a good idea to have a look at what others are doing, you might find inspiration, or just learn something new.

Here are some that I'll be keeping an eye on, go check them out:

- [Devine Lu Linvega](https://rabbits.srht.site/decadv/)
- [MESYETI](https://mesyeti.uk/december_adventure_log/) (Hey, it's the creator of [Callisto]({{< ref "tags/callisto" >}})!)
- [Capital](https://www.sheeeeeeeep.art/december-adventure-2024.html)
- [yumaikas](https://junglecoder.com/december-adventure/2024.html)

You can also find plenty more at the [main December Adventure page](https://eli.li/december-adventure).
