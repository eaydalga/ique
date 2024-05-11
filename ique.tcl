# The next line is executed by /bin/sh, but not Tcl
#

# Make sure we are in the IQUE directory and load the tc routines.
if {![string match "Win*" $::tcl_platform(os)]} {
    set ::IQUE(windows) 0
    cd [file dirname $argv0]
    catch {cd [file dirname [file readlink $argv0]]}
} else {
    set ::IQUE(windows) 1
    cd [file dirname $argv0]
}
source ique_tc.tcl
source ique_sag.tcl
source ique_kay.tcl

# Set our name for app default stuff
tk appname ique

# Remove the ability to send/receive X events.  If for some reason
# you want this call "tk appname ique" in your ./ique/iquerc
catch {rename send {}}

# Destroy all our children
eval destroy [winfo child .]
wm withdraw .

# Set the http user agent
catch {
#    package require http 2.0
    source http.tcl
    http::config -useragent $VERSION
}

#######################################################
# PROTOCOL LISTENERS
#######################################################
# These are the TC event listeners we registered.
# You can find the args documented in the PROTOCOL document.

proc SIGN_ON {name version} {
    # The following is true after migration
    if {[llength $::BUDDYLIST] > 0} {  
        ique_send_init 1
    }

    if {$::IQUE(INFO,sendinfo)} {
        tc_set_info $name $::IQUE(INFO,msg)
    }
}

proc CONFIG {name data} {
    if {$::IQUE(options,localconfig) != 0} {
        # Ignore what we get from host.
        set data ""
        if {[file exists $::IQUE(configDir)/$::KULLANICI.cnf]} {
            set f [open $::IQUE(configDir)/$::KULLANICI.cnf "r"]
            set data [read $f]
            close $f

            # Send local config to the host.
            if {$::IQUE(options,localconfig) == 2} {
                if {[string length $data] > 1000} {
                    tk_messageBox -type ok -message \
                        "Uzgunuz sizin configurasyonunuz 1000 byte'dan cok"
                } else {
                    tc_set_config $::KULLANICI $data
                }
            }
        }
    }

    ique_parse_config $data

    set ::IQUE(IDLE,sent) 0
    ique_non_idle_event
    ique_check_idle
    ique_send_init 1

    set ::IQUE(online) 1
    foreach package [lsort -ascii [array names ::IQUE pkg,*,pkgname]] {
        set pkgname $::IQUE($package)
        ${pkgname}::goOnline
    }

    ique_show_buddy
    ique_draw_list
    update
}

proc NICK {name nick} {
    set ::KULLAN $nick
}

proc IM_IN {name source msg auto} {
    ique_receive_im $source $auto $msg F
}

proc IM_OUT {name source msg auto} {
    ique_receive_im $source $auto $msg T
}

proc UPDATE_BUDDY {name user online evil signon idle uclass IP CPORT} {
    set bud [normalize $user]

    if {$user != $::BUDDIES($bud,name)} {
        foreach i $::BUDDIES($bud,indexs) {
            catch {sag::change_mainstring .buddy.list $i $user}
        }
    }

    if {$idle == 0} {
        set ::BUDDIES($bud,otherString) ""
    } else {
        set ::BUDDIES($bud,otherString) "($idle)"
    }

    if {$idle != $::BUDDIES($bud,idle)} {
        foreach i $::BUDDIES($bud,indexs) {
            catch {sag::change_otherstring .buddy.list $i \
                   $::BUDDIES($bud,otherString)}
        }
    }

    set ::BUDDIES($bud,name) $user
    set o $::BUDDIES($bud,online)
    set ::BUDDIES($bud,online) $online
    set ::BUDDIES($bud,evil) $evil
    set ::BUDDIES($bud,signon) $signon
    set ::BUDDIES($bud,idle) $idle
    set u $::BUDDIES($bud,uclass)
    set ::BUDDIES($bud,uclass) $uclass
    set ::BUDDIES($bud,IP) $IP
    set ::BUDDIES($bud,service) $CPORT

    ique_title_cim $user

    if {$o != $online} {
        if {$online == "T"} {
            set ::BUDDIES($bud,icon) "Login"
            ique_draw_list F
        } else {
            set ::BUDDIES($bud,icon) "Logout"
        }

        foreach i $::BUDDIES($bud,indexs) {
            catch {sag::change_icon .buddy.list $i $::BUDDIES($bud,icon)}
        }
        after 10000 ique_removeicon $bud

        if {$bud != $::KULLANICI} {
            if {$online == "T"} {
                after 100 ique_play_sound $::IQUE(SOUND,Arrive)
            } else {
                after 100 ique_play_sound $::IQUE(SOUND,Depart)
            }
        }

        ique_update_group_cnts
    } elseif {$u != $uclass} {
        ique_update_uclass $bud
    }
    ique_update_ptext $bud
}

proc ERROR {name code data} {
    set args [split $data ":"]
    switch -exact -- $code {
    "901" {
        tk_messageBox -type ok -message "[lindex $args 0] Henuz gecerli bir islem degil."
    } 
    "902" {
        tk_messageBox -type ok -message\
            "UYARI! [lindex $args 0] kabul edilmedi."
    } 
    "903" {
        tk_messageBox -type ok -message "Bir mesaj iptal edildi. Siz\
                                         Sunucu hizini zorluyorsunuz."
    } 
    "950" {
        tk_messageBox -type ok -message \
            "[lindex $args 0] dan Chat erisime acik degil."
    }
    "960" {
        tk_messageBox -type ok -message \
            "[lindex $args 0] baðlantýsýnda sorun var mesaji alamýyor..."
    }
    "961" {
        tk_messageBox -type ok -message \
            "Cok buyuk oldugu icin [lindex $args 0] tarafindan gelen mesaji alamadiniz"
    }
    "962" {
        tk_messageBox -type ok -message "Cok hizli gonderildigi icin \
            [lindex $args 0] tarafindan gonderilen mesaji alamadiniz."
    }
    "980" {
        tk_messageBox -type ok -message "Gecersiz kullanici Adi ya da sifresi girilmis."
        if { [winfo exists .login] } { .login.bF.signon configure -state active }
    }
    "981" {
        tk_messageBox -type ok -message "Bu hizmet gecici bir sure icin kullanima kapalidir."
    }
    "982" {
        tk_messageBox -type ok -message \
            "Sizin Izleme duzeyiniz sisteme baglanmak icin cok yuksek."
        if { [winfo exists .login] } { .login.bF.signon configure -state active }
    }
    "983" {
        tk_messageBox -type ok -message "Cok fazla baglaniyor ve baglantiyi kesiyorsunuz.\
            10 dakika bekleyin ve yeniden deneyin.\
            Eger boyle devam ederseniz daha uzun sure beklemeniz gerekecektir."
        if { [winfo exists .login] } { .login.bF.signon configure -state active }
    }
    "989" {
        tk_messageBox -type ok -message \
            "Bilinmeyen baglanti hatasi olustu: ([lindex $args 0])"
        if { [winfo exists .login] } { .login.bF.signon configure -state active }
    }
    default {
        tk_messageBox -type ok -message "Bilinmeyen bir hata $code:$data"
    }
    } ;# SWITCH
}

proc EVILED {name level user} {
    if {[string length $user] == 0 } {
       sflap::send [normalize $name] "tc_ok"
#        tk_messageBox -type ok -message \
#            "Sunucudan uyarildiniz! Sizin yeni uyari duzeyiniz %$level oldu."
    } else {
        tk_messageBox -type ok -message \
            "$user tarafindan uyarildiniz! Sizin yeni uyari duzeyiniz %$level oldu."
    }
}

proc CHAT_JOIN {name id loc} {
    catch {
        set people $::IQUE(invites,$loc,people)
        set msg $::IQUE(invites,$loc,msg)

        set p ""
        foreach i [split $people "\n" ] {
            set n [normalize $i]
            if {($n != "")} {
                append p $n
                append p " "
            }
        }

        if {$p != ""} {
            tc_chat_invite $name $id $msg $p
        }

        unset ::IQUE(invites,$loc,people)
        unset ::IQUE(invites,$loc,msg)
    }

    ique_create_chat $id $loc
}

proc CHAT_LEFT {name id} {
    ique_leave_chat $id
}

proc CHAT_IN {name id source whisper msg} {
    ique_receive_chat $id $source $whisper $msg
}

proc CHAT_UPDATE_BUDDY {name id online blist} {
    set w $::IQUE(chats,$id,list)

    if {[winfo exists $w] == 0} {
        return
    }

    foreach p $blist {
        set np [normalize $p]
        if {[info exists ::IQUE(chats,$id,people,$np)]} {
            if {$online == "F"} {
                catch {sag::remove $w $::IQUE(chats,$id,people,$np)}
                ique_receive_chat $id "*" F "$p ayrildi."
                unset ::IQUE(chats,$id,people,$np)
            }
        } else {
            if {$online == "T"} {
                set ::IQUE(chats,$id,people,$np) [sag::add $w 0 "" $p "" \
                    $::IQUE(options,buddymcolor) $::IQUE(options,buddyocolor)]
                ique_receive_chat $id "*" F "$p geldi."
            }
        }
    }
}

proc CHAT_INVITE {name loc id sender msg} {
    ique_create_accept $loc $id $sender $msg
}

proc GOTO_URL {name window url} {
    set tc $::SELECTEDTC

    if {[string match "http://*" $url]} {
        ique_show_url $window $url
    } else {
        if {$::USEPROXY != "Yok"} {
            ;# When using a proxy host must be an ip already.
            set ip $::TC($tc,host)
        } else {
            ;# Not using socks, look up the peer ip.
            set ip [lindex [sflap::peerinfo $name] 0]
        }
        ique_show_url $window "http://$ip:$::TC($tc,port)/$url"
    }
}

proc PAUSE {name data} {
    tk_messageBox -message "Bekliyor.."
}

proc DISCONNECT {name data} {
     sflap::disconnect                
     set ::TCSTAT(TOGGLE_CONN) 1
}

proc CONNECTION_CLOSED {name data} {
    if { [winfo exists .login] } { .login.bF.signon configure -state active }
    ique_show_login
    setStatus "Baglanti kesildi."
    catch {after cancel $::IQUE(IDLE,timer)}
    set ::IQUE(IDLE,sent) 0
    set ::IQUE(online) 0
    foreach package [lsort -ascii [array names ::IQUE pkg,*,pkgname]] {
        set pkgname $::IQUE($package)
        ${pkgname}::goOffline
    }
}

proc REGISTER {name data} {
    # registeration completed.
    tk_messageBox -message "$name icin Kayit Islemi tamamlandi"
    # store default values into ique file
    # close connection
    DISCONNECT $name $data
    set ::TCSTAT(TOGGLE_CONN) 1
    if { ![winfo exists .login] } {
         # restart program...
         tk_messageBox -message "Programi yeniden baslatin"
         exit
    } else {
         if { [winfo exists .top17] } {
              destroy .top17
         }
         focus -force .login
    }
}

# passwd isleminden donen mesaj ekranda goruntulenir
proc PASSWD {name data} {
     tk_messageBox -message "$data"
}

proc form_userdata { line } {
     set name [lindex [split $line :] 0]
     set data [lindex [split $line :] 1]
     foreach pair [split $data &] {
         set vari [lindex [split $pair =] 0]
         set deger [lindex [split $pair =] 1]
         set kayit($vari) $deger
     }
     set data "$name $kayit(sinif) $kayit(adsoyad)"
     return $data
}

# search sonucunda donen bilgiyi listeye tasi
proc SEARCH {name data} {
     set searchwin .sresult
     set namex [lindex [split $data] 0]
     set len [string length $namex]
     set ldata [string range $data $len end]
     foreach line [split $ldata \n] {
         if { [string length $line] > 2 } {
              if { ![winfo exist $searchwin] } {
                    create_searchwin
              }
              set userdata [form_userdata $line]
              $searchwin.fra18.cpd21.01 insert end $userdata
         }
     }
     if { [winfo exist $searchwin] } {
          focus -force $searchwin
     }
}

proc selected_user { selection } {
     if { $selection == "" } {
          tk_messageBox -message "Secim Yapilmamis"
          return
     }
     set searchwin .sresult
     if { ![winfo exist $searchwin] } {
           return
     }
     set line [$searchwin.fra18.cpd21.01 get $selection]
     $searchwin.fra18.cpd21.01 selection clear $selection
     set liste [split $line]
     set no 0
     set uname [lindex $liste $no]
     if { $uname == "" } {
          incr no
          set uname [lindex $liste $no]
     }
     set name [normalize $uname]
     set group "genel"
     incr no
     if { $name != $::KULLANICI } {
          set group [lindex $liste $no]
          if { $name == "" } {
               tk_messageBox -message "kullanici adi secilmemis..."
               return
          }
          if { ![info exists ::BUDDIES($name,name)] } {
               ique_add_buddy $group $name
               ique_set_config
               tk_messageBox -message "$name adli kullanici $group altina eklendi"
          } else {
               tk_messageBox -message "HATA: $name kullanici listesinde var..."
          }
     } else {
          tk_messageBox -message "HATA: $name sizin adiniz..."
     }
}

#######################################################
# CALLBACKS
#######################################################
# This routines are callbacks for buttons and menu selections.

# ique_get_info --
#     Request information on a person
#
# Arguments:
#     name   - SFLAP connection
#     person - get info on

proc ique_get_info {name person} {
    if { $person == "" } {
        tk_messageBox -type ok -message "Lutfen bilgisini gormek istediginiz bir kullanici secin."
    } else {
        tc_get_info $name $person
    }
}

# ique_kayitol --
# ilk kez kullanan icin IQUE sunucuya tanim yapma
#

proc ique_kayitol {} {
     create_kayitol
}

proc ique_kayit {} {

    # daha once kayit olmussa burada cik

    if {[string length [normalize $::KULLAN]] < 2} {
        tk_messageBox -type ok -message "Lutfen bir kullanici adi girin."
        return
    }

    if {[string length $::PASSWORD] < 3} {
        tk_messageBox -type ok -message "Lutfen bir sifre girin."
        return
    }

    if { $::PASSWORD != $::PASSWORD1 } {
        tk_messageBox -type ok -message "Sifre ve Onayi eslesmiyor."
        return
    }

    set ::KULLANICI $::KULLAN
    set nm [normalize $::KULLAN]
    # connect to server with user name and user info
    set tc "uretim"
    set e [sflap::connect $nm "" $::TC($tc,host) \
          $::TC($tc,port) $nm $::IQUE(proxies,$::USEPROXY,connFunc)]
    # 
    # if error exit from program
    # 
    # destroy .reg
    # destroy .

    # kayit olma bilgilerini gonder
    # 
    set regdata ""
    append regdata "adsoyad=$::kayit(adsoyad)&"
    append regdata "cins=$::kayit(cins)&"
    append regdata "meslek=$::kayit(meslek)&"
    append regdata "mdurum=$::kayit(mdurum)&"
    append regdata "ogrenim=$::kayit(ogrenim)&"
    append regdata "sehir=$::kayit(sehir)&"
    append regdata "ulke=$::kayit(ulke)&"
    append regdata "gun=$::kayit(gun)&"
    append regdata "ay=$::kayit(ay)&"
    append regdata "yil=$::kayit(yil)&"
    append regdata "abone=$::kayit(abone)&"
    append regdata "eposta=$::kayit(eposta)&"
    append regdata "sinif=$::kayit(sinif)&"
    tc_register $nm $::PASSWORD $regdata
}

# ique_signon --
#     Called when then Signon button is pressed.  This starts the
#     signon process.

