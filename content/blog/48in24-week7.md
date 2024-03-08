+++
title = "#48in24 – Week 7: Acronym"
date = 2024-03-03T09:40:03+11:00
summary = "TWWBLAA! (This week we'll be looking at acronyms!) Sounds simple enough, but there are a few tricky cases to catch. Featured languages: Haskell, Tcl, PowerShell."
tags = ["48in24"]
card_image = "/images/cards/48in24-week7.png"
+++

The latest featured exercise in Exercism's [#48in24](https://exercism.org/challenges/48in24) is [Acronym](https://exercism.org/exercises/acronym). It's a pretty easy one to describe: take a string, return the acronym formed from the first letter of each word. There are a few tricky elements to watch out for though.

Here are a few examples from the test cases:

**Portable Network Graphics**: PNG \
**Ruby on Rails**: ROR \
**Complementary metal-oxide semiconductor**: CMOS \
**Halley's Comet**: HC

So we can see that acronyms need to be in all-caps, treat hyphens as word separators, and ignore all other punctuation. There's also an even harder case in the Haskell version, as that track chose to keep an older test case around, so watch out for that!

# Languages

Haskell is the first featured languages, but I'd like to leave the hardest version to last in this post.

## Tcl

[Tcl](https://www.tcl.tk/) is a high-level language where everything is a command. Commands are strings, so string processing is used heavily throughout the language -- even the body of a loop is just another string!

The solution I settled on in Tcl uses a regular expression to break the words apart, which makes it quite short.

```tcl
proc abbreviate {phrase} {
    set words [regexp -all -inline {[A-Za-z']*} $phrase]
    set firsts [lmap w $words {string index $w 0}]
    string toupper [join $firsts ""]
}
```

First, we `set` the `words` variable to the result of executing another command -- that's what the square brackets are for. This command is a `regexp` command, which as the name suggests is for searching for regular expressions in strings. `-all` finds all matches, similar to the `g` flag in some languages, while `-inline` instructs `regexp` to return all matches as a list. The expression is passed in curly braces, which are just string delimiters that disable variable substitution in Tcl.

You might notice that the expression I used cheats a little bit. It's looking for words that are made up of letters and apostrophes, which allows it to handle the case "Halley's Comet", but doesn't ignore *all* other punctuation like I described in the intro. Still, dealing with apostrophes covers the vast majority of cases you would practically run into, so I'm okay with this.

The next line uses `lmap`, which is just like `map` in functional programming. As mentioned before, the body of this map call is just a string, which gets evaluated for each item. The variable binding is given by the first argument to `lmap`. After this, `firsts` contains a list of the first character in each word.

All that's left is to combine the list into a single string, and ensure all letters are uppercase.

I'm already shocked by how much flexibility Tcl can provide with its simple command/string design. I'll probably stick to more typical scripting languages, but it's interesting to see what can happen if a language isn't afraid to break traditional expectations!

## PowerShell

[PowerShell](https://github.com/PowerShell/PowerShell) is Microsoft's primary shell for Windows, though it can now run on macOS and Linux too. Just like Unix shells such as Bash, PowerShell can be used for scripting purposes, though it moves closer to typical programming languages -- it runs on the .NET framework, after all.

```pwsh
Function Get-Acronym() {
    [CmdletBinding()]
    Param (
        [string]$Phrase
    )
    (-join ($Phrase -split "[\s-]+" | % { $_ -match '[A-Za-z]' > $null; $Matches[0] })).ToUpper()
}
```

I solved this one in one line, ignoring the function definition lines. It's a bit of a mess, so I'll break it down.

1. `$Phrase -split "[\s-]+"` splits the input on groups of spaces and hyphens. The result is a list of words.
2. This is piped into a foreach loop, written with the `% {}` shorthand. In the loop:
    1. The word (`$_`) is matched against a regex that looks for letters. To disable the automatic command output, `> $null` is used.
    2. The first match of the regex is extracted -- this is the first letter of the word.
3. The resulting list is joined to a string with `-join`.
4. The string is converted to uppercase with `.ToUpper()`.

This code meets all the requirements, and works pretty much as I described in the intro, no cheating here.

So far, I'm not really a fan of PowerShell. It has a lot of power (it's in the name), but not enough consistency (Why are join and split operators, but `ToUpper` is a function call? Why does most of the code here return the output I need, but `-match` stores the full output in a random global variable?). It's certainly better than most Unix shells for more complex programming tasks, but I'd rather use something like Python once things get too complex for a shell script.

## Haskell

It's time for the big one! [Haskell](https://www.haskell.org/) is a purely functional programming language, ~~designed by mathematicians as a sick joke~~ designed for teaching and research. To quote the original report on Haskell: "The committee hopes the Haskell can serve as a basis for future research in language design." This explains why Haskell seems very different to most other languages around, even other functional languages.

This version of the task is extra-challenging, as the maintainers of the Haskell track chose to keep an older test case that has been removed from most versions of Acronym: "HyperText Markup Language" becomes HTML. I'll handle this by splitting in the usual way, but instead of just taking the first letter from each word, I'll detect camel-case words like this, and take all capital letters.

```hs
module Acronym (abbreviate) where

import Data.Char

isCamel :: String -> Bool
isCamel (x:xs) = any ((/= firstCase) . isUpper) xs
  where firstCase = isUpper x

lettersFor :: String -> String
lettersFor (x:xs)
  | isCamel (x:xs) = toUpper x : filter isUpper xs
  | otherwise      = [toUpper x]

dashesToSpaces :: String -> String
dashesToSpaces = map f
  where f '-' = ' '
        f x   = x

abbreviate :: String -> String
abbreviate = concat . map (lettersFor . filter isLetter) . words . dashesToSpaces
```

Typically in Haskell, it's easier to write many short functions then compose them with each other rather than writing one long function that does many things. I've done that here, and in my opinion it helps to make the logic very clear.

`isCamel` is a function that detects camel-case words. Technically, it also counts words like "Markup", because it's really looking for *mixed*-case words, but the behaviour is acceptable anyway -- only the uppercase M will be kept. It works by checking if any characters in the tail of the list have a different case to the first letter, using `isUpper` from `Data.Char`.

`lettersFor` takes a word, and returns the letters that it should add to the acronym. Using `isCamel` it switches between keeping the first letter + any other uppercase letters, and just taking the first letter. The camel-case arm could have been written `filter isUpper (x:xs)` instead, which works fine for the tests, but I like that my version can also handle the case "reStructuredText" = RST. We need to detect mixed-case words here, or "GNU Image Manipulation Program" would be handled incorrectly - "GNU" shortens to "G", not "GNU".

`dashesToSpaces` is a simple way to handle both separators without needing to reimplement Haskell's `words`. It simply replaces any "-"s in the string with spaces. This function uses `where` to define an extra helper function `f`, which performs the replacement.

`abbreviate` is the actual solution to the task. Reading right-to-left, it replaces hyphens with spaces, splits the string into words, for each word it removes non-letters and uses `lettersFor` to get the appropriate letters, and finally it joins all of the `lettersFor` results into one string.

I found it a little odd that there doesn't seem to be a standard library function that splits on multiple delimiters, or one for replacing items in a list, but the solution I used in the end works well enough.

# Final Thoughts

I enjoyed the additional challenge that the Haskell version provided, but I do understand that removing it makes for a better early exercise in general. With this task complete, Functional February is over, and Mechanical March can begin!

I hope you enjoyed seeing the different ways I solved this week's exercise, and I'm looking forward to Week 8!
