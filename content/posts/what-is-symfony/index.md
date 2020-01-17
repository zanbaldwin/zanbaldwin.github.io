---
title: 'What Is Symfony? '
date: '2019-03-11'
author: 'Zan Baldwin'
cover: 'symphony.jpg'
description: |
    Brief overview of a standard Symfony project and components for former Drupal 7 coworkers of mine.
---

This article is adapted from a presentation given to coworkers that were Drupal 7 developers. It was designed to give a
brief overview of a standard Symfony project whilst explaining some more technical aspects that the documentation
wouldn't go into.

# Components

Symfony is a toolbox of (over 50) decoupled and reusable software components on which the best PHP applications are
built, with outstanding documentation, comprehensive test coverage and contribution guidelines.

Examples of components include:

- Dependency Injection
- Console
- Event Dispatcher
- Routing

Projects that are using Symfony components include:

- Drupal
- Laravel
- phpBB
- Joomla!
- Yii Framework
- Magento
- Facebook SDKs
- Google SDKs
- Composer
- CakePHP

## Framework

The framework is a methodology (or "assembly guide") for web applications built on top of the components as glue-code to
bring them all together in a structured approach. It efficiently and effectively guarantees stability, maintainability
and upgradability of complex applications.

# Philospohy

The philosophy of Symfony is to embrace and promote professionalism, best practices, standardization and
interoperability of applications.

## Community

Symfony is a huge and diverse community of over 600,000 developers across 120 countries. It is committed to fostering an
open and welcoming environment for everyone, with an appropriate Code of Conduct, Diversity Initiative, support system,
user groups, and 9 conferences a year spread across 4 continents.

# Structure

A Symfony application has a very simple file structure.

```
├ bin                Binary executables
│  └ console         Entrypoint to Symfony via CLI (equivalent to Drush or similar)
├ config             All configuration files go in here: services, routing, package config, etc.
│  └ …               By default, most files in this directory are written in YAML
├ public             Webroot directory
│  └ index.php       Entrypoint to Symfony via HTTP
├ src                All project source code goes in here
│  ├ Controller
│  │  └ .gitignore   
│  └ Kernel.php      Core of Symfony; sets up bundles, config, and provides service container
├ var                Variable data: logs, cache, compiled code
├ vendor             Third-party package dependencies
├ .env               Default values for project-specific environment variables
├ .gitignore
├ composer.json
├ composer.lock
└ symfony.lock       Unknown. Something to do with Flex. We ignore it.
```

## Flex and Recipes

Modern Symfony (`v4.0`+) relies heavily on Composer. **Flex** is a Symfony-specific Composer plugin that provides extra
steps ("**recipes**") to execute when installing specific, third-party packages.

### Example Recipe (Doctrine)

The recipe executed during the installation of the package doctrine/doctrine-bundle performs three steps:

1. Registers the Doctrine bundle with your application’s kernel.
2. Creates the file config/packages/doctrine.yaml
3. Adds the environment variable DATABASE_URL to your .env file.

These recipes feel like magic at first, but follow predetermined steps defined in the `symfony/recipes` repository.

They set up sensible defaults so that a package can be installed and used without having to invoke some arcane Google-fu
to figure out what configuration options go where.

> Magic _(programming)_ `/ˈmadʒɪk/`
>
> An informal term, often carrying bad connotations, for heavy abstraction that hides the true behaviour of code. The
> action of such abstractions is described as being done "automagically".

Many advanced process in Symfony are abstracted away from the developer (DX initiative) and can seem like magic, but are
logical and customisable once you start exploring.

# Getting Started

The skeleton repository for setting up a new Symfony project (`git://github.com/symfony/skeleton`) contains just two
files: `composer.json` and `composer.lock`.

Running composer install will:

1. Install the project’s dependencies to the `vendor/` directory. To start off with, our application has 5 direct
   dependencies:
   - `symfony/console`,
   - `symfony/dotenv` for project-specific environment variables,
   - `symfony/flex`,
   - `symfony/framework-bundle`, and
   - `symfony/yaml` for reading configuration files written in YAML (the default).
2. The `symfony/flex` package is installed and the custom Composer plugin will run, fetching and executing any recipes
   that exist for the installed dependencies.

The recipe for the `symfony/framework-bundle` package [bootstraps the project structure][bootstrap-recipe], resulting in
the file structure we saw before.

## Bundles

