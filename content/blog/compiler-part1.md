+++
title = "Building a Compiler Backend (Part 1: Callisto)"
date = 2024-09-06T10:00:00+10:00
summary = "The story of how I became a compiler developer, I guess. In the first part, you'll see how a tiny benchmark program got me hooked on a neat little stack language."
tags = ["Programming Languages", "Callisto"]
+++

# A Strange Obsession

It all started with a silly little benchmark. The [Tak function](https://en.wikipedia.org/wiki/Tak_(function)) is a small recursive function that can be used as a primitive benchmark for the speed of recursion in a programming language. It has the following definition:

```python
def tak(x, y, z)
    if y < x:
        return tak(
            tak(x - 1, y, z),
            tak(y - 1, z, x),
            tak(z - 1, x, y),
        )
    else:
        return z
```

This is roughly how it looks in most popular programming languages today, as most popular programming languages follow the same procedural style. That doesn't mean this is the only way to write it though. In a functional language like Haskell, for instance, it might be written this way:

```haskell
tak :: Int -> Int -> Int -> Int
tak x y z
  | y < x = tak
    (tak (x - 1) y z)
    (tak (y - 1) z x)
    (tak (z - 1) x y)
  | otherwise = z
```

And in Forth, you could write this:
```forth
: tak ( z y x -- n )
    2dup >= if 2drop exit then
    3dup 1- recurse >r
    3dup -rot 1- recurse >r
    rot 1- recurse r> r>
    recurse ;
```

Forth is one of a family of languages known as [concatenative languages](https://concatenative.org/wiki/view/Concatenative%20language) (catlangs for short), specifically of the stack language variety. It works using a single shared stack for data, and each function (or word, in Forth terms) uses this stack for passing data around. A number of concatenative programming Discord server members became interested in the Tak function several months ago, collecting [implementations](https://concatenative.org/wiki/view/Tak%20function) in a range of catlangs.

I took this a little further, and created a [GitHub repo](https://github.com/soxfox42/tak) with a benchmarking script and consistent tools for building and running each implementation. I took some of the catlang implementations, along with a handful of my own implementations in other languages, and started tracking how quickly each ran. There are instructions for contributing in the repo (hint, hint), and I've accepted three PRs with new implementations so far: [flber](https://github.com/flber) wrote the Rust implementation (some Rust fan I am 😆), [yeti](https://github.com/yeti0904) wrote a D version, and [Ivan8or](https://github.com/Ivan8or) wrote a Ruby version.

# A New Language

The D implementation isn't yeti's only contribution to my Tak collection though. Much earlier in the project, he posted a version of Tak written in his own compiled language [Callisto](https://callisto.mesyeti.uk/). I was interested, and got it running on a Linux machine, but at that point I didn't include it in the main Tak repo as Callisto couldn't yet target my main computer -- an ARM Mac. It couldn't even target macOS at all, so I couldn't run it through Apple's translation layer Rosetta 2, as I did with Factor.

Fast forward to around a month ago, when I got a message from yeti on the catlang Discord server:

> are you still working on that collection of tak programs \
> I got callisto working on x86 macOS

This time, I would actually be able to benchmark Callisto against the other languages in a (mostly) fair environment... or so I thought. Unfortunately, one of the requirements I put in place for my Tak collection was that each program had to read the values of x, y, and z to use from the program arguments, and Callisto's macOS core was very limited at this stage, with no support for reading arguments. (Also its standard library was missing a way to parse integers.) The fact that there was any macOS support at all was pretty impressive, as without a Mac to test on, yeti had to develop without the ability to test directly, then get one of his friends to test it out.

This was where I got started working on Callisto -- I wanted to add just enough functionality to build an x86_64 macOS version of the Tak program suitable for my collection. This first round of changes was reasonably small. I introduced a `parse_int` function to the standard library, added `Args` support for macOS, and fixed a few easy bugs.

# A Brief Introduction

{{< figure src="/images/HP-45.jpg" title="Basically the same thing as Callisto" >}}

Before I get into the behind-the-scenes of Callisto, I'd like to show a quick overview of the language. As a stack-based language, simple arithmetic may seem a little unfamiliar (unless you're a fan of HP calculators):

```text
19 2 * 4 +

2 26 5 - *
```

The above lines represent the infix expressions "19 * 2 + 4" and "2 * (26 - 5)" respectively. Each number is pushed directly to the stack, and operators implicitly take their arguments from the stack. This same pattern applies to functions, and operators are in fact just regular functions, only they are implemented in assembly instead of Callisto. Here is a function that prints a newline:

```text
func new_line begin
  '\n' printch
end
```

Callisto also has fairly typical `if` and `while` statements, as well as variables with a slightly unusual syntax (this snippet is a slightly abridged version of `printstr` from the standard library):

```text
let usize i
while i length < do
	i arr a@ printch
	i 1 + -> i
end
```

There's also support for all the classic data types, including [structures](https://callisto.mesyeti.uk/docs/language/structures/), [arrays](https://callisto.mesyeti.uk/docs/language/arrays/), [enums](https://callisto.mesyeti.uk/docs/language/enum/), and [unions](https://callisto.mesyeti.uk/docs/language/unions/). If you want to learn more about Callisto, you can check out its [documentation](https://callisto.mesyeti.uk/docs/). In part 2 of this series, I'll start diving into how the Callisto compiler works, providing context for what exactly I added to the compiler.
