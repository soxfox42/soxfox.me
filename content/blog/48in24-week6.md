+++
title = "#48in24 – Week 6: List Ops"
date = 2024-02-25T11:18:15+11:00
summary = "This week, the battle of procedural and functional programming takes place... and a third thing? Featured Languages: Gleam, Swift, Standard ML."
tags = ["48in24"]
card_image = "/images/cards/48in24-week6.png"
+++

In week 6 of #48in24, the featured task is [List Ops](https://exercism.org/exercises/list-ops), and unlike the previous ones, the goal is to create a small library of functions, not just one solution to a problem. The specific functions that need to be implemented are:
- `append`: join two lists into a new one.
- `concatenate`: join many lists (a list of lists) into a single one.
- `filter`: given a list and a function, create a list containing only items for which the function returns true.
- `length`: get the length of a list.
- `map`: given a list and a function, create a list with the results of calling the function on each item.
- `foldl` and `foldr`: very powerful, see below.
- `reverse`: creates a reversed version of the list.

These functions are all fairly simple, but the challenge is to implement them all without using the existing functions provided by languages.

## List Folding

Two of the functions here, `foldl` and `foldr` are very powerful, very general functions, which can actually be used to implement *all* of the other functions on the list (hint, hint).

They take three arguments:
- The list to fold over.
- The starting value.
- A combining function.

Then, they set up an accumulator, initialised with the starting value, and for each item in the list, update the accumulator to the result of calling the combining function with the current accumulator, and the current list item. `foldl` combines the accumulator and the leftmost item first, continuing to the end of the list, while `foldr` works the other way, starting from the right/end, and moving to the left/start.

The effect of these functions is to allow just about any operation that needs to process every item in a list to be implemented with a single call. We'll see more examples of this power a bit later.

# Part 1: Procedural vs. Functional

