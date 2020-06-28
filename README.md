<img src="assets/static/images/favicon.png" alt="" width="200" />

# Remit

A self-hosted web app for [commit-by-commit code review](https://thepugautomatic.com/2014/02/code-review/), written using [Phoenix](https://www.phoenixframework.org/) [LiveView](https://github.com/phoenixframework/phoenix_live_view).

## Table of contents

* [Usage](#usage)
  * [How it all works](#how-it-all-works)
  * [Why commit-by-commit code review?](#why-commit-by-commit-code-review)
  * [Setting up Fluid.app](#setting-up-fluidapp)
  * [Without Fluid.app](#without-fluidapp)
  * [Stats API](#stats-api)
* [Setup](#setup)
  * [Heroku setup](#heroku-setup)
  * [Adding webhooks](#adding-webhooks)
  * [Automatically removing old data](#automatically-removing-old-data)
  * [Migrating from the "Review" app](#migrating-from-the-review-app)
* [Development](#development)
  * [Development setup](#development-setup)
  * [Faking new data coming in via webhook](#faking-new-data-coming-in-via-webhook)
  * [Working on the connection detection](#working-on-the-connection-detection)
  * [Updating dependencies](#updating-dependencies)
  * [Common production tasks](#common-production-tasks)
    * [Deploying](#deploying)
    * [IEX console](#iex-console)
* [Meta](#meta)
  * [The name](#the-name)
  * [What came before](#what-came-before)
  * [License](#license)

## Usage

Learn what Remit is for and how to use it.

### How it all works

You'll deploy your own copy of Remit to somewhere like Heroku, and you'll set up GitHub webhooks so it tells Remit about all commits and commit comments from then on.

This lets Remit show lists of commits and comments.

Clicking a commit opens the commit page on GitHub, where you can write comments either line-by-line or on the commit as a whole. You can mark commits as reviewed.

Remit also shows you comments and lets you mark these as resolved, so you don't miss the feedback you get. You'll see comments on commits you co-authored, replies in comment threads you've participated in, and @mentions. You can even @mention yourself if you look at your own commit and spot something.

When new commits and comments arrive, or when a co-worker starts and finishes a review, you see it all in real time.

Please see the "Settings" screen in Remit for details about how Remit figures out which user(s) every commit and comment belongs to.

### Why commit-by-commit code review?

See this blog post: ["The risks of feature branches and pre-merge code review"](http://thepugautomatic.com/2014/02/code-review/)

### Setting up Fluid.app

We recommend putting Remit inside [Fluid.app](https://fluidapp.com/) or equivalent so you can see Remit and the GitHub commit pages side-by-side. (We can't put GitHub inside an iframe, because they disallow it.)

Fluid.app is macOS only. Please do contribute instructions for other platforms.

* Install [Fluid.app](http://fluidapp.com/). You can use Homebrew: `brew cask install fluid`
* Launch Fluid.app, create a new app:
  * The URL should be `https://github.com`.
  * Use any name and icon you like – we recommend "Remit" and [this icon](assets/static/images/favicon.png).
  * Let it launch the app.
* Open your app's preferences and configure it like this:
  * Whitelist:
    * Allow browsing to any URL
  * Left:
    * Enter the Remit URL as home page, including the `auth_key` parameter. E.g. `https://MY-REMIT.herokuapp.com/?auth_key=MY_AUTH_KEY`
    * Navigation bar: is always hidden
    * Clicked links open in: current tab in current window
* In the main app (e.g. "Remit") menu, choose "User Agent > Google Chrome" – otherwise GitHub may disable certain features, like commenting on a specific line.

### Without Fluid.app

Links to commits will open in the same browser window/tab every time. So after clicking a link the first time, you can put this tab/window side-by-side with the Remit window (typically by dragging the tab out of the tab bar into its own window).

It won't be as convenient as with Fluid.app, but good in a pinch!

### Stats API

If you want some statistics for e.g. a dashboard or a chat integration, there's an API endpoint you may be interested in.

Just visit `/api/stats?auth_key=MY_AUTH_KEY` for some statistics.

The key is whatever `AUTH_KEY` you defined when you set up the app.

## Setup

Ready to set up Remit?

### Heroku setup

These instructions were written after the fact, so we may have missed something. Please open an issue or make a PR if you have any issues!

We'll assume you have a Heroku account and the `heroku` [command-line tools](https://devcenter.heroku.com/articles/heroku-cli).

    # Clone the repo.
    git clone https://github.com/barsoom/ex-remit.git
    cd ex-remit

    # Create a Heroku app.
    # Pick a unique name.
    # Pick a region close to you, for lower latency: https://devcenter.heroku.com/articles/regions
    heroku apps:create my-remit --region eu --buildpack hashnuke/elixir

    # We use "standard-1x" ($25/month) but you might get away with "free" ($0) or "hobby" ($7).
    # See: https://www.heroku.com/pricing
    heroku dyno:resize -a my-remit standard-1x

    heroku buildpacks:add https://github.com/gjaldon/heroku-buildpack-phoenix-static.git

    # Free plan with max 10 000 lines.
    # Probably good enough, because Remit can be configured to automatically remove old data.
    heroku addons:create heroku-postgresql:hobby-dev

    # The max on a free plan is 20.
    # We'll use 2 for one-off dynos like migrations and consoles, and 9 for the web dyno, so Heroku can run two side-by-side briefly during deploys.
    heroku config:set POOL_SIZE=9

    heroku config:set SECRET_KEY_BASE=`openssl rand -hex 32` AUTH_KEY=`openssl rand -hex 32` WEBHOOK_KEY=`openssl rand -hex 32`

    # Provide a GitHub "personal access token" (https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token)
    # from an account with access to all repos you will use in Remit.
    # This lets Remit fetch missing associated commits and comments when it receives a comment by webhook.
    heroku config:set GITHUB_API_TOKEN="yourtoken"

    # Optionally, set this to whatever value you prefer.
    # If you don't set it, nothing is removed automatically.
    heroku config:set REMOVE_DATA_OLDER_THAN_DAYS=100

    # Deploy!
    git push heroku

Once it's set up, visit e.g. <https://your-remit.herokuapp.com?auth_key=YOUR_KEY>.

### Adding webhooks

Add a webhook on each reviewed repo in GitHub.

You can do it manually, or you can write a script to do it – you can use the `GITHUB_API_TOKEN` you configured above, and these GitHub API endpoints may be useful:

* <https://developer.github.com/v3/repos/#list-organization-repositories>
* <https://developer.github.com/v3/repos/hooks/#create-a-repository-webhook>

When added manually, the hook should be something like:

    Payload URL: https://my-remit.herokuapp.com/webhooks/github?auth_key=MY_WEBHOOK_KEY
    Content type: application/json
    Secret: (left empty – it's part of the URL instead)
    Select events:
    - Commit comments
    - Pushes

Note that this is the `WEBHOOK_KEY` and not the `AUTH_KEY`!

You should see a happy green checkmark on GitHub, and if you click the hook, "Recent Deliveries" should show a successful ping-pong interaction.

### Automatically removing old data

To avoid growing out of your DB plan, set e.g.

    heroku config:set REMOVE_DATA_OLDER_THAN_DAYS=100

The app will schedule a recurring process (`Remit.Periodically`) to remove older data.

### Migrating from the "Review" app

Did you use our old [Review app](https://github.com/barsoom/review)? See `priv/repo/migrate_from_review.exs`.

## Development

Want to work on the Remit code?

### Development setup

Auctionet devs: This project is developed *outside* of the [Devbox](https://github.com/barsoom/devbox) VM, at the time of writing. But feel free to add Devbox support.

First time:

    # Ensure that `config/test.exs` and `config/dev.exs` have the right DB config for you.

    # Install deps and assets, create DB and migrate:
    mix setup

    # Verify that tests run:
    mix test

    # Start the server:
    mix phx.server

    # In a a separate shell, get some fake data via the webhook:
    mix wh.commits
    mix wh.comments

Every time:

    mix phx.server

Then visit <http://localhost:4000?auth_key=dev>

### Faking new data coming in via webhook

Just run either or both of these commands:

    mix wh.commits
    mix wh.comments

They default to adding just a few, but you can pass a count:

    # Add 100 commits via one webhook call.
    mix wh.commits 100

    # Add 100 comments via 100 webhook calls (GitHub sends one per call).
    # May not be listed exactly 100 times in the UI, because we list based on CommentNotifications.
    mix wh.comments 100

### Working on the connection detection

You probably want to temporarily set `code_reloading: false` in dev.exs to make sure Phoenix code reloading doesn't come into it.

To trigger a disconnection detection in dev, you can load Remit, turn off the Phoenix server for several seconds, then turn it back on. This should be detected as a disconnection and the page should be automatically reloaded. See `app.js`.

### Updating dependencies

Run:

    script/updatedeps

### Common production tasks

#### Deploying

Auctionet developers deploy by pushing to GitHub. [CI](https://github.com/barsoom/ex-remit/actions?query=workflow%3ACI) will automatically migrate and deploy.

Please note that we use [Heroku release phase](https://devcenter.heroku.com/articles/release-phase) – migrations run *before* the new app code is released.

### IEX console

Get a production IEX console:

    script/prodc

## Meta

More than you wanted to know!

### The name

* **Re**view com**mit**s
* *remit* in Oxford Dictionary of English:
  * "an item referred to someone for consideration"
  * "forgive (a sin)"

### What came before

We've reimplemented this app a few times to try out new tech:

* 2020: This one! Remit II in Phoenix LiveView (and also to try out [Tailwind](https://tailwindcss.com/))
* 2016: [Review](https://github.com/barsoom/review) in Phoenix/Elm
* 2014: [Remit I](https://github.com/henrik/remit) in Ruby on Rails with AngularJS and MessageBus
* 2014: [Hubreview](https://github.com/barsoom/hubreview) in Ruby on Rails with WebSockets

### License

[MIT](LICENSE.txt)
