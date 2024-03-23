+++
title = "#48in24 – Week 9: Parallel Letter Frequency"
date = 2024-03-23T11:06:15+11:00
summary = "Counting letters, but fast! (and hopefully without race conditions...) Featured Languages: Go, Java, Elixir."
tags = ["48in24"]
card_image = "/images/cards/48in24-week9.png"
+++

If you speak to a developer about multi-threading, there's a good chance they'll simply curl up into a ball to hide from the danger until you leave. (Source: I made it up.) Multi-threading and parallel processing are notoriously easy to screw up, leading to all manner of weird, hard to solve bugs.

Luckily, [Parallel Letter Frequency](https://exercism.org/exercises/parallel-letter-frequency) isn't *too* scary, as the task lends itself pretty well to multiple independent processes counting letters in separate strings. In this task, the input is given as a list of strings, and the aim is to count the total number of times each letter appears across all strings.

Basically, the strategy is to take all of the strings in the list and split them across multiple threads, each of which will produce a hashmap of the frequencies of letters in a particular string. Then, gather up all of these frequency maps and merge them together in the main thread - summing counts of letters that appear in multiple hashmaps.

# Languages

## Go

The first featured language is [Go](https://go.dev/), a language built by Google that is designed to excel at *concurrent programming*. What a useful coincidence (not a coincidence)! Go hides the idea of actual threads from the programmer, and throws away the traditional way of communicating between threads - shared memory. Instead, you write "goroutines", which can implicitly yield control to other goroutines and don't take as many resources as traditional threads, and pass data around through "channels", all without needing to manage the lower level details of threads.

```go
package letter

// FreqMap records the frequency of each rune in a given text.
type FreqMap map[rune]int

// Frequency counts the frequency of each rune in a given text and returns this
// data as a FreqMap.
func Frequency(text string) FreqMap {
	frequencies := FreqMap{}
	for _, r := range text {
		frequencies[r]++
	}
	return frequencies
}

// ConcurrentFrequency counts the frequency of each rune in the given strings,
// by making use of concurrency.
func ConcurrentFrequency(texts []string) FreqMap {
    parts := make(chan FreqMap)
    for _, t := range texts {
        t := t
        go func() {
            parts <- Frequency(t)
        }()
    }

    frequencies := FreqMap{}
    for range texts {
        part := <-parts
        for r, f := range part {
            frequencies[r] += f
        }
    }

    return frequencies
}
```

My Go solution follows the structure of the template code Exercism provides here, using a function `Frequency` to count the frequency of letters in a single string. The Go version of this task doesn't require any special handling of the characters pulled from the string, and just expects a raw map of runes (code points) to counts, so that makes `Frequency` very simple. It makes use of Go's zero value feature, where using a map key that doesn't exist (among other things) just adds a default value of 0 into the map.

The real solution happens in `ConcurrentFrequency`, which has to use `Frequency` to count characters in all items of `texts`, without just doing it in sequence. Go makes this pretty easy though, using goroutines and channels like I mentioned before.

First, it creates a channel to collect the results from, and starts a goroutine for each piece of text. The `t := t` line is necessary due to the use of a closure as a goroutine capturing the `t` variable from the loop (this is [fixed](https://go.dev/blog/loopvar-preview) in Go 1.22, but only if you specify that version in go.mod, and Exercism doesn't currently support this version). Copying the value like this ensures every closure has its own copy of `t`. Every goroutine launched will simply send the result of `Frequency` on one string to the channel.

Once all the goroutines are running (we don't know or care exactly how they are scheduled, but they have been started), we can start pulling results from the channel. `for range texts` will run its body once for every string in texts. The results it receives from `parts` could come in a completely different order, but all that matters is that the right *number* of parts are collected. Each part is merged into a result map, and that map is returned.

This exercise started pretty simple in Go, because thinking about concurrent code at this high level is much easier than working directly with threading code, plus Go's zero value handling makes the code very neat. The next language won't be quite as friendly to work with.

## Java

[Java](https://www.java.com/en/) is a language that runs on 3 billion devices according to its installer -- actually, I don't know for sure if it still says that, it's been a long time since I installed Java using anything other than a package manager.

Looking at some community solutions after completing this one, I noticed that in addition to the many solutions that don't actually use threads (seriously?), there are ways to do this using more modern Java features, but the Java documentation was so hard to work with the first time that I didn't bother trying to build a solution with such tools. Instead, this is a pretty low-level thread based approach that manually creates one thread for each string. It's pretty similar overall to my Go solution, but with less helpful features to make things neat.

```java
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

class ParallelLetterFrequency {
    private String[] texts;
    private List<Map<Character, Integer>> frequencies;

    ParallelLetterFrequency(String[] texts) {
        this.texts = texts;
        frequencies = new ArrayList<>();
    }

    Map<Character, Integer> countLetters() {
        List<Thread> threads = new ArrayList<>();
        for (int i = 0; i < texts.length; i++) {
            final int index = i;
            frequencies.add(new HashMap<>());
            final Map<Character, Integer> map = frequencies.get(i);
            Thread thread = new Thread(() -> {
                for (char c : texts[index].toCharArray()) {
                    if (!Character.isLetter(c)) continue;
                    char l = Character.toLowerCase(c);
                    if (map.get(l) == null) {
                        map.put(l, 1);
                    } else {
                        map.put(l, map.get(l) + 1);
                    }
                }
            });
            thread.start();
            threads.add(thread);
        }

        Map<Character, Integer> total = new HashMap<>();
        for (int i = 0; i < threads.size(); i++) {
            try {
                threads.get(i).join();
            } catch (InterruptedException e) {
                System.err.println("Thread interrupted");
                return new HashMap<>();
            }

            Map<Character, Integer> part = frequencies.get(i);
            for (Character key : part.keySet()) {
                if (total.get(key) == null) {
                    total.put(key, part.get(key));
                } else {
                    total.put(key, total.get(key) + part.get(key));
                }
            }
        }
        return total;
    }
}
```

The expected code structure here has the strings passed in via the constructor of `ParallelLetterFrequency`, and the computation performed by a `countLetters` method. In the constructor, I also set up an `ArrayList` to track the resulting partial frequency maps, since there's no convenient channels like in Go, and threads can't return values like in some other languages.

`countLetters` starts by iterating over all the strings, setting up result hashmaps for them, and starting and storing a thread for each one.

```java
List<Thread> threads = new ArrayList<>();
for (int i = 0; i < texts.length; i++) {
    final int index = i;
    frequencies.add(new HashMap<>());
    final Map<Character, Integer> map = frequencies.get(i);
    Thread thread = new Thread(() -> { /* ... */ });
    thread.start();
    threads.add(thread);
}
```

That `<>` syntax is a detail I found pretty annoying. When these collections were first introduced Java didn't have generics, and the non-generic version of these classes have stuck around to this day. You need to construct all generic collections with `<>` to indicate that you want the generic version (even though they are pretty much the same internally).

The code that each thread runs is provided here as a lambda:

```java
for (char c : texts[index].toCharArray()) {
    if (!Character.isLetter(c)) continue;
    char l = Character.toLowerCase(c);
    if (map.get(l) == null) {
        map.put(l, 1);
    } else {
        map.put(l, map.get(l) + 1);
    }
}
```

There's some extra code required to deal with excluding non-letters and storing everything in lowercase, which wasn't required by the Go task, and the hashmap access is also more complex as I have to manually detect if an item is not present. Once a thread finishes running this code, `frequencies[i]` should contain the partial frequency map for that thread's string.

By the way, that `final int index = i;`? It's just the Java version of Go's `t := t`. Loops and lambdas are a pain everywhere.

At this point, the program should have one thread running for each piece of text, with all the thread join handles stored in `threads`, so the last step is to wait for them to finish, and combine the results:

```java
Map<Character, Integer> total = new HashMap<>();
for (int i = 0; i < threads.size(); i++) {
    try {
        threads.get(i).join();
    } catch (InterruptedException e) {
        System.err.println("Thread interrupted");
        return new HashMap<>();
    }

    Map<Character, Integer> part = frequencies.get(i);
    for (Character key : part.keySet()) {
        if (total.get(key) == null) {
            total.put(key, part.get(key));
        } else {
            total.put(key, total.get(key) + part.get(key));
        }
    }
}
return total;
```

Java checks the exceptions that a function might throw, and complains if any aren't declared, which means that `countLetters` needs to handle the possibility of `InterruptedException`s from the threads. I chose to simply fall back to an empty hash map in that case. For each thread, I `join` it, which waits for the thread to run to completion, then merge its part of `frequencies` into the `total` map. Again, this takes more code than the equivalent Go.

You probably guessed already that I'm not a huge fan of Java, but I feel like I could overlook a lot of the issues here if I could at least get higher quality official documentation. That was the biggest problem I ran into while building this solution, and I feel like it would make a huge difference.

## Elixir

[Elixir](https://elixir-lang.org/) is a language that targets BEAM, the Erlang VM. Because of that, it inherits excellent support for lightweight threads, similar to Go's goroutines, so it's another really user-friendly language when dealing with concurrency. The Elixir version of the task has an additional requirement -- a worker count will be passed in, and the solution should not use more than that many threads/BEAM processes at once.

```elixir
defmodule Frequency do
  @spec frequency(String.t()) :: map
  defp frequency(text) do
    text
    |> String.graphemes()
    |> Enum.reduce(%{}, fn g, map ->
      if String.match?(g, ~r/[[:alpha:]]/) do
        Map.update(map, String.downcase(g), 1, fn count -> count + 1 end)
      else
        map
      end
    end)
  end

  @doc """
  Count letter frequency in parallel.

  Returns a map of characters to frequencies.

  The number of worker processes to use can be set with 'workers'.
  """
  @spec frequency([String.t()], pos_integer) :: map
  def frequency(texts, workers) do
    texts
    |> Task.async_stream(&frequency/1, max_concurrency: workers)
    |> Enum.reduce(%{}, fn {:ok, f}, acc -> Map.merge(acc, f, fn _, a, b -> a + b end) end)
  end
end
```

Just like in Go, I'm using one function that counts characters in a string, with just one thread, which is used by the main multi-threaded function. That's about where the similarities stop though. The two functions are both named `frequency`, and are differentiated by the number of arguments they take -- Elixir doesn't use types for overloading, just arities.

```elixir
text
|> String.graphemes()
|> Enum.reduce(%{}, fn g, map ->
 if String.match?(g, ~r/[[:alpha:]]/) do
    Map.update(map, String.downcase(g), 1, fn count -> count + 1 end)
  else
    map
  end
end)
```

The single-threaded frequency count function splits the string into [graphemes]({{< ref "blog/48in24-week2/#graphemes" >}}), and then uses `Enum.reduce` to [fold]({{< ref "blog/48in24-week6/#list-folding" >}}) over the sequence of graphemes. For each grapheme, if it is a letter (determined by a regex), the accumulated map is updated to increase the count of that letter.

```elixir
texts
|> Task.async_stream(&frequency/1, max_concurrency: workers)
|> Enum.reduce(%{}, fn {:ok, f}, acc -> Map.merge(acc, f, fn _, a, b -> a + b end) end)
```

This is where Elixir's excellent support for concurrency comes into play. Instead of manually managing the list of strings, I just call `async_stream` to run `frequency/1` (the one-argument form of `frequency`) on each of them. It even supports a `max_concurrency` keyword argument to handle the maximum workers option. The result of `async_stream` is a list of frequency maps, which can be merged with another `Enum.reduce`. `Map.merge` is very useful here, as it allows merging two maps with a function to calculate the result if both maps have the same key.

While there are downsides to having a large standard library like Elixir, it certainly made this exercise very simple.

# Final Thoughts

Of the three languages, Elixir was the easiest to handle concurrent processing in, because the standard library came with the necessary tools built in.

Next was Go, which is a language designed for simple concurrency, but has an intentionally smaller library, so couldn't deal with quite as much automatically.

Finally, Java. It does seem that Java has some similar tools to Elixir if you dig into the documentation enough, but the scale and quality of the documentation meant that just wasn't a great option.
