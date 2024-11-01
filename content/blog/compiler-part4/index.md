+++
title = "Building a Compiler Backend (Part 4: ARM)"
date = 2024-11-01T10:00:00+10:00
summary = "The story of how I became a compiler developer, I guess. It's time to add a backend for a new CPU -- by copying an existing one."
tags = ["Programming Languages", "Callisto"]
+++

Hey hey, I'm back! Been a while since I posted, but I'm ready to get back into things! Callisto has been through some big changes while this series was on hold, but nothing that affects backends too significantly. The main developer, yeti, has been hinting at some possible changes that do affect backends though, so I guess I should try to finish up this series before that.

So far in this series, we've looked at [what Callisto is]({{< ref "compiler-part1" >}}), and how its [compiler]({{< ref "compiler-part2" >}}) and [standard library]({{< ref "compiler-part3" >}}) are designed. With this background, it's time to cover how I added ARM64 support to Callisto.

# ARM Assembly Crash Course

I won't go through everything there is to know about the ARM64 architecture here, but I do want to cover most of the features that I use. That way, this post should hopefully be somewhat understandable, even if you don't have experience with ARM64.

## Registers

Most of the ARM64 registers are general purpose, and don't have any special behaviour, at least when it comes to assembly instructions. There is however a standard calling convention which defines which registers can be overwritten when calling functions, and this is important to keep in mind when calling external functions from Callisto.

Registers   | Usage
---------   | -----
x0 - x7     | Arguments for external functions
x8          | Indirect return address (unused here)
x9 - x15    | Local variables, functions may overwrite
x16 - x18   | Special purpose (unused here)
x19 - x28   | Functions must not overwrite
x29         | Frame pointer (unused here)
x30 (or lr) | Link register, contains the return address when calling a function
sp          | System stack pointer
xzr         | Always zero

Accessing these registers as 32-bit values is done by swapping the `x` for a `w`

## Instructions

Here are the main instructions that are used throughout the ARM64 backend:

Instruction      | Description
-----------      | -----------
`mov xa, xb`     | Sets register `xa` to the contents of register `xb`.
`mov xa, value`  | Sets `xa` to a given 16-bit value.
`ldr xa, =value` | Sets `xa` to a given 64-bit value (by loading from memory).
`ldr xa, [xb]`   | Load `xa` from the address stored in `xb`.
`str xa, [xb]`   | Stores the value in `xa` to the address in `xb`.
`add xa, xb, xc` | Adds `xb` and `xc`, storing the result in `xc`.
`sub xa, xb, xc` | Likewise for subtraction.
`b label`        | Jumps to the label `label`.
`beq label`      | Jumps to `label` if the previous comparison was equal.
`bne label`      | Jumps to `label` if the previous comparison was not equal.
`bl label`       | Jumps to `label`, saving the return address to `lr`.
`ret`            | Returns to the address in `lr`.

There are more that will pop up throughout, but these make up the majority of the assembly output.

## Stacks

Callisto is a stack-oriented language, so it will be useful to understand how to work with stacks. Some architectures have dedicated `push` and `pop` instructions that always operate on a hardware stack (including 32-bit ARM), but this is not the case on ARM64.

Instead, stack operations should make use of additional features in the `ldr` and `str` instructions. These are the pre-indexed and post-indexed modes. These modes allow you to use a single `ldr` or `str` instruction to both write a value to memory, and update the value in the register used as a memory address.

Here are some examples of how they look:

```asm
; Store x0 to the address in x1, then add 8 to x1.
str x0, [x1], #8

; Add 8 to x3, then store x2 to the new address in x3.
str x2, [x3, #8]

; Subtract 8 from x5, then load x4 from the new address in x5.
ldr x4, [x5, #-8]

; Add 16 to sp, then load x8 from the new address.
ldr x8, [sp, #16]
```

The advantage of these instructions is that you can choose to treat any register as a stack pointer, not just the special `sp` register.

## Picking Registers

Callisto requires *two* stacks in each backend. One of these is used as the main working stack, where function arguments are taken from and return values are placed, and the other is used to store return addresses and local variables. In the x86_64 backend, `r15` is used as a pointer for the working stack, while the dedicated `rsp` register is used for the return/local stack.

I'll mirror this in ARM, and use the first callee-saved register, `x19` to index the working stack, `sp` for the returns and locals, and `x9`-`x15` can be temporary registers, though I won't use them all.

This should work well, as `x19` will never be affected even by calls to C functions, thanks to its callee-saved nature in the system calling convention, and `sp` was designed for exactly this purpose -- that's what C code will do too, so I shouldn't run into any issues, right? Right?

# The Backend

The first step to supporting a new CPU architecture in Callisto is to add a new backend. This involves creating a new subclass of `CompilerBackend`, and adding a new option to the `-b` flag in **app.d** to create this subclass:

```d
// backends/arm64.d

import callisto.compiler;

class BackendARM64 : CompilerBackend {
}

// app.d

// ...
case "arm64": {
    backend = new BackendARM64();
    break;
}
// ...
```