I'm doing things a bit differently this week, and I'll be looking at two languages simultaneously for this first part of the post. Those languages are [Gleam](https://gleam.run/), a functional language inspired by the ML family of languages, but with some Rust-like syntax, and [Swift](https://swift.org/), Apple's modern replacement for Objective-C, and a fairly typical procedural language.

I'll look at each function in turn, comparing the Gleam and Swift implementations. Gleam is too new for my syntax highlighter, so I've formatted all Gleam as V, which seems to look alright as a stand-in.

## `append`

First up is `append`, which simply needs to join two lists into a single new one.

### Gleam
```v
pub fn append(first first: List(a), second second: List(a)) -> List(a) {
  case first {
    [] -> second
    [head, ..tail] -> [head, ..append(tail, second)]
  }
}
```
### Swift
```swift
func append<T>(_ first: [T], _ second: [T]) -> [T] {
    var result = first
    for item in second {
        result.append(item)
    }
    return result
}
```

In these two functions, we can already see the general structure that each language will use. In Gleam, there are no mutable variables, and no looping, so recursion will be used. We need a base case, usually the empty list, and a recursive case, which processes one list item, then recursively calls the function to process the rest of the list. In Swift, we instead use mutable variables and explicit loops.

We can also see a subtle difference between the two languages: Gleam uses linked lists, so insertion at the front is easiest, while Swift uses arrays, and inserting at the back is easiest. This means that in Gleam the code has to append the current item *after* all other items are processed, but in Swift, the current item is appended before moving on.

Also, a few syntax details I'd like to mention:
- Both languages require the use of generics to support any type of list. In Swift, this is done with the `<T>` syntax to introduce a type parameter, while in Gleam, generics are implicitly created by using lowercase identifiers in place of types.
- To fetch the first item in Gleam, as well as to handle the base case, we use pattern matching, which I've mentioned in previous weeks.
- In Gleam, everything is an expression, and expressions are implicitly returned when placed at the end of blocks. This means that the `case first` expression is automatically used as the result of `append`.
- Both languages support labelled arguments, but handle them a little differently.
    - In Gleam, arguments have no label by default, and labels are an optional convenience feature. Callers may still pass arguments without labels, or use labels to change the order of arguments.
    - In Swift, arguments have the same label as the variable name by default, and labels *must* be used, in the same order as they were declared. The only way to avoid passing arguments by label is to explicitly remove the label with `_`, which most of the List Ops functions do.

{{< aside "Stack Overflow" >}}
...the computing term, not the Q&A site.

Stack overflow is an issue that can happen when functions recurse too many times. Every time a function is called, it needs to place some state onto the computer's "stack" to keep track of information like local variables and where to return to. The stack has a limited amount of space though, so if a function calls itself too many times it can fill the stack, and this is called stack overflow.

The reason this is relevant is because Gleam's `append` calls itself for each item of `first`, so it might cause stack overflow on long lists. There is a way to avoid this using tail call optimisation, but it's not a topic I'll cover here.
{{< /aside >}}

## `concat`

This function is similar to `append` but works with as many lists as needed. In Gleam, this means joining a list of lists, in Swift it means joining many lists passed as variadic arguments (which is basically the same thing).

### Gleam
```v
pub fn concat(lists: List(List(a))) -> List(a) {
  case lists {
    [] -> []
    [head, ..tail] -> append(head, concat(tail))
  }
}
```
### Swift
```swift
func concat<T>(_ lists: [T]...) -> [T] {
    var result: [T] = []
    for list in lists {
        result = append(result, list)
    }
    return result
}
```

There's nothing particularly new here, it's basically `append`, but instead of adding one element at a time, `append` is used to add a whole list at a time.

## `length`

`length` should return the number of items in the list.

### Gleam
```v
pub fn length(list: List(a)) -> Int {
  case list {
    [] -> 0
    [_, ..tail] -> 1 + length(tail)
  }
}
```
### Swift
```swift
func length<T>(_ list: [T]) -> Int {
    var result = 0
    for item in list {
        result += 1
    }
    return result
}
```

Another simple one, instead of joining lists, `length` just has to count up by 1 for each item.

## `filter` and `map`

I'll tackle these both at once, as they work in similar ways.

### Gleam
```v
pub fn filter(list: List(a), function: fn(a) -> Bool) -> List(a) {
  case list {
    [] -> []
    [head, ..tail] -> case function(head) {
      True -> [head, ..filter(tail, function)]
      False -> filter(tail, function)
    }
  }
}

pub fn map(list: List(a), function: fn(a) -> b) -> List(b) {
  case list {
    [] -> []
    [head, ..tail] -> [function(head), ..map(tail, function)]
  }
}
```
### Swift
```swift
func filter<T>(_ list: [T], _ predicate: (T) -> Bool) -> [T] {
    var result: [T] = []
    for item in list {
        if predicate(item) {
            result.append(item)
        }
    }
    return result
}

func map<T, U>(_ list: [T], _ function: (T) -> (U)) -> [U] {
    var result: [U] = []
    for item in list {
        result.append(function(item))
    }
    return result
}
```

Both functions are higher-order functions, which means they take another function as a parameter, making their behaviour incredibly flexible.

`filter` works by running `predicate`/`function` on every item in the list, and only keeping those where it returns true. In Swift, this is achieved by wrapping `result.append` in an `if` statement, while in Gleam we have to return either just the result of running `filter` on the rest of the list (if the function returned false), or that result plus the current item (if the function returned true).

`map` is simpler, just add `function(item)` to the result list for every item. Because `map` is allowed to change the type of the list items, two generic type parameters need to be used here.

## `foldl` and `foldr`

Alright, time for the really powerful ones! Despite their insane flexibility, implementing them in both functional style and procedural style is actually pretty simple.

### Swift
```swift
func foldLeft<T, A>(_ list: [T], accumulated: A, combine: (A, T) -> A) -> A {
    var result = accumulated
    for item in list {
        result = combine(result, item)
    }
    return result
}

func foldRight<T, A>(_ list: [T], accumulated: A, combine: (T, A) -> A) -> A {
    var result = accumulated
    for item in reverse(list) {
        result = combine(item, result)
    }
    return result
}
```

Oh hey, argument labels are back!

The Swift code really does follow the explanation given at the top of this post pretty directly -- set up an accumulator, loop through the list, and `combine` each item into the accumulator. `foldl` and `foldr` only differ in a `reverse` call and the order of arguments given to `combine` (which strangely enough, is not the case in the of the Gleam version of the task).

### Gleam
```v
pub fn foldl(
  over list: List(a),
  from initial: b,
  with function: fn(b, a) -> b,
) -> b {
  case list {
    [] -> initial
    [head, ..tail] -> foldl(tail, function(initial, head), function)
  }
}

pub fn foldr(
  over list: List(a),
  from initial: b,
  with function: fn(b, a) -> b,
) -> b {
  case list {
    [] -> initial
    [head, ..tail] -> function(foldr(tail, initial, function), head)
  }
}
```

The Gleam code on the other hand has to use a recursive approach. `foldl` is pretty simple, it uses the `initial` argument as the accumulator in the recursive call -- take a list item, combine it with the accumulator, then use that as the new initial value for the next call. Rather than reversing the list for `foldr` though, this code takes advantage of the call stack to handle the reversing. First, it calculates the result from the rest of the list, then only once that's done does it combine the current item. This means that the first item of the list will always be combined last, which is what we want.

## `reverse`

Wait, why was something as simple as reversing a list left until last? Mostly for Gleam's benefit, as it requires the use of `foldl`.

### Gleam
```v
pub fn reverse(list: List(a)) -> List(a) {
  foldl(over: list, with: fn(acc, x) { [x, ..acc] }, from: [])
}
```
### Swift
```swift
func reverse<T>(_ list: [T]) -> [T] {
    var result = list
    let len = length(list)
    for i in 0..<(len / 2) {
        let temp = result[i]
        result[i] = result[len - 1 - i]
        result[len - 1 - i] = temp
    }
    return result
}
```

The approaches are drastically different here. Swift takes what I call the "coding interview" approach. It's the sort of task that might come up in a coding interview, with this kind of code being the expected solution. We loop over half of the list by index, and use a temporary variable to swap each element with its opposite.

Gleam on the other hand uses `foldl`. This is because we need the accumulator behaviour in order to implement reverse. The first item removed from the original list should also be the first item added to the new list, so it appears at the end. This isn't possible with the accumulator-less style functions that were used for most of the Gleam solutions, because those need to wait until the recursive call finishes until they can modify the result, causing the first item removed to be the last added. This could also be achieved without `foldl`, using a dedicated helper function for the accumulator.

## Wrapping up

Well, that's the first half of this post done. We've seen how common list operations can be implemented using nothing but the ability to add items to lists and to loop over the items in them, no standard library tools needed. I've also mentioned a few times how powerful the fold functions are, so....

# Part 2: It's Foldin' Time

When I say folding is powerful, I mean that it's the *only* function I need to solve this task. The last language featured this week is [Standard ML](https://en.wikipedia.org/wiki/Standard_ML), another functional language. This one has a more expression-based syntax, without Gleam's `{}` blocks. This time I'll implement `foldl` first, then use it (or `foldr`, once that's implemented) to complete the rest of the functions.

