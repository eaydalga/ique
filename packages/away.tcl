# Away Package
#
# All packages must be inside a namespace with the
# same name as the file name.

# Set VERSION and VERSDATE using the CVS tags.
namespace eval away {     
  regexp -- {[0-9]+\.[0-9]+} {@(#)TiK Away package $Revision: 1.15 $} \
      ::away::VERSION
  regexp -- { .* } {:$Date: 1999/02/08 14:52:05 $} \
      ::away::VERSDATE
}

# Options the user might want to set.  A user should use
# set ::IQUE(options,...), not the ique_default_set

# How many times do we send an away message?
ique_default_set options,Away,sendmax 1

namespace eval away {

    variable info

    # Must export at least: load, unload, goOnline, goOffline
    namespace export load unload goOnline goOffline register

    # All packages must have a load routine.  This should do most
    # of the setup for the package.  Called only once.
    proc load {} {
        tc_register_func * IM_IN away::IM_IN

        set away::info(msg)      ""
        set away::info(sendaway) 0

        menu .awayMenu -tearoff 0
        .toolsMenu add cascade -label "Ayrildim Mesaji" -menu .awayMenu
        .awayMenu add command -label "Yeni Ayrildim Mesaji" \
                              -command away::create_newaway
        .awayMenu add separator
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
        tc_unregister_func * IM_IN away::IM_IN
        .toolsMenu delete "Ayrildi Mesaji"
        destroy .awayMenu
    }


    proc IM_IN {name source msg auto} {
        if {$away::info(sendaway)} {
            set nsrc [normalize $source]
            # Don't send away message more than max times to the same person
            if {![info exists away::info(sentto,$nsrc)]} {
                set away::info(sentto,$nsrc) 0
            }

            if {$away::info(sentto,$nsrc) < $::IQUE(options,Away,sendmax)
                || $::IQUE(options,Away,sendmax) == -1} {
                tc_send_im $::KULLANICI $source \
                    [away::expand $away::info(msg) $source] auto
                incr away::info(sentto,$nsrc)
            } 
        }
    }

    proc expand {msg nick} {
        regsub -all -- "%n" $msg $nick new_msg
        regsub -all -- "%N" $new_msg $::KULLAN new_msg
        return $new_msg
    }

    proc back {} {
        away::set_away
        catch {destroy .awaymsg}
    }

    proc set_away {{awaymsg "_NOAWAY_"}} {
        if {$awaymsg == "_NOAWAY_"} {
            foreach i [array names away::info "sentto,*"] {
                unset away::info($i)
            }
            set away::info(sendaway) 0
            return
        } 

        set away::info(msg) $awaymsg
        set away::info(sendaway) 1

        set w .awaymsg

        if {[winfo exists $w]} {
            raise $w
            $w.text configure -state normal
            $w.text delete 0.0 end
            $w.text insert end $awaymsg
            $w.text configure -state disabled
            return
        }

        toplevel $w -class Takas
        wm title $w "Ayrildim Mesaji"
        wm iconname $w "Ayrildim Mesaji"
        if {$::IQUE(options,windowgroup)} {wm group $w .login}

        text  $w.text -width 40 -height 8 -wrap word
        $w.text insert end $awaymsg
        $w.text configure -state disabled

        button $w.back -text "Döndüm" -command away::back

        pack $w.back -side bottom
        pack $w.text -fill both -expand 1 -side top
    }

    proc register {awaymsg} {
        catch {.awayMenu delete $awaymsg}
        .awayMenu add command -label $awaymsg -command [list away::set_away $awaymsg]
    }

    proc newaway_ok {} {
        if {![winfo exists .newaway.text]} {
            return
        }
        set awaymsg [string trim [.newaway.text get 0.0 end]]
        away::register $awaymsg
        away::set_away $awaymsg
        destroy .newaway
    }

    proc create_newaway {} {
        set w .newaway

        if {[winfo exists $w]} {
            raise $w
            return
        }

        toplevel $w -class Takas
        wm title $w "Yeni Ayrildim Mesaji"
        wm iconname $w "Yeni Ayrildim Mesaji"
        if {$::IQUE(options,windowgroup)} {wm group $w .login}

        text  $w.text -width 40 -height 8 -wrap word

        label $w.info -text "Bu yeni mesaj dosyaya islenmez"
        frame $w.buttons
        button $w.ok -text "Tamam" -command "away::newaway_ok"
        button $w.cancel -text "Vazgec" -command [list destroy $w]
        pack $w.ok $w.cancel -in $w.buttons -side left -padx 2m

        pack $w.info -side top
        pack $w.buttons -side bottom
        pack $w.text -fill both -expand 1 -side top
    }
}

# Hack
proc ique_register_away {msg} {
    return [away::register $msg]
}