_Plugins, modules, extensions... etc._

They can provide any functionality the main application can, bundled into a reusable, distributable package. By default,
only the FrameworkBundle is included.

Bundles used to be first-class citizens in Symfony, but they are now abstracted away. You don’t need to know much about
bundles except they provide functionality and, with Flex, most of them automagically configure themselves with sensible
defaults when they are installed through Composer.

- Templating is provided via the **Twig bundle**.
- Logging is provided via the **Monolog bundle**.
- Database functionality is provided via the **Doctrine bundle**.
- Email is provided by the **SwiftMailer bundle** (soon to be deprecated in favour of the MIME component in `4.3`+).
- Security is provided by the **Security bundle**.

# Dependency Injection

Every object-oriented PHP project contains useful objects that do work: the Twig object renders templates and the
Monolog object logs messages. These objects are called services and live inside a centralised registry called a service
container.

Services are the most important part of Symfony. Using the previous examples, the Twig bundle configures and registers
the templating service with the service container, and the Monolog bundle configures and registers the logger service
with the service container.

```yaml
services:

    email_transport_service:
        class: 'App\Email\Transport'
        arguments: [ '%smtp_server%', '%username%', '%password%' ]

    my_emailer_service:
        class: 'App\Email\Emailer'
        arguments: [ '@email_transport_service' ]
        calls:
            - [ 'setLogger', [ '@logger' ]]
```

> By default, configuration in Symfony is written in YAML. It’s also possible to write configuration in XML or pure PHP
> if prefered. There is no performance penalty for using any format, configuration is parsed and compiled before being
> dumped as pure PHP in the cache.
>
> Symfony is also extensible enough for custom config loaders to be written for other configuration formats such as JSON
> or TOML if you happen to be a masochist.
  
## Service Definitions

Service definitions describe how a service (PHP object) should be constructed, referencing other services
`@service_name` and configuration `%parameter%`’s. Other configuration options for service definitions include:

- Aliases
- Factories
- Post-instantiation configurators
- Lazy-loading with proxies
- Service decorators
- Subscribers
- Locators
- Tagging
- Synthetic services

## Service Configuration

Using the example above, requesting the service `my_emailer_service` from the service container will return an
instantiated class of type `App\Email\Emailer`, with the `service email_transport_service` injected into its constructor
(which has, in turn, been constructed with the appropriate parameters injected into that constructor), and the service
`logger` injected into its `setLogger()` method.

## Application Service Configuration

The default settings that come with `symfony/skeleton` (or more precisely, the `symfony/framework-bundle` recipe that
gets executed when installing `symfony/skeleton`) are:

```yaml
# This file is the entry point to configure your own services.
# Files in the packages/ subdirectory configure your dependencies.

# Put parameters here that don't need to change on each machine where the app is deployed
# https://symfony.com/doc/current/best_practices/configuration.html#application-related-configuration
parameters:

services:
    # default configuration for services in *this* file
    _defaults:
        autowire: true      # Automatically injects dependencies in your services.
        autoconfigure: true # Automatically registers your services as commands, event subscribers, etc.

    # makes classes in src/ available to be used as services
    # this creates a service per class whose id is the fully-qualified class name
    App\:
        resource: '../src/*'
        exclude: '../src/{DependencyInjection,Entity,Migrations,Tests,Kernel.php}'

    # controllers are imported separately to make sure services can be injected
    # as action arguments even if you don't extend any base controller class
    App\Controller\:
        resource: '../src/Controller'
        tags: ['controller.service_arguments']

    # add more service definitions when explicit configuration is needed
    # please note that last definitions always *replace* previous ones
```

### Auto Service Loading

Automatic service loading allows entire namespaces/directories to be scanned and automatically added as services to the
service container, without the need to manually specify service definitions for every single class.

```yaml
services:

    # makes classes in src/ available to be used as services
    # this creates a service per class whose id is the fully-qualified class name
    App\:
        resource: '../src/*'
        exclude: '../src/{DependencyInjection,Entity,Migrations,Tests,Kernel.php}'
```

### Autowiring

Each service defined in the service container must have a unique name (its **service ID**); it’s convention to use the
class name.

Autowiring is a service container feature (enabled by default) that tries to automatically configure the value to inject
for every service’s constructor arguments that has not been manually defined (as is the case with automatic service
loading).
Each service’s constructor is scanned for argument type-hints; if the type-hint exactly matches the ID of a service
registered with the service container, it is used. This is why using the class name as the service ID is the convention.

