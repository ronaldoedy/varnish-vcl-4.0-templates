## Varnish VCL v4.0 Templates

Intended to learn all the basis and providing support for most functionality, feel free to change it, take the bits you need or contribute with your own solution ;)
I also added a brief description of all the non commercial tools provided by the default installation in order to avoid googling to much :)

### Varnish non commercial Tools
--------------------------------
The following tools mentioned are available in a standard varnish installation:

1. [Shared memory log (SHMLOG)](#shmlog)
  * [VARNISHTOP](#varnishtop)
  * [VARNISHNCSA](#varnishncsa)
  * [VARNISHHIST](#varnishhist)
  * [VARNISHLOG](#varnishlog)
2. [Admnistration](#administration)
  * [VARNISHADM](#varnishadm)
3. [Global counters](#counters)
  * [VARNISHSTAT](#varnishstat)
4. [Misc](#misc)
  * [VARNISHTEST](#varnishtest)


#### Shared memory log (SHMLOG) ####
---------------------

##### VARNISHTOP #####
----------------------
The [varnishtop](https://www.varnish-cache.org/docs/trunk/reference/varnishtop.html) utility reads varnishd shared memory logs and presents a continuously updated list of the most commonly occurring log entries. With suitable filtering using the -I, -i, -X and -x options, it can be used to display a ranking of requested documents, clients, user agents, or any other information which is recorded in the log.

**Useful commands:**

Create a list of URLs requested at the backend. Use this to find out which URL is the most requested.
```
$ varnishtop -i BereqURL
```
Lists what status codes Varnish returns to clients.
```
$ varnishtop -i RespStatus
```
You may also apply Query Language with -q option:
Shows you counters for responses where client seem to have erred
```
$ varnishtop -q 'respstatus > 400'
```
Displays what URLs are most frequently requested from clients.
```
$ varnishtop -i ReqUrl
```
Lists User-Agent headers with "Linux" in it. This example is useful for Linux users, since most web browsers in Linux report themselves as Linux.
```
$ varnishtop -i ReqHeader -I 'User-Agent:.*Linux.*'
```
Lists status codes received in clients from backends.
```
$ varnishtop -i RespStatus
```
Shows what VCL functions are used and returned
```
$ varnishtop -i VCL_call,VCL_return
```
Shows the most common referrer addresses.
```
$ varnishtop -i ReqHeader -I Referrer
```
Most frequent cookies
```
$ varnishtop -i ReqHeader -I Cookie
```

##### VARNISHNCSA #####
-----------------------
The [varnishncsa](https://www.varnish-cache.org/docs/trunk/reference/varnishncsa.html) utility reads shared memory logs and presents them in the Apache / NCSA "combined" log format :
```
10.10.0.1 - - [24/Aug/2008:03:46:48 +0100] "GET http://www.example.com/images/foo.png HTTP/1.1" 200 5330 "http://www.example.com/" "Mozilla/5.0"
```
If you already have tools in place to analyze NCSA Common log format, varnishncsa can be used
to print the SHMLOG in this format. varnishncsa dumps everything pointing to a certain domain
and subdomains.

##### VARNISHHIST #####
-----------------------
The [varnishhist](https://www.varnish-cache.org/docs/trunk/reference/varnishhist.html) utility reads the SHMLOG and presents a continuously updated histogram showing the distribution of the last n requests.
* The horizontal axis shows a time range from 1e-6 (1 microsecond) to 1e2 (100 seconds).
* Hits are marked with a pipe character ("|"), and misses are marked with a hash character ("#")
```
 1:1, n = 71                                                   localhost
                  #
                  #
                  #
                  #
                  ##
                 ###
                 ###
                 ###
                 ###
                 ###
            |    ###
            |    ###
            | |  ###
            |||| ###                       #
            |||| ####                      #
            |##|#####        #          #  #   # #
+-------+-------+-------+-------+-------+-------+-------+-------+-------
|1e-6   |1e-5   |1e-4   |1e-3   |1e-2   |1e-1   |1e0    |1e1    |1e2
```

##### VARNISHLOG #####
----------------------
The [varnishlog](https://www.varnish-cache.org/docs/trunk/reference/varnishlog.html) utility logs the incoming requests and the internal process inside varnish, this tool allows filtering and query language too.

#### ADMINISTRATION ###
------------------------------

##### VARNISHADM #####
----------------------
The varnishadm utility establishes a CLI connection to control a running Varnish instance.
You can use varnishadm to:
* start and stop the cacher (aka child) process
* change configuration parameters without restarting Varnish
* reload the Varnish Configuration Language (VCL) without restarting Varnish
* view the most up-to-date documentation for parameters

**Important Notes about varnishadm:**

1. Changes take effect on the running Varnish daemon instance without need to restart it.
2. Changes are not persistent across restarts of Varnish. If you change a parameter and you want the change to persist after you restart Varnish, you need to store your changes in the configuration file of the boot script.

#### GLOBAL COUNTERS ####
------------------
##### VARNISHSTAT #####
-----------------------
[Varnishstat](https://www.varnish-cache.org/docs/trunk/reference/varnishstat.html) gives a good representation of the general health of Varnish. Unlike all other tools, varnishstat does not read log entries, but counters that Varnish updates in real-time. It can be used to determine your request rate, memory usage, thread usage, number of failed backend connections, and tons of differents parameters.

#### MISC ####
--------------
##### VARNISHTEST #####
The [varnishtest](https://www.varnish-cache.org/docs/trunk/reference/varnishtest.html) program is a script driven program used to test the Varnish Cache.
The varnishtest program, when started and given one or more script files, can create a number of threads representing backends, some threads representing clients, and a varnishd process. This is then used to simulate a transaction to provoke a specific behavior.


