# IM Capture Package --
#
# Capture all ims
#             
# All packages must be inside a namespace with the
# same name as the file name.


# Set VERSION and VERSDATE using the CVS tags.
namespace eval imcapture {     
  regexp -- {[0-9]+\.[0-9]+} {@(#)TiK IM Capture package $Revision: 1.10 $} \
      ::imcapture::VERSION
  regexp -- { .* } {:$Date: 1999/02/08 14:52:07 $} \
      ::imcapture::VERSDATE
}

namespace eval imcapture {

    variable info

    # Must export at least: load, unload, goOnline, goOffline
    namespace export load unload goOnline goOffline

    # All packages must have a load routine.  This should do most
    # of the setup for the package.  Called only once.
    proc load {} {
        tc_register_func * tc_send_im imcapture::IM_OUT
        tc_register_func * IM_IN  imcapture::IM_IN

        menu .imcaptureMenu -tearoff 0
        .toolsMenu add cascade -label "Anlik Ileti Yakala" -menu .imcaptureMenu
        .imcaptureMenu add command -label "Hepsini Görüntüle" \
                              -command imcapture::view

        .imcaptureMenu add separator

        # Create and protect the capture dir.
        file mkdir $::IQUE(configDir)/capture
        catch {exec chmod og-rwx $::IQUE(configDir)/capture}

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
        tc_unregister_func * tc_send_im imcapture::IM_OUT
        tc_unregister_func * IM_IN  imcapture::IM_IN
        .toolsMenu delete "Anlik Ileti Yakala"
        destroy .imcaptureMenu
    }

    proc IM_OUT {connName nick msg auto} {
        set n [normalize $nick]
        # Open the capture file
        set f [open_capture_file $n $nick]
        # Add a new session header if necessary
        add_session_header $n $nick $f
        # Save the im in the file
        puts $f "<P>$::KULLAN:$msg</P>\n"
        close $f

        if {![info exists imcapture::info(menu,$n)]} {
            .imcaptureMenu add command -label "$nick" \
                                  -command "imcapture::view $n"
            set imcapture::info(menu,$n) [.imcaptureMenu index end]
            
        }
    }

    proc IM_IN {connName nick msg auto} {
        set n [normalize $nick]
        # Open the capture file
        set f [open_capture_file $n $nick]
        # Add a new session header if necessary
        add_session_header $n $nick $f
        # Save the im in the file
        puts $f "<P>$nick:[munge_message $msg]</P>\n"
        close $f

        if {![info exists imcapture::info(menu,$n)]} {
            .imcaptureMenu add command -label "$nick" \
                                  -command "imcapture::view $n"
            set imcapture::info(menu,$n) [.imcaptureMenu index end]
            
        }
    }

    proc view {{user {__ALL__}}} {
        if {$user == "__ALL__"} {
            ique_show_url imcapture "file://[file nativename $::IQUE(configDir)/capture/]"
        } else {
            ique_show_url imcapture "file://[file nativename $::IQUE(configDir)/capture/$user.html]"
        }
    }

    proc open_capture_file {n nick} {
        if {![file exists $::IQUE(configDir)/capture/$n.html]} {
            # This is the first IM from this buddy so setup the HTML
            #  page with the beginning stuff:)
            set f [open $::IQUE(configDir)/capture/$n.html a+]
            puts $f "<HTML><HEAD><TITLE>IM Sessions with $nick</TITLE></HEAD>\n"
            puts $f "<BODY>\n"
        } else {
            set f [open $::IQUE(configDir)/capture/$n.html a+]
        }
        return $f
    }

    proc add_session_header {n nick f} {
        # See if this is a new IM session
        if {![info exists imcapture::info(tod,$n)]} {
            set imcapture::info(tod,$n) 0
        }
        set lt $imcapture::info(tod,$n)
        set ct [clock seconds]
        # Check time difference (display header if more than 15 mins)
        if { ($ct - $lt) > 900 } {
            set tstr [clock format $ct -format "%m/%d/%y %H:%M %p"]
            puts $f "<HR><BR><H2 Align=Center>$nick ile Anlik Ileti Oturumu $tstr saatinde basladi</H2><BR>\n"
        }
        set imcapture::info(tod,$n) $ct
        return 0
    }

    proc munge_message {msg} {
        set clean $msg
        # Determine if the message is enclosed with <HTML> ... </HTML>
        if {[string first "<HTML>" $msg] == 0} {
            # Find the closing </HTML>
            set lpos [string last "</HTML>" $msg]
            incr lpos -1
            catch {set clean [string range $msg 6 $lpos]}
        }
        return $clean
    }
}
