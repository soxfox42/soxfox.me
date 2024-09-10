+++
title = "Building a Compiler Backend (Part 2: Compiler)"
date = 2024-09-10T10:00:00+10:00
summary = "The story of how I became a compiler developer, I guess. This time, I'm digging into how the Callisto compiler works in general, as background for what I worked on next."
tags = ["Programming Languages", "Callisto"]
+++

Before I can start writing about how I added ARM support to Callisto, there's one question to answer...

# What is a Compiler?

No, no, that's not it. There are plenty of excellent articles that explore compilers on a more abstract level and that need to come up with formal definitions before they can begin, and this is not one of them. A compiler is a program that turns source code into another program, and I don't need to be any more precise than that. What I really care about is...

# How Does a Compiler Work?

There's no single answer to this, since you can build a compiler any number of ways. For instance: Forth, another stack based language, is a language that compiles code by reading one word at a time, looking up that word's address in memory, and writing that address into the current definition (this is a little simplified, but gets the idea across). This is not the same method that Callisto uses at all.

Most compilers, however, work in largely the same way, and Callisto is no exception. Typically, the following steps are involved:

1. **Lexing:** The source code given to the compiler is just a plain text file, so we need to start making sense of it. The first step is to take this text and split it into "tokens" of one or more characters -- numbers, strings, identifiers, special characters -- any span of text with a specific meaning.
2. **Parsing:** The tokens produced by the lexer are still just stored as a flat list, but most programming languages have more structure than that, like loops, conditionals, and functions. The parser takes the tokens from the lexer, and identifies these structures, producing a tree structure known as an abstract syntax tree (AST).
3. **Intermediate Representation:** Many compilers convert the code into one or more additional formats along the way, which makes more advanced optimisation passes easier, and simplifies the process of supporting additional architectures.
4. **Optimisation:** Just generating output machine code that directly maps to the structure of the source code often produces inefficient programs, so most compilers will perform some optimisation passes before getting to the final output. This can include simple things like [constant folding](https://en.wikipedia.org/wiki/Constant_folding), as well as more complex optimisations that require [control flow analysis](https://en.wikipedia.org/wiki/Control-flow_analysis).
5. **Code Generation:** Finally, the compiler needs to produce a final output containing machine code for the target computer (or in some cases, including Callisto, assembly code that can be assembled into such machine code).

Callisto's compiler doesn't use an intermediate representation, instead opting to directly compile from the AST to assembly (not machine code). Its optimisation pass is also quite simple for the time being, with only the ability to remove unused functions.

# Callisto's Structure

So how does all of this look in Callisto? The compiler is reasonably small and understandable, so I'll break this down file by file. I'm referencing version b0.9.0 of [callisto-lang/compiler](https://github.com/callisto-lang/compiler/tree/b0.9.0), so it's possible that some things will have changed since then. Callisto's compiler is written in [D](https://dlang.org/), which should look pretty familiar if you've worked with pretty much any C-style language.

Callisto is not my project, almost everything in the compiler was written by [yeti](https://github.com/yeti0904). I'll do my best to explain how it works here, but I'm certainly not claiming credit for any of this, nor am I guaranteeing that everything will be 100% correct.

## app.d

Everything starts here, in the `main` function. A large portion of the function deals with the various command line options that can be passed into the compiler. Most of these are pretty simple, just setting some variables for later use, but there are a few options that are particularly interesting.

Here is the code that reads the `-b` option:

```d
case "-b": {
    ++ i;
    if (i >= args.length) {
        stderr.writeln("-b requires BACKEND parameter");
        return 1;
    }

    switch (args[i]) {
        case "rm86": {
            backend = new BackendRM86();
            break;
        }
        case "x86_64": {
            backend = new BackendX86_64();
            break;
        }
        // ...
        default: {
            stderr.writefln("Unknown backend '%s'", args[i]);
            return 1;
        }
    }
    break;
}
```

`-b` is used to select one of a handful of backends. I'll explain more about what the backends do in a bit, but you can already see that there is one for each CPU architecture Callisto can target. If no backend is selected, the default is to use one that matches the architecture the compiler is running on.

Here's the `-os` option:

```d
case "-os": {
    ++ i;
    if (i >= args.length) {
        stderr.writeln("-os expects OS argument");
        return 1;
    }

    os = args[i];
    break;
}
```

This one does just set `os` (representing the target operating system) to whatever value was passed in, but there is also code that runs after the argument parsing to handle the case where no OS was set:

```d
if (os == "DEFAULT") {
    os = backend.defaultOS;
}
```

This default can be set by the backend, and for both x86_64 and arm64, the behaviour is to match the host OS.

The rest of the `main` function takes care of running the various compilation steps as required. Here is a simplified version of that code:

```d
// Write a header directly to the output assembly
backend.output = header ~ '\n';

// Lex and parse the input file
auto nodes = ParseFile(file);

// Process includes and version blocks
preproc.includeDirs = includeDirs;
preproc.versions    = versions;
nodes = preproc.Run(nodes);

// Run the optimiser (dead code elimination)
if (optimise) {
    auto codeRemover = new CodeRemover();
    codeRemover.Run(nodes);
    nodes = codeRemover.res;
}

// Compile the program
compiler.Compile(nodes);

// Run final commands (assemble and link)
if (runFinal) {
    compiler.outFile   = outFile;
    auto finalCommands = compiler.backend.FinalCommands();

    foreach (cmd ; finalCommands) {
        executeShell(cmd);
    }
}
```

The header output code is mostly only used for the [Uxn](https://100r.co/site/uxn.html) backend, to create some predefined labels for the system devices, but works across all backends to add extra assembly to the top of the output file.

Parsing the file here includes both the lexing and parsing steps, resulting in an AST that gets stored in `nodes`.

The preprocessor is a step that I didn't mention in my initial compiler outline, and exists to handle `include` statements that expand to the contents of other Callisto source files, as well as `version` blocks that allow for conditional compilation based on platform or supported features.

The next two steps -- optimisation and compilation -- are pretty straight forward, just calling the relevant functions to do the work. Finally, if configured to do so (which it is by default), the compiler will run additional commands as specified by the selected backend. These typically involve assembling the generated code, then linking that assembled output into an executable program, using standard assembler and linker tools from the host system.

## Lightning Round

Before I get to the main compiler steps, here are a few of the simplest source files and an explanation of their purpose:

- **error.d:** Contains a struct for tracking locations of code in the source files, and functions for printing nice looking error messages.
- **language.d:** Specifies reserved words in the Callisto language, and contains the `ParseFile` function which reads a file, and calls the lexer followed by the parser on its contents.
- **util.d:** As the name suggests, contains a few utility functions, most notably `Sanitise`, which replaces special characters in function names with alphabetic representations (e.g. `a@` becomes `a__at__`).

## lexer.d

Now we're getting to the real stuff that makes the compiler work. The first step is to break the source file up into tokens, and that's what the `Lexer` class is responsible for. It works as a sort of state machine, keeping track of whether or not it's reading a string, and what characters make up the current token so far.

Callisto's token grammar is actually really simple, and mostly consists of runs of characters broken by whitespace. The lexer handles this by pushing each character it reads into a `reading` string, and then pushing a `Token` created from the `reading` string into the `tokens` array every time it encounters whitespace. Some characters have extra behaviour:

- **\[, \], and &** all need to push themselves as tokens. \] and & also push whatever was in the `reading` buffer.
- **# and (** start comments, so the lexer skips all content after them until the next line (for #) or the matching closing parenthesis.
- **'** reads the next character (or escape sequence) and creates an integer token from its ASCII value.
- **"** enters string mode by setting `inString`. While in this mode, every character is just pushed to `reading`. The exceptions are `\\`, which uses the next character as an escape code (for handling strings like `"\n"`), and `"`, which pushes a string token with the content from `reading`.

After this step, the code is now represented as an array of `Token` values, which each have a type, contents, and position information so that errors can be printed referencing the correct part of the code.

## parser.d

The next step is to take this flat array of tokens and convert it to the tree-based AST. The algorithm that Callisto uses to do this is known as [recursive descent parsing](https://en.wikipedia.org/wiki/Recursive_descent_parser). This essentially involves starting at the top level language constructs -- in Callisto's case this is just a list of statements -- and looking at the next few tokens to determine what type of AST node to parse. The recursive part of recursive descent comes from the fact that the functions that do the parsing may call themselves, directly or indirectly, resulting in deeply nested syntax trees.

As an example, the following Callisto code requires recursion to parse:

```text
if x 4 > then
  if x 8 < then
    "more than 4 and less than 8" printstr
  end
end
```

The `if` statements can each contain any number of other statements, even including further `if` statements, so `ParseIf` will eventually need to call itself again (indirectly, through `ParseStatement`).

This recursion can also be used for expression parsing in some languages, but as a stack based language Callisto has no need for that, and expressions are just a list of statements like any other code.

To give a better understanding of what goes in in this parsing step, here are a few of the parsing methods:

```d
Node ParseStatement() {
    switch (tokens[i].type) {
        case TokenType.Integer: {
            return new IntegerNode(GetError(), parse!long(tokens[i].contents));
        }
        case TokenType.Identifier: {
            switch (tokens[i].contents) {
                case "func":       return ParseFuncDef(false);
                case "inline":     return ParseFuncDef(true);
                case "include":    return ParseInclude();
                case "asm":        return ParseAsm();
                // ... (more statement types)
                default: return new WordNode(GetError(), tokens[i].contents);
            }
        }
        case TokenType.LSquare:   return ParseArray();
        case TokenType.String:    return ParseString();
        case TokenType.Ampersand: return ParseAddr();
        default: {
            Error("Unexpected %s", tokens[i].type);
        }
    }

    assert(0);
}
```

`ParseStatement` is the starting point for parsing basically every type of syntax node in Callisto. Integer tokens are directly converted to integer nodes, tokens that don't correspond to built in keywords are converted to word nodes, and anything else is handed off to the associated parse function.

A simple parse function such as `ParseInclude` (which parses includes that look like `include "std/io.cal"`) looks like this, creating an `IncludeNode` from the string token after `include`:

```d
Node ParseInclude() {
    auto ret = new IncludeNode(GetError());
    parsing  = NodeType.Include;

    Next();
    Expect(TokenType.String);

    ret.path = tokens[i].contents;
    return ret;
}
```

More complex functions like `ParseWhile` need to call `ParseStatement` until they see end token like `do` or `end` to fill out the body of the node:

```d
Node ParseWhile() {
    auto ret = new WhileNode(GetError());
    parsing  = NodeType.While;
    Next();

    while (true) {
        if (
            (tokens[i].type == TokenType.Identifier) &&
            (tokens[i].contents == "do")
        ) {
            break;
        }

        ret.condition ~= ParseStatement();
        Next();
        parsing = NodeType.While;
    }

    Next();

    while (true) {
        parsing = NodeType.While;
        if (
            (tokens[i].type == TokenType.Identifier) &&
            (tokens[i].contents == "end")
        ) {
            break;
        }

        ret.doWhile ~= ParseStatement();
        Next();
        parsing  = NodeType.While;
    }

    return ret;
}
```

Once all the code in the file has been parsed like this, we have an AST that accurately represents all of the structured syntax elements, which is an excellent point to start compiling from! ...almost.

## preprocessor.d

So far, the AST only represents the content of a single source file, and it also has no way to conditionally compile some code. While it would be possible to work within these restrictions, they aren't great, and the preprocessor exists to solve them.

The preprocessor looks for two types of node, recursively calling itself on the bodies of any other nodes:

### Includes

Whenever it encounters an `IncludeNode`, the preprocessor replaces it with the contents of the specified file. It first has to run the file through the parser just like the root file was in order to produce an AST, and it also calls itself on those ASTs so that included files are preprocessed correctly.

### Versions

Callisto's [version system](https://callisto.mesyeti.uk/docs/language/versions/) enables conditional compilation of code for specific platforms (or based on custom versions set by the user). This is handled in the preprocessor, and when it reaches one of these `VersionNode`s, it checks if the corresponding version is enabled, and simply omits it from the preprocessor result if not.

The output of the preprocessor is largely the same as the previous stage, but with `include`s replaced with content from other files, and `version` blocks either converted to plain statements or removed entirely. There's still one step left before we get to actually compiling nodes though.

## codeRemover.d

This is Callisto's one optimisation pass currently, and all it does is remove function definitions that are never called.

It works in two stages:

1. Find all the functions that are ever referenced in the code.
2. Create a copy of the AST, but skip over any functions that were not referenced.

The first step is a little more complex than it sounds, because naively recursing into every block body like the preprocessor did won't work perfectly here. Take the following code:

```text
func f1 begin 42 end
func f2 begin f1 end
```

`f2` is never called, so it should be eliminated. `f1` appears to be called, but only by another function which will be eliminated, so it should also not be considered as used.

`CodeRemover` deals with this by only looking inside function definitions if they themselves are used:

```d
case NodeType.Word: {
    auto node = cast(WordNode) inode;

    usedFunctions ~= node.name;

    if (node.name !in functions) {
        continue;
    }

    if (funcStack.canFind(node.name)) {
        continue;
    }

    funcStack ~= node.name;
    FindFunctions(functions[node.name]);
    funcStack = funcStack[0 .. $ - 1];
    break;
}
```

It also has to maintain a stack of functions to avoid entering an infinite loop when it encounters recursive calls.

Now, with the optional optimisation pass done, the AST is ready to be compiled!

## compiler.d

Finally, we've reached the code that actually converts Callisto ASTs to assembly! [Or have we?](https://www.youtube.com/watch?v=IfX1hJS0iGM&t=115s)

No. As it turns out, `Compiler` is a pretty boring class, mostly just looking at each node in the AST, and calling a function in another class according to the type of node. What class? `CompilerBackend`, an abstract class containing methods to compile each type of syntax node (and a few other methods for configuration).

This is what those backends selected by the argument parser are for. Each one specifies how to generate assembly for its target platform, exposed as a collection of methods starting with `Compile` for the compiler to call.

The backend implementations live in the `backends` directory, and it's these that I've worked the most with while adding ARM64 and better macOS support to Callisto. I'll dive more into how a backend works when I discuss my ARM64 one, but for now, here are some samples from the x86_64 backend.

Some nodes, like integers are very simple. Here, the integer is just placed on the data stack (addressed by `r15` in x86_64 Callisto). Code is generated by adding lines to `output`, which will all be written to the assembly file at the end of compilation.
```d
override void CompileInteger(IntegerNode node) {
    if (node.value > 0xFFFF) {
        output ~= format("mov r14, %d\n", node.value);
        output ~= "mov [r15], r14\n";
    }
    else {
        output ~= format("mov qword [r15], %d\n", node.value);
    }
    output ~= "add r15, 8\n";
}
```

Nodes with bodies need to compile those bodies in the right locations by calling back out to the compiler (stored as a member of `CompilerBackend`). This function also shows how labels can be generated and used in the assembly output:

```d
override void CompileIf(IfNode node) {
    ++ blockCounter;
    auto blockNum = blockCounter;
    uint condCounter;

    foreach (i, ref condition ; node.condition) {
        foreach (ref inode ; condition) {
            compiler.CompileNode(inode);
        }

        output ~= "sub r15, 8\n";
        output ~= "mov rax, [r15]\n";
        output ~= "cmp rax, 0\n";
        output ~= format("je __if_%d_%d\n", blockNum, condCounter + 1);

        foreach (ref inode ; node.doIf[i]) {
            compiler.CompileNode(inode);
        }

        output ~= format("jmp __if_%d_end\n", blockNum);

        ++ condCounter;
        output ~= format("__if_%d_%d:\n", blockNum, condCounter);
    }

    if (node.hasElse) {
        foreach (ref inode ; node.doElse) {
            compiler.CompileNode(inode);
        }
    }

    output ~= format("__if_%d_end:\n", blockNum);
}
```

(This `CompileIf` is simpler than the real one, I removed variable scope handling code.)

# Wrapping Up

Hopefully that was a decent overview of how the Callisto compiler is designed, because soon I'll be diving into the process of creating a backend for Callisto. Before that, I'll write a (probably shorter, and less code-heavy) post about Callisto's standard library, because there are some relevant pieces of code in there, and it will also be a good example of what Callisto code really looks like. See you next time!
