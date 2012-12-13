 Select scripts from Oliver
============================
:Author: Oliver Schneider

About
-----
This folder contains a selection of scripts I am using to help me accomplish
certain tasks.

* ``makemcpp.cmd`` can be used to build MCPP_, a portable C preprocessor.
  The tool is great, but it looks like the project is dormant or dead.
  ``makemcpp.cmd`` relies on ``setvcvars.cmd`` found in the same folder.
* ``ollisign.cmd`` is the script I am using to sign programs.
* ``setvcvars.cmd`` is a very nifty script that allows you to detect the
  given Visual C++ installation, given by the version number - e.g. 8.0
  for Visual C++ 2005, and call its ``vcvars32.bat`` or ``vcvarsall.bat``
  and thus make the build environment available to you (``devenv.exe``,
  ``nmake.exe`` etc). This is very useful if you don't want to hardcode
  the installation paths to Visual C++ into your build scripts. Instead
  ``setvcvars.cmd`` will use ``reg.exe`` (must be downloaded on Windows
  2000, but comes on board starting with XP) to detect the installation
  path.
* the folder ``speedcommander-includes`` contains some VBA snippets that
  I use for my favorite file manager on Windows: SpeedCommander_. SC as
  it is affectionately called by its fans (me included) allows to automate
  tasks by means of VBA macros. In order to not repeat the common code in
  each and every macro, I wrote these "include" files. Make sure to read
  the ``README.txt`` in the folder to see how this works.

License
-------
The scripts are placed into the PUBLIC DOMAIN (CC0).

.. _MCPP: http://mcpp.sourceforge.net/
.. _SpeedCommander: http://www.speedproject.de/enu/