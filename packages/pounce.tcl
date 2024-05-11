
#
# Monitor users and inform us when they signon.
#             
#
# All packages must be inside a namespace with the
# same name as the file name.

# Set VERSION and VERSDATE using the CVS tags.
namespace eval pounce {     
  regexp -- {[0-9]+\.[0-9]+} {@(#)TiK Pounce package $Revision: 1.10 $} \
      ::pounce::VERSION
  regexp -- { .* } {:$Date: 1999/02/08 14:52:09 $} \
      ::pounce::VERSDATE
}

namespace eval pounce {

    variable info

    # Must export at least: load, unload, goOnline, goOffline
    namespace export load unload goOnline goOffline register

    # All packages must have a load routine.  This should do most
    # of the setup for the package.  Called only once.
    proc load {} {
        tc_register_func * UPDATE_BUDDY pounce::UPDATE_BUDDY

        menu .pounceMenu -tearoff 0
        .toolsMenu add cascade -label "Kullanýcý Uyarma" -menu .pounceMenu
        .pounceMenu add command -label "Yeni Uyari" \
                              -command pounce::editpounce
        .pounceMenu add separator

        if {![info exists ::IQUE(SOUND,Pounce)]} {
            set ::IQUE(SOUND,Pounce) media/Pounce.au
        }
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
        tc_unregister_func * UPDATE_BUDDY pounce::UPDATE_BUDDY
        .toolsMenu delete "Kullanýcý Uyarma"
        destroy .pounceMenu
        destroy .editPounce
    }

    proc register { user {onlyonce 0} { playsound 1 } {popim 1} {sendim 0}
{msg ""} {execcmd 0} {cmdstr ""} } {
        set pouncing [normalize $user]

        set pounce::info($pouncing,pounce) 1
        set pounce::info($pouncing,user) $user
        set pounce::info($pouncing,playsound) $playsound
        set pounce::info($pouncing,onlyonce) $onlyonce
        set pounce::info($pouncing,popim) $popim
        set pounce::info($pouncing,sendim) $sendim
        set pounce::info($pouncing,msg) $msg
        set pounce::info($pouncing,execcmd) $execcmd
        set pounce::info($pouncing,cmdstr) $cmdstr

        if { [info exists pounce::info($pouncing,menulabel)] } {
        } else {
            .pounceMenu add command -label $user \
                    -command "pounce::editpounce $pouncing"
            set pounce::info($pouncing,menulabel) $user
        }
    }

    proc UPDATE_BUDDY {name user online evil signon idle uclass IP CPORT} {
        set nuser [normalize $user]
        if {[info exists pounce::info($nuser,pounce)]} {
            if {($pounce::info($nuser,pounce) > 0) && ($online == "T")} {
                if {$pounce::info($nuser,playsound)} {
                    ique_play_sound $::IQUE(SOUND,Pounce)
                }
                
                if {$pounce::info($nuser,onlyonce)} {
                    set pounce::info($nuser,pounce) 0
                    .pounceMenu delete $pounce::info($nuser,menulabel)
                } else {
                    # Watch for them to log off and then repounce
                    set pounce::info($nuser,pounce) -1
                }

                if {$pounce::info($nuser,popim)} {
                    ique_create_iim $name $user
                }

                if {$pounce::info($nuser,sendim)} {
                    tc_send_im $name $nuser $pounce::info($nuser,msg)
                }

                if {$pounce::info($nuser,execcmd)} {
                    catch {eval exec $pounce::info($nuser,cmdstr)}
                }
            } elseif {($pounce::info($nuser,pounce) < 0) && ($online == "F")} {
                set pounce::info($nuser,pounce) 1
            }
        }
    }

    proc editpounce_ok {user} {
        if {$user != "__NEW__"} {
            return
        }

        set pouncing [normalize $pounce::info(__NEW__,user)]

        set pounce::info($pouncing,pounce) 1
        set pounce::info($pouncing,user) $pounce::info(__NEW__,user)
        set pounce::info($pouncing,playsound) $pounce::info(__NEW__,playsound)
        set pounce::info($pouncing,onlyonce) $pounce::info(__NEW__,onlyonce)
        set pounce::info($pouncing,popim) $pounce::info(__NEW__,popim)
        set pounce::info($pouncing,sendim) $pounce::info(__NEW__,sendim)
        set pounce::info($pouncing,msg) $pounce::info(__NEW__,msg)
        set pounce::info($pouncing,execcmd) $pounce::info(__NEW__,execcmd)
        set pounce::info($pouncing,cmdstr) $pounce::info(__NEW__,cmdstr)

        .pounceMenu add command -label $pounce::info(__NEW__,user) \
                              -command "pounce::editpounce $pouncing"
        set pounce::info($pouncing,menulabel) $pounce::info(__NEW__,user)


    }

    proc editpounce_delete {user} {
        set pounce::info($user,pounce) 0
        .pounceMenu delete $pounce::info($user,menulabel)
    }

    proc editpounce {{pouncing {__NEW__}}} {
        set w .editpounce

        if {[winfo exists $w]} {
            raise $w
            return
        }

        toplevel $w -class Takas
        if {$pouncing == "__NEW__"} {
            wm title $w "Yeni Uyari Yarat"
            wm iconname $w "Yeni Uyari Yarat"
            set pounce::info($pouncing,user) ""
            set pounce::info($pouncing,playsound) 1
            set pounce::info($pouncing,onlyonce) 1
            set pounce::info($pouncing,popim) 1
            set pounce::info($pouncing,sendim) 0
            set pounce::info($pouncing,msg) ""
            set pounce::info($pouncing,execcmd) 0
            set pounce::info($pouncing,cmdstr) ""
        } else {
            wm title $w "$pouncing icin Uyari Bakimi"
            wm iconname $w "$pouncing icin Uyari Bakimi"
        }

        if {$::IQUE(options,windowgroup)} {wm group $w .login}
        frame $w.toF
        label $w.tolabel -text "Uyari icin Kullanýcý Girin: "
        entry $w.to  -textvariable pounce::info($pouncing,user)
        if {$pouncing != "__NEW__"} {
            $w.to configure -state disabled
        }
        pack $w.tolabel $w.to -in $w.toF -side left

        checkbutton $w.popupim -text "Kullanici baglaninca Anlik Ileti penceresini Ac." \
            -variable pounce::info($pouncing,popim)
        checkbutton $w.sendim -text "Kullanici baglaninca Anlik Ileti gonder:" \
            -variable pounce::info($pouncing,sendim)
        entry $w.immsg -textvariable pounce::info($pouncing,msg)
        checkbutton $w.sound -text "Kullanici bglaninca Uyari Sesini Cikar." \
            -variable pounce::info($pouncing,playsound)
        checkbutton $w.onlyonce -text "Kullanici icin bir kez uyari yap." \
            -variable pounce::info($pouncing,onlyonce)
        checkbutton $w.execcmd -text "Kullanici baglaninca bu komutu calistir:" \
            -variable pounce::info($pouncing,execcmd)
        entry $w.cmdstr -textvariable pounce::info($pouncing,cmdstr)

        frame $w.buttons
        button $w.ok -text "Tamam" \
            -command "destroy $w; pounce::editpounce_ok $pouncing"
        if {$pouncing == "__NEW__"} {
            button $w.cancel -text "Vazgec" -command [list destroy $w]
        } else {
            button $w.cancel -text "Sil" \
                -command "destroy $w; pounce::editpounce_delete $pouncing"
        }
        pack $w.ok $w.cancel -in $w.buttons -side left -padx 2m

        pack $w.toF -side top
        pack $w.popupim $w.sendim -side top -anchor w -padx 15
        pack $w.immsg -side top -expand 1 -fill x -anchor w
        pack $w.sound $w.onlyonce $w.execcmd -side top -anchor w -padx 15
        pack $w.cmdstr -side top -expand 1 -fill x -anchor w
        pack $w.buttons -side bottom
        focus $w.to
    }
}
