+++
title = "Feb 2025 Update"
date = 2025-02-19T10:00:00+10:00
summary = "About time I wrote about what I've been doing."
+++

Just felt like writing about some random projects I've been working on for the last couple of months, because I've been pretty quiet in that time.

# CalVM

I haven't touched the [Callisto](https://callisto.mesyeti.uk/) compiler in a while, but around a month ago, Yeti wrote a specification for an abstract virtual machine called [CalVM](https://github.com/callisto-lang/calvm). The eventual idea is for CalVM to be used as a platform-independent target for Callisto.

It looked pretty interesting to me, so I went ahead and wrote [my own implementation](https://github.com/soxfox42/cal-vm-zig) in [Zig](https://ziglang.org/). It's not totally aligned with the current reference implementation and spec, but that's something I'm more likely to tackle once Callisto can target it.

# Vee

Keeping on the theme of virtual machines, I also spent some time recently developing a RISC-V emulator called [Vee](https://github.com/soxfox42/vee) (which is not how you pronounce the V in RISC-V, but meh). It only supports RV32I instructions so far, and only user-mode, but I have some vague ideas of where this could be used.

# Avatars

Moving completely away from low-level programming, I found myself needing to write a web service recently. Specifically, I got fed up waiting for the team at [Desky](https://app.trydesky.com) (a hot-desk booking app my workplace uses) to fix a long-standing bug where users without profile pictures just weren't displayed at all.

Some quick background on that bug: previously, Desky relied on [Boring Avatars'](https://boringavatars.com/) free API to automatically assign profile pictures to such users. Since then, Boring Avatars stopped offering that service altogether, leaving it as a 404 page with an expired certificate. Desky was not written with any error handling when loading images from this API, and fell back to not rendering the involved users at all.

Patching Desky was easy enough with a small userscript, but I couldn't figure out a neat way to override the images directly from that script. Instead, I replaced all references to `source.boringavatars.com` with my own [`avatars.soxfox.me`](https://avatars.soxfox.me/beam/256/Test). The final piece of the puzzle was to develop a small service running on Cloudflare Workers to serve pseudo-randomised SVG images with the same API surface as the original one.

# Uxn5 + CRT

Sticking to web development for now, another fun project was adding a CRT shader to the [Uxn5](https://rabbits.srht.site/uxn5/) emulator. Doing this involved rewriting a bunch of the Screen device emulation to render with WebGL, then adapting a public domain shader to be used for post processing. Because this is all a little more complex than adding a quick post-process step, I've kept it in my own fork of Uxn5, which I've published at [uxn5.soxfox.me](https://rabbits.srht.site/uxn5/).

# Cibo

C in, binary out. Often, that's all I need my build system to do. Unfortunately, most C and C++ build systems try to do a lot more, and end up being incredibly annoying to use. Makefiles on the other hand are actually pretty nice for simple projects, but have just a few too many obscure and outdated features for me to want to stick with them -- implicit rules, special targets that don't refer to real files, the weird library search support, etc.

So I wrote my own build system. It pulls configuration from a static TOML file, and generates a simple [Ninja](https://ninja-build.org/) build configuration -- I've seen it used before as a intermediate stage by tools like CMake and Meson, and it was really pretty simple to start generating my own build.ninja files.

Cibo doesn't do much, though I'll probably expand it as I write more C projects, but it will always stick to the simple static configuration model, no need to run arbitrary code just to configure a build.

# Luami

Luami is a project that's been stuck in my head for a long time, but that I've only just managed to put together in a way I'm mostly satisfied with. It started out as an idea for an extended syntax to Lua to allow Lisp-y macros that transform syntax trees, but soon changed to a text-based preprocessor stage instead, when I realised it fit nicely with Lua's simplicity.

I think that the version of Luami I've just got working is the 4th? time I've tried to build it, since I always ran into something that just couldn't be solved with whatever design I'd tried to use. The trick that made it all work quite well in the end was to process source files in two steps: first, generate intermediate Lua source where everything except for Luami code is wrapped in calls to some sort of `emit` function, then run the generated code and collect its output to produce the final Lua file.

I'll probably keep tinkering with Luami for a bit to fix up a few remaining limitations, then once I'm happy with it, release it on GitHub.

# Write Nonsensical Things

That's kind of what I've been doing recently. Most of these projects aren't likely to be hugely useful to me in the long term, but just writing projects for the sake of creating something new, however useless, keeps me active and lets me learn new skills.

I get plenty of experience writing real, useful, sensible code in my job, but I'll never have the chance to work on anything like any of these projects there. So every now and then, I think it's good to take a break, and Write Nonsensical Things.
