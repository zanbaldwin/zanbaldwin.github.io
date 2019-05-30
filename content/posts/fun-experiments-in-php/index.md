---
title: 'Fun Experiments in PHP (Not for Production)'
date: '2019-04-08'
author: 'Zan Baldwin'
cover: 'science.jpg'
description: |
    I'll show you the crazy things you can do in PHP with streams and autoloader overloading to write your own language features, including generics. I'll also show you how you can supercharge your applications using aspect-oriented programming or encrypt source code on-the-fly using only PHP. As if that wasn't enough, we'll go even further and make PHP a polyglot language by importing esoteric language scripts!
    These aren't your average hacks and shouldn't be run in production... but let's explore these concepts as fun experiments so you'll never think of PHP as boring again!
published: false
---

# Introduction

This is a technical article, but it's not the main focus. It's designed to make you go _"huh?"_ or _"what?"_ Most
importantly however, even if for a split second, I want this article to make you go _"I wonder..."_ or _"what if?"_
Also, for the remainder of this article, imagine that we don't care about performance - there are many articles on the
web about performant PHP and this article is the opposite of that.

# Streams

In computer science, a stream is a sequence of data elements made available over time. Think of it as items on a
conveyor belt that are processed as they arrive - most streams, like conveyor belts, end once there are no more items
but they can run continuously if need be.

If you write PHP applications that deal with the input and output of data, you use streams. They're a core function in
PHP and pretty unavoidable for any developer. Streams in PHP are a way of generalizing file, network, data compression,
and other operations which share a common set of functions and uses: a stream is resource object which can be read from
and written to in a linear fashion.

If you've used Guzzle or sockets, accessed the filesystem, or even dealt with a `$_POST` request, you've used streams.
PHP is known for its low barrier-of-entry so the vast majority of stream handling is abstracted away from the developer.

An example of this is `file_get_contents('hello.txt')` which implicitly means `file_get_contents('file://hello.txt)` -
fetching the specified URI using the `file://` protocol.

