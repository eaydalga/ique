# Ticker Package
#
# All packages must be inside a namespace with the
# same name as the file name.
#
# This version of Revision yields an internal package identifier readable
# to the program, even when not using the package manager, as well as
# working with both the `ident(1)' and `what(1)' utilities:
namespace eval ticker {
    regexp -- {[0-9]+\.[0-9]+} {@(#)TiK Ticker package $Revision: 1.20 $} \
        ::ticker::VERSION
    regexp -- { .* } {:$Date: 1999/02/10 13:39:13 $} \
        ::ticker::VERSDATE
}

# Options the user might want to set.  A user should use
# set ::IQUE(options,...), not the ique_default_set
ique_default_set options,Ticker,on  0
ique_default_set options,Ticker,ique 1
ique_default_set options,Ticker,lines            2
ique_default_set options,Ticker,speeds           {-5 -3 -5 -5 -5 -5 -5}
ique_default_set options,Ticker,IQUE,line         0
ique_default_set options,Ticker,notice,line      1
ique_default_set options,Ticker,SlashMeat,line   0
ique_default_set options,Ticker,Stocks,line      0
ique_default_set options,Ticker,Wx,line          0
ique_default_set options,Ticker,geometry "+0+0"
ique_default_set options,Ticker,where,TopLeft    +0+0
ique_default_set options,Ticker,where,TopRight   -0+0
ique_default_set options,Ticker,where,BottomLeft +0-0
ique_default_set options,Ticker,where,BottomRight -0-0
ique_default_set options,Ticker,bgcolor          #d9d9d9
ique_default_set options,Ticker,buddymcolor      black
ique_default_set options,Ticker,buddyocolor      blue
ique_default_set options,Ticker,groupmcolor      black
ique_default_set options,Ticker,groupocolor      red

namespace eval ticker {

    variable info

    # Must export at least: load, unload, goOnline, goOffline
    namespace export load unload goOnline goOffline setGeometry newsflash

    # All packages must have a load routine.  This should do most
    # of the setup for the package.  Called only once.
    proc load {} {
        set ticker::info(font) $::SAGFONT
        set ticker::info(lineheight) [font metrics $ticker::info(font) -linespace]
        for {set line 0} {$line < $::IQUE(options,Ticker,lines)} {incr line} {
            set ticker::info(lastitem,$line) ""
            set ticker::info(items,$line) ""
        }

        tc_register_func * UPDATE_BUDDY      ticker::UPDATE_BUDDY
        menu .tickerMenu -tearoff 0
        .toolsMenu add cascade -label "Kullanýcý Izleme" -menu .tickerMenu
        .tickerMenu add checkbutton -label "Kullanýcý Izlemeyi Ac" -onvalue 1 \
            -offvalue 0 -variable ::IQUE(options,Ticker,on) \
            -command ticker::resetTicker
        .tickerMenu add checkbutton -label "IQUE Kulalnýcý'larýný göster" -onvalue 1 \
            -offvalue 0 -variable ::IQUE(options,Ticker,ique)\
            -command ticker::resetTicker
        menu .tickerMenu.where -tearoff 0
        .tickerMenu add cascade -label Nerede -menu .tickerMenu.where
        .tickerMenu.where add command -label "Ust Sol" \
            -command "if \[winfo exists .ticker] {
                    wm geometry .ticker $::IQUE(options,Ticker,where,TopLeft)
            }"
        .tickerMenu.where add command -label "Ust Sag" \
            -command "if \[winfo exists .ticker] {
                    wm geometry .ticker $::IQUE(options,Ticker,where,TopRight)
            }"
        .tickerMenu.where add command -label "Alt Sol" \
            -command "if \[winfo exists .ticker] {
                    wm geometry .ticker $::IQUE(options,Ticker,where,BottomLeft)
            }"
        .tickerMenu.where add command -label "Alt Sag" \
            -command "if \[winfo exists .ticker] {
                    wm geometry .ticker $::IQUE(options,Ticker,where,BottomRight)
            }"
        .tickerMenu.where add command -label {iquerc size & position} \
            -command "if \[winfo exists .ticker] {
                    wm geometry .ticker $::IQUE(options,Ticker,geometry)
            }"
        .tickerMenu add command -label Yavas \
            -command "
                    foreach s \$::IQUE(options,Ticker,speeds) {
                      incr s
                      if {\$s > -1} {set s -1}
                      lappend speeds \$s
                    }
                    set ::IQUE(options,Ticker,speeds) \$speeds
                    unset speeds"
        .tickerMenu add command -label "Daha Hizli" \
            -command "
                    foreach s \$::IQUE(options,Ticker,speeds) {
                      incr s -1
                      lappend speeds \$s
                    }
                    set ::IQUE(options,Ticker,speeds) \$speeds
                    unset speeds"
    }

    # All pacakges must have goOnline routine.  Called when the user signs
    # on, or if the user is already online when packages loaded.
    proc goOnline {} {
        destroy {.ticker}
        catch {after cancel $ticker::info(timer)}

        if {!$::IQUE(options,Ticker,on)} {
            return
        }

        toplevel .ticker -class Takas 
        wm geometry .ticker $::IQUE(options,Ticker,geometry)
        wm title .ticker "Kullanýcý Izleyici"
        wm iconname .ticker "Kullanýcý Izleyici"
        if {$::IQUE(options,windowgroup)} {wm group .ticker .login}
        canvas .ticker.c -borderwidth 0 -relief flat \
            -background $::IQUE(options,Ticker,bgcolor) -height \
            [expr $ticker::info(lineheight) * $::IQUE(options,Ticker,lines)]
        pack .ticker.c -expand 1 -fill both 
        after 2000 ticker::createTicker 1
    }

  # All pacakges must have goOffline routine.  Called when the user signs
  # off.  NOT called when the package is unloaded.
    proc goOffline {} {
        catch {after cancel $ticker::info(timer)}
        destroy {.ticker}

        foreach i [array names ticker::info *,online] {
            unset ticker::info($i)
        }
    }

  # All packages must have a unload routine.  This should remove everything 
  # the package set up.  This is called before load is called when reloading.
    proc unload {} {
        catch {destroy .ticker}
        tc_unregister_func * UPDATE_BUDDY      ticker::UPDATE_BUDDY
        .toolsMenu delete "Kullanýcý Ticker"
        destroy .tickerMenu
    }

    proc resetTicker {} {
        set ex [winfo exists .ticker]
        if {$::IQUE(options,Ticker,on) && !$ex} {
            goOnline
        } elseif {!$::IQUE(options,Ticker,on) && $ex} {
            goOffline
        } else {
            createTicker 1
        }
    }

    proc newsflash {str} {
        set width [winfo width .ticker.c]
        set x 0
        set line $::IQUE(options,Ticker,notice,line)
        set ypos [expr $line * $ticker::info(lineheight)]
        if {$ticker::info(lastitem,$line) != ""} {
            set x [lindex [.ticker.c coords \
              $ticker::info(lastitem,$line)] 0]
            set x [expr int($x + [font measure $ticker::info(font) $str])]
            incr x 10
        }
        if {$x < $width} {
            set x $width
        }
        set in [.ticker.c create text $x $ypos \
            -text $str \
            -font $ticker::info(font) \
            -anchor ne \
            -fill $::IQUE(options,Ticker,groupocolor) \
            -tags LINE$line]
        set ticker::info(lastitem,$line) $in
        lappend ticker::info(items,$line) $in
    }

    proc UPDATE_BUDDY {name user online evil signon idle uclass IP CPORT} {
        set nuser [normalize $user]
        if {(![info exists ticker::info($nuser,online)] ||
                  ($ticker::info($nuser,online) == "F")) && ($online == "T")} {
            set str "$user signed on"
        } elseif {(![info exists ticker::info($nuser,online)] ||
                  ($ticker::info($nuser,online) == "T")) && ($online == "F")} {
            set str "$user signed off"
        } else {
            return
        }
        if {!$::IQUE(options,Ticker,on) || ![winfo exists .ticker.c]} {
            return
        }
        newsflash $str
        set ticker::info($nuser,online) $online
    }

    proc createTicker {all args} {
        if {![winfo exists .ticker.c]} {
            return
        }
        if {$all == 0} {
            set single 1
            set doline [lindex $args 0]
            if {[llength $args] > 1} {
                set doclear [lindex $args 1]
            } else {
                set doclear 0
            }
        }
        if {$all} {
            set single 0
            set doline 0
            set ticker::info(cnt) 0
            for {set line 0} {$line < $::IQUE(options,Ticker,lines)} {incr line} {
                catch ".ticker.c delete LINE${line}"
                set ticker::info(items,$line) ""
                set ticker::info(lastitem,$line) ""
                set ticker::info(linelen,$line) [winfo width .ticker.c]
            }
        } elseif {$doclear} {
            catch ".ticker.c delete LINE$doline"
            incr ticker::info(cnt)
            set ticker::info(items,$doline) ""
            set ticker::info(lastitem,$doline) ""
            set ticker::info(linelen,$doline) [winfo width .ticker.c]
        } elseif {[info exists ticker::info(lastitem,$doline)]} {
            set ticker::info(linelen,$doline) \
                    [lindex [.ticker.c coords $ticker::info(lastitem,$doline)] 0]
        } else {
            set ticker::info(linelen,$doline) [winfo width .ticker.c]
        }
            
        set in ""
        foreach g $::BUDDYLIST {
            set gptype $::GROUPS($g,type)
            set line $::IQUE(options,Ticker,$gptype,line)
            if {$single && ( $line != $doline ) } {
                continue
            }
            set x [lindex [split $ticker::info(linelen,$line) \.] 0]
            incr x 20
            set ypos [expr $line * $ticker::info(lineheight)]
            set tags [list LINE$line LINE${line}$ticker::info(cnt)]
            if {($gptype == "IQUE") && !$::IQUE(options,Ticker,ique)} {
                continue
            }
            incr ticker::info(cnt)

            incr x [font measure $ticker::info(font) "$g:"]
            set in [ .ticker.c create text $x $ypos \
                      -text "$g:" \
                      -font $ticker::info(font) \
                      -anchor ne \
                      -fill red \
                      -tags $tags]
            set ticker::info($in,type) GROUP
            lappend ticker::info(items,$line) $in
            incr x 10
            foreach b $::GROUPS($g,people) {
                if {$::BUDDIES($b,online) == "F"} {
                    continue;
                }
                set bud $::BUDDIES($b,name)
                set other $::BUDDIES($b,otherString)

                incr x 16
                set iconIndex ""
                catch {set iconIndex [.ticker.c create image $x $ypos\
                        -image $::BUDDIES($b,icon) \
                        -anchor ne\
                        -tags $tags]}
                lappend ticker::info(items,$line) $iconIndex

                incr x [font measure $ticker::info(font) $bud]
                incr x 5
                set budIndex [.ticker.c create text $x $ypos \
                        -text $bud \
                        -font $ticker::info(font) \
                        -anchor ne \
                        -fill $::IQUE(options,Ticker,buddymcolor) \
                        -tags $tags]
                lappend ticker::info(items,$line) $budIndex

                incr x [font measure $ticker::info(font) $other]
                incr x 5
                set in [.ticker.c create text $x $ypos \
                        -text $other \
                        -font $ticker::info(font) \
                        -anchor ne \
                        -fill $::IQUE(options,Ticker,buddyocolor) \
                        -tags $tags]
                lappend ticker::info(items,$line) $in
                incr x 10
                set ticker::info(linelen,$line) $x
                set ticker::info($in,type) OTHER
                set ticker::info($in,b) $b
                .ticker.c bind $budIndex <Double-Button-1> "ique_double_click $b $b"
                .ticker.c bind $in <Double-Button-1> "ique_double_click $b $b"
                .ticker.c bind $budIndex <ButtonPress-3> "ique_buddy_popup $b %X %Y"
                .ticker.c bind $budIndex <ButtonRelease-3> {ique_buddy_release}
                .ticker.c bind $in <ButtonPress-3> "ique_buddy_popup $b %X %Y"
                .ticker.c bind $in <ButtonRelease-3> {ique_buddy_release}
            }
            if {$x > $ticker::info(linelen,$line)} {
                set ticker::info(linelen,$line) $x
            }
            set ticker::info(lastitem,$line) $in
        }
        catch {after cancel $ticker::info(timer)}
        set ticker::info(timer) [after 100 ticker::updateTicker]
    }

    proc updateTicker {} {
        catch {after cancel $ticker::info(timer)}
        for {set line 0} {$line < $::IQUE(options,Ticker,lines)} {incr line} {
            if {$ticker::info(lastitem,$line) != ""} {
                set width [winfo width .ticker.c]
                set x [lindex [.ticker.c coords $ticker::info(lastitem,$line)] 0]
                if {($line != $::IQUE(options,Ticker,notice,line)) && ($x < $width)} {
                    createTicker 0 $line
                    continue
                }
                .ticker.c move LINE$line \
                        [lindex $::IQUE(options,Ticker,speeds) $line] 0
            }
            set x 0
            foreach ob $ticker::info(items,$line) {
                if {[lindex [.ticker.c coords $ob] 0] < 0} {
                    catch {.ticker.c delete $ob}
                    catch {unset ticker::info($ob,type)}
                    catch {unset ticker::info($ob,b)}
                } else {
                    break
                }
                incr x
            }
            if {$x > 0} {
                set ticker::info(items,$line) [lrange $ticker::info(items,$line) $x end]
            }
        }
        catch {after cancel $ticker::info(timer)}
        set ticker::info(timer) [after 100 ticker::updateTicker]
    }
}