proc ique_signon {} {
    if {$::IQUE(online)} {
        tk_messageBox -type ok -message "online oldugunuz halde baglanmak istiyorsunuz!"
        return
    }

    if {[string length [normalize $::KULLAN]] < 2} {
        tk_messageBox -type ok -message "Lutfen bir kullanici adi girin."
        return
    }

    if {[string length $::PASSWORD] < 3} {
        tk_messageBox -type ok -message "Lutfen bir sifre girin."
        return
    }
    if { [winfo exists .login] } { .login.bF.signon configure -state disabled }
    set ::BUDDYLIST [list]
    set ::PERMITLIST [list]
    set ::DENYLIST [list]
    catch {unset ::BUDDIES}
    catch {unset ::GROUPS}
    set ::PDMODE 1
    set ::KULLANICI [normalize $::KULLAN]

    setStatus "Merkeze Baglaniyor";

    set auth $::SELECTEDAUTH
    set tc $::SELECTEDTC

    tc_open $::KULLANICI $::TC($tc,host) $::TC($tc,port) \
                   $::AUTH($auth,host) $::AUTH($auth,port) \
                   $::KULLANICI $::PASSWORD turkce $::REVISION \
                   $::IQUE(proxies,$::USEPROXY,connFunc)
    #
    # hata varsa baglanti dugmesini ac
    #
    if { [winfo exists .login] } { .login.bF.signon configure -state active }
}

# ique_set_color --
#     Allow the user to chose a color for a entry.
# 
# Arguments:
#     type - ique window type
#     desc - color choser window title
#     id   - ique window id

proc ique_set_color { type desc id} {
    set color [tk_chooseColor -initialcolor $::IQUE($type,$id,color) -title $desc]
    if {$color == ""} {
        return
    }
    set ::IQUE($type,$id,color) $color
    $::IQUE($type,$id,msgw) configure -foreground $color
}

# ique_set_default_color --
#     Set the default color for a particular window type
# 
# Arguments:
#     type - The window type.
proc ique_set_default_color { type } {
    set color [tk_chooseColor -initialcolor $::IQUE(options,$type)\
               -title "Varsayilan Renkler"]
    if {$color == ""} {
        return
    }
    set ::IQUE(options,$type) $color
}

# ique_signoff --
#     Start the signoff process.

proc ique_signoff {} {
#    set ::inform_server 0
#    sflap::send $::KULLANICI "tc_close"
#    tc_close $::KULLANICI
#    after 1300
#            wm iconify .login
#            update
    set sflap::info($::KULLANICI,FLAP_SIGNONbuddy) false
    catch {after cancel $::IQUE(IDLE,timer)}
    set ::IQUE(IDLE,sent) 0
    set ::IQUE(online) 0
    foreach package [lsort -ascii [array names ::IQUE pkg,*,pkgname]] {
        set pkgname $::IQUE($package)
        ${pkgname}::goOffline
    }
    if { [info exists ::server] } {
         close $::server
         unset ::server
    }
    if { [winfo exists .login] } { .login.bF.signon configure -state active }
    setStatus "Yeniden baglanincaya dek hoscakalin!"
    ique_show_login
    update
}

# ique_add_buddy --
#     Add a new buddy/group pair to the internal list of buddies.
#     This does not send anything to the server.
#
# Arguments:
#     group - group the buddy is in
#     name  - name of the buddy

proc ique_add_buddy {group name} {
    if {![info exists ::BUDDIES($name,online)]} {
        set ::BUDDIES($name,type) IQUE
        set ::BUDDIES($name,online) F
        set ::BUDDIES($name,icon) ""
        set ::BUDDIES($name,indexs) ""
        set ::BUDDIES($name,popupText) ""
        set ::BUDDIES($name,otherString) ""
        set ::BUDDIES($name,name) $name
        set ::BUDDIES($name,idle) 0
        set ::BUDDIES($name,uclass) ""
        set ::BUDDIES($name,IP) ""
        set ::BUDDIES($name,service) ""
        tc_add_buddy $::KULLANICI $name
    }

    if {![info exists ::GROUPS($group,people)]} {
        set ::GROUPS($group,people) [list]
        set ::GROUPS($group,collapsed) F
        set ::GROUPS($group,type) IQUE
        set ::GROUPS($group,online) 0
        set ::GROUPS($group,total) 0
        lappend ::BUDDYLIST $group
        lappend ::GROUPS($group,people) $name
        ique_edit_draw_list
    } else {
        lappend ::GROUPS($group,people) $name
        ique_edit_draw_list $group $name
    }
    ique_update_group_cnts

    ique_draw_list
}

# ique_add_pd --
#     Add a new permit/deny person.  This doesn't change
#     anything on the server.
#
# Arguments:
#     group - either permit or deny
#     name  - the person to permit/deny

proc ique_add_pd {group name} {
    if {$group == "Permit"} {
        lappend ::PERMITLIST $name
    } else {
        lappend ::DENYLIST $name
    }
    ique_pd_draw_list
}

# ique_set_config --
#     Create a string that represents the current buddylist and permit/deny
#     settings.  Based on options we send this config to the host and/or
#     the local disk.

proc ique_set_config {} {
    set str ""
    append str "m $::PDMODE\n"
    foreach p $::PERMITLIST {
        append str "p $p\n"
    }
    foreach d $::DENYLIST {
        append str "d $d\n"
    }
    foreach g $::BUDDYLIST {
        if {$::GROUPS($g,type) != "IQUE"} {
            continue
        }
        append str "g $g\n"
        foreach b $::GROUPS($g,people) {
            append str "b $b\n"
        }
    }

    set ::IQUE(config) $str

    if {$::IQUE(options,localconfig) > 0} {
        set file [open "$::IQUE(configDir)/$::KULLANICI.cnf" "w"]
        puts -nonewline $file $str
        close $file
    } 
    
    if { $::IQUE(options,localconfig) != 1} {
        if {[string length $str] > 1000} {
            tk_messageBox -type ok -message \
                           "Ozur dileriz, sizin konfigurasyonunuz 1000 byte'tan cok."
        } else {
            tc_set_config $::KULLANICI $str
        }
    }
}

# ique_send_init --
#     Send the TC server initialization sequence.  Basically
#     the buddy list, permit/deny mode, followed by tc_init_done.
#
# Arguments:
#     first - If not the first we don't do the tc_init_done,
#             and we also clear the permit/deny settings before sending.

proc ique_send_init {first} {
    foreach g $::BUDDYLIST {
        if {$::GROUPS($g,type) != "IQUE"} {
            continue
        }
        foreach b $::GROUPS($g,people) {
            lappend buds $b
        }
    }

    if {[info exists buds] == 0} {
        ique_add_buddy Buddies [normalize $::KULLAN]
    } else {
        tc_add_buddy $::KULLANICI $buds
    }

    if {!$first} {
        # This will flash us, but who cares, I am lazy. :(
        tc_add_permit $::KULLANICI
        tc_add_deny $::KULLANICI
    }

    if {$::PDMODE == "3"} {
        tc_add_permit $::KULLANICI $::PERMITLIST
    } elseif {$::PDMODE == "4"} {
        tc_add_deny $::KULLANICI $::DENYLIST
    }

    if {$first} {
        tc_init_done $::KULLAN
    }
}

# ique_is_buddy --
#     Check to see if a name is on our buddy list.
#
# Arguments:
#     name - buddy to look for.

proc ique_is_buddy {name} {
    foreach g $::BUDDYLIST {
        foreach b $::GROUPS($g,people) {
            if {$b == $name} {
                return 1
            }
        }
    }

    return 0
}

# ique_show_url --
#     Routine that is called to display a url.  By default
#     on UNIX we just call netscape, on windows we use start.
#
# Arguments:
#     window - The window name to display the url in, ignored here
#     url    - The url to display.

proc ique_show_url {window url} {
     if { $::IQUE(windows) } {
         catch {exec start $url &}
     } else {
         catch {exec netscape -remote openURL($url) &}
     }
}

# ique_play_sound --
#     Play a sound file.   This is platform dependant, and will
#     need to be changed or overridden on some platforms.
#
# Arguments:
#     soundfile - The sound file to play.

# This keeps multiple sounds from building up.  Since
# au files are about 8000 bytes a sec we can guess how
# long the file is.
proc ique_play_sound {soundfile} {
    if {($::SOUNDPLAYING == 0) || (![file exists $soundfile])} return
    set ::SOUNDPLAYING 1
    after [expr [file size $soundfile] / 8] set ::SOUNDPLAYING 0

    switch -glob -- $::tcl_platform(os) {
    "IRIX*" {
        catch {exec /usr/sbin/playaifc -p $soundfile 2> /dev/null &}
    }
    "OSF1*" {
        catch {exec /usr/bin/mme/decsound -play $soundfile 2> /dev/null &}
    }
    "HP*" {
        catch {exec /opt/audio/bin/send_sound $soundfile 2> /dev/null &}
    }
    "AIX*" {
        catch {exec /usr/lpp/UMS/bin/run_ums audio_play -f $soundfile 2> /dev/null &} 
    }
    "UnixWare*" -
    "SunOS*" {
        catch {exec dd if=$soundfile of=/dev/audio 2> /dev/null &}
    }
    "Windows*" {
        catch {exec C:/windows/rundll32.exe "C:\Program Files\Windows Media Player\mplayer2.exe,RunDll"  /Play /close "$soundfile" & }
    }
    default {
        catch {exec dd if=$soundfile of=/dev/audio 2> /dev/null &}
    }
    };# SWITCH
}

# ique_non_idle_event --
#     Called when an event happens that indicates we are not idle.
#     We check to see if we previous said we were idle, and change
#     that.

proc ique_non_idle_event {} {
    set ::IQUE(IDLE,last_event) [clock seconds]
    if {$::IQUE(IDLE,sent)} {
        set ::IQUE(IDLE,sent) 0
        tc_set_idle $::KULLANICI 0
    }
}

# ique_check_idle --
#     Timer that checks to see if the last non idle event
#     happened more then 15 minutes ago.  If it did we tell the
#     server that we are idle.

proc ique_check_idle {} {
    if {!$::IQUE(IDLE,sent)} {
        set cur [clock seconds]
        if {$::IQUE(options,reportidle) && $cur - $::IQUE(IDLE,last_event) > 900} {
            tc_set_idle $::KULLANICI [expr ($cur - $::IQUE(IDLE,last_event))]
            set ::IQUE(IDLE,sent) 1
        }
    }
    set ::IQUE(IDLE,timer) [after 30000 ique_check_idle]
}

proc ique_create_passwd { } {
    if {[winfo exists .passwd]} {
        destroy .passwd
    }
    set ::PASSWD ""
    set ::PASSWDX ""
    set ::PASSWD1 ""

    toplevel .passwd -class Takas
    wm title .passwd "Sifre Degistir"
    wm iconname .passwd "Sifre"

    wm protocol .passwd WM_DELETE_WINDOW {destroy .passwd }
    wm withdraw .passwd

    label .passwd.kullan -text "$::KULLANICI icin Yeni Sifre" -width 40
    frame .passwd.esifre
    label .passwd.esifre1 -text "Eski Sifreniz: " -width 15
    entry .passwd.esifre1e -font $::NORMALFONT -width 10 -relief sunken -textvariable ::PASSWDX -show "*"

    pack .passwd.esifre1 .passwd.esifre1e -in .passwd.esifre -side left -expand 1

    frame .passwd.sifre
    label .passwd.sifre1 -text "Yeni Sifreniz: " -width 15
    entry .passwd.sifre1e -font $::NORMALFONT -width 10 -relief sunken -textvariable ::PASSWD -show "*"

    pack .passwd.sifre1 .passwd.sifre1e -in .passwd.sifre -side left -expand 1

    frame .passwd.ysifre
    label .passwd.ysifre1 -text "Sifre Onayi: " -width 15
    entry .passwd.ysifre1e -font $::NORMALFONT -width 10 -relief sunken -textvariable ::PASSWD1 -show "*"
    pack .passwd.ysifre1 .passwd.ysifre1e -in .passwd.ysifre -side left -expand 1

    frame .passwd.buttons
    button .passwd.buttons.tamam -text Tamam -command ique_passwd
    button .passwd.buttons.vazgec -text Vazgec -command {destroy .passwd}
    pack .passwd.buttons.tamam .passwd.buttons.vazgec -side left -expand 1

    pack .passwd.kullan .passwd.esifre .passwd.sifre \
         .passwd.ysifre .passwd.buttons \
         -expand 0 -fill x -ipady 1m

    bind .passwd.esifre1e <Return> { focus .passwd.sifre1e }
    bind .passwd.sifre1e <Return> { focus .passwd.ysifre1e }
    bind .passwd.ysifre1e <Return> { ique_passwd }
    bind .passwd <Return> { ique_passwd }
    focus .passwd.esifre1e

    wm deiconify .passwd
    raise .passwd
}

proc ique_passwd { } {
#
    if { $::PASSWD != $::PASSWD1 } {
        tk_messageBox -message "Sifre ve Onayi uyumsuz"
        return
    }
    if {[string length $::PASSWD] < 3} {
        Mesaj 12
        return
    }
    if {[string length $::PASSWDX] < 3} {
        Mesaj 12
        return
    }
    if {[winfo exists .passwd]} {
        destroy .passwd
    }
    tc_send_passwd $::KULLANICI $::PASSWDX [string trimright $::PASSWD]
}

#######################################################
# UI UTILS
#######################################################
# createINPUT --
#     Create an input area based with different properities
#     based on set options.
#
# Arguments:
#     w  - the widget that will be packed in the upper layer, either
#          the widget created, or frame.
#     op - option to check.
#
# Returns:
#     The text or entry widget.

proc createINPUT {w op {width 40}} {
    if { $::IQUE(options,$op) == 0} {
        entry $w -font $::NORMALFONT -width $width
        return $w
    } elseif { $::IQUE(options,$op) > 0 } {
        text $w -font $::NORMALFONT -width 40 \
            -height $::IQUE(options,$op) -wrap word
        return $w
    } else {
        frame $w
        text $w.text -font $::NORMALFONT -width 40 \
            -height [string range $::IQUE(options,$op) 1 end] -wrap word \
            -yscrollcommand [list $w.textS set]
        scrollbar $w.textS -orient vertical -command [list $w.text yview]
        pack $w.textS -side right -in $w -fill y
        pack $w.text -side left -in $w -fill both -expand 1
        return $w.text
    }
}

# createHTML --
#     Create a HTML display area, basically just a text area
#     and scrollbar.
#
# Arguments:
#     w - frame name to place everything in.
#
# Results:
#     The text widget.

proc createHTML {w} { 
    frame $w
    scrollbar $w.textS -orient vertical -command [list $w.text yview]
    text $w.text -font $::NORMALFONT -yscrollcommand [list $w.textS set] \
        -state disabled -width 40 -height 10 -wrap word
    pack $w.textS -side right -in $w -fill y
    pack $w.text -side left -in $w -fill both -expand 1

    $w.text tag configure italic -font $::ITALICFONT
    $w.text tag configure bold -font $::BOLDFONT
    $w.text tag configure underline -underline true
    $w.text tag configure bbold -foreground blue -font $::BOLDFONT
    $w.text tag configure rbold -foreground red -font $::BOLDFONT

    set ::HTML($w.text,linkcnt) 0
    set ::HTML($w.text,hrcnt) 0

    bind $w.text <Configure> "p_updateHRHTML $w.text %w"

    return $w.text
}

# p_update_HRHTML --
#     Private method that takes care of resizing HR rule bars.
proc p_updateHRHTML {w width} {
   set width [expr {$width - 10}]

   for {set i 0} {$i < $::HTML($w,hrcnt)} {incr i} {
       $w.canv$i configure -width $width
   }
}

