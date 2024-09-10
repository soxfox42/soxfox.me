+++
title = "#48in24 – Four Interesting Solutions"
date = 2024-09-07T10:00:00+10:00
summary = "I'm finally getting back to doing some #48in24 challenges, and picked out a few highlights to share. It's got low-level assembly, declarative programming, and more!"
tags = ["48in24"]
card_image = "/images/cards/48in24-highlights1.png"
+++

# I'm Back!

...but I won't be continuing the regular posts, as I've moved away from trying to get gold on every week's featured exercise. I found that solving puzzles in three (often unfamiliar) programming languages each week started becoming more of a challenge than I liked, especially as I returned to studying.

I have still been solving exercises at a more casual pace, and coming across some interesting solutions as I go. In this post I'll go through a collection of four solutions I wrote in less common languages, that I found particularly worthy of writing about.

# Difference of Squares -- WebAssembly

[Difference of Squares](https://exercism.org/exercises/difference-of-squares) is a reasonably simple task, which is just as well considering how little WebAssembly gives you to work with. Designed primarily as a compilation target for higher level languages, [WebAssembly](https://webassembly.org/) is an assembly-like language targeting a small stack machine. Unlike a real CPU running machine code, WebAssembly was designed to be a safe environment to run untrusted code in, in order to provide a lower level, higher performance alternative to JavaScript for software running in the browser.

WebAssembly has a further difference from the majority of real CPU instruction sets -- it works mainly as a stack machine. Instead of a set of registers for storing temporary values during computation, it uses a stack of values, with each assembly instruction operating on the top values from the stack.

The Difference of Squares exercise requires three functions:

- `squareOfSum` takes an integer n, and calculates (1 + 2 + ... + n) ^ 2.
- `sumOfSquares` also takes an integer n, and instead calculates (1^2  + 2^2 + ... + n^2).
- `difference` again takes an integer n, and calculates the difference between the outputs of the previous functions for that n.

`difference` is simple, because you can just call the other two functions and subtract their results. As for the other two functions, there are two main ways they could be written:

- **Using Loops:** By just following the requirements directly, you could calculate these values by looping over each integer from 1 to n, and updating the sum as you go. This works fine, but takes longer as you reach higher values of n.
- **Using Maths:** Through the magic of mathematical transformation, it's possible to find formulas for the [sum of integers](https://en.wikipedia.org/wiki/Triangular_number), and for the [sum of squared integers](https://en.wikipedia.org/wiki/Square_pyramidal_number). Evaluating these formulas will take roughly the same amount of time regardless of the value of n you use.

This second solution is what I used to solve this exercise in WebAssembly (and most other languages I've used for this exercise).

{{< aside "S-Expressions" >}}
WebAssembly text syntax looks somewhat Lisp-like, but the standard way to write function bodies is still basically the same as typical assembly language -- a flat list of instructions. The specification does however provide an alternative, known as [folded instructions](https://webassembly.github.io/spec/core/text/instructions.html#text-foldedinstr), which allow the use of Lisp style S-Expressions in function bodies. It's purely syntactic sugar, so the same WebAssembly binary is generated in the end, and essentially works by moving the arguments from an S-Expression out before the head instruction:

```lisp
(i32.add (i32.const 25) (i32.const 17))
```

is transformed into:

```lisp
i32.const 25
i32.const 17
i32.add
```

This is possible because the stack machine architecture provides a natural way to manage temporary values. Performing this same transformation for a register machine would involve register allocation, a more complex step typically reserved for a compiler, not an assembler.
{{< /aside >}}

First up, `squareOfSum`. The formula for the sum of integers up to n is n × (n + 1) / 2, so I translated that into WebAssembly, then squared the result. WebAssembly doesn't have a way to duplicate the top value on the stack directly, so I saved the result to a local variable and fetched it again immediately after, resulting in two copies on the stack.

```lisp
(func $squareOfSum (export "squareOfSum") (param $max i32) (result i32) (local $temp i32)
  local.get $max
  local.get $max
  i32.const 1
  i32.add
  i32.mul
  i32.const 2
  i32.div_u

  local.tee $temp
	local.get $temp
	i32.mul)
```

`sumOfSquares` is very similar, but has a slightly longer formula (n × (n + 1) × (2n + 1) / 6). I find translating formulas to WebAssembly easier than to register architectures, because the presence of the stack removes any need to keep track of which register is used for which temporary value. The translation process is even quite easy to automate with the [shunting yard algorithm](https://en.wikipedia.org/wiki/Shunting_yard_algorithm).

```lisp
(func $sumOfSquares (export "sumOfSquares") (param $max i32) (result i32)
  local.get $max
	local.get $max
	i32.const 1
	i32.add
	local.get $max
	i32.const 2
	i32.mul
	i32.const 1
	i32.add
	i32.mul
	i32.mul
	i32.const 6
	i32.div_u)
```

Finally we have `difference`. This function shows off the function call syntax in WebAssembly. I gave each of the previous functions a symbolic identifier (the names beginning with `$`), then referenced it in the call instruction. This actually just assembles into a numeric index -- the index of the function within the module, but these identifiers serve the same purpose as labels in other assembly languages, providing a convenient human-readable way to reference part of the program.

```lisp
(func (export "difference") (param $max i32) (result i32)
  local.get $max
  call $squareOfSum
  local.get $max
  call $sumOfSquares
  i32.sub)
```

{{< aside "Compilers Are Magic" >}}
When writing assembly directly, or even writing code for a non-optimising compiler, mathematical tricks like this can sometimes be useful for squeezing as much performance as possible from a target system. If you're using a modern optimising compiler though, this might be happening for you without you realising. LLVM-based compilers in particular are able to perform some mathematical optimisation. I looked at the [WebAssembly code](https://godbolt.org/z/44P1sYM8q) Clang produced from a C implementation of `squareOfSum` using Compiler Explorer, and there was not a loop in sight!
{{< /aside >}}

# Zebra Puzzle -- Prolog

The Zebra Puzzle is a classic logic puzzle, over 60 years old by this point. It takes the form of a list of 15 facts/constraints about the inhabitants of five houses, and two final questions: "Which resident drinks water?", and "Who owns the zebra?". This puzzle is a good example of a constraint satisfaction problem (CSP), and is used as a common test of algorithms for solving such problems.

Prolog is a declarative programming language centered around logical programming. Instead of exact steps for the computation of some result, Prolog programs consist of facts and rules, building a logical foundation for the system you want to represent, which can then be used to evaluate queries about this system. Among other things, Prolog is a powerful tool for CSP solving, like needed for the zebra puzzle.

To solve this exercise, I will need a way to represent a possible arrangement of people and houses. To do this, I'll use a list where each term represents one house using a complex term like the following:

```prolog
% House Color, Nationality, Pet, Drink, Cigarette Brand
house(red, english, dog, coffee, kools)
```

Some of the rules in the zebra puzzle refer to houses being "next to", or "to the right of" other houses, so I created some rules to make that easier to express in Prolog:

```prolog
next(X, Y, Houses) :- append([_, [X, Y], _], Houses).
next(X, Y, Houses) :- append([_, [Y, X], _], Houses).

ordnext(X, Y, Houses) :- append([_, [X, Y], _], Houses).
```

Here you can see the general structure of a rule in Prolog. `:-` means that the predicate on the left is true whenever the predicate on the right is true. The `next` rule works by checking if the `Houses` list includes the two house arguments in either order, while `ordnext` checks for the two houses in a specific order. Writing rules with Prolog predicates can sometimes feel like working backwards, as is the case with the `append` here - instead of trying to deconstruct the list and find a specific subsequence, I wrote the rules more like "If you can *create* the Houses list from this partially unknown sequence, the rule holds."

The main logic of this solution lives in a rule for the predicate `solves`, which checks that a given list of houses satisfies all the constraints of the puzzle.

```prolog
solves(Houses) :-
    length(Houses, 5),

    member(house(_, _, _, water, _), Houses),
    member(house(_, _, zebra, _, _), Houses),

    member(house(red, english, _, _, _), Houses),
    member(house(_, spanish, dog, _, _), Houses),
    member(house(green, _, _, coffee, _), Houses),
    member(house(_, ukranian, _, tea, _), Houses),
    ordnext(house(ivory, _, _, _, _), house(green, _, _, _, _), Houses),
    member(house(_, _, snails, _, old_gold), Houses),
    member(house(yellow, _, _, _, kools), Houses),
    nth1(3, Houses, house(_, _, _, milk, _)),
    nth1(1, Houses, house(_, norwegian, _, _, _)),
    next(house(_, _, _, _, chesterfields), house(_, _, fox, _, _), Houses),
    next(house(_, _, _, _, kools), house(_, _, horse, _, _), Houses),
    member(house(_, _, _, orange_juice, lucky_strike), Houses),
    member(house(_, japanese, _, _, parliaments), Houses),
    next(house(_, norwegian, _, _, _), house(blue, _, _, _, _), Houses).
```

First, `solves` requires that `Houses` is a list of 5 items. This is the first clue given in the puzzle, but also lists can be any length, so this check is required to prevent an infinite number of solutions. Next, it uses `member` to check that there is a solution to each question from the puzzle. Without these lines, if we query `solves(X)` there's no way to know that water and zebra should be the final drink and pet respectively.

Finally, the 14 remaining clues are specified in Prolog. Most clues are written using `member`, which just checks that some house in the list satisfies the condition -- there must be a red house with an Englishman, and a house with a Ukrainian tea drinker, for instance. Underscores indicate that a particular property doesn't matter for a rule, and can have any value. There are also a few uses of `next` and `ordnext` to check that houses are adjacent as given in the clues. The other two clues use `nth1` to check a house at a specific index meets the rules.

With this rule in place, querying `solves(X)` now produces a complete solution to the zebra puzzle, but we're not quite done. The last step is to extract the answers to the two questions. For this, I just have each rule find the solution, then fetch the correct person from the result. Like everything else in Prolog, these are specified as true/false queries, but the query engine can take care of this and produce the matching input when asked `zebra_owner(X)` or `water_drinker(X)`.

```prolog
zebra_owner(Owner) :- solves(Houses), member(house(_, Owner, zebra, _, _), Houses).
water_drinker(Drinker) :- solves(Houses), member(house(_, Drinker, _, water, _), Houses).
```

Prolog is an interesting language to write in, since it focuses less on *how* the computer should compute results, and more on *what* to compute. This makes it great for this kind of logical computation work, because you can completely avoid the step of creating an algorithm that actually comes up with the solution, and instead just pass the work directly to an existing general-purpose algorithm.

# D&D Character -- Unison

[Unison](https://www.unison-lang.org/) is a pretty new language which, among other things, introduces the idea of [abilities](https://www.unison-lang.org/docs/fundamentals/abilities/), a new way to model side effects of computation. These abilities take the idea of separating pure functions (those without side-effects, that always return the same output for the same input) and impure functions (those that interact with the outside world), and extend it further to represent the effects of a function with more granularity, and with strong type checking.

[This exercise](https://exercism.org/exercises/dnd-character) doesn't involve any particularly complex applications of effects, but does use them just enough to get a feel for how they work. The goal is to create a function that randomly generates attributes for a Dungeons & Dragons style character.

I start by implementing the `modifier` and `ability` functions that are used to calculate individual player attributes. `modifier` is a pure function, and doesn't require any abilities, but `ability` will depend on random number generation, so specifies the `Random` ability.

<!-- haskell formatting is close enough -->

```haskell
dndCharacter.modifier : Nat -> Int
dndCharacter.modifier score =
  use Int /
  use Nat subtractToInt
  (subtractToInt score 10) / +2

-- ability is a keyword, so this has to be ability_
dndCharacter.ability_ : '{Random} Nat
dndCharacter.ability_ = do
  rolls = List.replicate 4 do Random.natIn 1 6
  min = List.foldLeft Nat.min 6 rolls
  Nat.sum rolls - min
```

The `modifier` code shows a few quirks of Unison:

- Even standard operators are functions that live within types, so I use `use Int /` to bring integer division into scope.
- Unison's standard integer type is `Nat`, or a 64-bit unsigned integer. To handle subtraction with possible negative results, I used `subtractToInt`.
- Integer literals are also of the `Nat` type, if you want a positive `Int` value, you need to add the positive sign.

The `ability_` function uses the `Random` ability along with some functional list operations to simulate rolling four dice and keeping the three highest. Notably, `List.replicate` doesn't just copy one value through the list, it performs a [delayed computation](https://www.unison-lang.org/docs/fundamentals/values-and-functions/delayed-computations/) multiple times and collects all the results. This means I can use it to generate multiple random numbers easily. `ability_` itself is also a delayed computation, so it has a quote in its type signature, and the body is wrapped in a `do` block.

```haskell
dndCharacter.character : '{Random} Character
dndCharacter.character = do
  use dndCharacter ability_ modifier
  use Int +
  constitution = !ability_
  Character
    !ability_
    !ability_
    constitution
    !ability_
    !ability_
    !ability_
    (Optional.getOrElse 0 (Int.toNat (+10 + modifier constitution)))
```

This last piece of code just ties together the modifier and ability calculation code into a complete `Character` record (a type provided by the initial exercise code). There's a bit of messy type conversion that I wasn't sure how to avoid in the last line, where the character's hitpoints are calculated, but more importantly, here we see how to evaluate delayed computations -- the `!` operator. Additionally, because `ability_` uses `Random`, `character` has to use it too.

{{< aside "Handling Abilities" >}}
Unison's abilities are more than just a static type-checking feature, as they actually allow you to swap out the code that performs the effects freely. `Random` doesn't just work on its own, it requires an ability handler to tell it how to generate those random numbers. In Exercism's case, this is `Random.lcg`, which uses a linear congruential generator for this purpose, but Unison also provides `Random.splitmix`, and a special one called `Random.run`, which uses the `IO` ability to pick the initial seed automatically.

All of these handlers could be used with the `character` function to change the RNG algorithm, all without ever touching the inner workings of `character`!
{{< /aside >}}

I think the idea of tracking computational effects precisely like this is really interesting, and it's not the only thing Unison is trying to do. It also has a tool called the Unison Codebase Manager, which provides a new way to manage code on a semantic level, and is designed heavily around distributed computing. All in all, while it's not a language I have much to do with right now, I'm excited to see where it goes!

# Robot Simulator - Gleam

I'll finish up this highlights post with a bit of functional programming in [Gleam](https://gleam.run/). I've featured Gleam in a couple of previous posts, and it's been great seeing how much it has continued to grow since 1.0, both through some small but welcome additions to the language, and through many enhancements to the compiler and the official language server.

This exercise has students create a function to simulate a simple robot. The robot can keep track of its position and rotation, and can execute a series of instructions given as a string. The possible instructions are:

- **L:** Turn 90 degrees left
- **R:** Turn 90 degrees right
- **A:** Move 1 step forward

The exercise starts out with some predefined data structures for the robot, and its position and direction, so these are what I'm working with:

<!-- again, good enough highlighting -->

```v
pub type Robot {
  Robot(direction: Direction, position: Position)
}

pub type Direction {
  North
  East
  South
  West
}

pub type Position {
  Position(x: Int, y: Int)
}
```

Next, I need to create functions that perform each of the three actions the robot can take -- left, right, and advance:

```v
fn left(robot: Robot) -> Robot {
  let new_direction = case robot.direction {
    North -> West
    East -> North
    South -> East
    West -> South
  }
  Robot(new_direction, robot.position)
}

fn right(robot: Robot) -> Robot {
  let new_direction = case robot.direction {
    North -> East
    East -> South
    South -> West
    West -> North
  }
  Robot(new_direction, robot.position)
}

fn advance(robot: Robot) -> Robot {
  let Position(x, y) = robot.position
  let #(dx, dy) = case robot.direction {
    North -> #(0, 1)
    East -> #(1, 0)
    South -> #(0, -1)
    West -> #(-1, 0)
  }
  Robot(robot.direction, Position(x + dx, y + dy))
}
```

These are pretty much just made with pattern matching to produce a different result for each direction the robot can be facing. In the case of `advance`, the `case` is used to select a pair of numbers to be added to the current position, so that the robot moves correctly in each direction.

Finally, the main body of the solution lives in the `move` function, which uses the three previous functions to update the robot position according to each character in the string. Looping over the instruction string and tracking the current position is done with a fold, a powerful operation that I've [previously written about]({{< ref "48in24-week6#part-2-its-foldin-time" >}}) for #48in24. I also used `map` to convert each character to the associated function ahead of time, so that the fold just applies a list of functions in order.

```v
pub fn move(
  direction: Direction,
  position: Position,
  instructions: String,
) -> Robot {
  instructions
    |> string.to_graphemes
    |> list.map(fn(inst) {
      case inst {
        "L" -> left
        "R" -> right
        "A" -> advance
        _ -> panic as "Unknown instruction"
      }
    })
    |> list.fold(
      create(direction, position),
      fn(robot, op) { op(robot) }
    )
}
```

With that, Robot Simulator is solved! This exercise was mostly just repetitive work setting up the functions for each action, matching on the directions, but I think the final `move` function is still a nice example of Gleam's pipe operator for functional programming.

# Wrapping Up

That brings me to the end of this highlights post, I hope you enjoyed seeing some solutions in uncommon but interesting programming languages! I don't have much of a plan as to when I'll next write about #48in24, as I wrote at the beginning, I'm only solving 48in24 exercises casually when I feel like it, not holding myself to the weekly goal. If I do feature it again, it will most likely not be until after I finish my [compiler series]({{< ref "compiler-part1" >}}) -- go check that out if you haven't!