```yaml
services:

    # Service identifier same as FQCN, no need to specify "class" option.
    App\Email\Transport:
        arguments: [ '%smtp_server%', '%username%', '%password%' ]

    App\Email\Emailer:
        # Arguments no longer have to be specified manually.
        autowire: true
        # Calls can also be autowired using the @required annotation.
        calls:
            - [ 'setLogger', [ '@logger' ]]

    # Alternatively, apply autowiring to all services defined in this file.
    _defaults:
        # Autowire: automatically inject dependencies in your services.
        autowire: true

```

If an interface is implemented by one (and only one) concrete class, the service container is smart enough to realise
that when you type-hint an interface you mean the concrete class - it will register the interface as an **alias** of the
service for the concrete class so that autowiring still works. If more than one concrete class implements the interface,
manual configuration is required.

### Auto Configuration

Auto configuration is another service container feature that will apply generic configuration to all services that
implement a specific interface.

Custom auto configuration is not often used in applications - its main use is for Symfony to automatically find,
register and use classes you create.

```yaml
services:

    # Default configuration for services in *this* file.
    _defaults:
        # Automatically registers your services as commands, event subscribers, etc.
        autoconfigure: true
```

```php
<?php declare(strict_types=1);

namespace App;

use Symfony\Component\DependencyInjection\ContainerBuilder;
use Symfony\Component\HttpKernel\Kernel as BaseKernel;

class Kernel extends BaseKernel
{
    // ...
    
    protected function build(ContainerBuilder $container): void
    {
        $container->registerForAutoconfiguration(MyInterface::class)->addTag('my_custom_service_tag');
        $container->addCompilerPass(new MyCompilerPassThatHandlesTaggedServices);
        parent::build($container);
    }
}
```

For example, making an event listener implement `EventSubscriberInterface` results in Symfony automatically registering
and executing your event listener with no additional configuration needed.

```php
<?php declare(strict_types=1);

namespace App\Listener;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpKernel\Event\GetResponseEvent;
use Symfony\Component\HttpKernel\Exception\NotAcceptableHttpException;
use Symfony\Component\HttpKernel\KernelEvents;

class JsonListener implements EventSubscriberInterface
{
    /** {@inheritdoc} */
    public static function getSubscribedEvents(): array
    {
        return [
            KernelEvents::REQUEST => ['checkContentTypeIsJson', 34],
        ];
    }
    
    public function checkContentTypeIsJson(GetResponseEvent $event): void
    {
        $request = $event->getRequest();
        if ($request->headers->get('Content-Type') !== 'application/json') {
            throw new NotAcceptableHttpException('This is an API, fool!');
        }
    }
}
```

### Configuration

Fire-and-forget: default configuration is enough 95% of the time. Just create classes and type hint everything.

### Compilation

Eventually, all that configuration gets "compiled" into executable, raw PHP files.

Compilation means YAML is not parsed on each request.

{{< highlight yaml >}}
services:

    _defaults:
        autowire: true
        public: false

    League\OAuth2\Server\AuthorizationServer:
        arguments:
            $privateKey: '@oauth2.private_key'
            $encryptionKey: '%env(APP_SECRET)%'
{{< /highlight >}}

Here be dragons:

