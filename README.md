What is this?
=============

  ldap-torture is a set of perl libraries and tools to torture your ldap
installation, and verify that it is up to your production standards!

  When we say torture we really mean send randomized search, inserts,
delete, moves, ... with an high degree of configurability, with the
idea of producing a load that might be similar to what you will experience
in your production environment.

  The focus of the tool is in correctness and finding problems: for each
operation, it verifies that the result is as expected, or close enough
to what is expected. It reports crashes or unexpected results.

  If you need a loadtest instead, verifying how many requests per seconds
your ldap installation can take, this might not be the right tool. However,
it might be a reasonable starting point. 

  It was written a long time ago, around 2004, and used a few times
since, and finally uploaded on a public repository.


Getting started
===============

We assume here that you have a Debian based system, you want to test
openldap, and you are ok with using the included example config file.
For other systems, the instructions here should be enough to get you
started.

1) Install openldap and useful tools:

   $ sudo apt-get install slapd ldap-utils

2) Create a database directory (has to be the same one specified in
   your slapd.conf file):

   $ mkdir -p /tmp/slapd

3) Create an empty ldap database with basic data:

   $ /usr/sbin/slapadd -f ./examples/slapd.conf < ./examples/base.ldiff

4) Start slapd. I generally suggest to start it with debugging enabled
   until you can get it running successfully:

   $ /usr/sbin/slapd -d'Any' -f./examples/slapd.conf -h "ldap://127.0.0.1:9009/"

   Note that this will start slapd listening on port 9009 on localhost
   only.

5) Verify that slapd is up and running:

   $ ldapsearch -x -H "ldap://127.0.0.1:9009/" -b dc=test,dc=it

   Note that slapd has been configured to ask for no password. An error here
   most likely means that slapd had some trouble starting. Errors are not
   always well reported by slapd, you might find the information you need
   to troubleshoot by scrolling up the screen where you started slapd,
   or checking /var/log/syslog (as root).

6) Once ldapsearch succeeds, you are ready to rock! you probably want
   to killall -TERM slapd, and restart it without -d Any, so to avoid
   spamming your screen.

7) Run ldap-torture.


Issues? Questions? Updates?
===========================

Please use the github pages. In particular, you can find:

   * Latest tarball and all previous versions:
     https://github.com/ccontavalli/ldap-torture/tags

   * Latest source code:
     https://github.com/ccontavalli/ldap-torture/

   * Report issues / ask questions:
     https://github.com/ccontavalli/ldap-torture/issues
     