The backend class needs a handful of methods to define basic properties of the target. Some are very straightforward, such as `MaxInt`, which defines the largest value supported by the target, and `DefaultHeader`, which adds output to the start of the assembly (which we don't need here).

```d
override long MaxInt() => -1; // -1 will be 64 ones in binary.
override string DefaultHeader() => "";
```

Along with these, we have `GetVersions`, which returns an array of the supported features of this target. The complete list depends on the target OS -- when targeting bare-metal devices, for instance, there won't be any built in file support:

```d
override string[] GetVersions() {
    // CPU features
    string[] ret = ["arm64", "LittleEndian", "16Bit", "32Bit", "64Bit"];

    // OS features
    switch (os) {
        case "linux": {
            ret ~= ["Linux", "IO", "File", "Args", "Time", "Heap", "Exit"];
            break;
        }
        default: break;
    }

    return ret;
}
```

The last notable configuration function is `FinalCommands`, where we define the commands to run after generating the output assembly. There are four commands to run:

1. Move the generated code to a specific file: `mv output output.asm`
2. Assemble the code to an object file: `as output.asm -o output.o`
3. Link the object file into a binary: `ld output.o -o output`
4. Remove the temporary files: `rm output.asm output.o`

The file names have to be updated according to the actual output name given to the compiler, and some of these commands may end up with additional arguments in some cases. `FinalCommands` checks the compiler options and builds an array of strings containing the commands to run:

```d
override string[] FinalCommands() {
    bool isCross = executeShell("which aarch64-linux-gnu-as").status == 0;
    string assembler = isCross ? "aarch64-linux-gnu-as" : "as";
    string linker = isCross ? "aarch64-linux-gnu-ld" : "ld";

    string[] ret = [
        format("mv %s %s.asm", compiler.outFile, compiler.outFile),
    ];

    string assembleCommand =  format(
        "%s %s.asm -o %s.o", assembler, compiler.outFile, compiler.outFile,
    );

    if (useDebug) {
        assembleCommand ~= " -g";
    }

    ret ~= assembleCommand;

    string linkCommand = format(
        "%s %s.o -o %s", linker, compiler.outFile, compiler.outFile
    );

    foreach (ref lib ; link) {
        linkCommand ~= format(" -l%s", lib);
    }

    if (useLibc) {
        string[] possiblePaths = [
            "/usr/aarch64-linux-gnu/lib/crt1.o",
            "/usr/lib/crt1.o",
            "/usr/lib64/crt1.o",
        ];
        bool crt1;

        foreach (ref path ; possiblePaths) {
            if (path.exists) {
                crt1 = true;
                linkCommand ~= format(" %s", path);
                linkCommand ~= format(" %s/crti.o", path.dirName);
                linkCommand ~= format(" %s/crtn.o", path.dirName);
                break;
            }
        }

        if (!crt1) {
            stderr.writeln("WARNING: Failed to find crt1.o, program may behave incorrectly");
        }
    }

    ret ~= linkCommand;

    if (!keepAssembly) {
         ret ~= format("rm %s.asm %s.o", compiler.outFile, compiler.outFile);
    }

    return ret;
}
```

## A Map of the Program

The compilation process is driven by **compiler.d**, specifically in the `Compile` method.

```d
void Compile(Node[] nodes) {
    // ...
    backend.Init();
    
    // ...

    Node[] header;
    Node[] main;

    foreach (ref node ; nodes) {
        switch (node.type) {
            case NodeType.FuncDef:
            case NodeType.Include:
            case NodeType.Let:
            case NodeType.Enable:
            case NodeType.Requires:
            case NodeType.Struct:
            case NodeType.Const:
            case NodeType.Enum:
            case NodeType.Union:
            case NodeType.Alias:
            case NodeType.Extern:
            case NodeType.Implement: {
                header ~= node;
                break;
            }
            default: main ~= node;
        }
    }

    foreach (ref node ; header) {
        CompileNode(node);
    }

    backend.BeginMain();

    foreach (ref node ; main) {
        CompileNode(node);
    }

    backend.End();
}
```

There are five main sections to the compiler output:

1. `Init` generates the code that runs first when the program is executed.
2. Definitions (or the `header`) are compiled. This includes both function and type definitions.
3. `BeginMain` generates the setup code for the Callisto main function.
4. All code outside of the previously compiled definitions is compiled, making up the main function.
5. `End` generates the final code to be run at the end of the main function.

The first thing to look at here are the three special functions: `Init`, `BeginMain`, and `End`, as they are responsible for making the compiled program work at all.

## Getting Started

Everything starts somewhere, and when you're creating executables with `ld`, that somewhere is `_start`. In the Callisto compiler, the `Init` generates this `_start` function, with code to prepare the stack and perform other setup.

```d
override void Init() {
    // ...

    output ~= ".text\n";
    if (useLibc) {
        output ~= ".global main\n";
        output ~= "main:\n";
    } else {
        output ~= ".global _start\n";
        output ~= "_start:\n";
    }

    output ~= "bl __init\n";

    // allocate data stack
    output ~= "sub sp, sp, #4096\n";
    output ~= "mov x19, sp\n";

    // jump to main
    output ~= "b __calmain\n";
    
    // create functions for interop
    if (exportSymbols) {
        output ~= "
            .global cal_push
            cal_push:
                str x0, [x19], #8
                ret
            .global cal_pop
            cal_pop:
                ldr x0, [x19, #-8]!
                ret
        ";
    }
}
```

The generated assembly does a few things:

1. Calls a `__init` function, to be defined later.
2. Allocates 4096 bytes, or 512 Callisto "cells" (64-bit integers) of stack space for the Callisto working stack.
3. Jumps to the `__calmain` label, where execution of Callisto code begins.
4. If requested by the user, the init section also contains helper functions to push and pop values from the Callisto stack -- allowing integration with another language.

You'll also notice that when configured to link with libc, the code actually starts from `main`, not `_start`. The C runtime has its own version of `_start`, which it uses for initialisation, and it will call `main` for us.

`BeginMain`, the function where `__calmain` is actually defined, is a fair bit simpler.

```d
override void BeginMain() {
    output ~= "__calmain:\n";

    // call constructors
    foreach (name, global ; globals) {
        if (global.type.hasInit) {
            output ~= format("ldr x9, =__global_%s\n", name.Sanitise());
            output ~= "str x9, [x19], #8\n";
            output ~= format("bl __type_init_%s\n", global.type.name.Sanitise());
        }
    }
}
```

It creates a `__calmain` label -- the main code within this function will be defined later when `Compile` compiles all of the main syntax nodes. By the time `BeginMain` is called, globals and custom types will have been defined, so it also generates calls to initialisation functions for any globals that have them. The address of a global is placed on the stack, and then the init function is called.

## Getting Finished

After emitting code for all of the syntax nodes, `End` is responsible for cleaning up before exiting, as well as defining storage in the correct executable sections for all the global variables used in the program. Let's break this one down bit by bit.

First up, it generates code to deconstruct all of the global variable in the program, just like the init code in `BeginMain`:

```d
override void End() {
    // call destructors
    foreach (name, global ; globals) {
        if (global.type.hasDeinit) {
            output ~= format("ldr x9, =__global_%s\n", name.Sanitise());
            output ~= "str x9, [x19], #8\n";
            output ~= format("bl __type_deinit_%s\n", global.type.name.Sanitise());
        }
    }
```

It then looks for a specially named word/function to run at the end of the program. Without this, the program would actually not exit correctly (unless using libc), because we need to make a system call to exit safely.

This part of `End` is also where the `__init` function mentioned earlier is defined. It uses the exact same system, looking for a specific word to have been defined. This wasn't possible back in `Init`, as the function definitions hadn't yet been processed.

```d
    // exit program
    if ("__arm64_program_exit" in words) {
        CallFunction("__arm64_program_exit");
    }
    else {
        WarnNoInfo("No exit function available, expect bugs");
    }

    output ~= "ret\n";

    // run init function
    output ~= "__init:\n";
    if ("__arm64_program_init" in words) {
        CallFunction("__arm64_program_init");
    }
    else {
        WarnNoInfo("No program init function available");
    }
    output ~= "ret\n";
```

All of the *code* has been generated by this point, and the only thing left to do is set up the program's *data*. First, we'll output a `bss` section, which is used for uninitialised data. In it, each global variable is defined with a `.lcomm` directive, telling the assembler how much space to reserve in the section for this global.

```d
    // create global variables
    output ~= ".bss\n";

    foreach (name, var ; globals) {
        output ~= format(".lcomm __global_%s, %d\n", name.Sanitise(), var.Size());

        if (exportSymbols) {
            output ~= format(".global __global_%s\n", name.Sanitise());
        }
    }
```

Finally, we generate code to set up the arrays. Arrays are special, because unlike global variables, they contain initial data that needs to be stored in the executable.

Each array gets a label in the `.data` section in the form `__array_0`, and the array data is placed after a `.byte` or similar directive:

```d
output ~= ".data\n";
foreach (i, ref array ; arrays) {
    output ~= ".align 8\n";
    if (exportSymbols) {
        output ~= format(".global __array_%d\n", i);
    }

    output ~= format("__array_%d: ", i);

    switch (array.type.size) {
        case 1:  output ~= ".byte "; break;
        case 2:  output ~= ".2byte "; break;
        case 4:  output ~= ".4byte "; break;
        case 8:  output ~= ".8byte "; break;
        default: assert(0);
    }

    foreach (j, ref element ; array.values) {
        output ~= element ~ (j == array.values.length - 1? "" : ", ");
    }

    output ~= '\n';
```

Global arrays also have a struct automatically created and filled with the details of the array.

```d
    if (array.global) {
        output ~= ".align 8\n";
        output ~= format(
            "__array_%d_meta: .8byte %d, %d, __array_%d\n",
            i,
            array.values.length,
            array.type.size,
            i
        );
    }
}
```

## Nodes and Types

It's finally time to start compiling AST nodes! 🎉

These nodes are passed from the `Compiler` class to our `CompilerBackend`, calling a different function for each type of node.

I'll start with some nodes that don't actually produce any assembly output. `CompileConst` is one such node, as it just defines a constant that other code can reference later:

```d
override void NewConst(string name, long value, ErrorInfo error = ErrorInfo.init) {
    consts[name] = Constant(new IntegerNode(error, value));
}
    
override void CompileConst(ConstNode node) {
    if (node.name in consts) {
        Error(node.error, "Constant '%s' already defined", node.name);
    }

    NewConst(node.name, node.value);
}
```

`NewConst` is useful because it allows other backend components to define constants directly, such as in `CompileEnum`, which creates a copy of an existing numeric type, and associated constants:

```d
override void CompileEnum(EnumNode node) {
    if (!TypeExists(node.enumType)) {
        Error(node.error, "Enum base type '%s' doesn't exist", node.enumType);
    }
    if (TypeExists(node.name)) {
        Error(node.error, "Enum name is already used by type '%s'", node.enumType);
    }

    auto baseType  = GetType(node.enumType);
    baseType.name  = node.name;
    types         ~= baseType;

    foreach (i, ref name ; node.names) {
        NewConst(format("%s.%s", node.name, name), node.values[i]);
    }

    NewConst(format("%s.min", node.name), node.values.minElement());
    NewConst(format("%s.max", node.name), node.values.maxElement());
    NewConst(format("%s.sizeof", node.name), GetType(node.name).size);
}
```

Another couple of nodes for defining types are `CompileUnion`, which defines a type like a C union (though all it really does here is give the type the maximum size of the child types), and `CompileAlias`, which defines a new name for an existing type.

```d
override void CompileUnion(UnionNode node) {
    size_t maxSize = 0;

    if (TypeExists(node.name)) {
        Error(node.error, "Type '%s' already exists", node.name);
    }

    string[] unionTypes;

    foreach (ref type ; node.types) {
        if (unionTypes.canFind(type)) {
            Error(node.error, "Union type '%s' defined twice", type);
        }
        unionTypes ~= type;

        if (!TypeExists(type)) {
            Error(node.error, "Type '%s' doesn't exist", type);
        }

        if (GetType(type).size > maxSize) {
            maxSize = GetType(type).size;
        }
    }

    types ~= Type(node.name, maxSize);
    NewConst(format("%s.sizeof", node.name), cast(long) maxSize);
}

override void CompileAlias(AliasNode node) {
    if (!TypeExists(node.from)) {
        Error(node.error, "Type '%s' doesn't exist", node.from);
    }
    if ((TypeExists(node.to)) && !node.overwrite) {
        Error(node.error, "Type '%s' already defined", node.to);
    }

    auto baseType  = GetType(node.from);
    baseType.name  = node.to;
    types         ~= baseType;

    NewConst(format("%s.sizeof", node.to), cast(long) GetType(node.to).size);
}
```

The last node for defining types is `CompileStruct`, which defines a compound structure that can hold multiple other values inside. Currently, using structures in Callisto is still a bit of a manual process -- `struct` definitions are just a way to create a type with the right size and some helper constants.

Now's a good time to mention that for longer functions, I'll omit some of the error handling code, to focus on the parts that really matter.

```d
override void CompileStruct(StructNode node) {
    size_t offset;
    StructEntry[] entries;

    // Used for checking duplicate names
    string[] members;

    // Copy the inherited fields
    if (node.inherits) {
        entries = GetType(node.inheritsFrom).structure;

        foreach (ref member ; GetType(node.inheritsFrom).structure) {
            members ~= member.name;
        }
    }

    // Add the new fields
    foreach (ref member ; node.members) {
        entries ~= StructEntry(
            GetType(member.type), member.name, member.array, member.size
        );
        members ~= member.name;
    }

    // Define constants for each field's offset
    foreach (ref member ; entries) {
        NewConst(format("%s.%s", node.name, member.name), offset);
        offset += member.array? member.type.size * member.size : member.type.size;
    }

    NewConst(format("%s.sizeof", node.name), offset);
    types ~= Type(node.name, offset, true, entries);
}
```

If you're looking at these and thinking "Gee, these don't look very backend-specific, couldn't they be implemented in one place for all backends?", you're right! In the latest version of the compiler, these no longer live in **arm64.d**, but in **compiler.d**. For consistency though, I'm sticking with b0.9.0 through this series.

## Nodes and Codes

Now, we can look at the nodes that emit real assembly. I'll start with some simple ones. First, there's `CompileInteger`, responsible for compiling integer literals to be pushed onto the stack:

```d
override void CompileInteger(IntegerNode node) {
    output ~= format("ldr x9, =%d\n", node.value);
    output ~= "str x9, [x19], #8\n";
}
```

`CompileBreak` and `CompileContinue` implement the usual `break` and `continue` control flow commands. `while` loops use labels that are distinguished with unique numbers, so these nodes can just compile to branches to those labels.

```d
override void CompileBreak(WordNode node) {
    if (!inWhile) {
        Error(node.error, "Not in while loop");
    }

    output ~= format("b __while_%d_end\n", currentLoop);
}

override void CompileContinue(WordNode node) {
    if (!inWhile) {
        Error(node.error, "Not in while loop");
    }

    output ~= format("b __while_%d_next\n", currentLoop);
}
```

Callisto has a built in `call` word for calling a function pointer, and it's similarly trivial to implement -- pop a value from the stack, and branch there. It does require a new instruction I hadn't mentioned: `blr` is a version of `bl` that takes the branch address from a register.

```d
override void CompileCall(WordNode node) {
    output ~= "ldr x9, [x19, #-8]!\n";
    output ~= "blr x9\n";
}
```

## Init/Deinit

I said that Callisto structs don't provide much beyond a correctly sized value and some constants, but there is one more thing, and it's important to understand before getting to many of the block nodes.

Each struct can have an associated `init` and `deinit` word defined, and these will be called, with the address of the struct as an argument, at the appropriate time. `init` will  be called either when a local is defined with `let`, or at the start of the program for globals, which we saw in `BeginMain`.

`deinit` is more complex. For globals, there's an obvious time to call it -- at the end of the program. For locals though, `deinit` has to be called whenever the local would go out of scope. This can happen in any block structure, as well as in an early return from a function. That means that the code to deinit structs will show up a few times in the backend.

The exact code differs slightly between functions, but generally it involves iterating over each variable in the current scope and checking if a `deinit` implementation was provided. Then, if there was a `deinit` word, we compute and push the address of the struct, and call `deinit`.

## Variables

The first function to look at in relation to variables is `CompileLet`. In Callisto, both local and global variables are defined using `let type var`, and this `let` node is responsible for creating the appropriate space for the variable, as well as initialising it. `CompileLet` has two parts, one for handling globals, and one for locals. Here's the global part:

```d
override void CompileLet(LetNode node) {
    if (inScope) {
        // Take care of locals
    }
    else {
        Global global;
        global.type        = GetType(node.varType);
        global.array       = node.array;
        global.arraySize   = node.arraySize;
        globals[node.name] = global;
    }
}
```

Okay, that's pretty straightforward. We've already seen the actual allocation, initialisation and deinitialisation of globals, in `BeginMain` and `End`. So what about locals?

```d
if (inScope) {
    Variable var;
    var.name      = node.name;
    var.type      = GetType(node.varType);
    var.offset    = 0;
    var.array     = node.array;
    var.arraySize = node.arraySize;

    foreach (ref ivar ; variables) {
        ivar.offset += var.Size();
    }

    variables ~= var;

    switch (var.Size()) {
        case 1: output ~= "strb wzr, [sp, #-1]!\n"; break;
        case 2: output ~= "strh wzr, [sp, #-2]!\n"; break;
        case 4: output ~= "str wzr, [sp, #-4]!\n"; break;
        case 8: output ~= "str xzr, [sp, #-8]!\n"; break;
        default: OffsetLocalsStack(var.Size(), true);
    }

    if (var.type.hasInit) {
        output ~= "str sp, [x19], #8\n";
        output ~= format("bl __type_init_%s\n", var.type.name.Sanitise());
    }
}
```

Not that much worse, actually. The new things that have to be done for locals are:

1. Update each existing variable's offset. This is required because locals are accessed relative to the stack pointer, which we're about to move.
2. Allocate the stack space. If this is a small value, this is done by pushing zero to the stack, otherwise by calling `OffsetLocalsStack` (see below), which doesn't zero initialise.
3. Here's where `init` comes in: if the variable's type has an initialiser, call it by pushing the variable's address and branching.

The `OffsetLocalsStack` function handles a few possible cases for adjusting the value of `sp`. It allows offsetting in either direction, using `add` or `sub` accordingly, and accounts for the fact that those instructions can only take a 12-bit immediate value by loading up to 16 bits with a `mov`.

```d
private void OffsetLocalsStack(size_t offset, bool sub) {
    if (offset >= 4096) {
        output ~= format("mov x9, #%d\n", offset);
        output ~= format("%s sp, sp, x9\n", sub ? "sub" : "add");
    } else {
        output ~= format("%s sp, sp, #%d\n", sub ? "sub" : "add", offset);
    }
}
```

Now that we have a way to define variables, how about a way to give them new values? Callisto uses `-> var` to do this, and this is compiled by the `CompileSet` method. Again, this is split between locals and globals, by searching for the given name in each set of variables.

In both cases, the first step is to fetch the top item of the stack into a register. For locals, we use the variable offset to store that register relative to the stack pointer. For globals, because ARM doesn't support storing to an absolute address, we load the address using `ldr` first.

```d
override void CompileSet(SetNode node) {
    output ~= "ldr x9, [x19, #-8]!\n";

    if (VariableExists(node.var)) {
        auto var = GetVariable(node.var);

        switch (var.type.size) {
            case 1: output ~= format("strb w9, [sp, #%d]\n", var.offset); break;
            case 2: output ~= format("strh w9, [sp, #%d]\n", var.offset); break;
            case 4: output ~= format("str w9, [sp, #%d]\n", var.offset); break;
            case 8: output ~= format("str x9, [sp, #%d]\n", var.offset); break;
            default: Error(node.error, "Bad variable type size");
        }
    }
    else if (node.var in globals) {
        auto global = globals[node.var];

        output ~= format("ldr x10, =__global_%s\n", node.var.Sanitise());

        switch (global.type.size) {
            case 1: output ~= "strb w9, [x10]\n"; break;
            case 2: output ~= "strh w9, [x10]\n"; break;
            case 4: output ~= "str w9, [x10]\n"; break;
            case 8: output ~= "str x9, [x10]\n"; break;
            default: Error(node.error, "Bad variable type size");
        }
    }
    else {
        Error(node.error, "Variable '%s' doesn't exist", node.var);
    }
}
```

Another useful operation on variables is to get their address -- that is, to create a pointer to them. In Callisto, this is done with the C-like `&var`, handled by `CompileAddr`. You can also take the address of a function, which is how function pointers for `call` are created.

```d
override void CompileAddr(AddrNode node) {
    if (node.func in words) {
        auto   word   = words[node.func];
        string symbol = word.type == WordType.Callisto?
            format("__func__%s", node.func.Sanitise()) : node.func;

        output ~= format("ldr x9, =%s\n", symbol);
        output ~= "str x9, [x19], #8\n";
    }
    else if (node.func in globals) {
        auto var = globals[node.func];

        output ~= format("ldr x9, =__global_%s", node.func.Sanitise());
        output ~= "str x9, [x19], #8\n";
    }
    else if (VariableExists(node.func)) {
        auto var = GetVariable(node.func);

        output ~= format("add x9, sp, #%d\n", var.offset);
        output ~= "str x9, [x19], #8\n";
    }
    else {
        Error(node.error, "Undefined identifier '%s'", node.func);
    }
}
```

You might have noticed that there's one key operation with variables that's missing so far -- reading them. That's intentional, because the syntax for getting a variable's value is just `var`, which is the same as any other word. I'll get into how plain words are compiled later, so you'll have to wait to see how that works.

## Variables × A Lot

Are you tired of creating 100 variables with names like `thing1`, `thing2`, `thing3`, and so on? Do you want to access hundreds, thousands, MILLIONS of items through one easy name? Do you want a nice way to store text, instead of just numbers? Then have I got the product for you!

{{< figure src="arrays.jpg" title="Definitely a real Microsoft product and not just an edited Visual Basic box" >}}

Callisto does of course have arrays, as well as strings, which are just arrays of bytes with a fancy syntax. I've already shown part of how they work, with `End` being responsible for inserting array data into the assembly output. `CompileArray` is responsible for converting the array syntax node to an `Array` definition, and generating the code to set up the array and put its address on the stack.

First, it gathers up all of the array's contents (which must be integers) into a new `Array` object, and adds it to `arrays` for `End` to take care of:

```d
override void CompileArray(ArrayNode node) {
    Array array;

    foreach (ref elem ; node.elements) {
        switch (elem.type) {
            case NodeType.Integer: {
                auto node2    = cast(IntegerNode) elem;
                array.values ~= node2.value.text();
                break;
            }
            default: {
                Error(elem.error, "Type '%s' can't be used in array literal");
            }
        }
    }

    array.type    = GetType(node.arrayType);
    array.global  = !inScope || node.constant;
    arrays       ~= array;
```

If the array is a global (including if it's a constant array), then putting it onto the stack is easy. `End` sets up a static struct in memory for the array, and all we need to do is push its address to the stack.

```d
    if (!inScope || node.constant) {
        output ~= format("ldr x9, =__array_%d_meta\n", arrays.length - 1);
        output ~= "str x9, [x19], #8\n";
    }
```

Otherwise, things are a little more complex. Because we need the ability to *modify* the array, not just read from it, the array set up by `End` won't be enough here. There are two steps to this process. First, we copy the contents of the array onto the locals stack:

```d
    else {
        OffsetLocalsStack(array.Size(), true);
        output ~= "mov x9, sp\n";
        output ~= format("ldr x10, =__array_%d\n", arrays.length - 1);
        output ~= format("ldr x11, =%d\n", array.Size());
        output ~= "1:\n";
        output ~= "ldrb w12, [x10], #1\n";
        output ~= "strb w12, [x9], #1\n";
        output ~= "subs x11, x11, #1\n";
        output ~= "bne 1b\n";
```

The equivalent of this assembly on x86_64 uses a built in `rep movsb` instruction to copy a large block of data. There's no such assembly shortcut on ARM, so here I just implemented a small loop to copy the array data. There are a couple of interesting new assembly tricks here. First, the loop itself uses local labels. This means that I can output this exact block of assembly many times, without conflict. `1b` refers to the previous use of the label `1:` (`1f` would refer to the *next* use). Second, to decrement `x11` and then jump back only if it's still positive, I used `subs`. This modifies the `sub` instruction to also set the flags according to its output, so the loop can keep jumping until that output is zero.

After this, the code sets up the definitions of both the raw data and the `Array` struct:

```d
        Variable var;
        var.type      = array.type;
        var.offset    = 0;
        var.array     = true;
        var.arraySize = array.values.length;

        foreach (ref var2 ; variables) {
            var2.offset += var.Size();
        }

        variables ~= var;

        // create metadata variable
        var.type   = GetType("Array");
        var.offset = 0;
        var.array  = false;

        foreach (ref var2 ; variables) {
            var2.offset += var.Size();
        }

        variables ~= var;
```

and fills in the struct fields, before pushing its address to the stack:

```d
        output ~= "mov x9, sp\n";
        output ~= format("sub sp, sp, #%d\n", var.type.size);
        output ~= format("ldr x10, =%d\n", array.values.length);
        output ~= "str x10, [sp]\n";
        output ~= format("ldr x10, =%d\n", array.type.size);
        output ~= "str x10, [sp, #8]\n";
        output ~= "str x9, [sp, #16]\n";

        // push metadata address
        output ~= "mov x9, sp\n";
        output ~= "str x9, [x19], #8\n";
    }
}
```

As strings are just a special syntax for arrays, `CompileString` is a very simple function. All it needs to do is convert the `StringNode` into an `ArrayNode`.

```d
override void CompileString(StringNode node) {
    auto arrayNode = new ArrayNode(node.error);

    arrayNode.arrayType = "u8";
    arrayNode.constant  = node.constant;

    foreach (ref ch ; node.value) {
        arrayNode.elements ~= new IntegerNode(node.error, cast(long) ch);
    }

    CompileArray(arrayNode);
}
```

## Take Control

Only a few more nodes left to look at! Let's have a look at the control flow nodes. `if` and `while` actually have a fair bit in common, as they both involve setting up labels in order to conditionally jump around some other piece of code. They also both introduce new scopes and therefore need to take care of calling `deinit` when ready.

I'll look at `CompileIf` first. An `if` statement has a series of conditions and associated blocks of code to run when the conditions are true. It can also have an `else` block, to run when no conditions are true.

First, we need a unique ID to use for the labels. Each control flow structure is assigned the next number, stored in a member variable of our backend:

```d
++ blockCounter;
auto blockNum = blockCounter;
uint condCounter;
```

For each pair of condition and body in the if statement, we start by compiling the nodes that make up the condition. After these nodes run, we expect a result to be left on the stack -- 0 means false, anything else means true. This is why after the condition, we compile a comparison and conditional jump. The jump will skip over the body of the statement whenever the result is zero by jumping to the label with the next higher index.

```d
foreach (i, ref condition ; node.condition) {
    foreach (ref inode ; condition) {
        compiler.CompileNode(inode);
    }
    output ~= "ldr x9, [x19, #-8]!\n";
    output ~= "cmp x9, #0\n";
    output ~= format("beq __if_%d_%d\n", blockNum, condCounter + 1);
```

Assembly that gets output here is part of the body of the if statement, and that means it starts a new scope. To take care of this, `CompileIf` takes a copy of the current variables before compiling any of the body. It can then reference this copy at the end in order to only deinitialise the newly added variables, and move the stack pointer back to its original place.. 

```d
    auto oldVars = variables.dup;
    auto oldSize = GetStackSize();

    foreach (ref inode ; node.doIf[i]) {
        compiler.CompileNode(inode);
    }

    foreach (ref var ; variables) {
        if (oldVars.canFind(var)) continue;
        if (!var.type.hasDeinit)  continue;

        output ~= format("add x9, sp, #%d\n", var.offset);
        output ~= "str x9, [x19], #8\n";
        output ~= format("bl __type_deinit_%s\n", var.type.name.Sanitise());
    }
    if (GetStackSize() - oldSize > 0) {
        OffsetLocalsStack(GetStackSize() - oldSize, false);
    }
    variables = oldVars;
```

After the body, we don't want to keep checking the other conditions, so we'll emit a jump to the end of the entire if statement. This is also where the internal `__if_1_1` type labels are created, so that each failing condition can jump over its associated body.

```d
    output ~= format("b __if_%d_end\n", blockNum);

    ++ condCounter;
    output ~= format("__if_%d_%d:\n", blockNum, condCounter);
}
```

Finally, if this particular if statement has an `else` block, it gets compiled, then the `__if_1_end` label is created. This works the same way as the previous bodies, so I won't show it in full.

```d
if (node.hasElse) {
    // Save the variables, compile the body, restore the stack
}

output ~= format("__if_%d_end:\n", blockNum);
```

`CompileWhile` works quite similarly to `CompileIf`, so here's a condensed version. Comments in `{}` indicate sections of code you've already seen:

```d
// {Get block ID}

// Save the block ID for break/continue to use
currentLoop = blockNum;

// The condition is placed after the loop, so jump there first.
output ~= format("b __while_%d_condition\n", blockNum);
output ~= format("__while_%d:\n", blockNum);

// {Save scope}

foreach (ref inode ; node.doWhile) {
    // Mark that we're in a loop so break/continue will be allowed.
    inWhile = true;
    compiler.CompileNode(inode);
    currentLoop = blockNum;
}

output ~= format("__while_%d_next:\n", blockNum);

// {Restore scope}

inWhile = false;

output ~= format("__while_%d_condition:\n", blockNum);

foreach (ref inode ; node.condition) {
    compiler.CompileNode(inode);
}

// Conditional branching, just like for `if`, but at the end.
output ~= "ldr x9, [x19, #-8]!\n";
output ~= "cmp x9, #0\n";
output ~= format("bne __while_%d\n", blockNum);
output ~= format("__while_%d_end:\n", blockNum);
```

And that's it for control flow -- right now, Callisto only features those two structures.

## Words, Words, Words

Finally, the core of Callisto. So far, the backend can compile some data types, literal values, and some control structures. Everything else in Callisto is a word, so the ARM backend better be able to compile words -- both their definitions and their usage.

I'll go over a slightly simplified version of these compiler functions here, but as always, the [Callisto source code](https://github.com/callisto-lang/compiler) is available to review in full. For simplicity, I'll be omitting the code to handle inline words (words that compile their bodies directly where they are used), and the code relating to error handling, both in the compiler, and at runtime (Callisto exceptions).

New words/functions are defined with `func`, and compiled using `CompileFuncDef`. The start of this function is pretty straightforward, making sure that the backend state is set correctly, and setting up labels with the right names.

```d
override void CompileFuncDef(FuncDefNode node) {
    thisFunc = node.name;

    assert(!inScope);
    inScope = true;

    words[node.name] = Word(
        node.raw? WordType.Raw : WordType.Callisto, false, [], node.errors
    );

    // Raw words are useful for exporting from the 
    string symbol =
        node.raw? node.name : format("__func__%s", node.name.Sanitise());

    if (exportSymbols) {
        output ~= format(".global %s\n", symbol);
    }

    output ~= format("%s:\n", symbol);
```

The next step is something that doesn't exist in the x86 backend. On x86, the `call` instruction does two things. First, it pushes the current program counter to the system stack, then it jumps to the given address. Keeping the return address on the stack means that nested calls work perfectly fine -- each pushes its own return address, then the corresponding `ret` will later pop it from the stack.

On ARM, it's not quite so straightforward. The equivalent of `call` is `bl`, or Branch and Link. Rather than saving the return address to the *stack*, `bl` saves it to the register `lr`. If you try to use `bl` on its own, then nested function calls won't work at all because `lr` can only store a single address. So to allow proper nested words, `CompileFuncDef` will insert an instruction to push `lr` to the stack here. Part of the motivation for making this a separate step in the ARM architecture is so that leaf functions -- functions that don't call other functions -- can skip it, but my ARM64 Callisto backend doesn't do so yet.

```d
    output ~= "str lr, [sp, #-8]!\n";
```

Function parameters are next. In Callisto b0.9.0, the version I'm looking at here, these were an optional feature, though in the latest version, they are almost always needed to work with the stack checker. Parameters are handled by creating associated variable definitions, then copying data directly from the working stack to the system/locals stack, using a copy loop like the one in `CompileArray`.

```d
    size_t paramSize = node.params.length * 8;
    if (paramSize > 0) {
        output ~= format("sub sp, sp, #%d\n", paramSize);
        foreach (ref var ; variables) {
            var.offset += paramSize;
        }

        size_t offset;
        foreach (i, ref type ; node.paramTypes) {
            auto     param = node.params[i];
            Variable var;

            var.name      = param;
            var.type      = GetType(type);
            var.offset    = cast(uint) offset;
            offset       += var.Size();
            variables    ~= var;
        }

        output ~= format("sub x19, x19, #%d\n", paramSize);
        output ~= "mov x9, x19\n";
        output ~= "mov x10, sp\n";
        output ~= format("mov x11, #%d\n", paramSize);
        output ~= "1:\n";
        output ~= "ldrb w12, [x9], #1\n";
        output ~= "strb w12, [x10], #1\n";
        output ~= "subs x11, x11, #1\n";
        output ~= "bne 1b\n";
    }
```

Now that the stack has been set up correctly, we can go right ahead and compile all of the function body, and the variable deinit code after that. This version of the deinitialisation loop is slightly different, though. In Callisto, functions are always the topmost scope that local variables can appear in, so there was no need to save the old variable definitions. Instead, wiping out every variable will suffice.

```d
    foreach (ref inode ; node.nodes) {
        compiler.CompileNode(inode);
    }

    size_t scopeSize;
    foreach (ref var ; variables) {
        scopeSize += var.Size();

        if (var.type.hasDeinit) {
            output ~= format("add x9, sp, #%d\n", var.offset);
            output ~= "str x9, [x19], #8\n";
            output ~= format("bl __type_deinit_%s\n", var.type.name.Sanitise());
        }
    }
    if (scopeSize > 0) {
        OffsetLocalsStack(scopeSize, false);
    }
```

These last few lines just reverse a few actions taken earlier -- the link register is restored, we use it to return to the caller, and then clean up the backend state.

```d
    output    ~= "ldr lr, [sp], #8\n";
    output    ~= "ret\n";
    inScope    = false;
    variables  = [];
}
```

`CompileImplement` is similar to `CompileFuncDef`, but without the code for handling function parameters and the code for handling exceptions (which I didn't include anyway). This is the function that compiles `init` and `deinit` definitions, from `implement` blocks. They are just regular functions, but with a different naming convention to avoid conflicts.

`CompileReturn` essentially just contains the end of `CompileFuncDef`, to allow inserting early returns into functions. It needs to call `deinit`, just like the end of a function, so that's included. `inScope` and `variables` are left as is, because we are still compiling the function body at this point.

```d
override void CompileReturn(WordNode node) {
    if (!inScope) {
        Error(node.error, "Return used outside of function");
    }

    size_t scopeSize;
    foreach (ref var ; variables) {
        scopeSize += var.Size();

        if (var.type.hasDeinit) { 
            output ~= format("add x9, sp, #%d\n", var.offset);
            output ~= "str x9, [x19], #8\n";
            output ~= format("bl __type_deinit_%s\n", var.type.name.Sanitise());
        }
    }
    if (scopeSize > 0) {
        OffsetLocalsStack(scopeSize, false);
    }

    output ~= "ldr lr, [sp], #8\n";
    output ~= "ret\n";
}
```

The last of these functions to look at is `CompileWord`. Since almost everything in Callisto is a word, this is a pretty important function. It's also a pretty long function, because there are four different cases to take care of -- a word can be:

1. **A word:** It might be clearer in this context to call this a function. For these, we'll need to jump to the corresponding piece of code.
2. **A local variable:** If the word matches a local in the current scope, it should fetch the value of that local.
3. **A global variable:** Similar to the previous, but the code used to load the variable is a bit different.
4. **A constant:** By far the simplest case, this just compiles to the value of the constant, which right now is always an `IntegerNode`.

Let's break them down one by one. Keep in mind, this is still simplified code -- no inlines, no exceptions. Handling Callisto words is pretty easy. Everything is stored on the working stack, so just branching to them is enough. Raw words skip the name mangling step, but a `bl` is still all that gets emitted.

```d
if (node.name in words) {
    auto word = words[node.name];

    if (word.type == WordType.Raw) {
        output ~= format("bl %s\n", node.name);
    }
    else if (word.type == WordType.C) {
        // ...
    }
    else {
        output ~= format("bl __func__%s\n", node.name.Sanitise());
    }
}
```

The C word type that I skipped over there takes a little more work. The C calling convention on ARM64 is actually the same across all platforms, because ARM themselves standardise it. It's quite simple, especially when handling only a limited number of integer arguments, as Callisto supports currently. For this case, we just need to place arguments into registers `x0` through `x7`, and fetch the result from `x0` after calling. C functions also expect to be able to use the stack, but this is fine as `sp` will point past Callisto's stack.

```d
        if (word.params.length > 8) {
            Error(node.error, "C call has too many parameters");
        }

        for (auto i = 0; i < word.params.length; i++) {
            auto reg = word.params.length - i - 1;
            output ~= format("ldr x%d, [x19, #-8]!\n", reg);
        }
    
        output ~= format("bl %s\n", word.symbolName);

        if (!word.isVoid) {
            output ~= "str x0, [x19], #8\n";
        }
```

For variables, both local and global, the code is pretty much the inverse of `CompileSet`. This allows any variable's name to be used to directly fetch its value onto the working stack.

```d
else if (VariableExists(node.name)) {
    auto var = GetVariable(node.name);

    switch (var.type.size) {
        case 1: output ~= format("ldrb w9, [sp, #%d]\n", var.offset); break;
        case 2: output ~= format("ldrh w9, [sp, #%d]\n", var.offset); break;
        case 4: output ~= format("ldr w9, [sp, #%d]\n", var.offset); break;
        case 8: output ~= format("ldr x9, [sp, #%d]\n", var.offset); break;
        default: Error(node.error, "Bad variable type size");
    }

    output ~= "str x9, [x19], #8\n";
}
else if (node.name in globals) {
    auto var = globals[node.name];

    output ~= format("ldr x9, =__global_%s\n", node.var.Sanitise());

    switch (var.type.size) {
        case 1: output ~= "ldrb w9, [x9]\n"; break;
        case 2: output ~= "ldrh w9, [x9]\n"; break;
        case 4: output ~= "ldr w9, [x9]\n"; break;
        case 8: output ~= "ldr x9, [x9]\n"; break;
        default: Error(node.error, "Bad variable type size");
    }

    output ~= "str x9, [x19], #8\n";
}
```

Finally, compiling constants is just as simple as described before -- pass the value of the constant back into the compiler to handle.

```d
else if (node.name in consts) {
    auto value  = consts[node.name].value;
    value.error = node.error;

    compiler.CompileNode(consts[node.name].value);
}
else {
    Error(node.error, "Undefined identifier '%s'", node.name);
}
```

Now, (excluding the simplifications I made), this backend is capable of compiling all Callisto code to ARM64 assembly, then building an executable using the appropriate commands.

# Facing Reality

I have a confession to make. I've been lying to you this whole time. At this point in developing the backend, I wasn't working on real ARM64 hardware. The most convenient way to test all of this was using QEMU on an x86 Linux PC, so I only tested it all inside an emulator. Once everything was pretty much working, I tested on two real ARM64 devices -- a Raspberry Pi 4, and an ARM64 MacBook running a Linux virtual machine -- and it failed on both.

I already hinted at the reason for this back when I was describing the registers. The culprit was `sp`. While `sp` can often be used as a normal register, it has an extra requirement that was not being enforced by QEMU. As [Jacob Bramley](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/using-the-stack-in-aarch32-and-aarch64) wrote on the ARM Community Blog:

> For AArch64, `sp` must be 16-byte aligned whenever it is used to access memory. This is enforced by AArch64 hardware.

This is an issue in Callisto, because though it might be easy to push an additional 8 bytes when pushing `lr` to the stack, locals each independently allocate stack space with different sizes, so that means a lot of additional stack alignment checks. I considered handling it this way for a while, but found a much simpler solution. Because ARM64 makes it so easy to use *any* register as a stack pointer, I just switched the register for Callisto's return and local stack to `x20`.

This actually introduced another subtle bug, which I didn't notice until some time after I started writing this series. Because the Callisto return stack is no longer synced with the C one, calling a C function had the potential to overwrite part of Callisto's used memory. It should only have affected the far end of the working stack, so was unlikely to come up in practice, but I fixed that with one extra instruction when calling C functions:

```asm
and sp, x20, ~0xf
````

This will reset `sp` to the current return stack position, and take care of alignment at the same time, rounding down to the next 16-byte boundary. Now, with all of this sorted out, Callisto actually works!

# Doing Useful Things

With all this work in the backend, what can Callisto on ARM64 do now? Well... nothing. Even for Callisto to perform arithmetic, there's more work to be done. Callisto needs its core library implemented, split into an OS and a CPU component. In the next post, I'll get into the implementation of this core on ARM64 Linux, so that Callisto is capable of doing anything interesting at all.

Until then, I hope you enjoyed reading another (mostly code) post about bringing an obscure language to a somewhat less obscure platform!
