# vinit.bash

| shell | Usage Guide  |
| ---------- | ---------- |
| help: | `./vinit.bash` |
| starting | `./vinit.bash start` |
| status | `./vinit.bash status` |
| stop | `./vinit.bash stop` |

A depiction of the script:
```
                          ___/*stop*
            .------------/____/*start*
            | vinit.bash |_____/*status*
            |   process  |______/*update*
            `------------[______/*restart*
                   |
                 start
                   |
       .------------------------.
       |    crash & cpu max     |
       |     monitor loop       |
       `-------/--------\-------'
            _/            \_
          /                  \
        /                      \ 
*ps_monitor_loop*    *ps_screen_session*
       |                      ,^,
       |                     / /
    #============#          / /
    | restart if |_________/ /
    | max / dead |RESTART   /
    #============#---------·
         |
         |
    notifications
```

This script is intended as a complimentary [*__`screen`__*] wrapper for a process to be launched in (eg via: `sudo service my_service`) and later stopped, forced restarted (aka: [*~~__`forever`__~~*]) where exited unexpectedly and where certain CPU limits may be exceeded for too long.

Whats demonstrated is the monitor of single (1x) CPU process on interval where over-consumption (< `99.1` `%`) / infinite loop is assumed over a certain limit and a subsequent `kill` & restart is attempted.

Expressed threshold values in `./vinit.bash` are as follows:

```
    cpu_max=99.1 ; # #// Maximum CPU in % above which a violation is counted.
    cpu_ilimit=3 ; # #// Total violations after threshold is exceeded.
    cpu_icheck=30 ; # #// Interval between checks in seconds.
    # #// if CPU is > 99.1% for: 3x30 == 90 seconds then hung?
```


Some other limits / tolerances have also been left that are specific to potential notification schemes such as e-mail or sms; these include:
```
    tNoticeReset=240 ; # #// Total seconds after which notification should reset.
    tNoticeGap=15 ; # #// Gap between notification in above time.
    iNoticeMax=2 ;	# #// Maximum notices in a given time. 
    # #// ^^^ a maximum of 2 notices will be sent where they are at least.
    # #// 15 secs apart and within 240 seconds - after which the rule restarts.
```

For demonstration the process loop that's used to max the CPU is *__Bash__*:
```
PS_LOOP="yes > /dev/null";
# #// or: PS_LOOP="while :; do echo 1 > /dev/null ; done" ;
```
Other processes can for example be *__Node.js :__* 
```
PS_LOOP="echo 'console.log(\'began\'); while (1) { }; console.log(\'how ?\');' | node" ;
```
This may be any other executable scripts (eg: `.sh`) that's executed as a background process. Logging is also enabled by default as part of `screen` which places all outputs to `screenlog.0` in the path of the `screen` `session` for the launched processes (`APATH`); this log file is concurrently appended to where the same process is launched from the same path - otherwise writes continue to the same file even on each restart.


## configuration, `screen` & `sysvinit`

Pertinent settings that are required for use beyond a demonstration can be found in the header of `./vinit.bash`:
```
USER="$(whoami)" ;
SNAME="vinit.bash" ;
APATH="$(pwd)" ;
# #// ^^^ require actual executing user, path & name (can be anything).
```

Multi-user screen mode should be enabled to allow for shared sessions & attaching to processes executed as a different user (eg in `/etc/screenrc`) :

```
# Append if needed:
multiuser on
acladd root
acladd execuser
acladd yourself
acladd someother
```


An example `vinit.template` file is also mocked which may be linked to [*__`sysvinit`__*] for all users with access rights and appropriate screen configuration; what's required are the path (`APATH`) to the `vinit.bash` script and the name (`SNAME`) of the service which by default are constructed from executing user (`USER`) where the service name is thought to be the same as the name of the project directory. Adjustments to make to `vinit.template` are:
```
USER="user_home"
SNAME="dir_name"
APATH="/home/$USER/$NAME"
# #// ^^^ these should match your vinit.bash.
# #// here USER & SNAME are used to make APATH
# #// where for example clone resides in users home.
```

Renaming & copying of `vinit.template` to the *__`sysvinit`__* (eg `/etc/init.d/`) will allow for `sudo service vinit` like control of the processes. On Linux systems the script may be added to run-time levels for automatic relaunching in case of a system wide restart / reboot - so for example on `Debian` to add the script to `defaults` :
```
# #// cp of template already at: /etc/init.d/vinit
update-rc.d vinit defaults
# #// to remove: update-rc.d -f vinit remove
```
The `chkconfig` utility (eg in: `CentOS`, `REHL`) can also be used to this end. 

Some temporary textual (`.txt`) files are created as references and counters within `/tmp` - these include:


| .txt file path & naming convention: | details of content |
| --- | --- |
| `/tmp/NAME_OF_SERVICE_INSTANCE___ID-AFTER-SPLIT.txt` | numeric & text `PID:active` or `PID:inactive` |
| `/tmp/zSentLast_NAME_OF_SERVICE_INSTANCE___ID-AFTER-SPLIT.txt` | notification time (epoch) eg: `1448359809` |
| `/tmp/zSentTotal_NAME_OF_SERVICE_INSTANCE___ID-AFTER-SPLIT.txt` | notifications total number of sends / strikes |

These are deleted / cleared on each *__succesful__* `stop`. 

----

## NOTES:
Processes are launched in the background and their corresponding `PID` (`$!`) logged to file for later termination / stopping. The `screen` `PID` containing the user process and that of the loop monitoring CPU resource differ; thus killing the specific child process contained in the screen will not cease the force relaunching that'll continue.

`APATH` could be uniquely set on each `ps_loop` to allow for logs on a per process basis which may be useful in a multi-process service being launched from the same path; this would require a unique directory generated for each session from which the `screen` could be launch & subsequently redirected (`cd `) to the required (root) executable level (`PS_LOOP`). If logging is not required then its recommended that they be disabled by omitting `-L` from the arguments used in `screen` - indefinite process that verbose / log to screen are prone eventually to overfill / flow available storage space.


Maximum CPU monitor are not accurate nor based on averages. The violation counters are incremented (or decremented) accordingly based on the specified limit at the given interval to sample; therefore it may be possible, though less likely, that on the exact specified intervals the undesired threshold is met due to coincidental spikes in load that were temporary to those times. A variant of these conditions are also possible where the CPU load may be high yet on the monitored intervals they may momentarily drop giving the impression that the process is not in violation; the occurrence of any of these and more are arguably subject to the exact threshold and number of strikes / intervals which are used to monitor potentially misbehaving processes.

If you use this script in sole [*__`systemd`__*] environment or have some suggestion for improving it I'd welcome them :-)


----------------

### Version
0.0.1

  [*__`sysvinit`__*]: <https://wiki.archlinux.org/index.php/SysVinit>
  [*__`screen`__*]: <https://www.gnu.org/software/screen/>
  [*~~__`forever`__~~*]: <https://www.npmjs.com/package/forever>
  [*__`systemd`__*]: <http://freedesktop.org/wiki/Software/systemd/>
