+++
title = "#48in24 – Week 2: Reverse String"
date = 2024-01-23T19:25:02+11:00
summary = "!2 keew rof emiT – sorry, time for week 2! This week the task is to reverse some strings, which is pretty simple... until it isn't. Featured languages: JavaScript, Nim, C++."
tags = ["48in24"]
card_image = "/images/cards/48in24-week2.png"
+++

This week's featured exercise is [Reverse String](http://exercism.org/exercises/reverse-string), and as the name implies, the task is to write a function that takes a string and returns a reversed version of that string. Sounds simple, but as we'll soon see, it can be surprisingly complex.

Before we get into the crazy stuff though, I'll explain a simple solution in each language, that at least passes the tests provided by Exercism. The featured languages this week are JavaScript, Nim, and C++.

# Languages

## JavaScript

JavaScript is the language of the web, and the initial prototype was created at Netscape in just 10 days. It was designed as a simple scripting language, so it was quite limited, but it has slowly grown into a pretty reasonable programming language, with the biggest jump coming in 2015 with [ES6/ES2015](https://en.wikipedia.org/wiki/ECMAScript_version_history#ES2015).

Interestingly, while it has decent string processing capabilities, including built in regular expressions, it lacks a built in function for reversing a string. Here's the implementation I came up with:

```javascript
export const reverseString = string => {
    return [...string].reverse().join("");
};
```

The approach this takes is pretty simple - convert the string to an array of characters, reverse that array, then join them together without separators into a new string. The `[...string]` syntax is known as spread syntax, and can be used to collect elements of a sequence into an array.

JavaScript is basically a requirement if you want to do any web development, and while it started out as a limited language that I wouldn't want to use, modern JavaScript is pretty nice overall. I prefer to use TypeScript where possible, because I love static typing, but overall I can't complain much about JavaScript.

## Nim

Nim is a language that first appeared in 2008, and I group it into the category of modern languages with others like Rust, Go, and Kotlin. It's a compiled language, but instead of compiling directly to machine code, or a low-level intermediate layer, it compiles to C source which can then be fed to any C compiler -- the `nim` command handles all this though, so most users won't even notice. Its syntax is somewhat Pythonic, though it is distinct from Python in a number of ways.

One thing I like about Nim is its large standard library, which already includes the functionality of reversing strings. Since Exercism likes to focus on idiomatic code, I think that using this is the best possible Nim solution, as there's no reason to rewrite existing behaviour.

```nim
import std/unicode
proc reverse*(s: string): string = s.reversed
```

{{< aside "Method call syntax" >}}
`s.reversed` is an interesting piece of syntax. At first glance, it appears to be calling a method on `s`. The lack of parentheses is fine, I've seen that in several languages before. However, if we look at the docs for [`std/unicode`](https://nim-lang.org/docs/unicode.html#reversed%2Cstring), it seems that `reversed` is just a regular proc that takes a string as its first argument. Nim doesn't differentiate between methods and functions like most languages do. Instead, `obj.func(a, b)` is just a different way to write `func(obj, a, b)`.
{{< /aside >}}

Nim seems like an interesting language, but I have a hard time seeing where it would fit when I already use Rust and Go. I'm not entirely sold on some of the syntax tricks it has, such as the method call syntax, or the way it [ignores case and underscores](https://nim-lang.org/docs/manual.html#lexical-analysis-identifier-equality) for variables, but I think I could learn to like programming in Nim, if I had a reason to.

## C++

C++ is a very well known language that expands upon C with a huge range of features. These days, it has diverged enough from C that they should be considered entirely distinct languages.

Like Nim, the C++ standard library has the functionality required for this task built in. Unlike Nim, C++'s built in version is not aware of Unicode at all, so we'll be limited to reversing ASCII strings. This is enough to pass the exercise though, so I implemented that as my first solution, and I'll revisit Unicode later.

For simplicity, I'm leaving out details of namespaces and header files required for the full Exercism solution. My abridged solution is as follows:

```cpp
#include <algorithm>
#include <string>

std::string reverse_string(std::string input) {
    std::reverse(input.begin(), input.end());
    return input;
}
```

The built in function for reversing sequences in C++ is `std::reverse`, declared in the `algorithm` header. It must be passed a pair of iterators, which is how sequences are typically handled by the standard library, and it reverses in-place. The in-place reversal is not an issue here, as the string was copied into a new piece of memory when it was passed by value, not by reference. After reversing, I return the copied string.

This code shows one of my biggest issues with the C++ standard library - iterators. The design has always felt flawed to me, as they are almost always meaningful in pairs, otherwise you may iterate past the end of a sequence. If Exercism was updated to use C++20, I could have written:

```cpp
std::string reverse_string(std::string input) {
    std::ranges::reverse(input);
    return input;
}
```

That's an improvement, since the iterators are now passed around as a pair automatically, but the `std::ranges` algorithms still use regular iterators in some cases. I find the C++ standard library to be pretty disappointing, and in just this short example I've run into two issues -- Unicode handling, and iterators. In my experience, these awkward points just get worse as programs get more complex in C++.

# Graphemes

I said that things were going to get complex, so here we are. If you just wanted to see what I thought of the main exercise, or if the complex system that is Unicode scares you (it should), you can click away now. Otherwise, welcome to the *real* Reverse String exercise.

What is the difference between the strings "wu&#x308;t" and "w&#xfc;t"? If you find their lengths in most programming languages, the first will be four characters long, and the second will be three. This is because the first string uses a combining character to add the [diaeresis](https://en.wikipedia.org/wiki/Diaeresis_(diacritic)) above the 'u', and the second string uses a single character that represents "U with Diaeresis". Running the naive solutions from above on the second string will produce the expected output, but if you do the same with the first string, the diaeresis moves across one character: "t&#x308;uw".

Modelling complex human writing systems on computers is a hard thing to do, and the systems used for this have changed over time. Once, [it was pure chaos](https://en.wikipedia.org/wiki/Code_page), and now, it's slightly less chaos -- [Unicode](https://home.unicode.org/) is a universal system that allows computers to encode almost all human languages, and it also specifies many of the details of how to process text.

One of the things that Unicode specifies is how to break strings into units that users perceive as "characters". These units are called grapheme clusters, and they do a pretty good job of representing what users would think of as individual characters, even when multiple Unicode code points are involved.

The [full algorithm](https://unicode.org/reports/tr29/) is well beyond the scope of this post, but feel free to check it out if you're curious about how it works behind the scenes. The same report also includes rules on breaking strings into words and sentences, even more complex tasks.

So, the goal now is to write new solutions that work correctly on words with combining characters. I want to be able to run the solutions on the online test runner too, but it seems only JavaScript will be compatible.

## JavaScript

I struggled for a while to find a way to do this without pulling in external libraries. There are plenty of libraries available for the task of splitting strings into grapheme clusters, but I'm not aware of a way to use them in the Exercism test runner. I finally came across [`Intl.Segmenter`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/Segmenter), which is an API added in 2021 that can do exactly what I need.

```javascript
export const reverseString = string => {
    const segmenter = new Intl.Segmenter();
    const segments = [...segmenter.segment(string)];
    return segments.reverse().map(s => s.segment).join("");
};
```

First, I construct the default `Segmenter`. This uses the default locale (it might be better to specify this to ensure a more robust solution), and splits into graphemes, as opposed to words or sentences. Then, I use it to segment the string, and use spread syntax again to convert the `Segments` iterable into a more useful array. Finally, I reverse the segments, extract the text from each, and join them together. It's more complex than the naive solution, but not by too much.

By the way, you probably shouldn't use this code on a web page yet - Firefox only supports the `Segmenter` API in Nightly as of this post. Node.js should be fine though.

{{< aside "Code points vs. Code units" >}}
In the original JavaScript solution, I used `join("")` but not `split("")`, instead opting for spread syntax for splitting the strings. It turns out there's actually a good reason for this -- split and spread syntax behave slightly differently on some characters. JavaScript uses UTF-16 strings, which use 16-bit values for each code point. With this, you can represent any code point up to U+FFFF directly, but no higher. The solution is [surrogate code points](https://en.wikipedia.org/wiki/UTF-16#Code_points_from_U+010000_to_U+10FFFF), which are a range of code points that can be used in pairs to encode values up to U+10FFFF.

For some reason, the two methods of splitting a string into characters behave differently on these higher code points:
- `split("")` returns the two surrogate code points separately.
- `[...string]` returns the two code points in a single element, allowing them to stay together when reversed.
{{< /aside >}}

## Nim

Nim impressed me here! While it doesn't completely meet my requirement of reversing strings based only on grapheme clusters, the `std/unicode` library already handles the most common use case for this - combining characters. That means that the "wu&#x308;t" string from before *already works*. So my new test case is "&#x1f1e6;&#x1f1fa;", the flag of Australia! This is made up of two "Regional Indicator Symbols", spelling AU. When reversed by a naive solution, the result is "&#x1f1fa;&#x1f1e6;", Ukraine's flag (UA).

Unfortunately, this is where the standard library gets a little less helpful. I might have missed something, but it seems to me that Nim's standard library doesn't have a way to iterate over grapheme clusters, or do much with them at all. The one thing I found that looked helpful was [`graphemeLen`](https://nim-lang.org/docs/unicode.html#graphemeLen%2Cstring%2CNatural), but that's named incorrectly - it only handles combining sequences, just like `reversed`. There is [an issue](https://github.com/nim-lang/Nim/issues/7740) open about this naming, but it doesn't look like there will be a change made.

So with the standard library of no help, it's time to look at third-party options. The best option I could find for this task was [nim-graphemes](https://github.com/nitely/nim-graphemes). It was easy to install with `nimble install graphemes`, and here is how I was able to use it in a solution:

```nim
import std/strutils
import graphemes
proc reverse*(s: string): string =
    s.graphemesReversed.join
```

`graphemesReversed` returns the grapheme clusters as a sequence of strings in reverse order. This is most of what I need, and I can put it back together into a single string with `join`. The solution turned out fairly simple, but most of that is thanks to an existing library that does exactly what I wanted.

## C++

For this one, I'm starting with a program that can't even handle non-ASCII characters, let alone grapheme clusters. I've already discussed C++'s limited standard library, so there's no way I can create a simple solution with that alone. Luckily, there is another option. The [Boost libraries](https://www.boost.org/) provide the missing components of `std` -- sometimes they even become part of `std` later, such as the `boost:filesystem`/`std::filesystem` library! For this reason, I consider them to be almost standard. Unfortunately, while a couple of exercises on Exercism officially support building with the Boost libraries, this doesn't extend to Reverse String, so my solution won't run on the test runner.

The specific library I'm looking at for this exercise is `boost::locale`, which has a useful iterator `ssegment_index` that can iterate over grapheme clusters, words, and sentences, just like the JavaScript `Intl.Segmenter`. It's less user-friendly than that API though, and it took me a while to work out how I could actually use it in the way I wanted.

```cpp
#include <algorithm>
#include <string>

#include <boost/locale/boundary/index.hpp>
#include <boost/locale/generator.hpp>

namespace locale = boost::locale;
namespace boundary = locale::boundary;

std::string reverse_string(std::string input) {
    // 1.
    std::string output;
    output.resize(input.size());

    // 2.
    locale::generator gen;
    std::locale loc = gen("en_US.UTF-8");

    // 3.
    boundary::ssegment_index segmenter(
        boundary::character, input.begin(), input.end(), loc
    );

    // 4.
    auto output_it = output.end();

    // 5.
    for (const auto &segment : segmenter) {
        output_it =
            std::copy_backward(segment.begin(), segment.end(), output_it);
    }

    return output;
}
```

This works as follows:
1. Create a string with null data and the same length as the input.
2. Generate a suitable `std::locale` object, using English defaults and UTF-8 encoding.
3. Create the segment iterator. This needs the type of segments to iterate over, a base iterator, and the previously generated locale object.
4. Initialise an iterator at the end of the output string (remember, the graphemes need to be written in the opposite order).
5. Iterate over the segments, using `std::copy_backward` to copy from the input string to the output string. This will keep the relative order of bytes the same, but moves the iterator backwards through the output string.

So there it is, a grapheme cluster based string reverse in C++, using only `std` and `boost`! It's quite a lot of code to reverse a string, but it seems to work pretty well.

# Final Thoughts

Reversing a string doesn't have to be complicated. If all you care about is reversing *most* text, the naive solutions are perfectly acceptable (C++ is pushing it with no UTF-8 support). There really is a lot of depth to it though, if you care to look at the stranger side of character encoding.

As for this weeks languages:
- JavaScript went pretty smoothly. I like working with JS/TS, and while it didn't have quite as much built in functionality as Nim, it was the only languages I could handle grapheme clusters in without extra libraries.
- I liked Nim's extensive standard library, though it fell short when it came to grapheme clusters. The Nim solution was the shortest in both cases, and I was impressed with how easily I could add an external library.
- My opinion on C++ has not been significantly changed by this exercise. The standard library has always felt weak compared to more recent languages, but I acknowledge that it's a widely used language, and is therefore useful to know.
