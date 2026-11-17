# Bonaparte test app

This application helps to generate a full and complete auto parts catalog to reuse it in selling marketplaces
or to improve the quality of original catalogs

## Requirements

- Ruby 3+ (This app was built on Ruby 4.0.0)
- Rails 8+
- PostgreSQL
- SerpApi API key (You need to create an account on https://serpapi.com/)
- OpenAI API Key (You need to creat an OPENAI API Key https://openai.com/)

`NOTE: You must put your keys on a .env file on projet's root (not included on repository).`

## How to install

To build this app on your local machine follow the next commands:

`$ bundle install`

This command will install the gems (dependencies) of the application, so you can use it later.

## How to run

### Prepare database

`$ rails db:prepare`

When you have already configured your database and your credentias, please run the dev server using the following command:
`$ ./bin/dev`

The command above starts up the dev server and the background procces to make this app works.

You can follow the application by this link on your browser: [localhost:3000](localhost:3000) or [127.0.0.1:3000](127.0.0.1:3000)
