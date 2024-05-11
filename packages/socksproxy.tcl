# Socks Proxy
#
# All packages must be inside a namespace with the
# same name as the file name.

# Set VERSION and VERSDATE using the CVS tags.
namespace eval socksproxy {     
  regexp -- {[0-9]+\.[0-9]+} {@(#)TiK SOCKS Proxy package $Revision: 1.5 $} \
      ::socksproxy::VERSION
  regexp -- { .* } {:$Date: 1999/02/08 14:52:12 $} \
      ::socksproxy::VERSDATE
}

namespace eval socksproxy {

    # Must export at least: load, unload, goOnline, goOffline
    namespace export load unload goOnline goOffline

    # All packages must have a load routine.  This should do most
    # of the setup for the package.  Called only once.
    proc load {} {
        ique_register_proxy Socks socksproxy::connect socksproxy::config
    }

    # All pacakges must have goOnline routine.  Called when the user signs
    # on, or if the user is already online when packages loaded.
    proc goOnline {} {
    }

    # All pacakges must have goOffline routine.  Called when the user signs
    # off.  NOT called when the package is unloaded.
    proc goOffline {} {
    }

    # All packages must have a unload routine.  This should remove everything 
    # the package set up.  This is called before load is called when reloading.
    proc unload {} {
        ique_unregister_proxy Socks
    }

    # connect --
    #     Connect via socks proxy.
    #
    # Arguments:
    #     host  - The ip of the host we are connecting to through socks
    #     port  - The port we are connecting to through socks
    #     sname - Our user name, since some proxies might need it.

    proc connect { host port sname } {
        if { ! [info exists ::SOCKSHOST] || ! [info exists ::SOCKSPORT]} {
            error "SOCKS ERROR: Please set SOCKSHOST and SOCKSPORT\n"
        }

        # Check to make sure the toc host is an ip address.
        set match [scan $host "%d.%d.%d.%d" a b c d]

        if { $match != "4" } {
            error "SOCKS ERROR: TC Host must be IP address, not name\n"
        }

        set fd [socket $::SOCKSHOST $::SOCKSPORT]
        fconfigure $fd -translation binary
        set data [binary format "ccScccca*c" 4 1 $port $a $b $c $d $sname 0]
        puts -nonewline $fd $data
        flush $fd

        set response [read $fd 8]
        binary scan $response "ccSI" v r port ip

        if { $r != "90" } {
            tk_messageBox -message "Request failed code : $r"
            return 0
        }

        return $fd
    }

    proc config {} {
        set w .proxyconfig
        destroy $w
        set ::SOCKSHOST "195.174.168.2"
        set ::SOCKSPORT "1080"

        toplevel $w -class Tik
        wm title $w "Proxy Config: SOCKS Connection"
        wm iconname $w "Proxy Config"
        if {$::IQUE(options,windowgroup)} {wm group $w .login}
        label $w.label -text "Change your iquerc to make permanent.\n\
             The TC servers listen on ALL ports.\n\
             TC Host MUST be an IP address for SOCKS.\n"

        frame $w.tochostF
        label $w.tochostF.l -text "IQUE Host: " -width 15
        entry $w.tochostF.e -textvariable ::TC($::SELECTEDTC,host) \
            -exportselection 0
        pack $w.tochostF.l $w.tochostF.e -side left

        frame $w.tocportF
        label $w.tocportF.l -text "IQUE Port: " -width 15
        entry $w.tocportF.e -textvariable ::TC($::SELECTEDTC,port) \
            -exportselection 0
        pack $w.tocportF.l $w.tocportF.e -side left

        frame $w.sockshostF
        label $w.sockshostF.l -text "SOCKS Host: " -width 15
        entry $w.sockshostF.e -textvariable ::SOCKSHOST \
            -exportselection 0
        pack $w.sockshostF.l $w.sockshostF.e -side left

        frame $w.socksportF
        label $w.socksportF.l -text "SOCKS Port: " -width 15
        entry $w.socksportF.e -textvariable ::SOCKSPORT \
            -exportselection 0
        pack $w.socksportF.l $w.socksportF.e -side left

        button $w.ok -text "Ok" -command "destroy $w"
        bind $w.tochostF.e <Return> { focus .proxyconfig.tocportF.e }
        bind $w.tocportF.e <Return> { focus .proxyconfig.sockshostF.e }
        bind $w.sockshostF.e <Return> { focus .proxyconfig.socksportF.e }
        bind $w.socksportF.e <Return> { destroy .proxyconfig }
        bind $w.ok <Return> { destroy .proxyconfig }
        pack $w.label $w.tochostF $w.tocportF \
             $w.sockshostF $w.socksportF $w.ok -side top
    }
}