proc addHTML {w text {doColor 0}} {
    set bbox [$w bbox "end-1c"]
    set bold 0
    set italic 0
    set underline 0
    set inlink 0
    set color "000000"

    set results [splitHTML $text]
    foreach e $results {
        regsub -all "&lt;" $e "<" e
        regsub -all "&gt;" $e ">" e
        switch -regexp -- $e {
            "^<[fF][oO][nN][tT][^#]*[cC][oO][lL][oO][rR]=\"#[0-9a-fA-F].*>" {
                # We should use regexp here sometime.
                catch {set color [string range $e [expr \
                    [string first "#" $e]+1] [expr [string first "#" $e]+6]]}
            }
            "^<[bB]>$" {
                set bold 1
            }
            "^</[bB]>$" {
                set bold 0
            }
            "^<[iI]>$" {
                set italic 1
            }
            "^</[iI]>$" {
                set italic 0
            }
            "^<[uU]>$" {
                set underline 1
            }
            "^</[uU]>$" {
                set underline 0
            }
            "^<[aA].*>$" {
                set inlink 1
                incr ::HTML($w,linkcnt)
                $w tag configure link$::HTML($w,linkcnt) -font $::BOLDFONT \
                    -foreground blue -underline true
                $w tag bind link$::HTML($w,linkcnt) <Enter> {%W configure -cursor hand2}
                $w tag bind link$::HTML($w,linkcnt) <Leave> {
                    regexp {cursor=([^ ]*)} [%W tag names] x cursor
                    %W configure -cursor $cursor
                }
                if {[regexp {"(.*)"} $e match url]} {
                    $w tag bind link$::HTML($w,linkcnt) <ButtonPress> \
                               [list ique_show_url im_url $url]
                    $w tag bind link$::HTML($w,linkcnt) <ButtonPress-3> [list ique_showurl_popup $url %X %Y]
                    $w tag bind link$::HTML($w,linkcnt) <ButtonRelease-3> {ique_showurl_release}
                } else {
                    $w tag bind link$::HTML($w,linkcnt) <ButtonPress> \
                               [list tk_messageBox -type ok -message \
                               "$e den URL adresi secilemedi"]
                }
            }
            "^</[aA]>$" {
                set inlink 0
            }
            "^<[pP]>$" -
            "^<[bB][rR]>$" {
                $w insert end "\n"
            }
            "^<[hH][rR].*>$" {
                canvas $w.canv$::HTML($w,hrcnt) -width 1000 -height 3
                $w.canv$::HTML($w,hrcnt) create line 0 3 1000 3 -width 3
                $w window create end -window $w.canv$::HTML($w,hrcnt) -align center
                $w insert end "\n"
                incr ::HTML($w,hrcnt)
            }
            "^<[cC][eE][nN][tT][eE][rR].*>$" -
            "^<[hH][123456].*>$" -
            "^<[iI][mM][gG].*>$" -
            "^<[tT][iI][tT][lL][eE].*>$" -
            "^<[hH][tT][mM][lL].*>$" -
            "^<[bB][oO][dD][yY].*>$" -
            "^<[fF][oO][nN][tT].*>$" -
            "^<[pP][rR][eE]>$" -
            "^<!--.*-->$" -
            "^</.*>$" -
            "^$" {
            }
            default {
                set style [list]

                if {$bold} {
                    lappend style bold
                }
                if {$underline}  {
                    lappend style underline
                }
                if {$italic} {
                    lappend style italic
                }

                if {$inlink} {
                    set style [list link$::HTML($w,linkcnt)] ;# no style in links
                    lappend style cursor=[$w cget -cursor]
                }

                if {$doColor} {
                    $w tag configure color$color -foreground #$color
                    lappend style color$color
                }

                $w insert end $e $style
            }
        }
    }
    if {$bbox != ""} {
        $w see end
    }
}

# ique_lselect --
#     Used as the callback for dealing with the buddy list.
#     it allows you to set up two different commands to be called
#     based on if the item selected is a group or not.
#
# Arguements:
#     list     - list widget
#     command  - command if a normal buddy
#     gcommand - command if a group.  A "-" for gcommand means
#                call the $command argument with no args.

proc ique_lselect {list command {gcommand ""}} {
    set sel [sag::selection $list]

    set name $::KULLANICI

    if {$sel == ""} {
        if {$command != ""} {
            $command $name ""
        }
        return
    }

    foreach s $sel {
        set c [string index $s 0]
        if {$c == "+" || $c == "-"} {
            if {$gcommand == "-"} {
                $command $name ""
            } elseif {$gcommand != "" } {
                $gcommand $name [string range $s 2 end]
            }
        } else {
            if {$command != ""} {
                $command $name [string trim $s]
            }
        }
    }
}

# ique_handleGroup -
#     Double Click callback for groups.  This collapses the groups.
#
# Arguments:
#     name  - unused
#     group - the group to collapse

proc ique_handleGroup {name group} {
    if {$::GROUPS($group,collapsed) == "T"} {
        set ::GROUPS($group,collapsed) "F"
    } else {
        set ::GROUPS($group,collapsed) "T"
    }

    ique_draw_list
}


# ique_double_click --
#     The user double clicked on a buddy, call the registered double
#     click method for the buddy.
#
# Arguments:
#     name  - the SFLAP connection
#     buddy - the buddy that was double clicked.

proc ique_double_click {name buddy} {
    set nbud [normalize $buddy]
    if {[info exists ::BUDDIES($nbud,doubleClick)]} {
        $::BUDDIES($nbud,doubleClick) $name $buddy
    } else {
            ique_create_iim $name $buddy
    }
}

proc ique_gonder_click {name buddy} {
    ique_export_file $name $buddy
}

# ique_show_buddy --
#     Show the buddy window, we first withdraw
#     the login window in case it is around.

proc ique_show_buddy {} {
    if {[winfo exists .login]} {
        wm withdraw .login
    }

    if {[winfo exists .buddy]} {
        wm deiconify .buddy
        raise .buddy
        ## wm iconify .buddy
    }
}

#######################################################
# Popup Routines
#######################################################

# ique_buddy_popup --
#     Generic routine for showing the popup for a buddy
#     at a given location.
#
# Arguments:
#     bud - The buddy to show information about, this might not
#           actually be a buddy in the true sense, since socks can be.
#     X   - The x root position
#     Y   - The y root position

proc ique_buddy_popup {bud X Y} {
    set w .buddypopup
    catch {destroy $w}

    set nstr [normalize $bud]
    if {$nstr == ""} {
        return
    }
    toplevel $w -border 1 -relief solid
    wm overrideredirect .buddypopup 1

    set textlist $::BUDDIES($nstr,popupText)

    set nlen 0
    set vlen 0
    foreach {name value} $textlist {
        set nl [string length $name]
        set vl [string length $value]

        if {$nl > $nlen} {
            set nlen $nl
        }
        if {$vl > $vlen} {
            set vlen $vl
        }
    }

    set i 0
    foreach {name value} $textlist {
        label $w.name$i -text $name -width $nlen -anchor se
        label $w.value$i -text $value -width $vlen -anchor sw
        grid $w.name$i $w.value$i -in $w
        incr i
    }

    set width [expr ($vlen + $nlen) * 10]
    set height [expr ($i * 25)]
    set screenwidth [winfo screenwidth $w]
    set screenheight [winfo screenheight $w]

    if {$X < 0} {
        set X 0
    } elseif {[expr $X + $width] > $screenwidth} {
        set X [expr $screenwidth - $width]
    }

    if {[expr $Y + $height] > $screenheight} {
        set Y [expr $screenheight - $height]
    }

    wm geometry $w +$X+$Y
}

# ique_buddy_release --
#     Hide the buddy popup.
proc ique_buddy_release {} {
    catch {destroy .buddypopup}
}

# ique_showurl_popup --
#     Generic routine for showing a URL, which is just a string
#
# Arguments:
#     url - The url (or string) to show
#     X   - The x root position
#     Y   - The y root position

proc ique_showurl_popup {url X Y} {
    set w .urlpopup
    catch {destroy $w}

    if {$url == ""} {
        return
    }
    toplevel $w -border 1 -relief solid
    wm overrideredirect $w 1

    set nlen [string length $url]

    label $w.url -text $url
    pack $w.url

    set width $nlen
    set height 25
    set screenwidth [winfo screenwidth $w]
    set screenheight [winfo screenheight $w]

    if {$X < 0} {
        set X 0
    } elseif {[expr $X + $width] > $screenwidth} {
        set X [expr $screenwidth - $width]
    }

    if {[expr $Y + $height] > $screenheight} {
        set Y [expr $screenheight - $height]
    }

    wm geometry $w +$X+$Y
}

# ique_showurl_release --
#     Hide the url popup.
proc ique_showurl_release {} {
    catch {destroy .urlpopup}
}

#######################################################
#  - 
#######################################################

proc ique_import_config {} {
    set fn [tk_getOpenFile -title "IQUE Tanimini Oku" \
        -initialfile "$::KULLANICI.cnf"]

    if {$fn == ""} {
        return
    }

    set f [open $fn r]
    set data [read $f]
    close $f

    set len [llength $data]
    if {($len >= 2) && ([lindex $data 0] == "Version") && 
                       ([lindex $data 1] == "2")} {
        # This is a Java Config

        set config $data
        set data "m 1\n"
        tk_messageBox -message "Java Tanimini, tasinmaya calisiliyor Onay/Red icermez."

        for {set i 2} {$i < $len} {incr i} {
            if {[lindex $config $i] != "Buddy"} {
                continue;
            }

            # Found the Buddy Section
            incr i
            set config [lindex $config $i]
            set len [llength $config]
            for {set i 0} {$i < $len} {incr i} {
                if {[lindex $config $i] != "List"} {
                    continue;
                }

                # Found the Buddy List Section
                incr i
                set config [lindex $config $i]
                set len [llength $config]

                for {set i 0} {$i < $len} {incr i} {
                    append data "g [lindex $config $i]\n"
                    incr i
                    set buds [lindex $config $i]
                    set jlast [expr [llength $buds] - 1]
                    for {set j 0} {$j <= $jlast} {incr j} {
                       set bud [lindex $buds $j]
                       if {$j == $jlast} {
                           append data "b [normalize $bud]\n"
                       } else {
                           set budtmp [lindex $buds [expr {$j + 1}]]
                           if {[string first "\n" $budtmp] == -1} {
                               append data "b [normalize $bud]\n"
                           } else {
                               incr j
                           }
                       }
                    }
                }

                break;
            }
            break;
        }
    } elseif {($len >= 2) && ([lindex $data 0] == "Config") && 
                       ([string trim [lindex $data 1]] == "version 1")} {
        # This is a WIN 95 Config

        set config $data
        set data "m 1\n"
        tk_messageBox -message "WIN95 Tanimini, tasinmaya calisiliyor Onay/Red icermez."

        for {set i 2} {$i < $len} {incr i} {
            if {[string trim [lindex $config $i]] != "Buddy"} {
                continue;
            }

            # Found the Buddy Section
            incr i
            set config [lindex $config $i]
            set len [llength $config]
            for {set i 0} {$i < $len} {incr i} {
                if {[string trim [lindex $config $i]] != "list"} {
                    continue;
                }

                # Found the Buddy List Section
                incr i
                set config [lindex $config $i]
                set lines [split $config "\n\r"]
                foreach line $lines {
                    set line [string trim $line]
                    set len [llength $line]
                    if {$len == 0} continue
                    append data "g [lindex $line 0]\n"
                    for {set i 1} {$i < $len} {incr i} {
                        append data "b [lindex $line $i]\n"
                    }
                }
                break;
            }
            break;
        }
    }

    # Figure out current buddies and remove them
    foreach g $::BUDDYLIST {
        if {$::GROUPS($g,type) != "IQUE"} {
            continue
        }
        foreach b $::GROUPS($g,people) {
            lappend buds $b
        }
    }
    tc_remove_buddy $::KULLANICI $buds

    # Parse the new config
    ique_parse_config $data
    ique_set_config
    ique_send_init 0
    ique_draw_list T
}

proc ique_export_config {} {
    set fn [tk_getSaveFile -title "IQUE Tanimini Yaz" \
        -initialfile "$::KULLANICI.cnf"]

    if {$fn != ""} {
        set f [open $fn w]
        puts -nonewline $f $::IQUE(config)
        close $f
    }
}

# p_ique_buddy_press --
#     Private routine called when a mouse button is clicked on the buddy
#     list
proc p_ique_buddy_press {y X Y} {
    set str [sag::pos_2_mainstring .buddy.list [sag::nearest .buddy.list $y]]
    set f [string index $str 0]
    if {($f == "+") || ($f == "-")} {
        return
    }

    ique_buddy_popup $str $X $Y
}

