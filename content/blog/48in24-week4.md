+++
title = "#48in24 – Week 4: Roman Numerals"
date = 2024-02-10T12:40:19+11:00
summary = "In Week IV of #48in24, Roman numerals are the focus, and some relatively obscure languages were chosen. Featured languages: Elixir, Pharo, Julia."
tags = ["48in24"]
card_image = "/images/cards/48in24-week4.png"
+++

This week of [#48in24](https://exercism.org/challenges/48in24), we'll be looking at at [Roman Numerals](https://exercism.org/exercises/roman-numerals). As you might be able to guess from the exercise name, the goal is to create a function that takes an integer, and returns a string with its [Roman numeral](https://en.wikipedia.org/wiki/Roman_numerals) representation.

For this one, I won't be showcasing anything particularly exciting, and I'll just let the featured languages speak for themselves.

The general algorithm I'm implementing in all three languages is as follows:
1. Create a list of value to Roman numeral pairs (including 4s and 9s).
2. Create a blank string to hold the result.
3. For each pair in the list:
    1. While the target number is greater than or equal to the value:
        1. Subtract the value from the target number.
        2. Add the Roman numeral fragment to the result string.
4. Return the result.

# Languages

## Elixir

[Elixir](https://elixir-lang.org/) is a functional programming language built on the Erlang VM. As it's functional, there is a lot of focus on features like pattern matching, function pipelining, and recursive algorithms. It's not a purely functional language though, so side-effects are possible without too much hassle.

My Roman Numerals implementation in Elixir uses all three of the features I mentioned above, and looks like this:

```elixir
defmodule RomanNumerals do
  def numeral(0), do: ""
  def numeral(number) do
    {value, roman} = [
      {1000, "M"},
      {900, "CM"}, {500, "D"}, {400, "CD"}, {100, "C"},
      {90, "XC"}, {50, "L"}, {40, "XL"}, {10, "X"},
      {9, "IX"}, {5, "V"}, {4, "IV"}, {1, "I"},
    ] |> Enum.find(fn {n, _} -> number >= n end)
    roman <> numeral(number - value)
  end
end
```

Pattern matching is used in a couple of ways here. First, it is used in one of the `numeral` definitions to match the literal value 0. When asked to convert 0 to Roman numerals, this code just returns an empty string. This isn't strictly correct, but it works well for this recursive implementation. Pattern matching is used again to split the `{value, roman}` tuples, both in the `Enum.find` call and in the top level assignment.

Function pipelining isn't used much here, but it cleans up the code that selects a pairing by avoiding nesting of the entire array into the `Enum.find` call. You can probably see how this would be useful for longer data processing flows. Arbitrary functions can be chained together as long as you can pass data into their first argument - though it's almost always possible to adapt functions to your needs with Elixir's excellent anonymous function shorthand.

Finally, recursion causes the biggest shift from the algorithm I outlined at the start of this post. Rather than explicitly using two nested loops, I just find the biggest value, process that one, then hand it off to the next recursive call to do the rest. Each `roman` fragment is concatenated with the result of the next call, building a complete Roman numeral at the end.

## Pharo

[Pharo](https://pharo.org/) is one of the weirder languages supported by Exercism. Like almost all Smalltalk derivatives, it includes a complete graphical interface for development, and everything takes place within a live environment.

{{< aside "My Eyes!!!" >}}
12 years ago (!), Apple introduced the first MacBook with a "Retina" display. Around the same time, higher DPI screens were gaining support in the Windows world. For a while, there was quite a lot of software that didn't handle these higher quality screens natively, and while the exact results of this differed by platform and application, the general outcome was that it looked *bad*.

12 years on though, that won't be an issue, at least not for actively maintained software, right? Right? As it turns out, Pharo *still* doesn't correctly handle these displays. Depending on the OS you use, and the version of Pharo, this either means low quality graphics scaled up to look blocky, or low quality graphics scaled up to look blurry. There is an option labelled "Display scale factor", which does seem to allow the use of the full resolution, but it also shrinks everything to the point of being unusable.

Luckily, it looks like this might be coming to an end. 2 months ago, a PR was merged that added another scaling option, with the *very sensible* name of "Canvas scale factor for OSWorldRenderer", which actually does produce the correct results on modern computers - clear text, at readable sizes. It currently doesn't default to 2 on Retina displays, though it probably should, and it's only available in Pharo 12.0 development images, which Exercism doesn't support, but it's finally a step in the right direction.
{{< /aside >}}

My solution in Pharo follows the pseudocode pretty closely, but there are some interesting syntax points to look at. The following function lives inside a class called `RomanNumerals`, by the way.

```st
romanNumber: aNumber
	| numerals remaining result |
	numerals := {
		1000 -> 'M'.
		900 -> 'CM'. 500 -> 'D'. 400 -> 'CD'. 100 -> 'C'.
		90 -> 'XC'. 50 -> 'L'. 40 -> 'XL'. 10 -> 'X'.
		9 -> 'IX'. 5 -> 'V'. 4 -> 'IV'. 1 -> 'I'. }.
	remaining := aNumber.
	result := String new writeStream.
	numerals do: [ :pair |
		[ remaining >= pair key ] whileTrue: [ 
			remaining := (remaining - pair key).
			result << pair value ] ].
	^ result contents
```

1. **Create a list of value to Roman numeral pairs (including 4s and 9s).**

   For this, I used a dynamic list literal containing some `Association`s. These are pairs designed for use as key-value records, and are often used to initialise `Dictionary`s and other such collections.
2. **Create a blank string to hold the result.**

   `String new` makes a string literal, but I then created a stream from that for more efficient string building.
3. **For each pair in the list:**

   This is done with the `do:` message, which takes a block (basically an anonymous function/closure), and runs it once for each list item.
    1. **While the target number is greater than or equal to the value:**

       Similar to the last point, this uses blocks, both for the condition and the body of the loop. The condition needs to be checked multiple times, so I can't just use a static value.
        1. **Subtract the value from the target number.**
        2. **Add the Roman numeral fragment to the result string.**

           These are pretty straightforward.
4. **Return the result.**

   Smalltalk uses `^` to indicate the return value, and returns the object itself (`self`) by default.

## Julia

The final language this week is [Julia](https://julialang.org/), which is much like last week's R, is a language targeted at data analysis. Julia is newer, and feels a little closer to the style of modern programming languages. I've used it before, mainly with [Pluto](https://plutojl.org/) which is a very nice interactive notebook tool.

There is one small difference in the Julia version of the Roman Numerals exercise: it expects the code to throw an error when given a value less than 1.

```julia
function to_roman(number)
    if number <= 0 error("invalid number") end
    numerals = [
        (1000, "M"),
        (900, "CM"), (500, "D"), (400, "CD"), (100, "C"),
        (90, "XC"), (50, "L"), (40, "XL"), (10, "X"),
        (9, "IX"), (5, "V"), (4, "IV"), (1, "I"),
    ]
    result = ""
    for (value, roman) in numerals
        while number >= value
            number -= value
            result *= roman
        end
    end
    result
end
```

This code really closely follows the pseudocode version, so here are a few interesting points I picked up on:

- Adding the extra error check was easy, thanks to the `error` function. I'm guessing this isn't necessarily ideal real-world error handling, as the only information it provides is an error string, but it's useful for adding some basic errors.
- Pattern matching came in handy here as well, because it allowed me to extract the values from the tuples really neatly as part of the loop.
- `*=` is not a typo, `*` is really the string concatenation operator in Julia. This choice comes from Julia's mathematical background, specifically relating to the non-commutativity of string concatenation.

# Final Thoughts

I kept this week pretty simple, in part because these are languages I haven't used much. I'll probably continue to use Julia in Pluto.jl occasionally, but I'm not sure I have much need for Elixir or Pharo beyond curiosity. Pharo is another language which has relatively little syntax explicitly defined, but that allows a huge amount of flexibility, like the Lisps I've looked at previously, so that was fun to play with.