```sml
fun foldl (f, acc, []) = acc
  | foldl (f, acc, x::xs) = foldl (f, f(acc, x), xs)
```

First up, `foldl` itself. This works just like in Gleam, with a base case that just returns `acc` and a recursive case that updates the accumulator then calls `foldl` again.

```sml
fun reverse xs = foldl (fn (acc, x) => x::acc, [], xs)
```

I'll need `reverse` implemented before I can create `foldr`. Just like Gleam, this loops over all the elements of `xs`, adding them to a list, which reverses their order in the process.

```sml
fun foldr (f, acc, xs) = foldl (fn (x, acc) => f(acc, x), acc, reverse xs)
```

With this, I have both directions of folding implemented. `foldr` uses `reverse`, like the Swift version, but just uses it to call out to `foldl`.

```sml
fun length xs = foldl (fn (acc, _) => acc + 1, 0, xs)
```

Starting the rest of the functions simple, we have `length`, which just uses the fold to loop and increment a counter.

```sml
fun append (xs, ys) = foldr (op::, ys, xs)
fun concat xss = foldr (append, [], xss)
```

Nothing shocking here, just using `foldr` to loop over all items and join them. `foldr` is used in `append` because items are always inserted at the start of the accumulator. Both folds work for `concat`, but I believe `foldr` will perform slightly better, as it avoids looping over the entire accumulator multiple times in `append`.

Also, `op::` is the syntax for referring to an operator (in this case `::`) as a function.

```sml
fun filter (f, xs) = foldr (fn (x, xs) => if f x then x::xs else xs, [], xs)
fun map (f, xs) = foldr (fn (x, xs) => (f x)::xs, [], xs)
```

Finally, the other higher-order functions. Similar to Gleam, an `if`-`else` expression is used here for filter, to add `x` to the list only when `f x` is true. `map` always inserts the transformed value `f x`.

# Final Thoughts

I use these sorts of list operations a lot when programming. Most languages have some form of them built in, and they make it really easy to write expressive data processing code. For the simpler functions, I found I enjoyed writing in Gleam more than Swift, but as the functions get more complex, I found Swift easier to understand. This is not exactly a criticism of functional programming in general, as it most likely comes from my relative inexperience with primarily functional coding, instead choosing to use functional style only when it makes something clearer.

I had a lot of fun playing with folds in Standard ML and discovering how much can be done with two very simple functions and some lambdas. I always like being able to build (useful) complexity from simple roots in programming, so it was nice to find a way to bring that into #48in24.

Feel free to send any corrections or ideas to {{< feedback >}}, and try playing around with some of these languages if you haven't used them before!

