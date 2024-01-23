+++
title = "#48in24 – Week 1"
date = 2024-01-19
summary = "Week 1 of #48in24 is here, and we're leaping into it by looking at leap years! Featured languages: Python, Clojure, MIPS Assembly."
tags = ["48in24"]
aliases = ["/blog/48in24/week1.html"]
card_image = "/images/cards/48in24-week1.png"
+++

<h1>Exercise</h1>

The first featured exercise of the year is "Leap". This is a pretty simple exercise, which is to be expected at this point in the challenge. It consists of a single function of the form `fn is_leap_year(year: u64) -> bool`. The goal is to return a boolean indicating whether the given year is a leap year according to the standard Gregorian calendar rules.

Here is a quick explanation of those rules:
- A year is a leap year if it is divisible by 4...
- unless it is divisible by 100...
- unless it is also divisible by 400.

# Languages

## Python

First up in the featured languages is Python, a well known, simple to use language. It is a fairly typical imperative programming language, with syntax that uses indentation for blocks, rather than e.g. braces. My solution to Leap in Python was the following:

```python
def leap_year(year):
    return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
```

This is a pretty standard boolean logic approach to checking leap years. Thanks to short-circuiting boolean operators, it doesn't perform unnecessary checks (though the runtime cost of a few `%` and `==` operators is next to nothing).

The Python solution is unsurprisingly simple, so let's move on.

## C (bonus!)

C wasn't a featured language here, but I had previously completed Leap in Clojure, so I needed another language in order to claim my silver and gold ranks. My solution is almost identical to the Python one though:

```c
bool leap_year(int year) {
    return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
}
```

There's nothing new here to address, as this is a straightforward translation of the previous solution. I promise the next one will be more interesting!

## Clojure

Time for something completely different: a Lisp. Lisp family languages get a bad reputation for being unreadable piles of parentheses))))))). I don't think this is entirely fair though - any language can be hard to read if you aren't used to it, or if it was written poorly. Generally, when reading Lisp code, you tune out the parentheses, and rely more on clean indentation to understand the code.

As mentioned before, I had already solved this one, but my previous solution was just another boolean logic implementation, and I wanted to try something a little more interesting. Here's what I came up with:

```clojure
(defn leap-year? [year]
  (cond
    (not (zero? (mod year 4))) false
    (not (zero? (mod year 100))) true
    (not (zero? (mod year 400))) false
    :else true))
```

The star of this solution is Clojure's [`code`](https://clojuredocs.org/clojure.core/cond) macro. It's a little like a `switch` statement but for arbitrary conditions, a cleaner way to write `if-else` chains. I haven't seen this in many other languages, though Kotlin's `when` comes to mind.

I used negated versions of the divisibility checks here as I wanted to keep the same order to them. If we find that a year is not divisible by four, we can return false right away, and this applies to each divisibility check in turn.

Personally, I'm a huge fan of Lisps. Something about the fact that you can't really reduce the language syntax much more without making a near unusable language really appeals to me. Reducing the language syntax happens to be exactly what our final language does though, so let's go!

## MIPS Assembly

...yeah. Syntax doesn't get much more minimal than this - labels and instructions, that's it. Here's the code:

```gas
is_leap_year:
    rem $t0, $a0, 4
    beqz $t0, divisible_by_four

    li $v0, 0
    jr $ra

divisible_by_four:
    rem $t0, $a0, 100
    beqz $t0, divisible_by_hundred

    li $v0, 1
    jr $ra

divisible_by_hundred:
    rem $t0, $a0, 400
    beqz $t0, divisible_by_four_hundred

    li $v0, 0
    jr $ra

divisible_by_four_hundred:
    li $v0, 1
    jr $ra
```

That's an awful lot of code to check whether a year is a leap year, but that's just what programming in assembly gets you. Luckily, it's basically the same piece of code three times, so I'll break down one of those units.

```gas
    rem $t0, $a0, 4
    beqz $t0, divisible_by_four

    li $v0, 0
    jr $ra

divisible_by_four:
```

This is the unit of code that makes up my assembly solution. First, a bit of context. `$a0` is the CPU register that holds the first argument (the year), and `$v0` is the CPU register used to return the result of 0 or 1.

1. `rem $t0, $a0, 4` calculates the value of `$a0` modulo 4, and stores it in `$t0`, a temporary register.
2. `beqz $t0, divisible_by_four` checks if that value is zero, and if it is, jumps ahead to `divisible_by_four`.
3. If we didn't jump to the next check, `li $v0, 0` and `jr $ra` load 0 into the return value register, and return to the caller.

That was a lot. At this point, all that's left is to run 3 of these checks in sequence with the right return values, and add a final return value of 1 at the end. The logic here is basically identical to my Clojure solution, it just doesn't look like it.

{{< aside Pseudo-instructions >}}

I want to address a quirk of MIPS assembly quickly. The MIPS architecture has very few instructions compared to many others, but MARS (the assembler and simulator used by Exercism) makes coding easier by introducing many pseudo-instructions. Some are simple, like `beqz` and `li` above - they assemble to a regular `beq` and an immediate add respectively. Some are more complex, like `rem`. MIPS can't divide by an immediate value natively, so MARS assembles this to an immediate load (which is really an add), a `div` instruction, which calculates division and remainder at the same time, and a `mfhi` to fetch the result into a register. A special register - `$ra` - exists for the assembler to use in pseudo-instructions like this.

{{< /aside >}}

I've had some experience coding in a few assembly languages, but the vast majority of my experience comes from [Zachtronics](https://www.zachtronics.com/) games (go check them out!). Applying those skills to real assembly is surprisingly simple, but sometimes there are interesting new things to learn about, like the pseudo-instructions above. Assembly always feels like a fun puzzle to me, so it's nice to see it getting some attention straight away in #48in24.

# Final Thoughts

I'm really looking forward to the next 47 weeks. I see a lot of potential for learning new programming tricks, both in languages I know, and those I don't! I hope to write one of these blog posts for each exercise, but only time will tell whether I can stick to that. Thanks for reading this post, I hope you found something new and interesting here!
