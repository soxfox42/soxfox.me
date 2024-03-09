+++
title = "#48in24 – Week 8: Circular Buffer"
date = 2024-03-08T09:51:02+11:00
summary = "It's week 8, which is a pretty circular number - and I'm writing some circular buffers! Featured languages: C, Groovy, Scala, plus a bonus one!"
tags = ["48in24"]
card_image = "/images/cards/48in24-week8.png"
+++

Mechanical March is upon us, so the next few weeks should be full of compiled featured languages, with at least one that compiles to native machine code per week. This week's exercise [Circular Buffer](https://exercism.org/exercises/circular-buffer) is a data structure based one, where the goal is to build a general purpose data structure with a set of functions to manipulate it. In this case, as the name suggests, we're building a circular buffer. 

# Circular Buffers

Circular buffers store a sequence of items. Items can be inserted at the end of a circular buffer, and taken from the start. So far, this is just the definition of a [queue](https://en.wikipedia.org/wiki/Queue_(abstract_data_type)), and circular buffers are in fact one way to implement a queue.

What makes circular buffers unique is the way that they use a fixed buffer in memory, without copying data around as items are added and removed. The part of a circular buffer that is used can start anywhere within the underlying memory, and when you try to read past the end, it should wrap back around to the start. For instance, the following buffer contains the items 1, 2, 3, and 4, even though they are split up differently in memory:

{{< image "/images/buffer.svg" >}}

Many community solutions I have seen for the Circular Buffer exercise do not actually use a circular buffer, because the tests will pass just fine using any other implementation of a queue, and they cannot detect when a more straightforward approach is used in a high level language.

# Languages

## C

First up is [C](https://en.wikipedia.org/wiki/C_(programming_language)), a language which has been around for over 50 years, and is essentially the de facto standard compiled language. Programming in C requires a lot of thought about managing memory usage, and this is very apparent in the implementation of a circular buffer.

C requires header files, typically with the extension `.h`, in order to know what functions are defined elsewhere. A header file contains just function prototypes without implementations, so that another `.c` file can include the header with `#include` and reference the functions and use the types declared within.

Exercism usually doesn't provide full header files in the C track, instead leaving students to determine the necessary interface from the test file. This is the header file I created for Circular Buffer:

```c
#ifndef CIRCULAR_BUFFER_H
#define CIRCULAR_BUFFER_H

#include <stddef.h>

typedef int buffer_value_t;
typedef struct circular_buffer circular_buffer_t;

circular_buffer_t *new_circular_buffer(size_t capacity);
void delete_buffer(circular_buffer_t *buffer);
void clear_buffer(circular_buffer_t *buffer);

int write(circular_buffer_t *buffer, buffer_value_t value);
int overwrite(circular_buffer_t *buffer, buffer_value_t value);
int read(circular_buffer_t *buffer, buffer_value_t *ptr);

#endif
```

Because handling generic data types in C is more challenging, the creators of the C track decided to limit this exercise to just storing `int`s, so I create a type alias `buffer_value_t` for `int`, along with declaring the `circular_buffer_t` type -- the contents of that struct are defined in the C file.

The first three functions are used to create and destroy a buffer, along with resetting its state to clear it. These functions also need to explicitly allocate the memory for the circular buffer to use, both for its internal state and the full data buffer. The other three functions are the three main operations that need to be provided on the buffer. `write` adds an item to the end of the buffer, `read` takes one from the start, and `overwrite` functions like `write`, except if the buffer is full it will overwrite the earliest item.

{{< aside "Guards, guards!" >}}

At the top and bottom of the header file, there are a few preprocessor directives that serve an interesting purpose. The entire file is wrapped in an `#ifndef` block, which means that it is only kept if `CIRCULAR_BUFFER_H` is not defined. Just inside that `#ifndef`, `CIRCULAR_BUFFER_H` is defined. So what's the point of this?

C only allows items to be defined once. This means that if we ever get into a situation where a header is included twice in the same compilation unit (even transitively through another header), it would create duplicate definitions and cause a compile error. This doesn't apply to the function declarations here, as they don't provide any actual definitions, but it does apply to the `typedef`s.

By using this set of preprocessor directives, also known as an "include guard", developers can ensure that even if the content of a header file is included multiple times, a definition will be added after by the first occurrence to prevent further occurrences being compiled.

{{< /aside >}}

In the `.c` implementation file itself, the first thing I did was define the `circular_buffer` struct fully:

```c
struct circular_buffer {
    size_t capacity;
    size_t write;
    size_t read;
    bool full;
    buffer_value_t data[];
};
```

In this implementation, I chose to use two indices marking the current read position and the current write position. This unfortunately causes issues with empty and full buffers. In both cases, the read and write positions will be the same, so I used an extra field `bool full` to resolve the ambiguity. The data is stored in the struct using a "flexible array member", which is a C99 feature. This allows me to allocate the header containing the internal state and the `buffer_value_t` buffer at the same time.

I implemented the first three functions as follows:

```c
circular_buffer_t *new_circular_buffer(size_t capacity) {
    circular_buffer_t *buffer = malloc(sizeof(circular_buffer_t) + sizeof(buffer_value_t) * capacity);
    buffer->capacity = capacity;
    clear_buffer(buffer);
    return buffer;
}

void delete_buffer(circular_buffer_t *buffer) {
    free(buffer);
}

void clear_buffer(circular_buffer_t *buffer) {
    buffer->write = 0;
    buffer->read = 0;
    buffer->full = false;
}
```

`new_circular_buffer` calls `malloc` ([pronounced "mal-ock"](https://digipres.club/@ryanfb/112033451964589941)) to allocate the memory for the structure, including its data as mentioned above. It then stores the capacity for later, uses `clear_buffer` to reset the rest of the state, and returns the pointer that `malloc` created.

`delete_buffer` is a simple call to `free` to deallocate the memory, and `clear_buffer` just sets the rest of the buffer state to indicate it is empty -- the data is technically still in `data`, but won't be accessible through the buffer functions.

Because `write` and `overwrite` are very similar, I chose to create a single shared implementation that is used by each, with a flag to indicate if overwriting should be allowed:

```c
static int write_impl(circular_buffer_t *buffer, buffer_value_t value, bool over) {
    if (buffer->full && !over) {
        errno = ENOBUFS;
        return EXIT_FAILURE;
    }
    buffer->data[buffer->write++] = value;
    if (buffer->full) {
        buffer->read++;
    }
    buffer->read %= buffer->capacity;
    buffer->write %= buffer->capacity;
    buffer->full = buffer->write == buffer->read;
    return EXIT_SUCCESS;
}
```

1. If `over` is not set, check whether the buffer is full (`full` flag). \
   If it is, report the error by setting `errno` and returning a failure status.
2. Write the value into the current cell according to the `write` index, and increment that index.
3. If the buffer was already full, the `read` index should also be incremented so it still points to the oldest item.
4. Wrap both `write` and `read` indices to fit in the `capacity`.
5. Update the `full` flag. If the read and write pointer are the same after inserting an item, the buffer must now be full.

`write` and `overwrite` themselves are of course just simple wrappers around this:

```c
int write(circular_buffer_t *buffer, buffer_value_t value) {
    return write_impl(buffer, value, false);
}

int overwrite(circular_buffer_t *buffer, buffer_value_t value) {
    return write_impl(buffer, value, true);
}
```

Finally, `read` is similar to `write`, but without needing to worry about "over-reading", because that's just plain silly.

```c
int read(circular_buffer_t *buffer, buffer_value_t *ptr) {
    if (buffer->write == buffer->read && !buffer->full) {
        errno = ENODATA;
        return EXIT_FAILURE;
    }
    buffer->full = false;
    *ptr = buffer->data[buffer->read++];
    buffer->read %= buffer->capacity;
    return EXIT_SUCCESS;
}
```

There's a similar empty buffer check, we always clear `full` (how can a buffer be full if we just removed from it?), and the data gets stored to a caller-provided pointer.

You can find my full solution [here](https://exercism.org/tracks/c/exercises/circular-buffer/solutions/soxfox42). Wow, this article is already longer than last week's, and I have three more languages to go. Why three? Well,

## Gleam (Bonus!)

it just so happens that I already solved Circular Buffer in C, less than a month before it would have counted for #48in24. So to get that sweet golden medal, I had to throw in a *bonus language* ([for the second time]({{< ref "/blog/48in24-week1" >}}))! My language of choice was [Gleam](https://gleam.run/). I covered Gleam a mere two weeks ago, but I liked it a lot and Gleam *just* released version 1.0, so I felt like bringing it back.

But now comes the sad part. I had to cheat. Gleam doesn't have arrays at all, they wouldn't work well with its immutable data model, since the entire array would need to be copied. So Circular Buffer is "impossible" in Gleam, and we have to settle for some other queue implementation.

Now, [List Ops]({{< ref "/blog/48in24-week6" >}}) in Gleam was all about *not* using the standard library, so this time I'll focus on using the standard library as much as possible. First, we need a custom type to represent our not-really-a-circular-buffer, and a constructor to go with it:

```v
pub opaque type CircularBuffer(t) {
  CircularBuffer(capacity: Int, queue: Queue(t))
}

pub fn new(capacity: Int) -> CircularBuffer(t) {
  CircularBuffer(capacity, queue.new())
}
```

Making the type `opaque` ensures that code outside of the module won't be able to peek inside and manipulate the data in odd ways. The type contains two fields -- `capacity`, which stores the maximum amount of items in the queue, and `queue`, a `Queue` from the `queue` module, which is created in the constructor with `queue.new()`.

Next, I implemented `read` like this:

```v
pub fn read(buffer: CircularBuffer(t)) -> Result(#(t, CircularBuffer(t)), Nil) {
  let CircularBuffer(capacity, queue) = buffer
  use #(item, queue) <- result.map(queue.pop_front(queue))
  #(item, CircularBuffer(capacity, queue))
}
```

There's a bit going on here, so I'll break things down bit by bit.

- `CircularBuffer(t)`: This was used in week 6 as well, but the lowercase `t` here, or any other lowercase identifier used in a type name, is used for generics. Every time the same identifier shows up in a particular context, it refers to the same type, so the generic buffer type affects the return value of this function.
- `Result`: This type has two variants -- `Ok`, which holds a value of the first generic type and indicates a successful result, and `Error`, which holds a value of the second generic type and indicates that something went wrong. In this case, the error type is `Nil`, which means we store no information about *what* went wrong.
- `#(t, CircularBuffer(t))`: I've already mentioned the generic part of this, but this is a tuple, allowing `read` to return multiple values. Specifically, when `read` returns an `Ok` variant, it will return the item read from the queue, as well as the updated queue (Gleam doesn't have mutable types, so we need to return this).
- `let CircularBuffer`: Pattern matching works on custom types too.
- `use`: Nope, nope, nope, nope, nope. I can't do this in this list, `use` gets it's own section.

### Gleam's magic keyword

(this section is based on [Gleam's `use` announcement](https://gleam.run/news/v0.25-introducing-use-expressions/))

`use` is a pretty clever keyword, something I just haven't seen in other languages (Haskell monads are a bit similar?). In Gleam, it's common to write functions that take a callback as their last argument, and the standard library has many of them. `gleam/result` contains 7 such functions, notably including `result.try` and `result.map`, which allow you to run code only if a previous `Result` was `Ok`. Some similar tools exist in `gleam/option`, there are of course common functional programming features that work similarly in `gleam/list`, and even `gleam/bool` has a helpful function in this form (which I'll use soon).

Unfortunately, when you start chaining these callback-based functions, you quickly reach what JavaScript developers refer to as "callback hell" -- a horrible triangular (from the indentation) mess of nested function in nested function. Initially, Gleam came up with a way to make working with results more ergonomic, as this was a common place that the problem might arise. It was the `try` statement, a simple way to unwrap an error if everything is `Ok`, or return its `Error` value otherwise:

```v
pub fn login(credentials) {
  try user = authenticate(credentials)
  try profile = fetch_profile(user)
  render_welcome(user, profile)
}
```

Which is fine for *most* cases, but what if you do want to start nesting other callback functions? In Gleam 0.25, a new solution was created: `use`. Rather than handling `Result`s specially, `use` is general purpose syntactic sugar for callbacks. Code that looks like this:

```v
pub fn main() {
  use file <- with_file("pokemon.txt")
  write(file, "Oddish\n")
  write(file, "Farfetch'd\n")
}
```

is rewritten to this code:

```v
pub fn main() {
  with_file("pokemon.txt", fn(file) {
    write(file, "Oddish\n")
    write(file, "Farfetch'd\n")
  })
}
```

Everything after the `use` expression becomes the body of a callback that gets passed to another function. This leads to highly flexible custom control flow, with just a single syntax addition.

Back to my implementation of `read`:

```v
pub fn read(buffer: CircularBuffer(t)) -> Result(#(t, CircularBuffer(t)), Nil) {
  let CircularBuffer(capacity, queue) = buffer
  use #(item, queue) <- result.map(queue.pop_front(queue))
  #(item, CircularBuffer(capacity, queue))
}
```

First, I use pattern matching to get the current capacity and queue. Then, I call `queue.pop_front` to take the next item from the queue. If there are no items this returns `Error(Nil)`, which should be the final result. Calling `result.map` (with the `use` syntactic sugar) lets me return `Error` values as-is, while updating an `Ok` value. In this case, I just wrap up the resulting queue in a new `CircularBuffer`.

```v
pub fn write(
  buffer: CircularBuffer(t),
  item: t,
) -> Result(CircularBuffer(t), Nil) {
  let CircularBuffer(capacity, queue) = buffer
  use <- bool.guard(queue.length(queue) == capacity, Error(Nil))
  Ok(CircularBuffer(capacity, queue.push_back(queue, item)))
}
```

`write` shows off another use of `use` -- `bool.guard`. As we've already seen, Gleam doesn't have typical control flow, so usual tricks like returning early if a condition isn't met won't work. However, since `use` is so flexible, `bool.guard` implements exactly that. If the condition is true, `bool.guard` evaluates to the given value, otherwise the (implicit) callback is run. In this case, it means that we can return an error if the queue is at capacity, then continue with the function knowing that there will be space.

```v
pub fn overwrite(buffer: CircularBuffer(t), item: t) -> CircularBuffer(t) {
  use <- result.lazy_unwrap(write(buffer, item))
  let CircularBuffer(capacity, queue) = buffer
  let assert Ok(#(_, queue)) = queue.pop_front(queue)
  CircularBuffer(capacity, queue.push_back(queue, item))
}
```

Yet another `use` here, this time with `result.lazy_unwrap`. `lazy_unwrap` is similar to map, but instead of running the callback for `Ok` values, it runs it if the input value was an `Error`. In this case, I first try to `write` the item normally, and if that fails, the rest of the function will run. In that case, I remove one item from the front of the queue, and add the new one at the back.

Finally, `clear` is nice and simple to finish off with:

```v
pub fn clear(buffer: CircularBuffer(t)) -> CircularBuffer(t) {
  CircularBuffer(..buffer, queue: queue.new())
}
```

The only new thing here is the `..buffer` record update syntax, which allows you to replace just some fields of a record type.

My complete Gleam solution can be found [here](https://exercism.org/tracks/gleam/exercises/circular-buffer/solutions/soxfox42). That was a pretty big one to cover, especially with my tangent about `use`, but I've really enjoyed playing around and learning more about Gleam through Exercism.

## Groovy

[Groovy](https://groovy-lang.org/) is a dynamic JVM-based language created by Apache. It is often used as a scripting language, sometimes embedded in other tools such as Gradle or Jenkins.

The implementation I went with in Groovy is pretty similar to my C one, but using object-oriented features without the manual memory management. The Circular Buffer task starts off with two predefined exceptions, as this is how error handling typically works in JVM-based languages.

```groovy
class EmptyBufferException extends Exception {}
class FullBufferException extends Exception {}
```

They are pretty self explanatory, and just get thrown from within the various `CircularBuffer` methods. The class definition contains the exact same fields as the C version, and again only supports `int`s as data:

```groovy
class CircularBuffer {
    int capacity
    int writeIndex
    int readIndex
    boolean full
    int[] buffer
}
```

The constructor and `clear()` function should also look very familiar:

```groovy
CircularBuffer(int capacity) {
    this.capacity = capacity
    buffer = new int[capacity]
    clear()
}

void clear() {
    writeIndex = 0
    readIndex = 0
    full = false
}
```

`read` is pretty close to the C version. The differences are that it throws an exception instead of using `errno` and uses a temporary variable rather than an output pointer:

```groovy
int read() {
    if (readIndex == writeIndex && !full) throw new EmptyBufferException()
    int value = buffer[readIndex]
    readIndex = (readIndex + 1) % capacity
    full = false
    value
}
```

For `write` and `overwrite`, I wrote separate implementations, rather than using the same `write_impl` idea:

```groovy
void write(int item) {
    if (full) throw new FullBufferException()
    buffer[writeIndex] = item
    writeIndex = (writeIndex + 1) % capacity
    full = writeIndex == readIndex
}

void overwrite(int item) {
    buffer[writeIndex] = item
    if (readIndex == writeIndex) readIndex = (readIndex + 1) % capacity
    writeIndex = (writeIndex + 1) % capacity
    full = writeIndex == readIndex
}
```

Again though, the logic mostly follows the C version. Check if the buffer is full, write an item into it, move the write index along, and the read index too if necessary, and update `full`.

The full code is [here](https://exercism.org/tracks/groovy/exercises/circular-buffer/solutions/soxfox42), and we have just one more language to go.

## Scala

[Scala](https://www.scala-lang.org/) is *another* JVM-based language, although it is now able to target JavaScript and native executables, which makes it a bit more flexible. There are two major versions of Scala currently in use, Scala 2 and Scala 3. Scala 3 has many syntactic changes, though it is largely backwards compatible and provides migration tools. (Why does this sound so similar to Python's story?) Currently, Exercism uses Scala 2 in the Scala track, so I'll be using the more traditional curly-brace syntax supported in that version.

Because Scala isn't all that different from Groovy, I'll make things a bit more interesting by trying a different implementation of a circular buffer. Previously, I've used two array indices to keep track of the used part of the buffer, but this time I'll use just one, plus a variable to track the *size* of the buffer -- how many items are currently in it, not the overall capacity.

This also allows me to get rid of the `full` variable, as there's no longer any ambiguity between full and empty:

```scala
class CircularBuffer(val capacity: Int) {
  var pos = 0
  var size = 0
  var buf = new Array[Int](capacity)
}
```

Scala doesn't require an explicit constructor here, instead we can just define the instance variables and their default values, which is a nice convenience. `capacity` is also automatically made into an instance variable because it was defined with `val` in the constructor arguments.

```scala
def clear() = {
  size = 0
}
```

I think this might be the single simplest snippet of code I've written so far for any of these #48in24 posts, and to be honest, I don't think I can beat it! I don't need to worry about `pos` here, because we can start writing anywhere in the buffer -- that's the whole point of circular buffers.

As for the rest of the functions, they still follow the previous model pretty closely:

```scala
def write(value: Int) = {
  if (size == capacity) throw new FullBufferException()
  val index = (pos + size) % capacity
  buf(index) = value
  size += 1
}

def read(): Int = {
  if (size == 0) throw new EmptyBufferException()
  val item = buf(pos)
  pos = (pos + 1) % capacity
  size -= 1
  item
}

def overwrite(value: Int) = {
  val index = (pos + size) % capacity
  buf(index) = value
  if (size == capacity) pos = (pos + 1) % capacity
  else size += 1
}
```

Here are the differences I'd like to highlight:

- I can't get the write position directly any more, and I need to calculate it from `pos` and `size`, taking into account the wrap-around behaviour.
- `read` has to update both `size` and `pos`, for a similar reason - there's no way to keep the write position fixed now, as it depends on both.
- There's no need to manage `full`, since I just check `size == 0` and `size == capacity`.

Overall, while it doesn't reduce the size of the code by much, I think I prefer this position + size approach to the two positions one. It removes an annoying edge case, and generally feels a little easier to understand. The full solution code is [here](https://exercism.org/tracks/scala/exercises/circular-buffer/solutions/soxfox42) if you want to check it out.

# Final Thoughts

I'm happy that Mechanical March has started, and I get to use languages with static typing, more manual control over behaviour, and higher performance, as those are my preferred languages! C is basic but reliable and a nice language to start off the month with. Groovy and Scala both seem like nicer JVM languages than Java itself, and while I don't usually rely heavily on OOP, it's a nice fit for custom data structures. It's a bit of a shame that none of the featured languages this week used generics in their Circular Buffer task implementation, as that makes such a structure infinitely more useful.

I'm glad I got to revisit Gleam so soon, now that I have built up my skills a little more through Exercism. It's definitely a language I'll have to keep an eye on, because it's already introduced some excellent new features like `use`, and I'm excited to see where the developers take it now that it's reached 1.0!

As always, feel free to send feedback to {{< feedback >}}, and I hope you were able to get something out of this (rather long) journey through circular buffers!