Known as **stream wrappers**, PHP supports the following protocols natively: `file`, `http`, `ftp`, `php`, `zlib`,
`bzip2`, `data`, `glob`, `phar`. The following protocols are also supported if their associated extensions are
installed: `zip`, `ssh2`, `rar`, `ogg`, `expect`. If you've come across the `s3://` protocol while using the
[AWS SDK](https://aws.amazon.com/sdk-for-php/), you've come across a stream wrapper. PHP lets us define out own stream
wrappers in userland PHP.

## Esoteric Language

Introducing [Brainf*ck](https://en.wikipedia.org/wiki/Brainfuck)! Obviously not exactly the best name to use (especially
at an [international conference](https://phpconference.nl) where this article was given as a talk) but it’s perhaps the
world's most well known esoteric language. Let’s assume we have a script `hello.bf`:

```
++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.
```

If, for some arcane, horrendous reason, we wanted to write parts of our application in BF, and require it in our
application the `file://` protocol is implicitly used when we `require` it in our application and the contents of the
file will get dumped byte-for-byte because the PHP interpreter doesn't find any PHP code.

However, we can substitute the implicit protocol for explicitly using a custom stream wrapper in userland PHP to
manipulate the input before including the result in our application.

## Custom Stream Wrapper

Here we have the boilerplate code for a stream wrapper: the class definition and a static method to register it with
PHP:

```php
<?php

class BfStreamWrapper
{
    /** @var resource $context */
    public $context;

    public static function register(string $filterName): void
    {
        stream_wrapper_register($filterName, static::class);
    }
}
```

Stream wrappers don't extend or implement anything in PHP core, but we need to implement a minimum of 5 methods to
process an incoming stream.

The first is `stream_open()`; we’re just checking that the file specified exists and taking note of its path.
 
```php
<?php

private $uri;

public function stream_open(string $path, string $mode, int $options, &$opened_path): bool
{
    $realpath = $this->removeProtocolFromPath($path, static::WRAPPER_PROTOCOL);
    if (file_exists('file://' . $realpath)) {
        $this->uri = $opened_path = $realpath;
        return true;
    }
    return false;
}
```

`stream_stat()` is something that’s called each time to collect information, it’s obviously recommended that you return
some useful information about the stream here but technically it's not actually required; in this example we're just
returning an empty array:

```php
<?php

public function stream_stat(): array
{
    return [];
}
```

Streams are read from and written to in chunks, meaning `stream_read()` could be invoked multiple times. This method is
more complicated than the rest because it needs to keep track of how much data has flowed out. But simplified, the
first line is the Brainf*ck script getting executed; every line thereafter is dealing with returning the buffered script
output in chunks as they're requested by the stream user.

```php
<?php

private $output;
private $pointer = 0;
private $eof = false;

public function stream_read(int $readNumBytes)
{
    $this->execute();
    $remainingBytes = strlen($this->output) - $this->pointer;
    if ($remainingBytes > 0) {
        $buffer = substr($this->output, $this->pointer, $readNumBytes);
        $this->pointer += $readNumBytes;
        return $buffer;
    }
    $this->eof = true;
    return false;
}
```

The `stream_eof()` method returns a boolean value indicating whether the previous `stream_read()` has been called enough times to reach the end of the stream.

```php
<?php

private $eof = false;

public function stream_eof(): bool
{
    return $this->eof;
}
```

`stream_close()` is just cleaning up the internal state - in other protocols this might be where you close a connection
or delete a lock file.

```php
<?php

private $uri;
private $output;
private $pointer = 0;
private $eof = false;

public function stream_close(): bool
{
    // Clear internal buffers.
    $this->uri = null;
    $this->output = null;
    $this->pointer = 0;
    $this->eof = false;
    return true;
}
```

Finally, for completeness, the powerhouse of stream wrapper is the method that executes Brainf*ck scripts. In this
example I’m using [Anthony Ferrara’s library](https://github.com/ircmaxell/brainfuck). We take the contents of the
Brainf*ck script, pump it through the language runtime, and save the result as a string in the `$output` class property.

```php
<?php

private $input = [];
private $output;

private function execute(): void
{
    if (is_string($output)) {
        return;
    }
    $result = (new \Brainfuck\Language)->run(
        file_get_contents('file://' . $this->uri),
        $this->input
    );
    $this->output = implode('', array_map(function (int $ord): string {
        // Brainf*ck returns result in bytes (8-bit integers). Convert to ASCII.
        return chr($ord);
    }, $result));
}
```

However, requiring a script using our new stream wrapper doesn’t give us a change to provide the script with any input,
which is kind of important for some scripts.

We can accept an input string, and save it in a class property to use when we execute the script. Unfortunately in our
example this means that we can only accept input before we execute our script, which is whenever we attempt to read the
output.

```php
<?php

private $input = [];

public function stream_write(string $data): int
{
   // No point in recording input if script has already been executed.
   if (is_string($this->output)) {
       return 0;
   }
   $count = 0;
   foreach (str_split($data) as $chr) {
       // Brainf*ck takes bytes (8-bit integers) as input.
       $this->input[] = ord($chr);
       $count++;
   }
   return $count;
}
```

Now it’s time to use it! After registering our stream filter, we can open up a stream handle, pump in some input, and
get the output of our script! Notice how if our script needs input, we can’t `require` the script like we would a PHP
file.

## Stream Filters

Next up in the PHP streams arsenal is stream filters. They’re simpler than wrappers: just a method to modify data as it
passes through - this does mean that it cannot deal with both input and output so this is a perfect time to introduce
**source code transformation**!

Here we have the boilerplate for a stream filter, the class definition and a static method to register it with PHP.
Unlike wrappers, stream filters extend a core PHP class and only need to implement one method.

```php
<?php

class BfStreamFilter extends \php_user_filter
{
    public static function register(string $filterName): void
    {
        stream_filter_register($filterName, self::class);
    }

    public function filter($in, $out, &$consumed, $closing): int
    {
        while ($bucket = stream_bucket_make_writeable($in)) {
            $this->input .= $bucket->data;
        }
        if ($closing || feof($this->stream)) {
            $consumed = strlen($this->input);
            $bucket = stream_bucket_new(
                $this->stream,
                // Has to be static because userland doesn't control instantiation.
                static::$twig->render('bf_closure.twig.php', [
                    'bf_php_value' => var_export($this->input, true),
                ])
            );
            stream_bucket_append($out, $bucket);
            return \PSFS_PASS_ON;
        }
        return \PSFS_FEED_ME;
    }
}
```

Again, streams are processed in chunks so the vast majority of this method is dealing with pulling in the contents of
the stream, possibly over multiple invocations...  But the main logic of this method is still simply just data in and
data out:

```php
<?php

public function filter($in, $out, &$consumed, $closing): int
{
    // Data in...
    $this->input .= $bucket->data;

    // Data out...
    static::$twig->render('bf_closure.twig.php', [
        'bf_php_value' => var_export($this->input, true),
    ])
}
```

```twig
<?php declare(strict_types=1);

{% Brainf*ck Closure Code Template %}

return function (array $input = []): string {
   $result = (new \Brainfuck\Language)->run(
       {{ bf_php_value }},
       $input
   );
   return implode('', array_map(
       function (int $ord): string {
           // BF returns result in bytes (8-bit
           // integers). Convert to ASCII.
           return chr($ord);
       },
       $result
   ));
};
```
