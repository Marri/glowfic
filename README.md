[![Build Status](https://travis-ci.com/Marri/glowfic.svg?branch=master)](https://travis-ci.com/Marri/glowfic) [![Test Coverage](https://codeclimate.com/github/Marri/glowfic/badges/coverage.svg)](https://codeclimate.com/github/Marri/glowfic/coverage)

## README

### Dependencies

*   [Ruby](https://www.ruby-lang.org/en/) 2.6.6
*   [Rails](http://rubyonrails.org/) 5.2
*   [Redis](https://redis.io/topics/quickstart)
*   [PostgreSQL](https://www.postgresql.org/)

If you are not acquainted with Rails, it may help to go through the [Getting Started with Rails](http://guides.rubyonrails.org/v5.1/getting_started.html) tutorial for Rails 5.1.
If you wish to learn Ruby, try out the [quickstart](https://www.ruby-lang.org/en/documentation/quickstart/) guide provided on their website, or if you are already acquainted with various programming languages, try the [Learn X in Y minutes](https://learnxinyminutes.com/docs/ruby/) tutorial for Ruby.

This README mostly focuses on how to get started developing this project with Docker – in any environment with Docker installed you should be able to have the Glowfic server up and running.

### Setup Process

#### Cloning the repository

*   Ensure you have Git installed:

    `sudo apt-get install git` on Ubuntu

    `sudo pacman -S git` on Arch Linux

*   Clone the repository
    *   Enter a folder you want to clone the code to:

        `cd ~/Documents`

    *   Copy the code:

        `git clone https://github.com/Marri/glowfic.git`

(More specific details, such as if you have write permission and wish to use SSH instead of HTTPS, may be found on the GitHub site.)

#### Setting up the Glowfic site environment

If you haven't already, start by installing [Docker](https://docs.docker.com/install/) and [Docker Compose](https://docs.docker.com/compose/install/).

Then run `docker-compose up` within the glowfic directory.
This will set up a Postgres server, a Redis server, and a Glowfic app server which can talk to both of them.

There are some scripts for interacting with the Glowfic server in bin-docker.
You may want to add them to your PATH.
If you want, you can use [direnv](https://direnv.net/) to ensure that they're on your path only when you're in the glowfic server.
In any case, you'll use the `rake` and `rails` commands in that directory to set up and start the server.

If you have added these scripts to your PATH you can leave off "bin-docker/" in any commands that follow.

#### Setting up the database

Once you've taken these steps, you should be able to set up the contents of the glowfic database with some example data:
*   `bin-docker/rake db:setup`

This will set up the database and add some sample information – currently these are users, continuities, characters, galleries, icons and templates; no posts will be created.

If you encounter an error involving the 'citext' extension:

*   Ensure the postgres container is running, with `docker-compose up postgres &`
*   Execute `docker-compose exec postgres psql`, and then in the prompt that appears:
*   `CREATE EXTENSION IF NOT EXISTS citext;`

You will need to re-run `bin-docker/rake db:migrate`.

### Executing the server

The server should have started itself when you ran `docker-compose up`.
When it's started, go to [http://localhost:3000/](http://localhost:3000/), where you should see a local copy of the Constellation.
To stop the server, either close the Terminal or use `Ctrl+C` to stop the process.

### Running tests

To run tests, go to the root of the directory (the 'glowfic' folder) and execute the command:

*   `bin-docker/rake spec`.

This will go through the [rspec](http://rspec.info/) tests.

If you encounter a `PG::UndefinedTable` error, mentioning that a relation doesn't exist, ensure you've also migrated your test database.
This can be done with:

*   `docker-compose run -e RAILS_ENV=test web rake db:migrate`

After this, you should be able to re-run the tests.

### Staying up to date

The code updates quite frequently.
To make sure you're using and developing against the latest version, you'll need to download the updated copy, update the gems, and possibly even update your version of Ruby.

First, go to the glowfic folder and download the latest code:

*   `git pull`

Then look at this README again, to make sure the version of Ruby hasn't changed; alternatively, in case this file is not up to date, look at the top of the `Gemfile` file, where it states the version of ruby.
As of writing, this is `ruby '2.6.6'`.
If it has changed, you can rebuild the glowfic image with:

*   `docker-compose stop`
*   `docker-compose build`
*   `docker-compose up`

Now, update the gems used for the project:

*   `bin-docker/bundler`

And finally, run any database migrations that might have been added in the meantime:

*   `bin-docker/rake db:migrate`

You should now be able to execute the server, as before but now with the latest updates.

### Validation tools

We use the following tools to make sure our code is clean and standards-ctompliant:

* [html-proofer](https://github.com/gjtorikian/html-proofer)
* The [W3 HTML validator](https://validator.w3.org/)
* [traceroute](https://github.com/amatsuda/traceroute)
* [rails_best_practices](https://github.com/flyerhzm/rails_best_practices)
* [haml-lint](https://github.com/sds/haml-lint)
* [sass-lint](https://github.com/sasstools/sass-lint)

CodeClimate runs the following tools automatically:
* [brakeman](https://github.com/presidentbeef/brakeman)
* [bundler-audit](https://github.com/rubysec/bundler-audit)
* [duplication](https://github.com/codeclimate/codeclimate-duplication)
* [ESLint](https://eslint.org/)
* [fixme](https://github.com/codeclimate/codeclimate-fixme)
* [Rubocop](https://github.com/rubocop-hq/rubocop)

Tools we do not currently use but are interested in evaluating:
* [bullet](https://github.com/flyerhzm/bullet)
* [Reek](https://github.com/troessner/reek) and [Flog](https://github.com/seattlerb/flog) if they're not already included by CodeClimate or other gems (Marri's brain thinks they might be, the way flay is in duplication, but isn't citing its sources)
* [Reek's brother and sister gems](https://github.com/troessner/reek#brothers-and-sisters)

### Attribution

We make use of the [famfamfam silk](http://www.famfamfam.com/lab/icons/silk/) pack of icons, which is licensed under a Creative Commons Attribution license, including some icons that have been modified from the originals.
These can be found in various locations, including in the dropdown menu in posts.
