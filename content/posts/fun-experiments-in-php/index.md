---
title: 'Fun Experiments in PHP (Not for Production)'
date: '2019-04-08'
author: 'Zan Baldwin'
cover: 'science.jpg'
description: |
    I'll show you the crazy things you can do in PHP with streams and autoloader overloading to write your own language
    features, including generics. I'll also show you how you can supercharge your applications using aspect-oriented
    programming or encrypt source code on-the-fly using only PHP. As if that wasn't enough, we'll go even further and
    make PHP a polyglot language by importing esoteric language scripts!
    These aren't your average hacks and shouldn't be run in production... but let's explore these concepts as fun
    experiments so you'll never think of PHP as boring again!
published: true
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
at an [international conference](https://phpconference.nl) where this article was given as a talk) but it's perhaps the
world's most well known esoteric language. Let's assume we have a script `hello.bf`:

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

The first is `stream_open()`; we're just checking that the file specified exists and taking note of its path.
 
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

`stream_stat()` is something that's called each time to collect information, it's obviously recommended that you return
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
example I'm using [Anthony Ferrara's library](https://github.com/ircmaxell/brainfuck). We take the contents of the
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

However, requiring a script using our new stream wrapper doesn't give us a change to provide the script with any input,
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

Now it's time to use it! After registering our stream filter, we can open up a stream handle, pump in some input, and
get the output of our script! Notice how if our script needs input, we can't `require` the script like we would a PHP
file.

## Stream Filters

Next up in the PHP streams arsenal is stream filters. They're simpler than wrappers: just a method to modify data as it
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

Almost every time I've had to output XML from an application, I've used Twig rather than deal with encoding data
structures. Why not do it for PHP, too?

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

Similar to before, we register our stream filter, except this time we attach our stream filter to an already existing
stream handle. When we read the contents of the stream we get back valid PHP code that we can `eval()`!

```php
<?php

BfStreamFilter::register('bf');

$handle = fopen('/app/hello.bf', 'r+');
stream_filter_append($handle, 'bf');

$closureCode = stream_get_contents($handle);
$closure = eval('?>' . $closureCode);

$output = $closure($input);
```

Attaching a filter to a stream handle and evaluating the result each time isn't ideal - and most importantly we can't
attach a stream filter to a `require` statement. That's where one of the most underrated features of PHP comes in: the
`php://` stream wrapper... in particular the `php://filter` meta-wrapper.

The `php://filter` meta-wrapper allows us to act upon any other stream resource (`/resource=`), while attaching any
number of filters to manipulate the stream when reading it (`/read=`) as well as when writing to it (`/write=`).

Most importantly, this allows us to specify a resource and attach a filter to it all in one string which we can pass to
require. This one string saves us from having to open up a handle, attaching a filter, and evaluating the result of the
stream. This one feature of PHP is the basis of this entire article.

```php
<?php

BfStreamFilter::register('bf');

$script = '/app/hello.bf';

// php://filter/read=bf/resource=file:///app/hello.bf
$closure = require 'php://filter'
                 . '/read=bf'
                 . '/resource=file://' . $script;

$output = $closure($input);
```

# Go! AOP

At [Dutch PHP Conference](https://phpconference.nl) 2016 I saw [Alexander Lisachenko](https://twitter.com/lisachenko)
talk about the [Go! AOP](http://go.aopphp.com/) framework he created, which is the main inspiration for this article.
I'll give an extremely brief idea of what the project does, then dive straight into the internals to figure out what's
going on.

Go! AOP is a framework for developing PHP application using aspect-oriented programming: separating out logic when
developing and joining it back together at runtime.

- Allows separation of cross-cutting concerns
- Increases modularity
- Adds additional behaviour to existing code

_To ensure that I explain the framework accurately, I'll use the same examples as the creator of this framework and I
recommend you look up Lisachenko's previous presentations on this subject._

Let's say we have a method that creates a new user in our application. As far as business logic goes, all that's
required for creating a new user is pretty simple:

```php
<?php

function createNewUser(string $email, string $password): UserInterface {
    $user = new User($email, $password);
    $this->entityManager->persist($user);
    $this->entityManager->flush();
    return $user;
}
```

But in the real world things are never this simple:

- We'll need to the authorization of the currently logged-in user to make sure they're allowed to create new users.
- We should log that a new user is being created.
- We need to emit an event onto a queue so that an email can be sent asynchronously to the new user informing them that
  their account is ready to use.
- And we need exception handling in case something goes wrong.

```php
<?php

function createNewUser(string $email, string $password): UserInterface {
    if (!$this->security->isGranted('ROLE_ADMIN')) {
        throw new AccessDeniedException;
    }
    try {
        $user = new User($email, $password);
        $this->entityManager->persist($user);
        $this->entityManager->flush();
    } catch (ORMException $e) {
        $this->logger->error('Could not persist new user.', ['email' => $email]);
        throw $e;
    }
    $this->eventDispatcher->dispatch(new UserCreatedEvent($email));
    $this->logger->info('User created successfully.', ['email' => $email]);
    return $user;
}
```

While this example may not be unwieldy once everything has been factored in, it does demonstrate how even the simplest
things need to consider many different cross-cutting concerns. More complex situations can get unwieldy very quickly.

Aspect-oriented programming is about keeping your method simple and interrupting the execution flow of the application
at specific points to add logic. You keep logic separated, and inject each piece to where it needs to be. These injected
pieces of logic are called **pointcuts**.

```php
<?php

function createNewUser(string $email, string $password): UserInterface {
    $user = new User($email, $password);
    $this->entityManager->persist($user);
    $this->entityManager->flush();
    return $user
}

/** @Before(pointcut=”public UserService->*(*)”) */
function checkCurrentUserCanCreateUsers(MethodInvocation $method): void {
    if (!$this->security->isGranted('ROLE_ADMIN')) {
        throw new AccessDeniedException;
    }
}

/** @AfterThrow(pointcut=”public UserService->createNewUser(*)”) */
function handleNewUserDatabaseError(MethodInvocation $method): void {
    $this->logger->error('Could not persist new user.', ['email' => $method->getArguments()[0]]);
    throw $e;
}

/** @After(pointcut=”public UserService->createNewUser(*)”) */
function onNewUserSuccessfullyCreated(MethodInvocation $method): void {
    $email = $method->getArguments()[0];
    $this->eventDispatcher->dispatch(new UserCreatedEvent($email));
    $this->logger->info('User created successfully.', ['email' => $email]);
}
```

We can even decorate the original method and make modifications to the result if we want to.

```php
<?php

/** @Around(pointcut=”public UserService->createNewUser(*)”) */
function logTimeTakenToCreateUser(MethodInvocation $method): UserInterface {
    $start = microtime(true);
    $result = $method->proceed();
    $duration = microtime(true) - $start;
    $this->logger->log(sprintf('Creating a user took %f seconds', $duration));
    return new TimedUserCreation($result, $duration);
}
```

## Source Transformers

The majority of the AOP's logic is in the form of source transformers. By using AOP in your application, you're entering
the realm of meta-programming: your application transforms its own source code when including it. So what is AOP doing
inside that transformer?

- AOP queries Composer's class loader for the location of the file that should contain the class definition for
  `MyClass`.
- It generates a load of metadata about the source code file, including its contents and the Abstract Syntax Tree
  generated from its contents by [Nikita Popov's pure-PHP language parser
  `nikic/php-parser`](https://github.com/nikic/PHP-Parser).
- It passes that metadata through a series of source transforming classes, each manipulating the AST to provide a
  particular feature.
- Dump the final manipulated AST back into PHP code as a string. It's at this point that the final compiled source is
  saved to cache so that subsequent requests skip the expensive source transformation stage.
- The final transformed code is returned to be executed by the PHP engine.

All of this happens while you're writing PHP applications normally without worrying about loading classes or compiling
into usable code. As this article is all about PHP streams, it may not come as a surprise that the main logic behind the
AOP framework is built around PHP's stream filters.

A huge amount of complexity is held within this process, enough for an entirely different presentation, so for the sake
of simplicity, we'll simplify AOP's source transforming process into a single function call. From now on, we'll use the
following function as an alias to implementing and registering a stream filter because, quite frankly, implementing a
stream filter didn't fit on the original slides!

```php
<?php

$executableCodeContents = transformCodeFilter($sourceCodeFileOnDisk);
```

## Autoloader Overloading

> `new MyClass` ⇢ ??? ⇢ `transformCodeFilter()`

But if you try to create a new instance of `MyClass`, how does AOP manipulate Composer to pass the source code file
through the `transformCodeFilter()` function before getting PHP to execute the contents?

- You go to instantiate a new class, eg `new MyClass`
- Composer does its normal thing of figuring out where the class definition is located, eg `/var/www/MyClass.php`
- AOP hijacks the normal Composer logic... _I'd like to interject for a moment_
- and tells PHP to load a new URI that uses the PHP stream wrapper:
  `php://filter/read=go.source.transforming.loader/resource=file:///var/www/MyClass.php`

PHP then applies the `go.source.transforming.loader` filter when reading the contents of the URI `/var/www/MyClass.php`
from the `file://` system.

So what kind of sneaky magic is this? 🐍

---

- "Hey, PHP! Give me all of the registered autoloaders please! 🙏"
  AOP will fetch all the currently loaded autoloaders using the spl_autoload_functions() function, which could return an array like `[ Composer\Autoload\ClassLoader, MyAppLoader ]`.
- "Hmm, let's take a closer look at those… 🔍"
  AOP will iterate over each autoloader. If AOP finds Composer in the list of autoloaders, it will replace original Composer autoloader with a decorated version which would end up with an array like `[ AopComposerLoader(Composer\Autoload\ClassLoader), MyAppLoader ]`.
- "Hot dang! I knew it!"
  Pretend it was there all along.
- "Okay, thanks PHP! You can have those back now! 😘"
  Then re-register the autoloaders with PHP
- PHP accepts the divine wisdom of AOP: "Sure AOP, looks legit 🤷‍♀️"

So what does this look like in code?

### The Magic™

This is our overloader. Since it decorates Composer we accept it as the first
argument, and it's always useful to know the name of the filter we should be
applying.

```php
<?php

class AutoloaderOverloader
{
    private $composer;
    private $filterName;

    protected function __construct(ComposerClassLoader $composer, string $filterName) {
        $this->composer = $composer;
        $this->filterName = $filterName;
    }
}
```

The autoloader part: all of the heavy lifting is still done by Composer, all we do
it rewrite the file path so that the `php://` stream wrapper applies a filter
when reading the file.

```php
<?php

class AutoloaderOverloader
{
    // ...

    public function loadClass($class) {
        $file = $this->composer->findFile($class);
        $compiledFile = $this->cache->findCachedFile($file)
                     ?: 'php://filter/read=' . $this->filterName . '/resource=file://' . $file;
        include $compiledFile;
    }
}
```

We've already established that we can generate code using templates, so if
`$this->composer->findFile($class)` did not return a file, this would be the
place to do it.

Next, the overloader part, we add a static helper method to initialize our overloader.

```php
<?php

class AutoloaderOverloader
{
   // ...

   public static function init(string $filterName): void
   {
       $loaders = spl_autoload_functions();
       foreach ($loaders as &$loader) {
           // Unregister each loader, so they can be re-registered in the same order.
           spl_autoload_unregister($loader);
           if (is_array($loader) && $loader[0] instanceof ComposerClassLoader) {
               // Replace Composer autoloader with our hijacking autoloader.
               $loader[0] = new self($loader[0], $filterName);
           }
       }
       // Processed all the loaders, re-register them with PHP in their original order.
       foreach ($loaders as $loader) {
           spl_autoload_register($loader);
       }
   }
}
```

Just like we described before in less technical terms, we:

- Fetch the list of registered autoloaders and iterate over them<br>
  `foreach (spl_autoload_functions() as &$loader)`
- If we detect that one of the autoloaders is Composer<br>
  `if (is_array($loader) && $loader[0] instanceof ComposerClassLoader)`
- We decorate it, replace it<br>
  `$loader[0] = new self($loader[0], $filterName);`
- Before re-registering each autoloader in their original order.<br>
  `spl_autoload_unregister($loader);` and `foreach ($loaders as $loader) spl_autoload_register($loader);`

To make all this come to life, we: load Composer, register our stream filter,
and initialise our autoloader overloader.

Now we carry on developing as normal - any class loaded after initializing
our autoloader will have its source code passed through our stream filter!

```php
// index.php
require_once __DIR__ . '/vendor/autoload.php';
stream_filter_register('my_compiler_filter', MyCompilerFilter::class);
AutoloaderOverloader::init('my_compiler_filter');
```

That was a lot of code to throw at you, but that's it for our overloader!

### Other Projects

```php
$executableCode = transformCode($sourceCodeFile);

eval($executableCode);
file_put_contents($compiledFile, $executableCode); require $compiledFile;
```

There are other projects out there that implement autoloader overloading.

Some evaluate the source code with `eval($executableCode)` but evaluating
strings as code using the eval() function is usually disabled on hardened PHP
installations, or at least highly discouraged.

Others write the generated code to disk before requiring the new file, But this
won't work on read-only filesystems, such as sandboxes containers where cache is
already warmed up on deployment.

Using stream filters is perhaps the most elegant. It's built into PHP's core
functionality and just works. Been there since at least PHP `5.0`. If already into
meta-programming by manipulating source code, streams aren't a challenge.

## What Next?

Now that we know we can modify the PHP code that actually gets executed by PHP
on-the-fly from within the application we are running, what's next? What
important work can we do given all this power?

We could implement PHP 7.4's short closures in PHP 7.3 using [Christopher Pitt](https://github.com/assertchris)'s [Preprocessor library](https://preprocess.io). His Preprocessor library takes invalid PHP code and turns it into valid PHP code:

```php
<?php

// Pre
$oddLetterCountWords = array_filter($fruits, ($fruit) => {
    return strlen($fruit) % 2;
});

// Compiled
$oddLetterCountWords = array_filter($fruits, function ($fruit) {
    return strlen($fruit) % 2;
});
```

It's a pretty unremarkable change, but we're transpiling invalid code into
something that PHP will understand. Building on the knowledge we've already gone
over, implementing this is a two-step process: include the library as a
dependency and then use it inside your stream filter.

```php
<?php

# composer require pre/short-closures:^0.8

// Alias for implementing and registering a stream filter.
public function transformCodeFilter($sourceFile) {
    return \Pre\Plugin\parse(file_get_contents($sourceFile));
}
```

## Obfuscation

We've established that as long as we return a string containing valid PHP code,
we can accept pretty much any input to manipulate even if that input is nothing.
Even encrypted source code!

```php
<?php exit('Source Code Protected.'); ?>

aFcZG1BJF0UNAxVSBAgAEREcERF/HxwJRRJTVQlSeSoADhlFHhUADREANR9QLyYMGwYXAxVMABxYeHMF
B0VUOxxNFQAbCz8mTw4fCwtLOhw1O1QdA2YBGhpEAFQaCg0pIABTGwoXUwRVbioKH0EdHFRkCAMAGxhU
NwBOBxcMGR4AHnNbb05DUlkAAUIYAQYAFRobERcMTw1POzpHOh4GGEVBIUUfGhFTFQBXFwYEBwBTH0xD
ADMLF1AGHVMLTw8qTUVBTlQAVE9SFhEWBxxFAhxXRTwGAQkfGlMRQEJoFgMZHU9FdwwdCAEPc0FSeQBJ
UwATZQk=
```

Which can be unencrypted on-the-fly into something resembling a normal PHP file.

```php
<?php declare(strict_types=1);

namespace App\Controller;

use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

class DefaultController
{
    public function __invoke(Request $request): Response {
        return new Response('Hello, World!');
    }
}
```

Once again, we have a fairly simple-ish stream filter method to what once seemed
like something that could only happen using extensions.

```php
<?php

function transformCodeFilter(string $sourceFile): string {
    $source = file_get_contents($sourceFile);
    return strpos($source, PREAMBLE_TEXT) !== 0
        ? $source
        : xorStringWithKey(
            base64_decode(substr($source, strlen(PREAMBLE_TEXT))),
            ENCRYPTION_KEY
        );
}
```

We grab the source code just like every other transformation we've done, and if
we don't need to decrypt the source code we immediately return it untouched.
But if we do detect the source code needs decrypting, by looking for the exit
statement at the beginning of the file (called the preamble) we pass it to
another function to decrypt it.

```php
<?php

const PREAMBLE_TEXT = "<?php exit('Source Code Protected'); ?>\n\n";
// The "encryption" key used by GitHub Enterprise. See:
// http://blog.orange.tw/2017/01/bug-bounty-github-enterprise-sql-injection.html
const ENCRYPTION_KEY = 'This obfuscation is intended to discourage GitHub Enterprise customers from making modifications to the VM. We know this \'encryption\' is easily broken.';
```

As for the decryption function itself, it iterates each byte of the source file and xor's it with the corresponding byte in an encryption key.
This isn't AES - it's meant to be simple. It also happens to be how GitHub protects their Enterprise source code (people always going to reverse engineer something if they really want, XOR encryption should be enough prove intent in court of law).

```php
function xorStringWithKey(string $str, string $key): string {
    for ($i = 0; $i < strlen($str); $i++) {
        $str[$i] .= $str[$i] ^ $key[$i % strlen($key)];
    }
    return $str;
}
```

## Performance like it's 1994 🎉

Remember that this is an experiment. Caching the transformation result from decrypting source code would be completely pointless.
Even with the Just-In-Time compiler coming in PHP8, source transformation or manipulating ASTs on the fly is never going to be fast.

But that’s not the point.

You can do some amazing things in PHP that it was never designed to do.

- Christopher Pitt’s Preprocessor library transpiles new and non-existant language features just like BabelJS.
- AOP allows you to inject logic at points in your code on-the-fly.
- Using source transformation and autoloader overloading you can not just manipulate existing code on-the-fly, but generate entirely new classes with code templates.
- ReactPHP allows you to write asynchronous code by using the native `stream_select()` function.
  - And Icicle does it using generators.

There are so many projects out there that push PHP beyond the limits of what people thought was possible for the language and the likelihood that the authors of these projects specifically knew what they were going to build ahead of time is very low.

## Question. Experiment. Have fun.

Question what's possible. Experiment with ideas. Have fun, like you did when you first became a developer.

You won’t know what’s possible until you push past the limits of the language.
Be curious, I hope you finish this article thinking it didn’t go into enough detail, and that you’re curious to know more.

Create terrible things, because if you don't the amazing things you create will just be average.

## Z-Engine

Since I wrote this talk, Lisachenko has come out with yet another crazy framework for PHP. [Z-Engine](https://github.com/lisachenko/z-engine) uses FFI to access internal structures of PHP itself; it loads the definitions of native PHP structures, like `zend_class_entry`, `zval`, etc and manipulates them in runtime.
If you can use streams to execute encrypted source code, imagine the possibilities of manipulating the internals of the PHP engine!
