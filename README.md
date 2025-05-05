# SRB2Circuit.eu

SRB2Circuit.eu was an SRB2 server dedicated to the circuit racing gamemode.
The server was live from 2020 to 2025, and had an active community of racers on [Discord](https://discord.gg/wNwg9vk).
The server binary was modded to store times from each player in a database, which allowed for dynamic leaderboards which were showed on the website srb2circuit.eu (please take care when visiting the link, it might be registered by someone else).

This repo describes the srb2circuit.eu server configuration and contains a full back-up of the database with high scores and backups of the leaderboards from the time when the server was shut down. This repository should enable anyone to rehost the server including all it's components to revive a future SRB2 circuit racing community. If you miss anything, do not hesitate to open an issue!

## Components

* [SRB2 server](https://github.com/srb2circuit-eu/SRB2): The SRB2 server is the core of the system, it is a modified version of SRB2. The server saves scores in a Mariadb database.
* [Website](https://github.com/srb2circuit-eu/website): The website connects to the same Mariadb database to analyse and display leaderboards.
* [Discord bot](https://github.com/srb2circuit-eu/discord_bot): The Discord bot allows users to query leaderboard information from the Discord community. The bot uses the API of the website.
* [Client-side lua script](https://github.com/srb2circuit-eu/SRB2/blob/speedrun_server/src/luascripts/CircuitEU-v1.9.lua): To display the current highscore for a given map and skin, the server binary sends the highscores through a special chat message. This message is filtered by a Lua script client-side and the contained information is used to display a leaderboard in the game. In addition, this lua script also contains a library called `mapvote`, which is based on the works of Krabs. This script is based on the following scripts: [highscore_show](https://github.com/srb2circuit-eu/SRB2/blob/speedrun_server/src/luascripts/highscore_show.lua), [mapvote](https://github.com/srb2circuit-eu/mapvote).

## Repository contents

This section describes the contents of this repository.

* **leaderboard_archive**: An archive of the leaderboard on srb2circuit.eu at the shutdown time of the server.
* **sql**: A backup of the database of the website at the shutdown time of the server.
* **srb2_config**: The configuration and addons used by the SRB2 server(s). The `default1.cfg` configuration is the main server config. The `chars.cfg` is the "modded friday" configuration, where character mods were added. The `thicc.cfg` is the configuration for the Thicc server, which is a different type of Circuit racing.
* **webserver**: The configuration for the web server hosting the srb2circuit.eu website.
* **systemd**: The SystemD unit files to run the SRB2 servers and discord bot. The servers are executed in a screen session to allow manual interaction after the service is started. The timers automatically stop the main server after thursday and start the "modded friday" server.
* **etc**: Contains the /etc/hosts file of the server. This file contains an entry for `srb2circuit.eu`, which was used to redirect the srb2circuit.eu domain to the local host of the server. This was my way of allowing srb2circuit.eu to be reached from within an LXC container, while the domain actually points to the host system. You probably will not need this in a new set-up, but it is included for completeness.
* **reverse_proxy**: Since the SRB2circuit server was hosted in an LXC container and the IP address points to the host server, some forwarding was necessary to reach the server. An Apache server was used as a reverse proxy using the configuration in this directory. You will not need this if your server has it's own public IP address.

## Installation instructions

* Set up a Mariadb/Mysql server and database
* Change the [SRB2 server](https://github.com/srb2circuit-eu/SRB2) source code to use your database. See [highscores.md](https://github.com/srb2circuit-eu/SRB2/blob/speedrun_server/highscores.md) for instructions.
* Change the [Website](https://github.com/srb2circuit-eu/website) source code to use your database and deploy it. Modify `app.wsgi` to point to the location of the website repo on your server.
* Copy the [SRB2 server configuration](https://github.com/srb2circuit-eu/srb2circuit.eu/tree/main/srb2_config) and SRB2 server binary to your server.
* Copy the [SystemD](https://github.com/srb2circuit-eu/srb2circuit.eu/tree/main/systemd) unit files to ~/.config/systemd/user/.
* Change the unit files to match the location and configuration of your server (`default1.cfg` was the config file of the main SRB2Circuit server in normal operation) and start+enable the services using  and `systemctl --user start <service>`. Optionally start the timers using
`systemctl --user enable --now <service>.timer` to enable "modded friday".
* Change the source code of the [Discord bot](https://github.com/srb2circuit-eu/discord_bot) to match the location of your website. Deploy the Discord bot to your server. Start the [SystemD unit file for the Discord bot](https://github.com/srb2circuit-eu/srb2circuit.eu/blob/main/systemd/srb2_discordbot.service).
* Integrate the Discord bot with your Discord community.
* Modify the source code of the website to point to your Discord community.
