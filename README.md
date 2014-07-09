dashing-openstack
============

## Description

dashing based dashboard displaying status of an openstack cluster.

==============

Overview
--------

This repo contains the widgets, the dashboard definition, and the required data collection jobs.

It provides one single dashboard with the following components:

* Nagios or Icinga monitoring status (critical, warning)
* Usage per tenant (vcpus, memory, instances, floating ips)
* Global cluster usage (vcpus, memory)

Screenshots
-----------

#![image](https://raw.githubusercontent.com/rochaporto/dashing-openstack/master/public/openstack-dashing.png)

Requirements
------------

Aviator, an openstack API in ruby.

OpenStack credentials with appropriate privileges for tenant list and tenant usage queries.

Setup
-----

Start by getting [dashing](http://shopify.github.io/dashing/).

You can find more details in the website, but something like this should work (ubuntu):

    apt-get install rubygems ruby-bundler nodejs
    gem install dashing

Limitations
-----------

Dashing seems to go out of memory on devices like raspberrypi. A workaround
was implemented in the ceph dashboard, just add `?refresh=X` to the url to
have it refreshed every X seconds.

CPU and Memory allocation ratios have to be defined in the config file (would be better to get them from an API call).

Development
-----------

All contributions more than welcome, just send pull requests.

License
-------

GPLv3 (check LICENSE).

Contributors
------------

Ricardo Rocha <ricardo@catalyst.net.nz>

Support
-------

Please log tickets and issues at the [github home](https://github.com/rochaporto/dashing-openstack/issues).

Packaging
-------

Simple debian/ubuntu packaging is provided, [check here](docs/ubuntu.md) for instructions.
