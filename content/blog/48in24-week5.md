+++
title = "#48in24 – Week 5"
date = 2024-02-17T16:13:45+11:00
summary = "I get to learn about biochemistry and functional programming in the same week of #48in24, what a deal! Featured languages: F#, Crystal, C#."
tags = ["48in24"]
card_image = "/images/cards/48in24-week5.png"
+++

Week 5 of #48in24 is also the second week of Functional February -- the themes from #12in23 are sticking around. This week, the task is not quite as typical a coding task as the first four weeks, and it's called [Protein Translation](https://exercism.org/exercises/protein-translation). The goal is to take a string of RNA nucleotides (A, U, C, G), and convert them into a matching list of proteins, stopping once a certain pattern is found.

More precisely, the string has to be split into 3-character units called codons, and then each codon must be translated to the right protein name (or throw an error if no matching protein exists). Some codons are translated to "STOP" instead, which indicates that the rest of the RNA sequence can be ignored (and the STOP codon should not appear in the output).

As all three languages have strong functional programming features, I will be using a functional approach to this task. That means that instead of explicitly writing loops and mutating variables, the computation is performed by chaining various functions, some of which are higher-order functions that take other functions as input.

# Languages

## F#

[F#](https://fsharp.org/) is a language from Microsoft that targets the .NET runtime, and uses a primarily functional approach to programming. It supports imperative programming, as well as handling .NET's object-oriented style, but generally, F#-native code heavily relies on functional programming techniques.

```fsharp
module ProteinTranslation

let translate = function
    | "AUG" -> "Methionine"
    // omitted for brevity
    | "UAA" | "UAG" | "UGA" -> "STOP"
    | _ -> failwith "Unknown codon"

let proteins rna =
    rna
    |> Seq.chunkBySize 3
    |> Seq.map (System.String >> translate)
    |> Seq.takeWhile ((<>) "STOP")
    |> Seq.toList
```

This code maps out the general strategy I'm taking with this problem. I start with a way to convert individual codons to proteins, raising an error if necessary. Then, I put the RNA sequence through several conversion steps:

1. Split it into groups of 3 characters.
2. Join the characters back into a string and look up the corresponding protein.
3. Take as many proteins from this sequence as possible without taking a STOP codon.

In F#, I implemented this using the `|>` operator (that's two characters, `|` and `>`, and I don't like how Fira Code chooses to display it). This operator takes a value on the left, and a function on the right, and applies the function to the value. This might seem like a fairly pointless operation, but it actually makes this code much cleaner. `toList(takeWhile(map(chunk(rna))))` looks a bit messy, and is read backwards compared to how it gets evaluated.

Another interesting operator used here is the `>>` operator. Given two functions -- `f >> g` -- this operator returns a new function by combining them: `h(x) = g(f(x))`.

Finally, you might have noticed that 3 of the functions already have one argument provided. There's no special syntax to handle this, it simply emerges from the way F# handles functions. All functions are "curried", meaning that they take their first argument, and return a new function, which takes the second argument, and so on. By only providing one argument to these two argument functions, they are only partially applied and can still take the transformed RNA sequence as input. This is also how `((<>) "STOP")` works -- it's the `<>` inequality operator applied to only one value.

## Crystal

[Crystal](https://crystal-lang.org/) is a high-level language with syntax like Ruby, but with a compiler and strict type-checking. It is not strictly a functional language, and a lot of code written in it will be in an imperative style, but like Ruby, it has strong standard library support for functional programming.

```crystal
module ProteinTranslation
  CODONS = {
    "AUG" => "Methionine",
    # omitted for brevity
    "UAA" => "STOP",
    "UAG" => "STOP",
    "UGA" => "STOP",
  }
  def self.proteins(strand : String) : Array(String)
    strand
      .each_char
      .in_groups_of(3)
      .map { |codon| CODONS[codon.join]? || raise ArgumentError.new }
      .take_while { |protein| protein != "STOP" }
      .to_a
  end
end
```

This code works pretty much the same way as the F# code, so rather than explaining it again, I'll summarise the main differences:

- Instead of using a function with pattern-matching to convert codons, all mappings are placed in a `Hash` to be looked up in `proteins`.
- No pipe operator this time, but being able to call methods on various objects also avoids the function nesting problem.
- In Crystal, strings aren't implicitly `Enumerable`, so an `each_char` call is necessary.
- Rather than curried functions, the Crystal solution uses blocks, a form of anonymous function.

I could have used a `translate` function just like F#, but I chose to insert a little extra variety. Despite that, the core code survived being translated between languages pretty well.

## C#

[C#](https://dotnet.microsoft.com/en-us/languages/csharp), just like F#, is a Microsoft language targeting .NET, and is in fact the reason .NET exists at all. It is very similar to Java, on account of it starting as Microsoft's custom Java dialect before pesky legal issues got in the way. C#'s functional programming support comes in the form of LINQ, which is both a language syntax feature and a set of interfaces in the standard library. Here, I won't be using the dedicated syntax, I'll just call the functions on the interfaces.

```csharp
using System;
using System.Linq;

public static class ProteinTranslation
{
    static string Translate(string codon)
    {
        switch (codon)
        {
            case "AUG": 
                return "Methionine";
            // omitted for brevity
            case "UAA": case "UAG": case "UGA":
                return "STOP";
        }
        throw new Exception("Unknown Codon");
    }

    public static string[] Proteins(string strand) => strand
        .Chunk(3)
        .Select(codon => Translate(new string(codon)))
        .TakeWhile(protein => protein != "STOP")
        .ToArray();
}
```

I'm back to using a `Translate` function like in F#, but this time it's built with more C-like `switch-case` syntax, not pattern matching and expressions (though in recent versions of C#, this is possible). There's very little new to comment on in this solution, as I've already covered all the features this uses in the other two languages. The strangest part of this solution is the fact that what F# and Crystal call `map` is now called `Select`, which actually makes me think of the typical `filter` operation. This odd naming choice comes from the LINQ syntax being inspired by SQL.

# Final Thoughts

This was a fun week of functional programming, so I'm excited for the remaining Functional February exercises. While I don't typically code in languages like F# where functional programming is the primary paradigm, I try to apply functional techniques wherever they can make code more expressive.
