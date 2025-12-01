+++
title = "December Adventure Log 2025"
date = 2025-12-01T10:00:00+11:00
summary = "This year, for the first time, I'm going to join in with [December Adventure](https://eli.li/december-adventure)! What will I write? I don't know yet!"
tags = ["Projects", "December Adventure"]
+++

> The December Adventure is **low key**. The goal is to write a little bit of code every day in December.
>
> --- https://eli.li/december-adventure

Welcome to my December Adventure log! I'll try to update it with a little bit of progress every day this month. I don't have a specific project in mind to focus on, but I have a few ongoing ones that I can share some updates for.

# Day 1: Shine Through Outlines

[Shine Through](https://github.com/soxfox42/shine-through) is a Pebble watchface I recently released. I was actually going to write a separate post about it, but here's the summary:

- Pebble is the best smartwatch ever made (according to my standards).
- I wanted a new watchface for my Pebble Time Steel.
- After playing around with some watchface design concepts that were floating in my head, I landed on a digital clock with hours and minutes overlapping each other.
- After a few days of development, I had implemented it on Pebble.

{{< figure src="shine-through-1.png" caption="Shine Through" alt="Shine Through watchface, displaying 22:01 with overlapping digits" >}}

But if it already exists, why am I bringing it up for December Adventure? Because "released" is not the same as finished. Right now, this face only supports the Pebble Time and Pebble Time Steel, because it needs the colour screen to work, and I haven't bothered with new assets and/or layouts for the other possible screen sizes.

So that's one goal during DecAdv. Today's project is *not* that, but it is an important step towards making the face look good on black and white screens -- outlines for the digits. I want to add an option in the watchface settings to turn on outlines around the digits with custom colours.

{{< figure src="shine-through-outline-mockup.png" caption="A mock-up of the outline feature" width="144" >}}

I'll update this page later once I work on the implementation :)

---

Hey, it's me again! I finished implementing the outline feature. It came down to a handful of steps:

1. Create some prerendered outlines. I did this very quickly in [Aseprite](https://www.aseprite.org/) the same way I did it for the mockup above - select the digits, expand the selection by 1px, then border it by 2px.
2. Boring settings updates. I'm using the Pebble Clay configuration framework, so I can expose these new settings to the mobile app by adding a couple of items to a JSON list. This step also involved creating new message keys, expanding the persistent settings structure, and adding all the plumbing that lets me get settings from phone to watch.
3. Render some outlines! For this, I used the prerendered outlines I mentioned above with a bitmap in `1BitPalette` mode. That way I can switch the colour of the outlines really easily. There were some tricky details around layout and enabling transparency, but everything came together nicely.

{{< figure src="shine-through-outline.png" alt="Outlines enabled in the QEMU-based Pebble emulator" caption="I didn't get the colours quite right for this screenshot." >}}
