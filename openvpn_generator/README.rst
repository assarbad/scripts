﻿===================================================
 Little helper script to generate OpenVPN profiles
===================================================
:Author: Oliver Schneider

About
-----

This folder contains a Python script that uses Jinja2 to create one profile
per region in which Witopia offers servers.

Instructions
------------

* Get the ``.py`` file from this folder
* Fetch your personalVPNPro_CN*.zip from ``my.witopia.net``
* Extract the ZIP into the same folder as the ``.py``
* Run the ``.py`` from that folder

The result should be a number of OpenVPN profiles, one per region, with
embedded ``ca``, ``cert`` and ``key`` values. The files are named after
the region and have the file extension ``.ovpn``.

Customization
-------------

The order of the ``servers`` list per key of the ``dict`` in the ``.py``
governs the order of the ``remote`` stanzas in the resulting profile.

The first run will create a ``.ini`` and a ``.ovpn.j2`` file in the folder
where the script resides. These files can be customized, but usually don't
have to be changed.

Requirements
------------

The script requires Python 2.7 and the Jinja2 Python module. It was only
tested on Linux.

License
-------

The script is placed into the PUBLIC DOMAIN/CC0.
