+++
title = "#48in24 – Week 3"
date = 2024-02-01T20:25:36+11:00
summary = "Objects and vectors and macros, oh my! This week is all about Exercism's take on FizzBuzz. Featured languages: Ruby, R, Common Lisp."
tags = ["48in24"]
card_image = "/images/cards/48in24-week3.png"
+++

[Raindrops](https://exercism.org/exercises/raindrops) is the latest featured exercise of #48in24, and the final featured exercise of January -- the warm-up month. Raindrops is a simple variation on the classic coding interview question/children's game [FizzBuzz](https://en.wikipedia.org/wiki/Fizz_buzz). The original task asks coders to print the integers from 1 to 100, but replace multiples of three with "Fizz", multiples of five with "Buzz", and multiples of *both* with "FizzBuzz". Exercism's version of this task also includes multiples of seven, and replaces "Fizz" and "Buzz" with the sounds of raindrops. It also removes the looping requirement, and now just expects the code to take a number and return the corresponding raindrop string.

This week, since the exercise is pretty easy, I'm choosing to keep things entertaining (for myself at least) by solving it in each featured language using a notable feature of that language.

# Languages

## Ruby

[Ruby](https://www.ruby-lang.org/) is an interpreted language created by Matz (Yukihiro Matsumoto) in 1995. It has strong roots in both [Perl](https://www.perl.org/) and [Smalltalk](https://en.wikipedia.org/wiki/Smalltalk), though over time some of the more Perl-like features have fallen out of use. Thanks to its Smalltalk inspiration, it's a very object-oriented language, with a preference for [duck-typing](https://en.wikipedia.org/wiki/Duck_typing) rather than strong types.

For this first solution, I'm (unnecessarily) using object-oriented programming, metaprogramming, and a touch of functional programming (wait, it's not Functional February yet!).

```ruby
Sound = Struct.new(:divisor, :sound) do
  def of(number)
    number % divisor == 0 ? sound : ""
  end
end

class Raindrops
  SOUNDS = [Sound.new(3, "Pling"), Sound.new(5, "Plang"), Sound.new(7, "Plong")]
  def self.convert(number)
    sound = SOUNDS.map { |sound| sound.of(number) }.join
    sound.empty? ? number.to_s : sound
  end
end
```

First, I make a `Sound` class, but instead of using Ruby's usual class syntax and providing attributes and a constructor manually, I've used [`Struct`](https://docs.ruby-lang.org/en/3.2/Struct.html) to handle this for me. `Struct::new` creates a subclass of `Struct` with the given attributes, and allows additional methods to be defined on this subclass with a block. Here, one new method is added (`Sound#of`) which returns the string to be added for a specific number -- either the given sound, or a blank string.

The bulk of the solution lives in `Raindrops`. It contains a constant list with the three `Sound`s required for this task. In `Raindrops::convert`, `map` is used to convert the list of `Sound`s to a list of strings, demonstrating the syntax for anonymous functions (blocks) in Ruby. Finally, join these strings and return either the joined string, or if no sounds were made, the original number converted to a string.

What I found most interesting about this solution was the metaprogramming involved in `Struct`. A class (which is also an object) has a method to create a new subclass with its own methods -- maybe don't think too hard about it. I can definitely see how this makes Ruby as a language highly extensible.

## R

[R](https://www.r-project.org/) is the first featured language with a single-character name. It's a language primarily focused on statistics, data analysis, and data visualisation, and is part of the [GNU Project](https://www.gnu.org/). The language feature that caught my eye for Raindrops was vectorisation, which means that many operations in R can be applied to more than one piece of data at a time.

```r
raindrops <- function(number) {
  sounds <- c("Pling", "Plang", "Plong")[number %% c(3, 5, 7) == 0]
  if (length(sounds) == 0) return(as.character(number))
  paste(sounds, collapse="")
}
```

I'll take this one step at a time:
- `c(3, 5, 7)` combines the three numbers into a vector.
- `number %% c(3, 5, 7)` calculates `number` modulo 3, 5, and 7 at once. (Yes, the R syntax for modulo is two `%`s)
- `== 0` finds which of these values are equal to 0, resulting in a vector of three Booleans, also known as a logical vector.
- Using this to index another vector returns a vector containing only the words at the same positions as `TRUE`. This is much like the `filter` operation in many functional languages.
- At this point, `sounds` contains a vector with the necessary sounds for `number`. The rest of the function handles the case with no sounds, and joins `sounds` into a single string.

R is perhaps not well suited to general purpose programming, but I think for this exercise it worked well. Vectorised operations are very powerful, which is why they can be found in many data processing libraries for other languages -- they are expressive, and can have some major performance benefits.

## Common Lisp

The parentheses have returned! For anyone who was annoyed that I only used closing parentheses when joking about Lisp in [Week 1]({{< ref "48in24-week1#clojure" >}}), enjoy these opening ones to balance it out: (((((((. [Common Lisp](https://lisp-lang.org/) is *much* older than Clojure, which was featured in week 1. One of the interesting features of Lisps is their powerful macro support, and I really wanted to do something with that for Raindrops.

What I came up with was the following macro:

```lisp
(defmacro def-fizzbuzz (name &rest pairs)
  `(defun ,name (number)
     (let ((sound
            (concatenate 'string
                         ,@(loop for (a b) on pairs by #'cddr
                                 collect `(if (zerop (mod number ,a)) ,b "")))))
          (if (zerop (length sound)) (write-to-string number) sound))))
```

This macro can solve not just Raindrops, but FizzBuzz, and in fact any similar problem with any choice of factors. Even better, it generates the code to do so at compile-time - that's the power of macros!

{{< aside "Macros vs. Macros" >}}
If you've come from more mainstream programming languages, your experience with macros might stop at the simple text replacement utility provided by the C pre-processor. These macros are pretty much limited to pasting in a block of text, and perhaps inserting a few parameters verbatim.

Lisp (and other languages, like Rust and Nim) macros are an entirely different story. In these languages, macros are functions themselves, but instead of processing data at runtime, they process code at compile-time. Lisp helps with this by making runtime data and compile-time code the same thing -- everything is made of lists.
{{< /aside >}}

The main power in this macro is that it can take multiple factor-word pairs, and expand that into multiple lines of code. This is handled by the `loop` call, which is itself a very powerful macro. Lisp's `loop` is incredibly flexible, and I've used just a fraction of its options here. Specifically, I used `for` and `on` to pattern-match the first two items of the list, `by` with `cddr` to remove those items from the list, and `collect` to build a new list by evaluating the next expression for each iteration of the loop.

I'm not going to dig into every part of how this macro works, but I will provide a quick overview of some of the stranger syntax:
- `&rest` allows the macro to take many arguments, and collects all arguments after that point into a list (`pairs`).
- `` ` `` enters a "quasi-quoting" mode -- the form it is applied to is evaluated as a literal list, not a function call, however:
  - `,` inside of a quasi-quote causes the following form to be evaluated fully.
  - `,@` does the same, but removes the outermost list wrapper - `` `(+ ,@(list 1 2))`` becomes `(+ 1 2)`, not `(+ (1 2))`.

The macro can be used as follows:

```lisp
(def-fizzbuzz convert
  3 "Pling"
  5 "Plang"
  7 "Plong")
```

which expands to:

```lisp
(defun convert (number)
  (let ((sound
        (concatenate 'string 
                     (if (zerop (mod number 3)) "Pling" "")
                     (if (zerop (mod number 5)) "Plang" "")
                     (if (zerop (mod number 7)) "Plong" ""))))
       (if (zerop (length sound)) (write-to-string number) sound)))
```

The expanded function overall works very similarly to the previous solutions - join one or more strings together to form the sound, then return the sound, or the original number as a string if there isn't a sound.

This was a pretty interesting challenge, though I don't know if I would use this in production. I prefer more modern Lisps, but Common Lisp has some pretty cool features that I would like to see in more languages - `loop` is one, and the insanely over-the-top `format` macro is another.

# Final Thoughts

I really enjoyed playing with some of the more distinct features of these languages, and I'll keep trying to do that, at least for the simpler exercises.

Lisp macros are always bit of a fun puzzle to figure out, and I'm hoping to get a chance to use similar macros in a non-Lisp language, since they aren't exclusive to Lisp. I've used Ruby before, so there was less to surprise me there, but I do like the functional parts of my solution at least. I'm excited to see how R will be used in #48in24, because it probably won't fit as a completely general purpose language, but vectorisation could be useful again.

I hope you enjoyed this exploration of some very different languages, and that I was able to show you something new! Feel free to send any corrections or suggestions you have to {{< feedback >}}, and keep an eye out for Week 4!
