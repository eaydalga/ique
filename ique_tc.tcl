#
# $Revision: 1.34 $

# Load the low level sflap routines.
source sflap.tcl

#******************************************************
#********************* UTILITIES **********************
#******************************************************

# normalize --
#     Convert a string to just lowercase and
#     strip out all non letters or numbers.
#
# Arguments:
#     str - The string to normalize
#
proc normalize {str} {
    set str [string tolower $str]
    regsub -all {[^a-z0-9]} $str "" str
    return $str
}

# roast_password --
#     Roast a password so it isn't sent in "clear text" over
#     the wire, although it is still trivial to decode.
#
# Arguments:
#     pass - The password to roast

proc roast_password {pass} {
    set CODE $::IQUE(CODE)
    set CODELEN [string length $CODE]
    if { $CODELEN } {
        set cpw "0x"

        set i 0
        foreach ch [split $pass ""] {
            binary scan [string index $CODE [expr $i % $CODELEN]] c bc
            binary scan $ch c bch
            append cpw [format "%02x" [expr $bch ^ $bc]]
            incr i
        }
    } else {
        set cpw $pass
    }
    return $cpw
}

# encode -- 
#     Convert a string so it can be passed through TC safely.
#
# Arguments:
#     str - the string to encode
proc encode {str} {
    append s {"}
    foreach i [split $str {}] {
        if { ($i == "\\") || \
             ($i == "\}") || \
             ($i == "\{") || \
             ($i == "\(") || \
             ($i == "\)") || \
             ($i == "\]") || \
             ($i == "\[") || \
             ($i == "\$") || \
             ($i == "\"")} {
            append s "\\"
        }
        append s $i
    }

    append s {"}
    return $s
}

# splitHTML -- 
#     Split a HTML message into a list of tags and text.
#
# Arguments:
#     str - The string to split
proc splitHTML {str} {
   while {1} {
       set e [string first "<" $str]
       if {$e == -1} {
           lappend results $str
           break
       }

       set t [string range $str $e end]
       if {[string match {<[/a-zA-Z!]*} $t] == 0} {
           lappend results [string range $str 0 $e]
           set str [string range $str [expr $e+1] end]
           continue
       }

       lappend results [string range $str 0 [expr $e-1]]
       set str $t

       set e [string first ">" $str]
       set d [string first "<" [string range $str 1 end]]
       if {($d != -1) && ($e > $d)} {
           lappend results "[string range $str 0 [expr $d-1]]" 
           set str [string range $str $d end]
       } else {
            if {$e == -1} {
                lappend $str
                break
            }
           lappend results [string range $str 0 $e]
           set str [string range $str [expr $e+1] end]
       }
   }
   return $results
}

# tc_open -- 
#     Utility function that opens the sflap connection and sends 
#     the tc_signon message.
#
# Arguments:
#     connName - name to give the SFLAP connection
#     tchost  - hostname of TC server
#     tcport  - port of TC server
#     authhost - hostname of OSCAR authorizer
#     authport - port of OSCAR authorizer
#     sn       - user's screen name
#     pw       - user's password
#     lang     - language to use.
#     version  - client version string
#     proxy    - proxy to use
proc tc_open {connName tchost tcport authhost authport sn pw lang 
              {version "tc.tcl Unknown"} {proxy ""}} {

    # Have extra updates here for when tc.tcl is used for stress testing.
    update
    set e [sflap::connect [normalize $connName] "" $tchost \
                          $tcport [normalize $sn] $proxy]
    if { $e == "" } return
    if { $e } return
    update
    tc_signon $connName $authhost $authport $sn $pw $lang $version
    update

    incr ::TCSTATS(tc_open)
    return
}

#
# tc_close --
#     Just a matching for tc_open.  Close the TC and SFLAP connection.
#
# Arguments:
#     connName - SFLAP connection name.

proc tc_close {connName} {
    set norm [normalize $connName]
    sflap::close2 $norm ""

    if { [info exists ::TCSTATS($norm,ONLINE)] } {
        if {$::TCSTATS($norm,ONLINE)} {
            incr ::TCSTATS(ONLINE) -1
        } else {
            incr ::TCSTATS(TOTAUTHFAIL)
        }

        unset ::TCSTATS($norm,ONLINE)

        incr ::TCSTATS(CONNECTED) -1
        incr ::TCSTATS(tc_close)
    }
}
proc tc_register {connName pw regdata} {
    set cpw $pw
    if {[string  match "0x0x*" $pw]} {
        set cpw [string range $pw 2 end]
    } else {
        set cpw [roast_password $pw]
    }

    set norm [normalize $connName]
    sflap::send $norm "tc_register $norm $cpw $regdata"
}

# tc_register_func --
#     Register the proc to be called
#     when certain messages are received.  A connName of
#     "*" implies all connections should use that function
#
# Arguments:
#     connName - name of SFLAP connection or "*" = all
#     cmd      - the PROTOCOL cmd
#     func     - the callback that is executed when cmd is received.

proc tc_register_func {connName cmd func} {
    if {$connName != "*"} {
        set connName [normalize $connName]
    }

    lappend ::FUNCS($connName,$cmd) $func

    incr ::TCSTATS(tc_register_func)
}

# tc_unregister_func --
#     Unregister the proc to be called when certain messages are received.
#     A connName of "*" implies all connections should unregister that function
#
# Arguments:
#     connName - name of SFLAP connection or "*" = all
#     cmd      - the PROTOCOL cmd
#     func     - the callback that is executed when cmd is received.

proc tc_unregister_func {connName cmd func} {
    if {$connName != "*"} {
        set connName [normalize $connName]
    }

    set i [lsearch -exact $::FUNCS($connName,$cmd) $func]
    if {$i != -1} {
        set ::FUNCS($connName,$cmd) [lreplace $::FUNCS($connName,$cmd) $i $i]
    }

    incr ::TCSTATS(tc_unregister_func)
}

# tc_unregister_all --
#     Remove all the proc registrations for a particular connection.
#
# Arguments:
#     connName - name of SFLAP connection or "*" = all

proc tc_unregister_all {connName} {
    if {$connName != "*"} {
        set connName [normalize $connName]
    } else {
        set connName "\\\*"
    }

    foreach i [array names ::FUNCS "$connName,*"] {
        unset ::FUNCS($i)
    }

    incr ::TCSTATS(tc_unregister_all)
}

#******************************************************
#******************OUTGOING PROTOCOL ******************
#******************************************************

# These are documented in the PROTOCOL document

proc tc_signon {connName authhost authport sn pw lang 
                 {version "Ique.tcl Unknown"}} {

    set cpw $pw
    if {[string  match "0x0x*" $pw]} {
        set cpw [string range $pw 2 end]
    } else {
        set cpw [roast_password $pw]
    }

    set norm [normalize $connName]

    set ::TCSTATS($norm,ONLINE) 0

    sflap::send $norm "tc_signon $authhost $authport [normalize $sn] \
                $cpw $lang [encode $version]"

    incr ::TCSTATS(CONNECTED)
    incr ::TCSTATS(TOTCONNECTED)
    incr ::TCSTATS(tc_signon)
}

proc tc_init_done {connName} {
    sflap::send [normalize $connName] "tc_init_done"

    set funcs [p_getFuncList $connName tc_init_done]
    foreach func $funcs {
        $func $connName
    }
#    update           
#    if {!$::TCSTATS(TOGGLE_CONN)} {
#        tc_toggle_connection [normalize $connName] 1
#        sflap::close2 [normalize $connName] ""
#    }
    incr ::TCSTATS(tc_init_done)
}

proc tc_send_im {connName nick msg {auto ""}} {

    if { $auto == "" } {
         sflap::send [normalize $connName] "IM_IN:[normalize $connName]:F:[encode $msg]:$nick" 
    } else {
         sflap::send [normalize $connName] "tc_send_im [normalize $nick] [encode $msg] " 
    }

    set funcs [p_getFuncList $connName tc_send_im]
    foreach func $funcs {
        $func $connName $nick $msg $auto
    }

    incr ::TCSTATS(tc_send_im)
}

proc tc_add_buddy {connName blist} {
    set str "tc_add_buddy"
    foreach i $blist {
        append str " " [normalize $i]
    }
    sflap::send [normalize $connName] $str

    set funcs [p_getFuncList $connName tc_add_buddy]
    foreach func $funcs {
        $func $connName $blist
    }

    incr ::TCSTATS(tc_add_buddy)
}

proc tc_remove_buddy {connName blist} {
    set str "tc_remove_buddy"
    foreach i $blist {
        append str " " [normalize $i]
    }
    sflap::send [normalize $connName] $str

    set funcs [p_getFuncList $connName tc_remove_buddy]
    foreach func $funcs {
        $func $connName $blist
    }

    incr ::TCSTATS(tc_remove_buddy)
}

proc tc_set_config {connName config} {
    sflap::send [normalize $connName] "tc_set_config {$config}" 

    set funcs [p_getFuncList $connName tc_set_config]
    foreach func $funcs {
        $func $connName $config
    }

    incr ::TCSTATS(tc_set_config)
}

proc tc_evil {connName nick {anon F}} {
    if {$anon == "T" || $anon == "anon"} {
        sflap::send [normalize $connName] "tc_evil [normalize $nick] anon" 
    } else {
        sflap::send [normalize $connName] "tc_evil [normalize $nick] norm" 
    }

    set funcs [p_getFuncList $connName tc_evil]
    foreach func $funcs {
        $func $connName $nick $anon
    }

    incr ::TCSTATS(tc_evil)
}

proc tc_add_permit {connName {plist {}}} {
    set str "tc_add_permit"
    foreach i $plist {
        append str " " [normalize $i]
    }
    sflap::send [normalize $connName] $str

    set funcs [p_getFuncList $connName tc_add_permit]
    foreach func $funcs {
        $func $connName $plist
    }

    incr ::TCSTATS(tc_add_permit)
}

proc tc_add_deny {connName {dlist {}}} {
    set str "tc_add_deny"
    foreach i $dlist {
        append str " " [normalize $i]
    }
    sflap::send [normalize $connName] $str

    set funcs [p_getFuncList $connName tc_add_deny]
    foreach func $funcs {
        $func $connName $dlist
    }

    incr ::TCSTATS(tc_add_deny)
}

proc tc_chat_join {connName exchange loc} {
    sflap::send [normalize $connName] "tc_chat_join $exchange [encode $loc]"

    set funcs [p_getFuncList $connName tc_chat_join]
    foreach func $funcs {
        $func $connName $exchange $loc
    }

    incr ::TCSTATS(tc_chat_join)
}

proc tc_chat_send {connName roomid msg} {
    sflap::send [normalize $connName] "tc_chat_send $roomid [encode $msg]"

    set funcs [p_getFuncList $connName tc_chat_send]
    foreach func $funcs {
        $func $connName $roomid $msg
    }

    incr ::TCSTATS(tc_chat_send)
}

proc tc_chat_whisper {connName roomid user msg} {
    sflap::send [normalize $connName] "tc_chat_whisper $roomid\
                                       [normalize $user] [encode $msg]"

    set funcs [p_getFuncList $connName tc_chat_whisper]
    foreach func $funcs {
        $func $connName $roomid $user $msg
    }

    incr ::TCSTATS(tc_chat_whisper)
}

proc tc_chat_invite {connName roomid msg people} {
    sflap::send [normalize $connName] "tc_chat_invite $roomid\
                                       [encode $msg] $people"

    set funcs [p_getFuncList $connName tc_chat_invite]
    foreach func $funcs {
        $func $connName $roomid $msg $people
    }

    incr ::TCSTATS(tc_chat_invite)
}

proc tc_chat_leave {connName roomid} {
    sflap::send [normalize $connName] "tc_chat_leave $roomid"

    set funcs [p_getFuncList $connName tc_chat_leave]
    foreach func $funcs {
        $func $connName $roomid
    }

    incr ::TCSTATS(tc_chat_leave)
}

proc tc_chat_accept {connName roomid} {
    sflap::send [normalize $connName] "tc_chat_accept $roomid"

    set funcs [p_getFuncList $connName tc_chat_accept]
    foreach func $funcs {
        $func $connName $roomid
    }

    incr ::TCSTATS(tc_chat_accept)
}

proc tc_get_info {connName nick} {
    sflap::send [normalize $connName] "tc_get_info [normalize $nick]" 
    p_simpleFunc $connName $nick tc_get_info
    incr ::TCSTATS(tc_get_info)
}

proc tc_set_info {connName info} {
    sflap::send [normalize $connName] "tc_set_info [encode $info]" 

    p_simpleFunc $connName $info tc_set_info

    incr ::TCSTATS(tc_set_info)
}

proc tc_set_idle {connName idlesecs} {

    if { $::TCSTATS(TOGGLE_CONN) == 1 } {
         set ::inform_server 0
         sflap::send [normalize $connName] "tc_set_idle $idlesecs" 
         sflap::disconnect
    } else {
         sflap::send [normalize $connName] "tc_set_idle $idlesecs" 
    }
    set funcs [p_getFuncList $connName tc_set_idle]
    foreach func $funcs {
         $func $connName $idlesecs
    }

    incr ::TCSTATS(tc_set_idle)
}

proc tc_get_dir {connName nick} {
    sflap::send [normalize $connName] "tc_get_dir $nick"
    p_simpleFunc $connName $nick tc_get_dir

    incr ::TCSTATS(tc_get_dir)
} 

proc tc_set_dir {connName dir_info} {
    sflap::send [normalize $connName] "tc_set_dir $dir_info"
    p_simpleFunc $connName $dir_info tc_set_dir

    incr ::TCSTATS(tc_set_dir)
}

proc tc_dir_search {connName dir_info} {
    sflap::send [normalize $connName] "tc_dir_search $dir_info"
    p_simpleFunc $connName $dir_info tc_dir_search

    incr ::TCSTATS(tc_dir_search)
}

proc tc_toggle_connection {connName boolean} {
    set ::TCSTATS(TOGGLE_CONN) $boolean
#    if {$::inform_server} {
#           sflap::send [normalize $connName] "tc_toggle_connection $boolean" 
#    }
    incr ::TCSTATS(tc_toggle_connection)
}

proc tc_send_passwd {connName epw pw } {
    if {[string  match "0x0x*" $pw]} {
        set cpw [string range $pw 2 end]
    } else {
        set cpw [roast_password $pw]
    }
    if {[string  match "0x0x*" $epw]} {
        set ecpw [string range $epw 2 end]
    } else {
        set ecpw [roast_password $epw]
    }

    set norm [normalize $connName]
    sflap::send $norm "tc_passwd $norm $ecpw $cpw"
}

proc tc_set_search {connName config} {
    sflap::send [normalize $connName] "tc_set_search {$config}" 
}

#******************************************************
#******************INCOMING PROTOCOL ******************
#******************************************************

# These are documented in the PROTOCOL document

proc p_getFuncList {connName func} {
    if {[catch {set al $::FUNCS(*,$func)}] != 0} {
        set al [list]
    }

    if {[catch {set l $::FUNCS($connName,$func)}] == 0} {
        return concat $al $l
    }

    return $al
}

proc p_simpleFunc {connName data func} {
    set funcs [p_getFuncList $connName $func]
    foreach func $funcs {
        $func $connName $data
    }
}

proc scmd_SEARCH {connName data} {
    p_simpleFunc $connName $data SEARCH
}

proc scmd_REGISTER {connName data} {
    p_simpleFunc $connName $data REGISTER
}

proc scmd_PASSWD {connName data} {
    p_simpleFunc $connName $data PASSWD
}

proc scmd_SIGN_ON {connName data} {
    incr ::TCSTATS(SIGN_ON)

    set ::TCSTATS($connName,ONLINE) 1
    incr ::TCSTATS(ONLINE)
    incr ::TCSTATS(TOTONLINE)
    p_simpleFunc $connName $data SIGN_ON
}

proc scmd_CONFIG {connName data} {
    if { ![info exists ::server] } {
        if { [catch { set ::server [socket -server sflap::serverOpen $::AUTH(uretim,port)] } err] } {
             tk_messageBox -message "$::AUTH(uretim,port) kullaniliyor."
             scmd_DISCONNECT $connName
             return
             }
    }

    incr ::TCSTATS(CONFIG)
    p_simpleFunc $connName $data CONFIG
}

proc scmd_NICK {connName data} {
    incr ::TCSTATS(NICK)

    p_simpleFunc $connName $data NICK
}

proc scmd_IM_IN {connName data} {
    incr ::TCSTATS(IM_IN)

    set args [split $data ":"]
    set source [lindex $args 0]
    set sourcel [string length $source]
    set auto [lindex $args 1]
    set dl [string length $data] 
    set msg [string range $data [expr $sourcel + 4] [expr $dl - 3]]

    set funcs [p_getFuncList $connName IM_IN]
    foreach func $funcs {
        $func $connName $source $msg $auto
    }
}

proc scmd_UPDATE_BUDDY {connName data} {
    incr ::TCSTATS(UPDATE_BUDDY)

    set args [split $data ":"]
    set user   [lindex $args 0]
    set online [lindex $args 1]
    set evil   [lindex $args 2]
    set signon [lindex $args 3]
    set idle   [lindex $args 4]
    set uclass [lindex $args 5]
    set IP [lindex $args 6]
    set CPORT [lindex $args 7]

    set funcs [p_getFuncList $connName UPDATE_BUDDY]
    foreach func $funcs {
        $func $connName $user $online $evil $signon $idle $uclass $IP $CPORT
    }
}

proc scmd_ERROR {connName data} {
    incr ::TCSTATS(ERROR)

    set args [split $data ":"]
    set code [string range $args 0 2]
    if {[string length $data] > 4} {
        set args [string range $args 4 end]
    } else {
        set args ""
    }

    set funcs [p_getFuncList $connName ERROR]
    foreach func $funcs {
        $func $connName $code $args
    }
}

proc scmd_EVILED {connName data} {
    incr ::TCSTATS(EVILED)

    set args [split $data ":"]
    set level [lindex $args 0]
    set eviler [lindex $args 1]

    set funcs [p_getFuncList $connName EVILED]
    foreach func $funcs {
        $func $connName $level $eviler
    }
}

proc scmd_DISCONNECT {connName {data ""} } {
    set funcs [p_getFuncList $connName DISCONNECT]
    foreach func $funcs {
        $func $connName $data
    }
}

proc scmd_CHAT_JOIN {connName data} {
    incr ::TCSTATS(CHAT_JOIN)

    set args [split $data ":"]
    set id [lindex $args 0]
    set loc [lindex $args 1]

    set funcs [p_getFuncList $connName CHAT_JOIN]
    foreach func $funcs {
        $func $connName $id $loc
    }
}
proc scmd_CHAT_IN {connName data} {
    incr ::TCSTATS(CHAT_IN)

    set args [split $data :]
    set id [lindex $args 0]
    set idl [string length $id]
    set source [lindex $args 1]
    set sourcel [string length $source]
    set whisper [lindex $args 2]
    set msg [string range $data [expr $idl + $sourcel + 4] end]

    set funcs [p_getFuncList $connName CHAT_IN]
    foreach func $funcs {
        $func $connName $id $source $whisper $msg
    }
}

proc scmd_CHAT_UPDATE_BUDDY {connName data} {
    incr ::TCSTATS(CHAT_UPDATE_BUDDY)

    set args [split $data :]
    set id [lindex $args 0]
    set online [lindex $args 1]
    set argsl [llength $args]

    set blist [list]
    for {set i 2} {$i < $argsl} {incr i} {
        set p [lindex $args $i]
        lappend blist $p
    }

    set funcs [p_getFuncList $connName CHAT_UPDATE_BUDDY]
    IZLEME "$data $id $online $blist $funcs"
    foreach func $funcs {
        $func $connName $id $online $blist
    }
}

proc scmd_CHAT_INVITE {connName data} {
    incr ::TCSTATS(CHAT_INVITE)

    set args [split $data :]
    set loc [lindex $args 0]
    set locl [string length $loc]
    set id [lindex $args 1]
    set idl [string length $id]
    set sender [lindex $args 2]
    set senderl [string length $sender]
    set msg [string range $data [expr $locl + $idl + $senderl + 3] end]

    set funcs [p_getFuncList $connName CHAT_INVITE]
    foreach func $funcs {
        $func $connName $loc $id $sender $msg
    }
}

proc scmd_CHAT_LEFT {connName data} {
    incr ::TCSTATS(CHAT_LEFT)

    p_simpleFunc $connName $data CHAT_LEFT
}

proc scmd_GOTO_URL {connName data} {
    incr ::TCSTATS(GOTO_URL)

    set args [split $data :]
    set window [lindex $args 0]
    set windowl [string length $window]
    incr windowl
    set url [string range $data $windowl end]

    set funcs [p_getFuncList $connName GOTO_URL]
    foreach func $funcs {
        $func $connName $window $url 
    }
}

proc scmd_PAUSE {connName data} {
    incr ::TCSTATS(PAUSE)

    p_simpleFunc $connName $data PAUSE
}

proc scmd_CONNECTION_CLOSED {connName pname reason} {

    incr ::TCSTATS(CONNECTION_CLOSED)
    p_simpleFunc $connName $reason CONNECTION_CLOSED
    if { [info exists ::TCSTATS($connName,ONLINE)] } {
        if {$::TCSTATS($connName,ONLINE)} {
            incr ::TCSTATS(ONLINE) -1
        } else {
            incr ::TCSTATS(TOTAUTHFAIL)
        }
        unset ::TCSTATS($connName,ONLINE)
        incr ::TCSTATS(CONNECTED) -1
    }

}   
proc scmd_DIR_STATUS {connName data} {
    incr ::TCSTATS(DIR_STATUS)

    set args [split $data :]
    set code [string range $args 0 2]
    if {[string length $data] > 4} {
        set args [string range $args 4 end]
    } else {
        set args ""
    }

    set funcs [p_getFuncList $connName DIR_STATUS]
    foreach func $funcs {
        $func $connName $code $args
    }
}
########################################################

#########################################################
proc tc_send_file_header {fnames fsizes pname} {
    set nname [normalize $::KULLANICI]
    set a 1
    sflap::send $nname "FILE_HEADER_INCOMING:$nname:$fnames:$fsizes:$a:$pname"
    set ::ftransferstatus "WAITING_ON_ACCEPTANCE"
    set_ft_status "$pname'in dosya(lar)i kabulu bekleniyor."
}

proc tc_accept_file {pname rejlist} {
   set tkcount [expr $::IQUE(ft_accept,cnt)-1] 
   $::IQUE(ft_accept,$tkcount,toplevel).accept configure -state disabled
   $::IQUE(ft_accept,$tkcount,toplevel).reject configure -state disabled
   if {$rejlist==""} {  
      foreach i [array names ::f "*,chckbut"] {
           set ::f($i) 1
                 }
      update
   }     
   set nname [normalize $::KULLANICI]
   set fd $::sflap::info($nname,fd$pname) 
   sflap::send $nname "FILE_TRANSFER_ACCEPTANCE:$nname:$rejlist:a:$pname"
   set ::cnt 0
   fileevent $fd readable [list sflap::incoming_file $fd $pname]
             
}

proc tc_file_transfer_ongoing {fd pname} {
    incr ::cnt
    set nname [normalize $::KULLANICI]
    sflap::send $nname "FILE_TRANSFER_ONGOING:$nname:$pname"
    fileevent $fd readable [list sflap::incoming_file $fd $pname]
}
proc scmd_FILE_TRANSFER_ACCEPTANCE {connName data } {
    set args [split $data ":"]
    set pname [lindex $args 0]
    set rejlist [lindex $args 1]
    if {$rejlist!=""} {
         set i 0
         foreach rej $rejlist {
               set rmv [expr $rej - $i]
               lappend frejnames [file tail [lindex $::PLIST($pname) $rmv]]
               set ::PLIST($pname) [lreplace $::PLIST($pname) $rmv $rmv]
               incr i 
         }
         set tkcount [expr $::IQUE(ftws,cnt)-1] 
         set w $::IQUE(ftws,$tkcount,toplevel)
         message $w.m -text "$pname $frejnames dosya(lar)ini kabul etmiyor."
         pack $w.m
    }
    set ::cnt 0
    sflap::send_file $pname 
}
proc scmd_FILE_TRANSFER_ONGOING {connName pname} {
    incr ::cnt
    sflap::send_file  $pname 
}
proc scmd_FILE_HEADER_INCOMING {connName data} {
    set args [split $data ":"]
    set pname [lindex $args 0]
    set ::fnames($pname) [lindex $args 1]
    set ::fsizes($pname) [lindex $args 2]
    ique_create_ft_accept $pname 
}

# We keep stats that are used by the testing tools.  These aren't
# need for Takas, so I guess we could remove them. :-)
set ::TCSTATS(tc_open) 0
set ::TCSTATS(tc_close) 0
set ::TCSTATS(tc_register_func) 0
set ::TCSTATS(tc_unregister_func) 0
set ::TCSTATS(tc_unregister_all) 0
set ::TCSTATS(TOTCONNECTED) 0
set ::TCSTATS(CONNECTED) 0
set ::TCSTATS(TOTONLINE) 0
set ::TCSTATS(ONLINE) 0
set ::TCSTATS(TOTAUTHFAIL) 0
set ::TCSTATS(tc_signon) 0
set ::TCSTATS(tc_init_done) 0
set ::TCSTATS(tc_send_im) 0
set ::TCSTATS(tc_add_buddy) 0
set ::TCSTATS(tc_remove_buddy) 0
set ::TCSTATS(tc_set_config) 0
set ::TCSTATS(tc_evil) 0
set ::TCSTATS(tc_add_permit) 0
set ::TCSTATS(tc_add_deny) 0
set ::TCSTATS(tc_chat_join) 0
set ::TCSTATS(tc_chat_send) 0
set ::TCSTATS(tc_chat_whisper) 0
set ::TCSTATS(tc_chat_invite) 0
set ::TCSTATS(tc_chat_leave) 0
set ::TCSTATS(tc_chat_accept) 0
set ::TCSTATS(tc_get_info) 0
set ::TCSTATS(tc_set_info) 0
set ::TCSTATS(tc_set_idle) 0
set ::TCSTATS(tc_toggle_connection) 0
set ::TCSTATS(tc_get_dir) 0
set ::TCSTATS(tc_set_dir) 0
set ::TCSTATS(tc_dir_search) 0

set ::TCSTATS(TOGGLE_CONN) 0
set ::TCSTATS(SIGN_ON) 0
set ::TCSTATS(CONFIG) 0
set ::TCSTATS(NICK) 0
set ::TCSTATS(IM_IN) 0
set ::TCSTATS(UPDATE_BUDDY) 0
set ::TCSTATS(ERROR) 0
set ::TCSTATS(EVILED) 0
set ::TCSTATS(CHAT_JOIN) 0
set ::TCSTATS(CHAT_IN) 0
set ::TCSTATS(CHAT_UPDATE_BUDDY) 0
set ::TCSTATS(CHAT_INVITE) 0
set ::TCSTATS(CHAT_LEFT) 0
set ::TCSTATS(GOTO_URL) 0
set ::TCSTATS(PAUSE) 0
set ::TCSTATS(CONNECTION_CLOSED) 0
set ::TCSTATS(DIR_STATUS) 0
set ::inform_server 1
set ::pref(datapath) "./"