proc ique_create_buddy {} {
    if {[winfo exists .buddy]} {
        destroy .buddy
    }

    # Load the images required
    image create photo Login -file media/Login.gif
    image create photo Logout -file media/Logout.gif
    image create photo Admin -file media/Admin.gif
    image create photo Kullan -file media/Kullan.gif
    image create photo DT -file media/DT.gif
    image create photo uparrow -file media/uparrow.gif
    image create photo downarrow -file media/downarrow.gif

    # Create the Menus
    menu .menubar -type menubar
    bind .menubar <Motion> ique_non_idle_event
    menu .fileMenu -tearoff 0
    .menubar add cascade -label "Dosya" -menu .fileMenu
    .fileMenu add command -label "Kullanýcý Arama" -command ique_create_search \
                          -accelerator Control+f
    .fileMenu add command -label "Kullanýcý Ekleyin" -command ique_create_add \
                          -accelerator Control+a
    .fileMenu add command -label "Kullanýcý Listesini Editleme" -command ique_create_edit \
                          -accelerator Control+e
    .fileMenu add command -label "Edit Kabul/Red" -command ique_create_pd \
                          -accelerator Control+p
    .fileMenu add separator
    .fileMenu add command -label "Kullanýcý Listesini Sakla" -command ique_export_config
    .fileMenu add command -label "Kullanýcý Listesini GeriAl" -command ique_import_config
    .fileMenu add separator
    .fileMenu add command -label "Baglantiyi Kapat" -command ique_signoff
    .fileMenu add command -label "Çýkýþ" -command {ique_signoff;exit}

    menu .toolsMenu -tearoff 0
    .menubar add cascade -label "Araclar" -menu .toolsMenu

    menu .generalMenu -tearoff 0
    .toolsMenu add cascade -label "Genel Secenekler" -menu .generalMenu
    .toolsMenu add command -label "Sifre Degistir" -command ique_create_passwd
    .generalMenu add checkbutton -label "Mesaj saatini Ac" -onvalue 1 \
                     -offvalue 0 \
                     -variable ::IQUE(options,imtime)
    .generalMenu add checkbutton -label "Sesi Ac" -onvalue 0 -offvalue 1 \
                     -variable ::SOUNDPLAYING
    .generalMenu add checkbutton -label "Yeni Mesajda mesaj penceresini ac." \
                     -onvalue 1 \
                     -offvalue 0 -variable ::IQUE(options,raiseim)
    .generalMenu add checkbutton -label "Yeni Mesaj icin icon goruntule." \
                     -onvalue 1 \
                     -offvalue 0 -variable ::IQUE(options,deiconifyim)
    .generalMenu add checkbutton -label "Yeni mesajla Chat penceresini ac." \
                     -onvalue 1 \
                     -offvalue 0 -variable ::IQUE(options,raisechat)
    .generalMenu add checkbutton \
                     -label "Yeni mesajda Chat penceresi icon'unu goruntule." \
                     -onvalue 1 \
                     -offvalue 0 -variable ::IQUE(options,deiconifychat)
    .generalMenu add checkbutton -label "Plugin degisikliklerini goruntule." \
                     -onvalue 1 \
                     -offvalue 0 -variable ::IQUE(options,monitorpkg)
    .generalMenu add checkbutton -label "Bos sureyi bildir." -onvalue 1 \
                     -offvalue 0 -variable ::IQUE(options,reportidle)

    menu .msgSendMenu -tearoff 0
    .generalMenu add cascade -label "Mesaji gonderirken ekle" -menu .msgSendMenu
    .msgSendMenu add radiobutton -label "Yalniz GONDER dugmesi ile" \
         -variable ::IQUE(options,msgsend) -value 0
    .msgSendMenu add radiobutton -label "GONDER dugmesi ya da Enter tusu ile" \
         -variable ::IQUE(options,msgsend) -value 1
    .msgSendMenu add radiobutton -label "GONDER dugmesi ya da Ctl-Enter ile" \
         -variable ::IQUE(options,msgsend) -value 2
    .msgSendMenu add radiobutton -label "GONDER dugmesi, Enter, ya da Ctl-Enter ile" \
         -variable ::IQUE(options,msgsend) -value 3

    menu .localconfigMenu -tearoff 0
    .generalMenu add cascade -label "Tanimlamayi Sakla" -menu .localconfigMenu
    .localconfigMenu add radiobutton -label "Yalniz Merkezde" \
         -variable ::IQUE(options,localconfig) -value 0
    .localconfigMenu add radiobutton -label "Yerel Olarak" \
         -variable ::IQUE(options,localconfig) -value 1
    .localconfigMenu add radiobutton -label "Hem yerel hem de merkezde" \
         -variable ::IQUE(options,localconfig) -value 2

    menu .colorMenu -tearoff 0
    .toolsMenu add cascade -label "Renk Ayarlari" -menu .colorMenu
    .colorMenu add separator
    .colorMenu add checkbutton -label "Mesaj renklerini ac" \
                     -onvalue 1 -offvalue 0 \
                     -variable ::IQUE(options,imcolor)
    .colorMenu add command -label "Varsayilan mesaj renklerini degistir" \
                     -command "ique_set_default_color defaultimcolor"
    .colorMenu add checkbutton -label "Chat renklerini ac" -onvalue 1 \
                     -offvalue 0 \
                     -variable ::IQUE(options,chatcolor)
    .colorMenu add command -label "Varsayilan Chat renklerini degistir" \
                     -command "ique_set_default_color defaultchatcolor"
    .toolsMenu add separator

#############
    source packages/socksproxy.tcl
    socksproxy::load
    source packages/away.tcl
    away::load
    source packages/imcapture.tcl
    imcapture::load
    source packages/pounce.tcl
    pounce::load
    source packages/quickchat.tcl
    quickchat::load

    source packages/ticker.tcl
    ticker::load
#########
    away::register "Yemege gittim. Bir saate dönerim"
    away::register "Toplantýdayým. Hemen geri döneceðim"


    menu .helpMenu -tearoff 0
    .menubar add cascade -label "Yardim" -menu .helpMenu
    .helpMenu add command -label "IQue Hakkinda" -command ique_show_version

    # Create the Kullanýcý Window
    toplevel .buddy -menu .menubar -class Ique
    wm title .buddy "Kullanýcý Listesi"

    if {$::IQUE(options,windowgroup)} {wm group .buddy .login}

    bind .buddy <Control-a> ique_create_add
    bind .buddy <Control-e> ique_create_edit
    bind .buddy <Control-p> ique_create_pd
    bind .buddy <Motion> ique_non_idle_event

    wm withdraw .buddy

    set canvas [sag::init .buddy.list 150 300 yes $::SAGFONT #a9a9a9]

    bind $canvas <Double-Button-1> \
         {ique_lselect .buddy.list ique_double_click ique_handleGroup}
    bind $canvas <ButtonPress-3> {p_ique_buddy_press %y %X %Y}
    bind $canvas <ButtonRelease-3> {ique_buddy_release}

    frame .buddy.isim 
    pack .buddy.isim -side bottom

    label .buddy.isim.x -font $::fnt \
          -text "  Dosya    Mesaj       Söyleþi         Bilgi    "
    pack .buddy.isim.x


    frame .buddy.bottomF -relief groove -borderwidth 2
    button .buddy.file  -image ftransfer -relief flat  \
          -command {ique_lselect .buddy.list ique_create_ftw "-"}
    button .buddy.im -image "mesaj" -relief flat -height 22 \
          -command {ique_lselect .buddy.list ique_double_click "-"}
    bind .buddy <Control-m> {ique_lselect .buddy.list ique_double_click "-"}
    button .buddy.chat -image cat -relief flat -height 22 \
          -command {ique_create_invite}
    bind .buddy.chat <Button-3> { chat_menu %W %X %Y }
    bind .buddy <Control-c> ique_create_invite
    button .buddy.info -image "bilgi" -relief flat -height 22 \
          -command {ique_lselect .buddy.list ique_get_info}
    bind .buddy <Control-b> {ique_lselect .buddy.list ique_get_info }
    pack .buddy.file .buddy.im .buddy.chat .buddy.info -in .buddy.bottomF \
       -side left -padx 2m -pady 2m

    pack .buddy.bottomF -side bottom

    
    pack .buddy.list -fill both -expand 1 -padx 2m -side top

    wm protocol .buddy WM_DELETE_WINDOW {ique_signoff;exit}
}


#
# sag tus menusu
#

proc sag_tus {widget x y} {
    tk_popup .chatMenu $x $y
    grab .chatMenu
    bind .chatMenu <ButtonRelease> {
        grab release .chatMenu
        .chatMenu unpost
    }
}

proc chat_menu { w x y } {
    if { [winfo exists .chatMenu] } {
         sag_tus $w $x $y
         return
         }
    menu .chatMenu -tearoff 0
    .chatMenu add command -label " Yasmine" \
          -command {ique_create_iim $::KULLANICI "yasmine"}
    .chatMenu add command -label " Richard" \
          -command {ique_create_iim $::KULLANICI "richard"}
    .chatMenu add command -label " Aylin" \
          -command {ique_create_iim $::KULLANICI "aylin"}
    .chatMenu add command -label " Necmi" \
          -command {ique_create_iim $::KULLANICI "necmi"}
    # .chatMenu add command -label " Alice" \
    #       -command {ique_create_iim $::KULLANICI "alice"}
    # .chatMenu add command -label " Paul" \
    #       -command {ique_create_iim $::KULLANICI "paul"}
    # .chatMenu add command -label " Roberto" \
    #       -command "ique_create_iim $::KULLANICI "roberto""
    # .chatMenu add command -label " Maria" \
    #       -command "ique_create_iim $::KULLANICI "irina""
    # .chatMenu add command -label " Fernando" \
    #       -command "ique_create_iim $::KULLANICI "fernando""
    # .chatMenu add command -label " Alicia" \
    #       -command "ique_create_iim $::KULLANICI "alicia""
    # .chatMenu add command -label " Alex" \
    #       -command "ique_create_iim $::KULLANICI "alex""
    # .chatMenu add command -label " Irina" \
    #       -command "ique_create_iim $::KULLANICI "irina""
    tkwait window .chatMenu
    sag_tus $w $x $y
}


#******************************************************
#********************BUDDY LIST METHODS ***************
#******************************************************

proc ique_parse_config {data} {
    set ::BUDDYLIST [list]
    set ::PERMITLIST [list]
    set ::DENYLIST [list]
    set ::PDMODE 1

    set ::IQUE(config) $data
    set lines [split $data "\n"]
    foreach i $lines {
        switch -exact -- [string index $i 0] {
        "b" {
            set bud [normalize [string range $i 2 end]]
            set ::BUDDIES($bud,type) IQUE
            set ::BUDDIES($bud,online) F
            set ::BUDDIES($bud,name) $bud
            set ::BUDDIES($bud,idle) 0
            set ::BUDDIES($bud,indexs) ""
            set ::BUDDIES($bud,popupText) ""
            set ::BUDDIES($bud,otherString) ""
            set ::BUDDIES($bud,uclass) ""
            set ::BUDDIES($bud,IP) ""
            set ::BUDDIES($bud,service) ""
            incr ::GROUPS($group,total)
            lappend ::GROUPS($group,people) $bud
        } 
        "d" {
            set deny [string range $i 2 end]
            lappend ::DENYLIST $deny
        }
        "g" {
            set group [string range $i 2 end]
            lappend ::BUDDYLIST $group
            lappend ::GROUPS($group,collapsed) F
            set ::GROUPS($group,people) [list]
            set ::GROUPS($group,type) IQUE
            set ::GROUPS($group,online) 0
            set ::GROUPS($group,total) 0

            quickchat::sakla $group $group 4

        }
        "m" {
            set ::PDMODE [string range $i 2 end]
        }
        "p" {
            set permit [string range $i 2 end]
            lappend ::PERMITLIST $permit
        }
        }
    }
}

# Update the user class display for a buddy
proc ique_update_uclass {bud} {
    switch -glob -- $::BUDDIES($bud,uclass) {
    "?A" {
        set ::BUDDIES($bud,icon) Admin
    }
    "?O" {
        set ::BUDDIES($bud,icon) Kullan
    }
    "?U" {
        set ::BUDDIES($bud,icon) DT
    }
    default {
        set ::BUDDIES($bud,icon) ""
        return; 
    }
    } ;# SWITCH

    catch {
        foreach i $::BUDDIES($bud,indexs) {
            catch {sag::change_icon .buddy.list $i $::BUDDIES($bud,icon)}
        }
    }
}

# Update the popup text for a buddy
proc ique_update_ptext {bud} {
    set ::BUDDIES($bud,popupText) [list \
        $::BUDDIES($bud,name): ""\
        Idle: $::BUDDIES($bud,idle) \
        "Baganti Zamani:" ] ; # Evil: "$::BUDDIES($bud,evil)%"

    if {$::BUDDIES($bud,online) == "T"} {
        lappend ::BUDDIES($bud,popupText) [clock format $::BUDDIES($bud,signon)]
    } else {
        lappend ::BUDDIES($bud,popupText) "Bagli Degil"
    }

    lappend ::BUDDIES($bud,popupText) "Kullanici Grubu:"

    set class ""

    if {($class != "") && ([string index $::BUDDIES($bud,uclass) 1] != " ")} {
        append class ", "
    }

    switch -exact -- [string index $::BUDDIES($bud,uclass) 1] {
    "A" {
        append class "Admin"
    }
    "O" {
        append class "Genel"
    }
    "G" {
        append class "Uzman"
    }
    "I" {
        append class "Internet"
    }
    "L" {
        append class "Yonetici"
    }
    "U" {
        append class "Deneme Kullanicisi"
    }
    } ;# SWITCH

    lappend ::BUDDIES($bud,popupText) $class
}

# Change from the Login/Logout icon to a "normal" icon.
proc ique_removeicon {bud} {
    if {!$::IQUE(online)} {
        return
    }

    set ::BUDDIES($bud,icon) ""
    catch {
        foreach i $::BUDDIES($bud,indexs) {
            catch {sag::change_icon .buddy.list $i ""}
        }
    }

    if {$::BUDDIES($bud,online) == "F"} {
        ique_draw_list F
    } else {
        ique_update_uclass $bud
    }
}

# Update the online/total counts for each of the groups.
proc ique_update_group_cnts {} {
    foreach g $::BUDDYLIST {
        set ::GROUPS($g,online) 0
        set ::GROUPS($g,total) 0
        foreach b $::GROUPS($g,people) {
            incr ::GROUPS($g,total)
            if {$::BUDDIES($b,online) != "F"} {
                incr ::GROUPS($g,online)
            }
        }
        catch {sag::change_otherstring .buddy.list $::GROUPS($g,index) \
                    "($::GROUPS($g,online)/$::GROUPS($g,total))"}
    }
}

proc ique_draw_list { {clearFirst T}} {
    if { [winfo exists .buddy.list] == 0} {
        return
    }

    if {$clearFirst != "F"} {
        sag::remove_all .buddy.list
        foreach i $::BUDDYLIST {
            foreach j $::GROUPS($i,people) {
                set ::BUDDIES($j,indexs) ""
            }
        }
    }

    set n 0
    foreach i $::BUDDYLIST {
        incr n
        if {$::GROUPS($i,collapsed) != "T"} {
            if {$clearFirst != "F"} {
                set ::GROUPS($i,index) [sag::add .buddy.list -10 "" "- $i" \
                    "($::GROUPS($i,online)/$::GROUPS($i,total))" \
                    $::IQUE(options,groupmcolor) $::IQUE(options,groupocolor)]
            }
            foreach j $::GROUPS($i,people) {
                set normj [normalize $::BUDDIES($j,name)]
                set normn [normalize [sag::pos_2_mainstring .buddy.list $n]]
                if {$::BUDDIES($j,online) == "T"} {
                    if {$normj != $normn} {
                        lappend ::BUDDIES($j,indexs) [sag::insert .buddy.list \
                            $n 16 $::BUDDIES($j,icon) $::BUDDIES($j,name) \
                            $::BUDDIES($j,otherString) \
                            $::IQUE(options,buddymcolor) \
                            $::IQUE(options,buddyocolor)]
                    }
                    incr n
                } else {
                    if {$normj == $normn} {
                        sag::remove .buddy.list [sag::pos_2_index .buddy.list $n]
                    }
                }
            }
        } else {
            if {$clearFirst != "F"} {
                set ::GROUPS($i,index) [sag::add .buddy.list -10 "" "+ $i" \
                    "($::GROUPS($i,online)/$::GROUPS($i,total))" \
                    $::IQUE(options,groupmcolor) $::IQUE(options,groupocolor)]
            }
        }
    }
}
#######################################################
# Routines for IM Conversations
#######################################################
proc p_ique_cim_send {name} {
    set w $::IQUE(imconvs,$name,msgw)
    if { $::IQUE(options,cimheight) == 0} {
        set msg [string trimright [$w get]]
    } else {
        set msg [string trimright [$w get 0.0 end]]
    }

    if { [string length [string trim $msg]] == 0} {
        tk_messageBox -type ok -message "Gonderileck mesaji girin"
        return
    }

    if {$::IQUE(options,imcolor)} {
        set msg "<FONT COLOR=\"$::IQUE(imconvs,$name,color)\">$msg</FONT>"
    }

    if { [string length $msg] > 950 } {
        tk_messageBox -type ok -message "Gonderilecek mesaj boyu cok buyuk."
        return
    }
    if { ![info exists ::BUDDIES($name,IP)] } {
         set ipno $::TESTHOST
         set port $::TC(uretim,port)
         set auto "T"
         tc_send_im $::KULLANICI $name $msg $auto
    } else {
         tc_send_im $::KULLANICI $name $msg
    }


    if { $::IQUE(options,cimheight) == 0} {
        $w delete 0 end
    } else {
        $w delete 0.0 end
    }
}

proc p_ique_cim_out {connName nick auto msg} {
    ique_receive_im $nick noauto $msg T
}

proc ique_title_cim {name} {
    set nname [normalize $name]

    set w .imConv$nname
    if {![winfo exists $w]} {
        return
    }

    set str "$name ile Gorusme"

    catch {
        if {$::BUDDIES($nname,idle) != 0} {
            if {$::BUDDIES($nname,evil) != 0} {
                append str " (Idle: $::BUDDIES($nname,idle)\
                              Evil: $::BUDDIES($nname,evil)%)"
            } else {
                append str " (Idle: $::BUDDIES($nname,idle))"
            }
        } elseif {$::BUDDIES($nname,evil) != 0} {
            append str " (Evil: $::BUDDIES($nname,evil)%)"
        }
    }
    wm title $w $str
}

proc ique_create_cim {name} {
    set nname [normalize $name]

    set w .imConv$nname
    if {[winfo exists $w]} {
        return
    }

    toplevel $w -class $::IQUE(options,imWMClass)
    ique_title_cim $name
    wm iconname $w $name
    if {$::IQUE(options,windowgroup)} {wm group $w .login}

    set ::IQUE(imconvs,$nname,toplevel) $w
    set ::IQUE(imconvs,$nname,textw) [createHTML $w.textF]

    set mw [createINPUT $w.msgArea cimheight]
    set ::IQUE(imconvs,$nname,msgw) $mw

    frame $w.isim5

    label $w.isim5.x -font $::fnt  -text "Gönder          Bilgi          Uyar           Renk          Kapat    "

    frame $w.buttonF -relief groove -borderwidth 2
    button $w.info -image "bilgi" -relief flat -height 24 \
           -command [list tc_get_info $::KULLANICI $nname]
    bind $w <Control-l> [list tc_get_info $::KULLANICI $nname]
    button $w.warn -image "uyar" -relief flat -height 24 \
           -command [list tc_evil $::KULLANICI $nname F]
    bind $w <Control-W> [list tc_evil $::KULLANICI $nname T]
    button $w.send -image "gonder" -relief flat -height 24 \
           -command "p_ique_cim_send $nname"
    if { [expr {$::IQUE(options,msgsend) & 1} ] == 1} {
        bind $mw <Return> "p_ique_cim_send $nname; break"
    }
    if { [expr {$::IQUE(options,msgsend) & 2} ] == 2} {
        bind $mw <Control-Return> "p_ique_cim_send $nname; break"
    } else {
        bind $mw <Control-Return> " "
    }
    bind $mw <Control-s> "p_ique_cim_send $nname; break"
    button $w.close -image "kapat" -relief flat -height 24 \
           -command " destroy $w ;  sflap::close2 \"$::KULLANICI\" \"$nname\""
    bind $mw <Control-period> [list destroy $w]
    pack $w.send $w.info $w.warn -in $w.buttonF -side left -padx 2m

    if {$::IQUE(options,imcolor)} {
        set ::IQUE(imconvs,$nname,color) $::IQUE(options,defaultimcolor)
        button $w.color -image "renk" -relief flat -height 24 \
           -command "ique_set_color imconvs {IM Color} $nname"
        pack $w.color -in $w.buttonF -side left -padx 2m
    }

    pack $w.close -in $w.buttonF -side left -padx 2m
    
    if {![ique_is_buddy $nname]} {
        button $w.add -image "ekle" -relief flat \
           -command "ique_create_add buddy \"$name\""
        pack $w.add -in $w.buttonF -side left -padx 2m
        label $w.isim5.x1 -font $::fnt  -text "    Ekle    "
        pack $w.isim5.x $w.isim5.x1 -in $w.isim5 -side left

    } else {
        pack $w.isim5.x -in $w.isim5
    }
    pack $w.isim5 -side bottom

    pack $w.buttonF -side bottom
    if {($::IQUE(options,cimheight) != 0) && $::IQUE(options,cimexpand)} {
        pack $w.msgArea -fill both -side bottom -expand 1
    } else {
        pack $w.msgArea -fill x -side bottom
    }
    pack $w.textF -expand 1 -fill both -side top

    focus -f $mw

    bind $w <Motion> ique_non_idle_event
    wm protocol $w WM_DELETE_WINDOW " destroy $w ;  sflap::close2 \"$::KULLANICI\" \"$nname\""
}

proc ique_receive_im {remote auto msg us} {
    if {$us == "T"} {
        ique_play_sound $::IQUE(SOUND,Send)
    } else {
        ique_play_sound $::IQUE(SOUND,Receive)
    }

    set nremote [normalize $remote]
    set autostr ""
    if { ($auto == "auto") || ($auto == "T") } {
        if { [info exists ::BUDDIES($remote,IP)] } {
             set autostr " (hemen yanitla) "
        }
    }

    ique_create_cim $remote
    set w $::IQUE(imconvs,$nremote,textw)
    $w configure -state normal
    if {$::IQUE(options,imtime)} {
        set tstr [clock format [clock seconds] -format "%H:%M:%S "]
    } else {
        set tstr ""
    }
    if {$us == "T"} {
        $w insert end "$tstr$::KULLAN$autostr: " bbold
    } else {
        $w insert end "$tstr$remote$autostr: " rbold
    }
    append msg \n
    addHTML $w $msg $::IQUE(options,imcolor)
    $w configure -state disabled

    if {$::IQUE(options,raiseim)} {
        raise $::IQUE(imconvs,$nremote,toplevel)
    }

    if {$::IQUE(options,deiconifyim)} {
        wm deiconify $::IQUE(imconvs,$nremote,toplevel)
    }
}

#######################################################
# Routines for sending an initial IM
#######################################################
proc p_ique_iim_send {id} {
    set to $::IQUE(iims,$id,to)
    if { $::IQUE(options,iimheight) == 0} {
        set msg [string trimright [$::IQUE(iims,$id,msgw) get]]
    } else {
        set msg [string trimright [$::IQUE(iims,$id,msgw) get 0.0 end]]
    }

    set w $::IQUE(iims,$id,toplevel)

    if {$::IQUE(options,imcolor)} {
        set msg "<FONT COLOR=\"$::IQUE(options,defaultimcolor)\">$msg</FONT>"
    }

    if { [string length [string trim $msg]] == 0} {
        tk_messageBox -type ok -message "Gonderilecek mesaj girin"
        return
    }

    if { [string length $msg] > 950 } {
        tk_messageBox -type ok -message "Gonderilecek mesaj cok buyuk."
        return
    }

    destroy $w
    set nbud [normalize $to] 
    set nname [normalize $::KULLANICI] 
    if { ![info exists ::BUDDIES($nbud,IP)] } {
         set ipno $::TESTHOST
         set port $::TC(uretim,port)
         set auto "T"
         tc_send_im $::KULLANICI $nbud $msg $auto
    } else {
         set ipno $::BUDDIES($nbud,IP)
         set port $::BUDDIES($nbud,service)
         sflap::connect $nname $nbud $ipno $port $nname ""
         tc_send_im $::KULLANICI $nbud $msg
    }
}

proc ique_create_iim {cname name} {
    if { ($name == $cname) } {
        tk_messageBox -type ok -message "Kendi kendinize Mesaj gonderemezsiniz"
        return
    }
    set cnt 0
    catch {set cnt $::IQUE(iims,cnt)}
    set ::IQUE(iims,cnt) [expr $cnt + 1]

    set ::IQUE(iims,$cnt,to) $name

    set w .iim$cnt
    set ::IQUE(iims,$cnt,toplevel) $w

    toplevel $w -class $::IQUE(options,imWMClass)
    wm title $w "Mesaj Gonder"
    wm iconname $w "Mesaj Gonder"
    if {$::IQUE(options,windowgroup)} {wm group $w .login}

    bind $w <Motion> ique_non_idle_event

    frame $w.top 
    label $w.toL -text "Alici:"
    entry $w.to -width 16 -relief sunken -textvariable ::IQUE(iims,$cnt,to)
    pack  $w.toL $w.to -in $w.top -side left

    set tw [createINPUT $w.textArea iimheight]
    set ::IQUE(iims,$cnt,msgw) $tw
    bind $w.to <Return> [list focus $tw]

    if { [expr {$::IQUE(options,msgsend) & 1} ] == 1} {
        bind $tw <Return> "p_ique_iim_send $cnt; break"
    }
    if { [expr {$::IQUE(options,msgsend) & 2} ] == 2} {
        bind $tw <Control-Return> "p_ique_iim_send $cnt; break"
    } else {
        bind $tw <Control-Return> " "
    }

    frame $w.isim3 
    pack $w.isim3 -side bottom

    label $w.isim3.x -font $::fnt  -text "Gönder        Vazgeç"
    pack $w.isim3.x


    frame $w.bottom -relief groove -borderwidth 2
    button $w.send -image "gonder" -relief flat -height 23 -command [list p_ique_iim_send $cnt]
    bind $w <Control-s> "p_ique_iim_send $cnt; break"
    button $w.cancel -image "vazgec" -relief flat -height 23 -command [list destroy $w]
    bind $w <Control-period> [list destroy $w]
    pack $w.send $w.cancel -in $w.bottom -side left -padx 2m

    pack $w.top -side top
    pack $w.bottom -side bottom
    pack $w.textArea -expand 1 -fill both
    if { $name == ""} {
        focus $w.to
    } else {
        focus $tw
    }
}
#######################################################
# Routines for doing a Chat Invite
#######################################################
proc p_ique_invite_send {id} {
    set ::inform_server 1
    set roomid $::IQUE(cinvites,$id,roomid)
    set msg $::IQUE(cinvites,$id,msg)
    set loc $::IQUE(cinvites,$id,loc)
    set peoplew $::IQUE(cinvites,$id,peoplew)
    set w $::IQUE(cinvites,$id,toplevel)

    if { [string length [string trim $msg]] == 0} {
        tk_messageBox -type ok -message "Luften gonderilecek mesaji girin"
        return
    }

    if { [string length $msg] > 200 } {
        tk_messageBox -type ok -message "Gonderilecek mesaj cok buyuk."
        return
    }

    if { [string length [string trim $loc]] == 0} {
        tk_messageBox -type ok -message "Gidilecek Yer adi girin"
        return
    }

    if { [string length $loc] > 50 } {
        tk_messageBox -type ok -message "Yer adi cok buyuk."
        return
    }

    set ::IQUE(invites,$loc,people) [$peoplew get 0.0 end]
    set ::IQUE(invites,$loc,msg) $msg

    if {$roomid != "" } {
        CHAT_JOIN $::KULLANICI $roomid $loc
    } else {
        tc_chat_join $::KULLANICI 4 $loc
    }
    destroy $w
    foreach i [array names ::IQUE "cinvites,$id,*"] {
        unset ::IQUE($i)
    }

}
proc p_ique_invite_add {id} {
    set sel [sag::selection .buddy.list]
    set peoplew $::IQUE(cinvites,$id,peoplew)

    if {$sel == ""} {
        return
    }

    foreach s $sel {
        set c [string index $s 0]
        if {$c == "+" || $c == "-"} {
            set g [string range $s 2 end]
            if {$::GROUPS($g,type) != "IQUE"} {
                continue
            }
            foreach i $::GROUPS($g,people) {
                if {$::BUDDIES($i,online) == "T"} {
                    $peoplew insert end "$::BUDDIES($i,name)\n"
                }
            }
        } else {
            $peoplew insert end "[string trim $s]\n"
        }
    }
}
proc ique_create_invite {{roomid ""} {loc ""}} {
    set cnt 0
    catch {set cnt $::IQUE(cinvites,cnt)}
    set ::IQUE(cinvites,cnt) [expr $cnt + 1]

    set ::IQUE(cinvites,$cnt,roomid) $roomid
    set ::IQUE(cinvites,$cnt,msg) "Chat odasina davet edildiniz:"

    if {$loc == ""} {
        set ::IQUE(cinvites,$cnt,loc) "$::KULLAN chat[expr int(rand() * 10000)]"
    } else {
        set ::IQUE(cinvites,$cnt,loc) $loc
    }

    set w .invite$cnt
    toplevel $w -class $::IQUE(options,chatWMClass)
    wm title $w "Chat Daveti"
    wm iconname $w "Chat Daveti"
    if {$::IQUE(options,windowgroup)} {wm group $w .login}
    set ::IQUE(cinvites,$cnt,toplevel) $w

    bind $w <Motion> ique_non_idle_event

    label $w.inviteL -text "Davet edilecek kullanici adlari: (Her satira bir tane)"
    text $w.invite -font $::NORMALFONT -width 40
    set ::IQUE(cinvites,$cnt,peoplew) $w.invite
    label $w.messageL -text "Gonderilecek Mesaj:"
    entry $w.message -font $::NORMALFONT -textvariable ::IQUE(cinvites,$cnt,msg) -width 40
    bind $w.message <Return> [list focus $w.location]
    label $w.locationL -text "Yer"
    entry $w.location -font $::NORMALFONT -textvariable ::IQUE(cinvites,$cnt,loc) -width 40
    bind $w.location <Return> "p_ique_invite_send $cnt; break"

    frame $w.isim6
    pack $w.isim6 -side bottom

    label $w.isim6.x -font $::fnt  -text "Gönder         Ekle         Kapat  "
    pack $w.isim6.x

    frame $w.buttons -relief groove -borderwidth 2
    button $w.send -image "gonder" -height 24 -relief flat -command [list p_ique_invite_send $cnt]
    bind $w <Control-s> "p_ique_invite_send $cnt; break"
    button $w.add -image "ekle" -height 24 -relief flat -command [list p_ique_invite_add $cnt]
    bind $w <Control-a> [list p_ique_invite_add $cnt]
    button $w.cancel -image "kapat" -height 24 -relief flat -command [list p_ique_invitew_close $cnt]
    wm protocol $w WM_DELETE_WINDOW [list p_ique_invitew_close $cnt]
    bind $w <Control-period> [list destroy $w]
    pack $w.send $w.add $w.cancel -in $w.buttons -side left -padx 2m

    pack $w.inviteL $w.invite $w.messageL $w.message $w.locationL $w.location $w.buttons

    if {$loc != ""} {
        $w.location configure -state disabled
    }

    p_ique_invite_add $cnt
}

#######################################################
# Routines for doing a Chat Accept
#######################################################
proc p_ique_accept_send {w id} {
    set ::inform_server 1
    destroy $w
    set w .chats$id
    if {[winfo exists $w]} {
        ique_create_chat $id $::IQUE(chats,$id,name)
    }
    tc_chat_accept $::KULLANICI $id
}
proc ique_create_accept {loc id name msg} {
    set w .accept$id

    toplevel $w -class $::IQUE(options,chatWMClass)
    wm title $w "$name davetiye cikartti"
    wm iconname $w "$name davetiyesi"
    if {$::IQUE(options,windowgroup)} {wm group $w .login}

    bind $w <Motion> ique_non_idle_event

    label $w.msg -text $msg
    label $w.loc -text "Chat Odasi: $loc"

    frame $w.isim
    pack $w.isim -side bottom

    label $w.isim.x -font $::fnt -text "Kabul         Bilgi          Uyar         Vazgeç"
    pack $w.isim.x 


    frame $w.buttons -relief groove -borderwidth 2
    button $w.accept -image "kabul" -relief flat -height 24 -command [list p_ique_accept_send $w $id]
    bind $w <Control-a> [list p_ique_accept_send $w $id]
    button $w.im -text Mesaj -command [list ique_create_iim $::KULLANICI $name]
    bind $w <Control-i> [list ique_create_iim $::KULLANICI $name]
    button $w.info -image "bilgi" -relief flat -height 24 -command [list tc_get_info $::KULLANICI $name]
    bind $w <Control-l> [list tc_get_info $::KULLANICI $name]
    button $w.warn -image "uyar" -relief flat -height 24 -command [list tc_evil $::KULLANICI $name F]
    bind $w <Control-W> [list tc_evil $::KULLANICI $name T]
    button $w.cancel -image "vazgec" -relief flat -height 24 -command [list destroy $w]
    bind $w <Control-period> [list destroy $w]
    pack $w.accept $w.info $w.warn $w.cancel -in $w.buttons -side left -padx 2m

    pack $w.msg $w.loc $w.buttons
}

#######################################################
# Routines for doing a Chat Room
#######################################################
proc p_ique_chat_send {id whisper} {
    set w $::IQUE(chats,$id,msgw)
    if { $::IQUE(options,chatheight) == 0} {
        set msg [string trimright [$w get]]
    } else {
        set msg [string trimright [$w get 0.0 end]]
    }

    if {$::IQUE(options,chatcolor)} {
        set msg "<FONT COLOR=\"$::IQUE(chats,$id,color)\">$msg</FONT>"
    }
 
    if { [string length [string trim $msg]] == 0} {
        tk_messageBox -type ok -message "Gonderilecek mesaji girin"
        return
    }

    if { [string length $msg] > 950 } {
        tk_messageBox -type ok -message "Mesaj cok uzun."
        return
    }

    if {$whisper == "T"} {
        set sel [sag::selection $::IQUE(chats,$id,list)]
        if {$sel == ""} {
            tk_messageBox -type ok -message "Fisildanacak kullanici secin."
            return
        } else {
            tc_chat_whisper $::KULLANICI $id $sel $msg
            ique_receive_chat $id $::KULLANICI S $msg $sel
        }
    } else {
        tc_chat_send $::KULLANICI $id $msg
    }

    if { $::IQUE(options,chatheight) == 0} {
        $w delete 0 end
    } else {
        $w delete 0.0 end
    }
}

proc ique_leave_chat {id} {
    if {[winfo exists ::IQUE(chats,$id,toplevel)]} {
        destroy $::IQUE(chats,$id,toplevel)
    }

    foreach i [array names ::IQUE "chats,$id,*"] {
        unset ::IQUE($i)
    }
    chat_disconnect 

}

proc p_ique_chat_close {id} {
    tc_chat_leave $::KULLANICI $id
    destroy $::IQUE(chats,$id,toplevel)
}

proc ique_create_chat {id name} {
    set ::inform_server 1
    set w .chats$id
    if {[winfo exists $w]} {
        return
    }

    toplevel $w -class $::IQUE(options,chatWMClass)
    wm title $w "Chat in $name"
    wm iconname $w $name
    if {$::IQUE(options,windowgroup)} {wm group $w .login}
    set ::IQUE(chats,$id,toplevel) $w
    set ::IQUE(chats,$id,name) $name

    bind $w <Motion> ique_non_idle_event

    frame $w.left
    set ::IQUE(chats,$id,textw) [createHTML $w.textF]

    frame $w.msgF

    set mw [createINPUT $w.msgArea chatheight 30]
    set ::IQUE(chats,$id,msgw) $mw

    if { [expr {$::IQUE(options,msgsend) & 1} ] == 1} {
        bind $mw <Return> "p_ique_chat_send $id F; break"
    }
    if { [expr {$::IQUE(options,msgsend) & 2} ] == 2} {
        bind $mw <Control-Return> "p_ique_chat_send $id F; break"
    } else {
        bind $mw <Control-Return> " "
    }

    
    button $w.send -image "gonder" -relief flat -height 24 -command [list p_ique_chat_send $id F]
    button $w.whisper -image "fisilda" -relief flat -height 24 -command [list p_ique_chat_send $id T]
    pack $w.send $w.whisper -in $w.msgF -side right -pady 2m
    pack $w.msgArea -in $w.msgF -side left -fill x -expand 1

    pack $w.msgF -in $w.left -fill x -side bottom
    pack $w.textF -in $w.left -fill both -expand 1 -side top

    frame $w.right

    sag::init $w.list 100 100 yes $::SAGFONT #a9a9a9
    set ::IQUE(chats,$id,list) $w.list

    frame $w.bottom2 
    pack $w.bottom2 -side bottom -fill both


    frame $w.bottom -relief groove -borderwidth 2
    pack $w.bottom -side bottom -fill both 

    
    label $w.bottom2.isim -font $::fnt  -text "Uyar            Bilgi          Anlýk            Davet          Renk          Kapat"
    pack $w.bottom2.isim 

    frame $w.r1
    button $w.bottom.warn -image "uyar" -width 45 -height 27 -relief flat -command [list ique_lselect $w.list tc_evil]
    bind $w <Control-W> [list ique_lselect $w.list tc_evil T]
    pack $w.bottom.warn -side left

    frame $w.r2
    button $w.bottom.info -image "bilgi" -width 45 -height 27 -relief flat -command [list ique_lselect $w.list ique_get_info]
    bind $w <Control-l> [list ique_lselect $w.list ique_get_info]
    button $w.bottom.im -image "anlik" -width 45 -height 27 -relief flat -command [list ique_lselect $w.list ique_create_iim ]

    bind $w <Control-i> [list ique_lselect $w.list ique_create_iim ]
    if {$::IQUE(options,chatcolor)} {
        button $w.bottom.invite -image "davet" -width 45 -height 27 -relief flat -command [list ique_create_invite $id $name]
        bind $w <Control-v> [list ique_create_invite $id $name]
        pack $w.bottom.info -side left -pady 2m -padx 3m
        pack $w.bottom.im -side left -pady 2m
        pack $w.bottom.invite -side left -pady 2m -padx 3m
    } else {
        pack $w.info $w.im -in $w.r2 -side left
    }


    frame $w.r3
    if {$::IQUE(options,chatcolor)} {
        set ::IQUE(chats,$id,color) $::IQUE(options,defaultchatcolor)
        button $w.bottom.color -image "renk" -width 45 -height 27 -relief flat -command "ique_set_color chats {Chat Color} $id"
        pack $w.bottom.color -side left -pady 2m
    } else {
        button $w.invite -text "Davet" -command [list ique_create_invite $id $name]
        bind $w <Control-v> [list ique_create_invite $id $name]
        pack $w.invite -side left -pady 2m
    }
    button $w.bottom.close -image "kapat" -width 45 -height 27 -relief flat -command [list p_ique_chat_close $id]
    wm protocol $w WM_DELETE_WINDOW [list p_ique_chat_close $id]
    bind $w <Control-period> [list p_ique_chat_close $id]
    pack $w.bottom.close -side left -pady 2m -padx 3m

    pack $w.list -in $w.right -expand 1 -fill both
    pack $w.r1 $w.r2 $w.r3 -in $w.right

    pack $w.right -side right -expand 0 -fill both
    pack $w.left  -side left -expand 1 -fill both
    focus $mw
}
    

    
proc ique_receive_chat {id remote whisper msg {whispersto {}}} {
    if {[normalize $remote] == $::KULLANICI} {
        ique_play_sound $::IQUE(SOUND,Send)
    } else {
        ique_play_sound $::IQUE(SOUND,Receive)
    }

    set whisperstr ""
    if { $whisper == "T" } {
        set whisperstr " (Fisilda) "
    } elseif { $whisper == "S" } {
        if { [string length $whispersto] > 0 } {
             set whisperstr " ($whispersto ya fisildiyor) "
        } else {
             set whisperstr " (fisildiyor) "
        }
    }

    set w $::IQUE(chats,$id,toplevel)

    if {[winfo exists $w] == 0} {
        return
    }

    if {$::IQUE(options,chattime)} {
        set tstr [clock format [clock seconds] -format "%H:%M:%S "]
    } else {
        set tstr ""
    }

    set textw $::IQUE(chats,$id,textw)

    $textw configure -state normal
    $textw insert end "$tstr$remote$whisperstr: " bold
    append msg \n
    addHTML $textw $msg $::IQUE(options,chatcolor)
    $textw configure -state disabled

    if {$::IQUE(options,raisechat)} {
        raise $w
    }

    if {$::IQUE(options,deiconifychat)} {
        wm deiconify $w
    }
}

#######################################################
# setStatus - Set the status label in the login dialog
#######################################################
proc setStatus {str} {
    if { [winfo exists .login] } { .login.status configure -text $str }
}

#######################################################
# ique_show_login - Show the login window, we first withdraw
# the buddy window in case it is around.
#######################################################
proc ique_show_login {} {
    if {[winfo exists .buddy]} {
        wm withdraw .buddy
    }

    if {[winfo exists .login]} {
        wm deiconify .login
        raise .login
    }
}
#######################################################
# ique_create_login - 
#######################################################
proc ique_create_login {} {
    if {[winfo exists .login]} {
        destroy .login
    }

    toplevel .login -class Ique
    wm title .login "Login"
    wm iconname .login "Login"
    wm command .login [concat $::argv0 $::argv]
    wm group .login .login

    wm withdraw .login

    image create photo logo -file media/Logo.gif

    label .login.logo -image logo
    label .login.status

    frame .login.snF
    entry .login.snE -font $::NORMALFONT -width 16 -relief sunken \
           -textvariable ::KULLAN 
    label .login.snL -text "Takma Adiniz:" -width 13
    pack .login.snL .login.snE -in .login.snF -side left -expand 1

    frame .login.pwF
    label .login.pwL -text "Sifre:" -width 13
    entry .login.pwE -font $::NORMALFONT -width 16 -relief sunken \
           -textvariable ::PASSWORD -show "*"
    pack .login.pwL .login.pwE -in .login.pwF -side left -expand 1

    frame .login.bF
    button .login.bF.register -text KayitOl \
           -command {ique_kayitol}
    pack .login.bF.register  -side left -expand 1
    button .login.bF.signon -text Baglan -command ique_signon
    pack .login.bF.signon -side left -expand 1

    frame .login.prF -border 1 -relief solid
    label .login.prF.label -text "Proxy:"

    menubutton .login.prF.proxies -textvariable ::USEPROXY -indicatoron 1 \
            -menu .login.prF.proxies.menu \
            -relief raised -bd 2 -highlightthickness 2 -anchor c \
            -direction flush
    menu .login.prF.proxies.menu -tearoff 0

    ique_register_proxy Yok "" "ique_noneproxy_config" .login.prF.proxies.menu

    button .login.prF.config -text Tanýmla -command \
        {$::IQUE(proxies,$::USEPROXY,configFunc)}
    pack .login.prF.label .login.prF.proxies .login.prF.config -side left \
           -expand 1

    pack .login.logo .login.status .login.snF \
         .login.pwF .login.bF .login.prF -expand 0 -fill x -ipady 1m

    bind .login.snE <Return> { focus .login.pwE }
    bind .login.pwE <Return> { ique_signon }
    bind .login <Control-s> { ique_signon }
    focus .login.snE

    wm protocol .login WM_DELETE_WINDOW {exit}
}

#######################################################
# Routines for proxy stuff
#######################################################
proc wrtpre { win } {
    set fp [open $::IQUE(prefile) w]

    puts $fp "set ::TESTHOST $::TC($::SELECTEDTC,host)"
    puts $fp "set AUTH(uretim,port) $::TC($::SELECTEDTC,port)"
    puts $fp "set TC(uretim,port) $::AUTH($::SELECTEDTC,port)"
    close $fp
    destroy $win
}

proc ique_noneproxy_config {} {
    set w .proxyconfig
    destroy $w

    toplevel $w -class Ique
    wm title $w "Proxy Tanimlama: Dogrudan Baglanti"
    wm iconname $w "Proxy Tanimlama"
    if {$::IQUE(options,windowgroup)} {wm group $w .login}
    label $w.label -text "IQUE sunucu $::TC($::SELECTEDTC,port) portu dinler."

    frame $w.iquetchostF
    label $w.iquetchostF.l -text "I-QUE Sunucu: "
    entry $w.iquetchostF.e -textvariable ::TC($::SELECTEDTC,host) \
        -exportselection 0
    pack $w.iquetchostF.l $w.iquetchostF.e -side left

    frame $w.iquetcportF
    label $w.iquetcportF.l -text "I-Que Sunucu Portu: "
    entry $w.iquetcportF.e -textvariable ::TC($::SELECTEDTC,port) \
        -exportselection 0
    pack $w.iquetcportF.l $w.iquetcportF.e -side left

    frame $w.iquetcportK
    label $w.iquetcportK.l -text "I-Que Ýstemci Portu: "
    entry $w.iquetcportK.e -textvariable ::AUTH($::SELECTEDTC,port) \
        -exportselection 0
    pack $w.iquetcportK.l $w.iquetcportK.e -side left

    button $w.ok -text "Tamam" -command "wrtpre $w"
    bind $w.iquetchostF.e <Return> { focus .proxyconfig.iquetcportF.e }
    bind $w.iquetcportF.e <Return> { wrtpre .proxyconfig }
    bind $w.ok <Return> { destroy .proxyconfig }
    pack $w.label $w.iquetchostF $w.iquetcportF $w.iquetcportK $w.ok -side top
}

proc ique_register_proxy { name connFunc configFunc {win ""} } {
    set ::IQUE(proxies,$name,connFunc) $connFunc
    set ::IQUE(proxies,$name,configFunc) $configFunc
    if { $win == "" } {
       if { [winfo exists .login] } { .login.prF.proxies.menu add radiobutton -label $name -variable ::USEPROXY }
    } else {
       $win add radiobutton -label $name -variable ::USEPROXY
    }
}

proc ique_unregister_proxy {name} {
    .proxyMenu delete $name
}

proc kayitoptions { win vr choices } {
  eval tk_optionMenu $win ::kayit($vr) $choices
}

#######################################################
# Routines for doing a Kullanýcý Add
#######################################################
proc p_ique_add_send {id} {
    set group $::IQUE(adds,$id,group)
    set name $::IQUE(adds,$id,name)
    set w $::IQUE(adds,$id,toplevel)

    if {[string length [normalize $group]] < 2} {
        tk_messageBox -type ok -message "Kullanýcý Grubunu girin."
        return
    }

    if {[string length [normalize $name]] < 2} {
        tk_messageBox -type ok -message "Kullanýcý Adý girin."
        return
    }

    if {$::IQUE(adds,$id,mode) == "pd"} {
        ique_add_pd $group [normalize $name]
    } else {
        ique_add_buddy $group [normalize $name]
    }

    # Only send config if not in edit mode
    if {(![winfo exists .edit]) && (![winfo exists .pd])} {
        ique_set_config
    }

    destroy $w
}

proc ique_create_add {{mode {buddy}} {name {}}} {
    set cnt 0
    catch {set cnt $::IQUE(adds,cnt)}
    set ::IQUE(adds,cnt) [expr $cnt + 1]

    set w .add$cnt
    toplevel $w -class Ique
    set ::IQUE(adds,$cnt,toplevel) $w
    set ::IQUE(adds,$cnt,mode) $mode
    set ::IQUE(adds,$cnt,name) $name
    wm title $w "Kullanýcý Ekle"
    wm iconname $w "Kullanýcý Ekle"
    if {$::IQUE(options,windowgroup)} {wm group $w .login}

    frame $w.top
    label $w.buddynameL -text "Adý: "
    entry $w.buddyname -font $::NORMALFONT -width 16 -textvariable ::IQUE(adds,$cnt,name)
    if {$mode == "buddy"} {
        bind $w.buddyname <Return> [list focus $w.buddygroup]
    } else {
        bind $w.buddyname <Return> [list p_ique_add_send $cnt]
    }
    pack $w.buddynameL $w.buddyname -in $w.top -side left

    frame $w.middle
    label $w.buddygroupL -text "Grubu: "


    if {$mode == "buddy"} {
        eval tk_optionMenu $w.m ::IQUE(adds,$cnt,group) $::BUDDYLIST
        $w.m configure -width 16
        entry $w.buddygroup -font $::NORMALFONT -width 16 \
           -textvariable ::IQUE(adds,$cnt,group)
        pack $w.buddygroup -in $w.middle -side right
        bind $w.buddygroup <Return> [list p_ique_add_send $cnt]
    } else {
        tk_optionMenu $w.m ::IQUE(adds,$cnt,group) Permit Deny
        $w.m configure -width 16
    }
    pack $w.buddygroupL $w.m -in $w.middle -side left

    frame $w.isim7
    pack $w.isim7 -side bottom

    label $w.isim7.x -font $::fnt -text "  Ekle        Vazgeç"
    pack $w.isim7.x 

    frame $w.bottom -relief groove -borderwidth 2
    button $w.add -image "ekle" -height 24 -relief flat \
           -command [list p_ique_add_send $cnt]
    bind $w <Control-a> [list p_ique_add_send $cnt]
    button $w.cancel -image  "vazgec" -height 24 -relief flat \
           -command [list destroy $w]
    bind $w <Control-period> [list destroy $w]
    pack $w.add $w.cancel -in $w.bottom -side left -padx 2m 

    pack $w.top $w.middle $w.bottom

    focus $w.buddyname
}

proc p_ique_search_send {id} {
    set name $::IQUE(find,$id,name)
    set w $::IQUE(find,$id,toplevel)

    if {[string length $name] < 2} {
        tk_messageBox -type ok -message "Arama bilgisi girin."
        return
    }

    # Only send search data
    tc_set_search $::KULLANICI $name

    destroy $w
}

proc ique_create_search {} {
    set cnt 0
    catch {set cnt $::IQUE(find,cnt)}
    set ::IQUE(find,cnt) [expr $cnt + 1]

    set w .find$cnt
    toplevel $w -class Ique
    set ::IQUE(find,$cnt,toplevel) $w
    wm title $w "Kullanýcý Ara"
    wm iconname $w "Arama"
    if {$::IQUE(options,windowgroup)} {wm group $w .login}

    frame $w.top
    label $w.buddynameL -text "Aranacak Bilgi: "
    entry $w.buddyname -font $::NORMALFONT -width 16 \
          -textvariable ::IQUE(find,$cnt,name)
    bind $w.buddyname <Return> [list p_ique_search_send $cnt]
    pack $w.buddynameL $w.buddyname -in $w.top -side left

    frame $w.isim7
    pack $w.isim7 -side bottom

    label $w.isim7.x -font $::fnt -text "  Ara        Vazgeç"
    pack $w.isim7.x 

    frame $w.bottom -relief groove -borderwidth 2
    button $w.find -image "gonder" -height 24 -relief flat \
           -command [list p_ique_search_send $cnt]
    bind $w <Control-a> [list p_ique_search_send $cnt]
    button $w.cancel -image  "vazgec" -height 24 -relief flat \
           -command [list destroy $w]
    bind $w <Control-period> [list destroy $w]
    pack $w.find $w.cancel -in $w.bottom -side left -padx 2m 

    pack $w.top $w.bottom

    focus $w.buddyname
}

#######################################################
# Routines for doing buddy edit
#######################################################
proc ique_edit_draw_list { {group ""} {name ""}} {
    if {[winfo exists .edit] != 1} {
        return
    }

    if {$name == ""} {
        .edit.list delete 0 end

        foreach g $::BUDDYLIST {
            .edit.list insert end $g
            foreach j $::GROUPS($g,people) {
                .edit.list insert end "   $::BUDDIES($j,name)"
            }
        }
    } else {
        set n 0
        set s [.edit.list size]
        while {1} {
            if {$group == [.edit.list get $n]} {
                break
            }
            incr n
        }
        incr n
        while { ($n < $s) } {
            set t [.edit.list get $n]
            if {[string index $t 0] != " "} {
                break
            }
            incr n
        }
        .edit.list insert $n "   $name"
    }
}

proc p_ique_edit_remove {} {
    set n [.edit.list curselection]
    if { $n == "" } {
        return
    }

    set name [.edit.list get $n]


    if {[string index $name 0] == " "} {
        .edit.list delete $n
        set norm [normalize $name]
        foreach i $::BUDDYLIST {
            incr n -1
            set c 0
            foreach j $::GROUPS($i,people) {
                if {$n == 0} {
                    set ::GROUPS($i,people) [lreplace $::GROUPS($i,people) $c $c]
                    if {[ique_is_buddy $j] == 0} {
                        tc_remove_buddy $::KULLANICI $j
                    }
                    break
                }
                incr n -1
                incr c
            }
            if {$n == 0} {
                break
            }
        }
    } else {
        set c 0
        foreach i $::BUDDYLIST {
            if {$i == $name} {
                set ::BUDDYLIST [lreplace $::BUDDYLIST $c $c]
                break
            }
            incr c
        }

        set g $::GROUPS($name,people)
        unset ::GROUPS($name,people)
        unset ::GROUPS($name,collapsed)
        foreach i $g {
            if {[ique_is_buddy $i] == 0} {
                tc_remove_buddy $::KULLANICI $i
            }
        }
        ique_edit_draw_list
    }
}

proc p_ique_edit_close {} {
    ique_set_config
    ique_draw_list
    destroy .edit
}

proc ique_create_edit {} {
    if {[winfo exists .edit]} {
        raise .edit
        ique_edit_draw_list
        return
    }

    toplevel .edit -class Ique
    wm title .edit "Kullanýcý Listesini Editle"
    wm iconname .edit "Kullanýcý Listesini Editle"
    if {$::IQUE(options,windowgroup)} {wm group .edit .login}

    frame .edit.listf
    scrollbar .edit.scroll -orient vertical -command [list .edit.list yview]
    listbox .edit.list -exportselection false \
           -yscrollcommand [list .edit.scroll set] 
    pack .edit.scroll -in .edit.listf -side right -fill y
    pack .edit.list -in .edit.listf -side left -expand 1 -fill both

    frame .edit.buttons
    button .edit.add -text "Ekle" -command ique_create_add
    bind .edit <Control-a> ique_create_add
    button .edit.remove -text "Sil" -command p_ique_edit_remove
    bind .edit <Control-r> p_ique_edit_remove
    button .edit.close -text "Kapat" -command p_ique_edit_close
    bind .edit <Control-period> p_ique_edit_close
    pack .edit.add .edit.remove .edit.close -in .edit.buttons -side left \
           -padx 2m

    pack .edit.buttons -side bottom
    pack .edit.listf -fill both -expand 1 -side top
    ique_edit_draw_list
}

#######################################################
# Routines for doing permit deny
#######################################################

proc ique_pd_draw_list { {group ""} {name ""}} {
    if {[winfo exists .pd] != 1} {
        return
    }

    .pd.list delete 0 end

    .pd.list insert end "Kabul"
    foreach i $::PERMITLIST {
        .pd.list insert end "   $i"
    }
    .pd.list insert end "Red"
    foreach i $::DENYLIST {
        .pd.list insert end "   $i"
    }
}

proc p_ique_pd_remove {} {
    set n [.pd.list curselection]
    if { $n == "" } {
        return
    }
    incr n -1
    set k 0
    foreach i $::PERMITLIST {
        if {$n == 0} {
            set ::PERMITLIST [lreplace $::PERMITLIST $k $k]
        }
        incr k
        incr n -1
    }

    incr n -1
    set k 0
    foreach i $::DENYLIST {
        if {$n == 0} {
            set ::DENYLIST [lreplace $::DENYLIST $k $k]
        }
        incr k
        incr n -1
    }

    ique_pd_draw_list
}

proc p_ique_pd_close {} {
    ique_set_config
    destroy .pd

    # This will flash us, but who cares, I am lazy. :(
    tc_add_permit $::KULLANICI
    tc_add_deny $::KULLANICI

    # Set everyone off line since we will get updates
    foreach g $::BUDDYLIST {
        foreach b $::GROUPS($g,people) {
            if {$::BUDDIES($b,type) == "IQUE"} {
                set ::BUDDIES($b,online) F
            }
        }
    }
    ique_draw_list

    # Send up the data
    if {$::PDMODE == "3"} {
        tc_add_permit $::KULLANICI $::PERMITLIST
    } elseif {$::PDMODE == "4"} {
        tc_add_deny $::KULLANICI $::DENYLIST
    }
}

proc ique_create_pd {} {
    if {[winfo exists .pd]} {
        raise .pd
        ique_pd_draw_list
        return
    }

    toplevel .pd -class Ique
    wm title .pd "Edit Kabul/Red"
    wm iconname .pd "Edit Kabul/Red"
    if {$::IQUE(options,windowgroup)} {wm group .pd .login}

    frame .pd.radios
    radiobutton .pd.all -value 1 -variable ::PDMODE \
       -text "Herkes bana baglanabilsin"
    radiobutton .pd.permit -value 3 -variable ::PDMODE \
       -text "Kabul ettigim sinifta olanlari onayla"
    radiobutton .pd.deny -value 4 -variable ::PDMODE \
       -text "Red sinifinda olanlari onaylama"
    pack .pd.all .pd.permit .pd.deny -in .pd.radios

    frame .pd.listf
    scrollbar .pd.scroll -orient vertical -command [list .pd.list yview]
    listbox .pd.list -exportselection false \
           -yscrollcommand [list .pd.scroll set] 
    pack .pd.scroll -in .pd.listf -side right -fill y
    pack .pd.list -in .pd.listf -side left -expand 1 -fill both

    frame .pd.buttons
    button .pd.add -text "Ekle" -command "ique_create_add pd"
    bind .pd <Control-a> ique_create_add
    button .pd.remove -text "Sil" -command p_ique_pd_remove
    bind .pd <Control-r> p_ique_pd_remove
    button .pd.close -text "Kapat" -command p_ique_pd_close
    bind .pd <Control-period> p_ique_pd_close
    pack .pd.add .pd.remove .pd.close -in .pd.buttons -side left -padx 2m

    pack .pd.buttons -side bottom
    pack .pd.radios .pd.listf -fill both -expand 1 -side top
    ique_pd_draw_list
}

#######################################################
# Routines for INFO
#######################################################
proc ique_set_info {info} {
    set ::IQUE(INFO,msg) $info
    set ::IQUE(INFO,sendinfo) 1
}

proc p_ique_setinfo_set {} {
    if {![winfo exists .setinfo.text]} {
        return
    }

    set ::IQUE(INFO,msg) [.setinfo.text get 0.0 end]
    set ::IQUE(INFO,sendinfo) 1
    tc_set_info $::KULLANICI $::IQUE(INFO,msg)
    destroy .setinfo
}

proc ique_show_version {} {
    set w .showver

    if {[winfo exists $w]} {
            raise $w
            return
    }

    toplevel $w -class Ique
    wm title $w "IQUE Anlik Ileti Sistemi $::VERSION"
    wm iconname $w "$::VERSION"

    image create photo logo -file media/Logo.gif

    label .showver.logo -image logo
    label .showver.status


    label $w.info -text "Anlik Ileti Sistemi"
    label $w.info1 -text "Surum $::VERSION"

    frame $w.buttons
    button $w.cancel -text "Tamam" -command [list destroy $w]
    pack $w.cancel -in $w.buttons -side left -padx 2m
    pack .showver.logo .showver.status
    pack $w.info -side top
    pack $w.info1 -side top
    pack $w.buttons -side bottom
}


proc ique_create_setinfo {} {
    set w .setinfo

    if {[winfo exists $w]} {
        raise $w
        return
    }

    toplevel $w -class Ique
    wm title $w "Gecici Bilgi Degisikligi"
    wm iconname $w "Bilgi Degisikligi"
    if {$::IQUE(options,windowgroup)} {wm group $w .login}

    text  $w.text -width 40 -height 10 -wrap word
    $w.text insert end $::IQUE(INFO,msg)

    frame $w.buttons
    button $w.set -text "Bilgi Ata" -command "p_ique_setinfo_set"
    button $w.cancel -text "Vazgec" -command [list destroy $w]
    pack $w.set $w.cancel -in $w.buttons -side left -padx 2m

    pack $w.buttons -side bottom
    pack $w.text -fill both -expand 1 -side top
}

#######################################################
# Routines for montior config files and packages
#######################################################

proc ique_default_set {var val} {
    if {![info exists ::IQUE($var)]} {
        set ::IQUE($var) $val
    }
}

proc socketcheck {conn var count} {
    if {[catch {fconfigure $conn -peername}] == 0} {
        set $var 1
        return
    }
    incr count -1
    if {$count == 0} {
        set $var 0
    } else {
        after 100 socketcheck $conn $var $count
    }
}

# don't use this anymore
proc ique_ping {host port var {cnt 10}} {
    set $var 1
}

proc getFILE {w txt {doColor 0}} {
    set bbox [$w bbox "end-1c"]
    set color "000000"

    set results [splitHTML $text]
    foreach e $results {
        $w insert end $e $style
    }
    if {$bbox != ""} {
        $w see end
    }
}

proc chat_disconnect {} {
    if {[string length [array names ::IQUE "chats,*,toplevel"]]!= 0} {

               return
       }
    if { !$::TCSTATS(TOGGLE_CONN)} {
           sflap::disconnect
       }
}

proc p_ique_invitew_close {id} {
    
    destroy $::IQUE(cinvites,$id,toplevel)
    foreach i [array names ::IQUE "cinvites,$id,*"] {
        unset ::IQUE($i)
    }
    chat_disconnect 
}
########################################################

#########################################################
proc destroy_window {type} {
    after 3000
    set tkcount [expr $::IQUE($type,cnt)-1] 
    destroy $::IQUE($type,$tkcount,toplevel)
    if {[string match "*ft_accept*" $type]} {
         foreach i [array names ::f "*,chckbut"] {
                unset ::f($i)
         }
    }
}

proc p_ft_reject {pname} {
   set tkcount [expr $::IQUE(ft_accept,cnt)-1] 
   $::IQUE(ft_accept,$tkcount,toplevel).accept configure -state disabled
   $::IQUE(ft_accept,$tkcount,toplevel).reject configure -state disabled
   set nname [normalize $::KULLANICI]
   sflap::close2 $nname $pname 
   set_ftaccept_status "$pname'in dosya gonderme teklifi geri cevrildi." 
   destroy_window ft_accept
}

proc p_delete_listbox_entry {w} {
     if {[$w.filedisplay index end]== 0} { 
          destroy $w          
          return
         }
     set index [$w.filedisplay curselection]
     if {$index==""} {
          tk_messageBox -message "Gondermekten vazgectiginiz bir dosya secmediniz."
          return
         }
     set tkcount [expr $::IQUE(ftws,cnt)-1] 
     set buddy $::IQUE(ftws,$tkcount,to)
         set ::PLIST($buddy) [lreplace $::PLIST($buddy) $index $index]
         $::IQUE(ftws,$tkcount,toplevel).filedisplay delete $index
     if {$::PLIST($buddy)==""} {
         $::IQUE(ftws,$tkcount,toplevel).send configure -state disabled     
         $::IQUE(ftws,$tkcount,toplevel).filedisplay configure -width 35
     }
}

proc p_ique_file_send {pname} {
    set tkcount [expr $::IQUE(ftws,cnt)-1] 
    $::IQUE(ftws,$tkcount,toplevel).cancel configure -state disabled
    $::IQUE(ftws,$tkcount,toplevel).send configure -state disabled
    $::IQUE(ftws,$tkcount,toplevel).add configure -state disabled

    if {$pname==""} {
        set pname $::IQUE(ftws,$tkcount,to)
    }
    set fnames {}
    set fsizes {}
    foreach path $::PLIST($pname) {
        set fsize [file size $path]
        set fname  [file tail $path]
        lappend fnames $fname
        lappend fsizes $fsize
    }
    set nname [normalize $::KULLANICI]
    if { [info exists ::BUDDIES($pname,IP)] } {
         set ipno $::BUDDIES($pname,IP)
         set port $::BUDDIES($pname,service)
         sflap::connect $nname $pname $ipno $port $nname ""
         tc_send_file_header $fnames $fsizes $pname
    } else {
         tk_messageBox -message "Bu kullanici aktif degil"
    }
}

proc set_ftaccept_status {msg} {
    set tkcount [expr $::IQUE(ft_accept,cnt)-1] 
    $::IQUE(ft_accept,$tkcount,toplevel).statusbar configure -text $msg
    update
}

proc set_ft_status {msg} {
    set tkcount [expr $::IQUE(ftws,cnt)-1] 
    $::IQUE(ftws,$tkcount,toplevel).statusbar configure -text $msg
    update
}
proc ique_create_open_file {} {
    set tkcount [expr $::IQUE(ftws,cnt)-1] 
    set buddy $::IQUE(ftws,$tkcount,to)
    if {$buddy==""} { 
         tk_messageBox -message " Alici ismi girmediniz"
         return
    }
    set typeList {    
        {{All Files} {.*}}
        }
    set fpath [tk_getOpenFile -initialdir /usr/src/TCL/tk8.0/library \
    -filetypes $typeList]
    if {$fpath!=""} {
        set w $::IQUE(ftws,$tkcount,toplevel)
        $w.filedisplay configure -width 0
        if {[$w.filedisplay index end]== 0} { 
             set ::PLIST($buddy) [list]
        }
        $w.filedisplay insert end $fpath
        lappend ::PLIST($buddy) $fpath
        $w.send configure -state active
    }
}

proc Receiving_Copy_More {in out  size bytes {error {}}} {
    incr ::total $bytes
    if {([string length $error] != 0) ||  [eof $in] || ( $size == $::total ) } {
	    set ::done $::total
            # err varsa buraya "error message"
    } else {
	    fcopy $in $out -command [list CopyMore $in $out $size] -size [expr $size - $::total]	
    }
}

proc Sending_Copy_More {in out  bytes {error {}}} {
    incr ::total $bytes
    if {([string length $error] != 0) || [eof $in]} {
	   set ::done $::total
    } else {
	   fcopy $in $out -command [list CopyMore $in $out ] 	 
    }
}
proc p_get_rejlist {pname} {
     set rejlist {}
     set length [expr [llength $::fnames($pname)]-1]
     for {set i 0} {$i <= $length} {incr i} {
          if {$::f($i,chckbut) == 0} {
              lappend rejlist $i
          }
     }    
     if {$length == [expr [llength $rejlist]-1]} {
         p_ft_reject $pname
         return
     }
     set i 0
     foreach rej $rejlist {
         set rmv [expr $rej - $i]
         set ::fnames($pname) [lreplace $::fnames($pname) $rmv $rmv]
         set ::fsizes($pname) [lreplace $::fsizes($pname) $rmv $rmv]
         incr i 
     }
     tc_accept_file $pname $rejlist
}

proc ique_create_ftw {cname pname} {
    set cnt 0
    catch {set cnt $::IQUE(ftws,cnt)}
    set ::IQUE(ftws,cnt) [expr $cnt + 1]

    set ::IQUE(ftws,$cnt,to) $pname

    set w .ftw$cnt
    set ::IQUE(ftws,$cnt,toplevel) $w

    toplevel $w -class $::IQUE(options,imWMClass)
    wm title $w "Dosya Gonder"
    wm iconname $w "Dosya Gonder"
    if {$::IQUE(options,windowgroup)} {wm group $w .login}

    bind $w <Motion> ique_non_idle_event

    frame $w.top 
    label $w.toL -text "Alici:"
    entry $w.to -width 16 -relief sunken -textvariable ::IQUE(ftws,$cnt,to)
    pack  $w.toL $w.to -in $w.top -side left

    frame $w.display
    listbox $w.filedisplay -selectmode single -exportselection no -height 10 \
            -yscrollcommand "$w.scroll set" -relief sunken
    scrollbar $w.scroll -command "$w.filedisplay yview"
    pack $w.filedisplay -in $w.display -side left
    pack $w.scroll -in $w.display -side right -expand 1 -fill y
    frame $w.isim3 
    label $w.isim3.x -font $::fnt  -text "Gönder         Ekle         Vazgec  "
    pack $w.isim3.x
    label $w.statusbar -text ""

    frame $w.bottom -relief groove -borderwidth 2
    button $w.send -image "gonder" -height 24 -relief flat -state disabled \
           -command [list p_ique_file_send $pname]
    bind $w <Control-s> "p_ique_invite_send $cnt; break"
    button $w.add -image "ekle" -height 24 -relief flat \
           -command [list ique_create_open_file]
    bind $w <Control-a> [list p_ique_invite_add $cnt]
    button $w.cancel -image "kapat" -height 24 -relief flat \
           -command [list p_delete_listbox_entry $w]
    bind $w <Control-period> [list destroy $w]
    pack $w.send $w.add $w.cancel -in $w.bottom -side left -padx 2m

    pack $w.top  $w.display  $w.bottom  $w.isim3 -side top
    pack $w.statusbar -side bottom
    if { $pname == ""} {
        focus $w.to
    } else {
        focus $w.filedisplay
    }
}

proc ique_create_ft_accept {pname} {
    set cnt 0
    catch {set cnt $::IQUE(ft_accept,cnt)}
    set ::IQUE(ft_accept,cnt) [expr $cnt + 1]

    set w .ft_accept$cnt
    toplevel $w -class $::IQUE(options,chatWMClass)
    wm title $w "Dosya Kabulu"
    wm iconname $w "Dosya Kabulu"
    if {$::IQUE(options,windowgroup)} {wm group $w .login}
    set ::IQUE(ft_accept,$cnt,toplevel) $w

    bind $w <Motion> ique_non_idle_event
    set maxl 0
    foreach fname $::fnames($pname) {
          if {[string length $fname] > $maxl } {
              set maxl [string length $fname]
	  }
    set i 0	                      }
    foreach fname $::fnames($pname) {
	set ff [frame $w.sub$i]
	pack $ff
        checkbutton $ff.c  -variable f($i,chckbut) -relief flat 
	label $ff.lab1 -text $fname -width $maxl -anchor e 
	label $ff.lab2 -text "[lindex $::fsizes($pname) $i] bayt" 
	pack $ff.c $ff.lab1 $ff.lab2 -side left -in $ff
	incr i
    }
    label $w.statusbar -text "$pname yukaridaki dosya(lari) gondermek istiyor." 
    frame $w.isim6

    label $w.isim6.x -font $::fnt  -text "Secilenlere Evet         Tumune Evet         Tumune Hayir  "
    pack $w.isim6.x

    frame $w.buttons -relief groove -borderwidth 2
    button $w.send -image "kabul" -height 24 -relief flat \
           -command [list p_get_rejlist $pname]
    bind $w <Control-s> [list get_rejlist $pname]
    button $w.accept -image "ekle" -height 24 -relief flat \
           -command [list tc_accept_file $pname ""]
    bind $w <Control-a> [list p_ique_invite_add $cnt]
    button $w.reject -image "kapat" -height 24 -relief flat \
           -command [list p_ft_reject $pname]

    bind $w <Control-period> [list destroy $w]
    pack $w.send $w.accept $w.reject -in $w.buttons -side left -padx 2m

    pack $w.buttons $w.isim6
    pack $w.statusbar  -side bottom
}



proc IZLEME { value } {
#     tk_messageBox -message $value
##    puts "$value"
}

#
# Burada takilabilir programlar yuklenecek
#
proc loadplugins { } {

    if { [info exists ::IQUE(progs)] } {
         foreach prg $::IQUE(progs) {
             if { [file extension $prg] == "dll"} {
                if { [catch {load $prg} err] } {
                     tk_messageBox -message $err
                }
             }
             if { [file extension $prg] == "tcl"} {
                if { [catch {source $prg} err] } {
                    tk_messageBox -message $err
                }
             }
         }
    }
}


#######################################################
# MAIN
#######################################################

# Globals
set ::IQUE(INFO,sendinfo) 0
set ::IQUE(INFO,msg) ""
set ::IQUE(IDLE,sent) 0
set ::IQUE(IDLE,timer) 0
if { $::IQUE(windows) } {
   set ::IQUE(configDir) "_ique"
} else {
   set ::IQUE(configDir) ".ique"
}
set ::IQUE(online) 0

set ::USEPROXY Yok

# Default OPTIONS
set ::IQUE(options,imtime)     1    ;# Display timestamps in IMs?
set ::IQUE(options,chattime)   1    ;# Display timestamps in Chats?

# Heights:  
#   ==  0 :One Line Entry.  Resizing keeps it 1 line
#   >=  1 :Text Entry, Multiline.  Resizing may increase number of lines
#   <= -1 :Text Entry, Multiline.  Same as >=1 but with scroll bar.
set ::IQUE(options,iimheight)  4    ;# Initial IM Entry Height
set ::IQUE(options,cimheight)  0    ;# Converation IM Entry Height
set ::IQUE(options,chatheight) 0    ;# Chat Entry Height

set ::IQUE(options,cimexpand)   0   ;# If cimheight is not 0, then this
                                   ;# determins if the entry area expands
                                   ;# on resize.

set ::IQUE(options,imcolor)          1           ;# Process IM colors?
set ::IQUE(options,defaultimcolor)   "#000000"   ;# Default IM color
set ::IQUE(options,chatcolor)        1           ;# Process Chat colors?
set ::IQUE(options,defaultchatcolor) "#000000"   ;# Default Chat color

set ::IQUE(options,windowgroup)   0     ;# Group all Tanimi windows together? 
set ::IQUE(options,raiseim)       1     ;# Raise IM window on new message
set ::IQUE(options,deiconifyim)   0     ;# Deiconify IM window on new message
set ::IQUE(options,raisechat)     1     ;# Raise Chat window on new message
set ::IQUE(options,deiconifychat) 0     ;# Deiconify Chat window on new message
set ::IQUE(options,monitorrc)     1     ;# Monitor rc file for changes?
set ::IQUE(options,monitorrctime) 20000 ;# Check for rc file changes how often (millisecs)
set ::IQUE(options,monitorpkg)     1     ;# Monitor pkgs for changes?
set ::IQUE(options,monitorpkgtime) 20000 ;# Check the pkg dir for changes how often (millisecs)

# 0 - Enter/Ctl-Enter insert NewLine,  Send Button Sends
# 1 - Ctl-Enter inserts NewLine,  Send Button/Enter Sends
# 2 - Enter inserts NewLine,  Send Button/Ctl-Enter Sends
# 3 - No Newlines,  Send Button/Ctl-Enter/Enter Sends
set ::IQUE(options,msgsend) 1

# 0 - Use the config from the host
# 1 - Use the config from ./.ique/KULLANICI.cnf
# 2 - Use the config from ./.ique/KULLANICI.cnf & keep this config
#     on the host.  (Remember the host has a 1k config limit!)
set ::IQUE(options,localconfig) 0

# 0 - Don't report idle time
# 1 - Report idle time
set ::IQUE(options,reportidle) 1

# Kullanýcý Colors
set ::IQUE(options,buddymcolor) black
set ::IQUE(options,buddyocolor) blue
set ::IQUE(options,groupmcolor) black
set ::IQUE(options,groupocolor) red

# Sound Names
set ::IQUE(SOUND,Send)    media/Send.wav
set ::IQUE(SOUND,Receive) media/Receive.wav
set ::IQUE(SOUND,Arrive)  media/BuddyArrive.wav
set ::IQUE(SOUND,Depart)  media/BuddyLeave.wav

# Window Manager Classes
set ::IQUE(options,imWMClass) Ique
set ::IQUE(options,chatWMClass) Ique

# Register the callbacks, we are cheesy and use the
# same function names as the message names.
tc_register_func * SIGN_ON           SIGN_ON
tc_register_func * CONFIG            CONFIG
tc_register_func * NICK              NICK
tc_register_func * IM_IN             IM_IN
tc_register_func * tc_send_im        IM_OUT
tc_register_func * UPDATE_BUDDY      UPDATE_BUDDY
tc_register_func * ERROR             ERROR
tc_register_func * EVILED            EVILED
tc_register_func * CHAT_JOIN         CHAT_JOIN
tc_register_func * CHAT_IN           CHAT_IN
tc_register_func * CHAT_UPDATE_BUDDY CHAT_UPDATE_BUDDY
tc_register_func * CHAT_INVITE       CHAT_INVITE
tc_register_func * CHAT_LEFT         CHAT_LEFT
tc_register_func * GOTO_URL          GOTO_URL
tc_register_func * PAUSE             PAUSE
tc_register_func * CONNECTION_CLOSED CONNECTION_CLOSED
tc_register_func * DISCONNECT        DISCONNECT
tc_register_func * FILE_IN           FILE_IN
tc_register_func * REGISTER          REGISTER
tc_register_func * PASSWD            PASSWD
tc_register_func * SEARCH            SEARCH

#user registery constants
set ::kayit(siniflar) {{Internet} {Uzman} {Yonetim} {Genel} }
set ::kayit(cinsler) { {Erkek} {Kadin} }
set ::kayit(ogrenimler) { {Ilk} {Orta} {Lise} {Yuksek} }
set ::kayit(mdurumlar) { {Bekar} {Evli} }
set ::kayit(meslekler) { {Ogretmen} {Muhendis} }
set ::kayit(ulkeler) { {Turkiye} {Diger} }


# Set up the fonts that we use for all "entry" and "text" widgets.
# First we create a fake label and find out the font Tk uses for
# that.  We use this as the defaults for the rest.  
label .fonttest
set ::IQUEFONT [font actual [.fonttest cget -font]]
destroy .fonttest
set ::SAGFONT [eval font create $::IQUEFONT -family helvetica -size -12 -weight normal ]
set ::NORMALFONT [eval font create $::IQUEFONT -weight normal ]
set ::BOLDFONT [eval font create $::IQUEFONT -weight bold]
set ::ITALICFONT [eval font create $::IQUEFONT -weight normal -slant italic]

set ::IQUE(prefile) $::IQUE(configDir)/iquepre
set ::IQUE(pkgDir) packages

# Set up the available tcs and auths.
set TCS [list uretim]
set AUTHS [list uretim]

set ::TESTHOST "212.175.17.6"
set AUTH(uretim,port) 33001 ;# Any port will work
set TC(uretim,port) 8901 ;# Any port will work

# Load the pre user config
if {[file exists $::IQUE(prefile)] == 1} {
    # burada TESTHOST ve port tanimlari bulunuyor
    source $::IQUE(prefile)
}

set TC(uretim,host) $::TESTHOST
set AUTH(uretim,host) $::TESTHOST

set ::SELECTEDAUTH "uretim"
set ::SELECTEDTC "uretim"

set VERSION "I-QUE 1.00"
set REVISION {I-QUE:Surum:1.00}

set ::IQUE(CODE) "HerHangiBir"

set SOUNDPLAYING 0
##########images###############

set ::fnt {times 12 bold}
set xh [pwd]
if { $::IQUE(windows) } {
   set ::fnt {times 10 bold}
}
image create photo cat -file "$xh/media/cat.gif"
image create photo mesaj -file "$xh/media/mesaj.gif"
image create photo bilgi -file "$xh/media/bilgi.gif"
image create photo gonder -file "$xh/media/gonder.gif"
image create photo fisilda -file "$xh/media/fisilda.gif"
image create photo uyar -file "$xh/media/uyar.gif"
image create photo vazgec -file "$xh/media/vazgec.gif"
image create photo davet -file "$xh/media/davet.gif"
image create photo anlik -file "$xh/media/anlik.gif"
image create photo renk -file "$xh/media/renk.gif"
image create photo kapat -file "$xh/media/kapat.gif"
image create photo ekle -file "$xh/media/ekle.gif"
image create photo kabul -file "$xh/media/kabul.gif"
image create photo ftransfer -file "$xh/media/ftransfer.gif"

loadplugins

if { ! [file exists $::IQUE(configDir)] } {
    catch {
        tk_messageBox -message "$::IQUE(configDir) yolu yaratiliyor\n"
        file mkdir $::IQUE(configDir) }
        
    if { $::IQUE(windows) } {
        tk_messageBox -message "Tanimlama dosyasi $::IQUE(configDir) altinda yaratiliyor"
    } else {
        catch {exec chmod og-rwx $::IQUE(configDir)}
        tk_messageBox -message "Tanimlama dosyasi $::IQUE(configDir) altinda yaratiliyor"
        catch {file copy example.iquepre $::IQUE(configDir)/iquepre }
    }
    #
    # login ekranindan once kayit ol ekranini goruntule
    #
    create_kayitol
    ique_kayitol
    tkwait window .top17
    if { $::kayit(cik) } {
         destroy .
         exit
    }
}

# Create the windows
ique_create_login
ique_create_buddy

# Show the login screen and set the initial status to the version of Ique.
ique_show_login
setStatus $VERSION


catch {set KULLAN $IQUE(clUser)}
catch {set PASSWORD $IQUE(clPass)}