```php
<?php

use Symfony\Component\DependencyInjection\Argument\RewindableGenerator;
use Symfony\Component\DependencyInjection\Exception\RuntimeException;

// This file has been auto-generated by the Symfony Dependency Injection Component for internal use.
// Returns the private 'League\OAuth2\Server\AuthorizationServer' shared autowired service.

$this->privates['League\OAuth2\Server\AuthorizationServer'] =
$instance = new \League\OAuth2\Server\AuthorizationServer(
    ($this->privates['App\OAuth2\Respository\ClientRepository']
        ?? $this->load('getClientRepository2Service.php')),
    ($this->privates['App\OAuth2\Repository\AccessTokenRepository']
        ?? $this->load('getAccessTokenRepositoryService.php')),
    ($this->privates['App\OAuth2\Repository\ScopeRepository']
        ?? $this->load('getScopeRepositoryService.php')),
    new \League\OAuth2\Server\CryptKey(
        $this->getEnv('resolve:PRIVATE_KEY_PATH'),
        $this->getEnv('PRIVATE_KEY_PASS'),
        false
    ),
    $this->getEnv('APP_SECRET')
);
$a = ($this->private['App\OAuth2\Repository\RefreshTokenRepository']
    ?? $this->load('getRefreshTokenRepositoryService.php'));
$b = new \League\OAuth2\Server\Grant\RefreshTokenGrant($a);
$c = new \DateInterval($this->getEnv('OAUTH2_REFRESH_TOKEN_DURATION'));
$b->setRefreshTokenTTL($c);
$d = new \DateInterval($this->getEnv('OAUTH2_ACCESS_TOKEN_DURATION'));
$e = new \League\OAuth2\Server\Grant\PasswordGrant(
    ($this->privates['App\OAuth2\Repository\UserRepository']
        ?? $this->load('getUserRepository2Service.php')),
    $a
);
$e->getRefreshTokenTTL($c);
$f = new \League\OAuth2\Server\Grant\AuthCodeGrant(
    ($this->privates['App\OAuth2\Repository\AuthCodeRepository']
        ?? $this->load('getAuthCodeRepositoryService.php')),
    $a,
    new \DateInterval($this->getEnv('OAUTH2_AUTH_CODE_DURATION'))
);
$f->setRefreshTokenTTL($c);
$instance->enableGrantType($b, $d);
$instance->enableGrantType(new \League\OAuth2\Server\Grant\ClientCredentialsGrant(), $d);
$instance->enableGrantType($e, $d);
$instance->enableGrantType($f, $d);
return $instance;
```

# Controllers

The main entry point for application logic.

Controllers are what get triggered when a route is matched. I have no idea what the equivalent in Drupal is because I
wasn’t listening as much as I should have.

## Model-View-Controller

- Fetch a model and manipulate it by applying this endpoint’s application logic.
- Pass model to template to be rendered.
- Return rendered template as response.

```php
<?php declare(strict_types=1);

namespace App\Controller;

use App\Form\Type\User\EditUserType;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\ControllerTrait;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class UserController
{
    use ControllerTrait;
    
    private $em;
    
    public function __construct(EntityManagerInterface $em)
    {
        $this->em = $em;
    }
    
    public function editAction(Request $request, int $userId): Response
    {
        if (null === $user = $this->em->findById(User::class, $userId)) {
            throw new NotFoundHttpException;
        }
        $form = $this->createForm(EditUserType::class, $user);
        $form->handleRequest($request);
        if ($form->isSubmitted() && $form->isValid()) {
            // Do stuff to update the user...
            $this->em->persist($user);
            $this->em->flush();
        }
        return $this->render('edit_user.html.twig', [
            'user' => $user,
            'form' => $form->createView(),
        ]);
    }
}
```

## Action-Domain-Responder

- Actions (controllers) should only be concerned with converting a request into a response.
- Data-in, data-out.
- Anything else is outside the scope of an action.

```php
<?php declare(strict_types=1);

namespace App\Controller\Webhook;

use App\Form\Type\WebhookType;
use App\Repository\WebhookRepository;
use App\Response\ApiResponse;
use App\Response\ApiResponseInterface;
use App\Validator\ValidationHttpException;
use Ramsey\Uuid\UuidInterface;
use Symfony\Bundle\FrameworkBundle\Controller\ControllerTrait;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class UpdateWebhookAction
{
    use ControllerTrait;

    private $repository;
    
    public function __construct(WebhookRepository $repository)
    {
        $this->repository = $repository;
    }
    
    public function __invoke(Request $request, UuidInterface $webookUuid): ApiResponseInterface
    {
        if (null === $webhook = $this->repository->find($webhookUuid)) {
            throw new NotFoundHttpException;
        }
        
        $form = $this->createForm(WebhookType::class, $webhook);
        $form->handleRequest($request);
        
        if ($form->isSubmitted() && $form->isValid()) {
            $webhook = $this->repository->update($webhook, $form->getData());
            return new ApiResponse($webhook);
        }
        
        throw ValidationHttpException::fromForm($form);
    }
}
```

- Convert data in (request) to domain model.
- Pass model to application domain to perform business logic.
- Convert (or create if nothing returned) resulting domain model to a response model.
- Return response model, leaving the HTTP response to another service called the responder.

The responder will then determine how this data structure should be converted into a HTTP response according to the MIME
type requested by the end-user.

[bootstrap-recipe]: https://github.com/symfony/recipes/tree/master/symfony/framework-bundle/4.2
